{:ok, client} = TigerBeetlex.NifAdapter.client_init(0, "3000", 1)

samples = 1_000_000
batch_size = 8191

bench = fn ->
  chunks =
    Enum.chunk_every(0..(samples - 1), batch_size)
    |> Enum.map(fn chunk ->
      chunk
      |> Enum.with_index()
      |> Enum.map(&elem(&1, 1))
    end)

  {total, max} =
    Enum.reduce(chunks, {0, 0}, fn chunk, {time_total_us, max_batch_us} ->
      start_batch = :erlang.monotonic_time()
      {:ok, batch} = TigerBeetlex.NifAdapter.create_transfer_batch(batch_size)

      Enum.each(chunk, fn idx ->
        :ok = TigerBeetlex.NifAdapter.add_transfer(batch)

        :ok =
          TigerBeetlex.NifAdapter.set_transfer_id(batch, idx, <<0::unsigned-little-size(128)>>)

        :ok =
          TigerBeetlex.NifAdapter.set_transfer_debit_account_id(
            batch,
            idx,
            <<0::unsigned-little-size(128)>>
          )

        :ok =
          TigerBeetlex.NifAdapter.set_transfer_credit_account_id(
            batch,
            idx,
            <<0::unsigned-little-size(128)>>
          )

        :ok = TigerBeetlex.NifAdapter.set_transfer_ledger(batch, idx, 1)
        :ok = TigerBeetlex.NifAdapter.set_transfer_code(batch, idx, 1)
        :ok = TigerBeetlex.NifAdapter.set_transfer_amount(batch, idx, 10)
      end)

      submit_fun = fn ->
        {:ok, ref} = TigerBeetlex.NifAdapter.create_transfers(client, batch)

        receive do
          {:tigerbeetlex_response, ^ref, response} -> response
        end
      end

      {elapsed, response} = :timer.tc(submit_fun)

      {_operation, _status, result} = response

      if byte_size(result) / 8 != length(chunk), do: raise("Invalid result")

      max = max(max_batch_us, elapsed)
      total = time_total_us + elapsed
      {total, max}
    end)

  IO.puts("Total time: #{total / 1000} ms")
  IO.puts("Max time per batch: #{max / 1000} ms")
  IO.puts("Transfers per second: #{samples * 1_000_000 / total}")
end

Enum.each(1..10, fn idx ->
  IO.puts("Run #{idx}")
  bench.()
end)
