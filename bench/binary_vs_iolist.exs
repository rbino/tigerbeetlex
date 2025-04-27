# Benchmark to measure the impact of storing the binary-serialized
# structs in a iolist, serializing them in a big binary only inside
# the NIF using enif_inspect_iolist_as_binary.

alias TigerBeetlex.Transfer

{:ok, client} =
  TigerBeetlex.connect(<<0::128>>, ["3000"])

max_batch_size = 8189

base_transfer = %Transfer{
  id: <<0::unsigned-little-size(128)>>,
  debit_account_id: <<0::unsigned-little-size(128)>>,
  credit_account_id: <<0::unsigned-little-size(128)>>,
  ledger: 1,
  code: 1,
  amount: 10
}

inputs =
  [1, 10, 100, 1000, max_batch_size]
  |> Map.new(fn n ->
    label = if n == 1, do: "transfer", else: "transfers"
    {"#{n} #{label}", List.duplicate(base_transfer, n)}
  end)

# Since we're only interested in measuring the speed to serialize
# the input, we use the message-based client and only measure the
# request phase, but we wait for the response before making a new
# request to always start from a clean state
Benchee.run(
  %{
    "create_transfers" => fn input ->
      TigerBeetlex.create_transfers(client, input)
    end,
    "create_transfers_iolist" => fn input ->
      TigerBeetlex.create_transfers_iolist(client, input)
    end
  },
  after_each: fn {:ok, ref} ->
    receive do
      {:tigerbeetlex_response, ^ref, _response} ->
        :ok
    after
      1_000 ->
        raise ""
    end
  end,
  inputs: inputs,
  time: 30
)
