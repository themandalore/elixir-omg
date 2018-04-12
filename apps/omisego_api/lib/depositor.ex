defmodule OmiseGO.API.Depositor do
  @moduledoc """
  Periodically fetches deposits made on dynamically changing block range
  on parent chain and feeds them to state.
  """

  alias OmiseGO.Eth
  alias OmiseGO.API.EventListener.Core
  alias OmiseGO.API.State

  ### Client

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ### Server

  use GenServer

  def init(:ok) do
    #TODO: initialize state with the last ethereum block we have seen deposits from
    block_finality_margin = Application.get_env(:omisego_api, :depositor_block_finality_margin)
    max_blocks_in_fetch = Application.get_env(:omisego_api, :depositor_max_block_range_in_deposits_query)
    get_deposits_interval = Application.get_env(:omisego_api, :depositor_get_deposits_interval_ms)

    with {:ok, parent_start} <- Eth.get_root_deployment_height() do
      schedule_get_deposits(0)
      {:ok,
       %Core{
         last_event_block: parent_start,
         block_finality_margin: block_finality_margin,
         max_blocks_in_fetch: max_blocks_in_fetch,
         get_events_inerval: get_deposits_interval
       }
      }
    end
  end

  def handle_info(:get_deposits, state) do
    with {:ok, eth_block_height} <- Eth.get_ethereum_height(),
         {:ok, new_state, next_get_deposits_interval, eth_block_from, eth_block_to} <-
           Core.get_events_block_range(state, eth_block_height),
         {:ok, deposits} <- Eth.get_deposits(eth_block_from, eth_block_to),
         :ok <- State.deposit(deposits) do
      schedule_get_deposits(next_get_deposits_interval)
      {:no_reply, new_state}
    else
      {:no_blocks_with_event, state, next_get_deposits_interval} ->
        schedule_get_deposits(next_get_deposits_interval)
        {:no_reply, state}
      _ -> {:stop, :failed_to_get_deposits, state}
    end
  end

  defp schedule_get_deposits(interval) do
    Process.send_after(self(), :get_deposits, interval)
  end
end