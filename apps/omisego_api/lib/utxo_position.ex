defmodule OmiseGO.API.UtxoPosition do
  @moduledoc """
  Representation of a utxo position, handles the encoding/decoding to/from single integer required by the contract
  """

  require Record

  @block_offset 1_000_000_000
  @transaction_offset 10_000

  @type t() :: record(:utxo_position,
          blknum: pos_integer,
          txindex: non_neg_integer,
          oindex: non_neg_integer
        )

  Record.defrecord :utxo_position, [blknum: 0, txindex: 0, oindex: 0]

  @spec encode(t()) :: pos_integer()
  def encode(utxo_position(blknum: blknum, txindex: txindex, oindex: oindex)) do
    blknum * @block_offset + txindex * @transaction_offset + oindex
  end

  @spec decode(pos_integer()) :: t()
  def decode(encoded) when encoded > @block_offset do
    blknum = div(encoded, @block_offset)
    txindex = encoded |> rem(@block_offset) |> div(@transaction_offset)
    oindex = rem(encoded, @transaction_offset)

    utxo_position(blknum: blknum, txindex: txindex, oindex: oindex)
  end
end
