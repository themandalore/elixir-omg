defmodule OmiseGO.API.UtxoPositionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import OmiseGO.API.UtxoPosition, only: :macros
  alias OmiseGO.API.UtxoPosition

  test "encode and decode the utxo position checking" do
    decoded = utxo_position(blknum: 4, txindex: 5, oindex: 1)
    assert 4_000_050_001 = encoded = UtxoPosition.encode(decoded)
    assert decoded == UtxoPosition.decode(encoded)
  end
end
