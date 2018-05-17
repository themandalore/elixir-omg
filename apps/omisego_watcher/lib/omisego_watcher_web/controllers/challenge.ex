defmodule OmiseGOWatcherWeb.Controller.Challenge do
  @moduledoc """
  Handles exit challenges
  """

  use OmiseGOWatcherWeb, :controller

  @doc """
  Challenges exits
  """
  def challenge(conn, utxo_exit) do
    challenge = OmiseGOWatcher.Challenger.challenge(utxo_exit)
  end
end
