defmodule OmiseGOWatcher.Challenger.Challenge do
  @moduledoc """
  Represents a challenge
  """

  defstruct cutxopos: 0, eutxopos: 0, txbytes: nil, proof: nil, sigs: nil
end
