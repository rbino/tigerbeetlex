alias TigerBeetlex.Connection
alias TigerBeetlex.TransferBatch

{:ok, _pid} =
  Connection.start_link(
    name: :tb,
    cluster_id: 0,
    addresses: ["3000"],
    concurrency_max: 1,
    partitions: 1
  )

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
      batch =
        Enum.reduce(chunk, TransferBatch.new!(batch_size), fn _idx, acc ->
          TransferBatch.add_transfer!(acc,
            id: <<0::unsigned-little-size(128)>>,
            debit_account_id: <<0::unsigned-little-size(128)>>,
            credit_account_id: <<0::unsigned-little-size(128)>>,
            ledger: 1,
            code: 1,
            amount: 10
          )
        end)

      {elapsed, response} = :timer.tc(fn -> Connection.create_transfers(:tb, batch) end)

      {:ok, stream} = response

      if length(Enum.to_list(stream)) != length(chunk), do: raise("Invalid result")

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
