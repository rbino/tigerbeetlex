alias TigerBeetlex.TransferBatch

{:ok, _pid} =
  TigerBeetlex.start_link(
    name: :tb,
    cluster_id: 0,
    addresses: ["3000"],
    concurrency_max: 1
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
      {:ok, batch} = TransferBatch.new(batch_size)

      Enum.each(chunk, fn _idx ->
        {:ok, _batch} =
          TransferBatch.add_transfer(batch,
            id: <<0::unsigned-little-size(128)>>,
            debit_account_id: <<0::unsigned-little-size(128)>>,
            credit_account_id: <<0::unsigned-little-size(128)>>,
            ledger: 1,
            code: 1,
            amount: 10
          )
      end)

      {elapsed, response} = :timer.tc(fn -> TigerBeetlex.create_transfers(:tb, batch) end)

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
