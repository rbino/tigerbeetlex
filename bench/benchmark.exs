alias TigerBeetlex.Connection
alias TigerBeetlex.Transfer

{:ok, _pid} =
  Connection.start_link(
    name: :tb,
    cluster_id: <<0::128>>,
    addresses: ["3000"],
    partitions: 1
  )

samples = 1_000_000
batch_size = 8189

bench = fn ->
  chunks =
    0..(samples - 1)
    |> Enum.chunk_every(batch_size)
    |> Enum.map(fn chunk ->
      chunk
      |> Enum.with_index()
      |> Enum.map(&elem(&1, 1))
    end)

  {total, max} =
    Enum.reduce(chunks, {0, 0}, fn chunk, {time_total_us, max_batch_us} ->
      transfers =
        for _idx <- chunk do
          %Transfer{
            id: <<0::unsigned-little-size(128)>>,
            debit_account_id: <<0::unsigned-little-size(128)>>,
            credit_account_id: <<0::unsigned-little-size(128)>>,
            ledger: 1,
            code: 1,
            amount: 10
          }
        end

      {elapsed, response} = :timer.tc(fn -> Connection.create_transfers(:tb, transfers) end)

      {:ok, results} = response

      if length(results) != length(chunk), do: raise("Invalid result")

      max = max(max_batch_us, elapsed)
      total = time_total_us + elapsed
      {total, max}
    end)

  IO.puts("Total time: #{round(total / 1000)} ms")
  IO.puts("Max time per batch: #{round(max / 1000)} ms")
  IO.puts("Transfers per second: #{round(samples * 1_000_000 / total)}\n")
end

for _idx <- 1..10 do
  bench.()
end
