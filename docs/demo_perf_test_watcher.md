# Submitting transactions using the PerfTest's sender machine and watching using Watcher

The following demo is a mix of commands executed in IEx (Elixir's) REPL (see README.md for instructions) and shell.
**NOTE**: start IEx REPL with code and config loaded, as described in README.md instructions.

```elixir

### PREPARATIONS

# run the child chain and watcher, FIXME: how?


# we're going to be using the exthereum's client to geth's JSON RPC
{:ok, _} = Application.ensure_all_started(:ethereumex)

# (paste output from `prepare_env!` to setup the REPL environment)
contract_address = Application.get_env(:omisego_eth, :contract_addr)

Code.load_file("apps/omisego_api/test/testlib/test_helper.ex")
alias OmiseGO.{API, Eth}
alias OmiseGO.API.TestHelper

### UGLY setup begin FIXME: prettify
{:ok, _} = Application.ensure_all_started(:jsonrpc2)
:tx_hash

defmodule Parallel do
  def pmap(collection, func) do
    collection
    |> Enum.map(&(Task.async(fn -> func.(&1) end)))
    |> Enum.map(fn task -> Task.await(task, :infinity) end)
  end
end

# necessary, because the parallel requests take a lot of time
Application.put_env(:ethereumex, :request_timeout, :infinity)
Application.put_env(:ethereumex, :http_options, [recv_timeout: :infinity])
### UGLY setup end


### START DEMO HERE

# sends a deposit transaction _to Ethereum_
deposit_amount = 10_000_000_000_000

do_single_deposit = fn _number ->

  alice = TestHelper.generate_entity()
  {:ok, alice_enc} = Eth.DevHelpers.import_unlock_fund(alice)


  {:ok, deposit_tx_hash} = Eth.DevHelpers.deposit(deposit_amount, 0, alice_enc, contract_address)

  # need to wait until its mined
  {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)

  # we need to uncover the height at which the deposit went through on the root chain
  # to do this, look in the logs inside the receipt printed just above
  deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)
  %{owner: alice, blknum: deposit_blknum, amount: deposit_amount}
end

n_senders = 10

deposits =
  1..n_senders |>
  Parallel.pmap(do_single_deposit)

# wait for logs about deposit being recognized by the child chain ~10 seconds
Task.start(fn -> OmiseGO.Performance.SenderManager.start_link_all_senders(10_000, n_senders, %{destdir: ".", deposits: deposits}) end)
