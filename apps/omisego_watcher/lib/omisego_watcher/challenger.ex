defmodule OmiseGOWatcher.Challenger do
  @moduledoc """
  Manages challenges of exits
  """

  def challenge(_utxo_exit) do
    :challenged
  end

  @doc """
  Returns challenge for exit
  """
  def create_challenge(%{blknum: blknum, txindex: txindex, oindex: oindex} = utxo_exit) do
    with offending_tx <- OmiseGOWatcher.TransactionDB.get_transaction_spending_utxo(utxo_exit),
         offending_block <-
           OmiseGOWatcher.TransactionDB.get_transactions_from_block(offending_tx[:txblknum]) |> create_block,
         challenge <-
           OmiseGO.API.Block.prove_transaction(offending_block, offending_tx[:txblknum])
           |> create_challenge(utxo_exit, offending_tx) do
      OmiseGO.Eth.challenge(challenge)
    end
  end

  defp create_block(transaction_in_block) do
  end

  defp create_challenge(proof, utxo, offending_tx) do
  end
end
