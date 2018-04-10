defmodule OmiseGO.API.Integration.HappyPathTest do
  @moduledoc """
  Tests a simple happy path of all the pieces working together
  """

  use ExUnitFixtures
  use ExUnit.Case, async: false

  alias OmiseGO.DB

  alias OmiseGO.API.State.Transaction

  @moduletag :requires_geth

  deffixture db_path_config() do
    dir = Temp.mkdir!()

    Application.put_env(:omisego_db, :leveldb_path, dir, persistent: true)
    {:ok, started_apps} = Application.ensure_all_started(:omisego_db)

    on_exit fn ->
      Application.put_env(:omisego_db, :leveldb_path, nil)
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture geth do
    {:ok, exit_fn} = OmiseGO.Eth.geth()
    on_exit(exit_fn)
    :ok
  end

  # FIXME: copied from eth/fixtures - DRY
  deffixture contract(geth) do
    _ = geth
    {from, {txhash, contract_address}} = OmiseGO.Eth.DevHelpers.create_new_contract()

    %{
      address: contract_address,
      from: from,
      txhash: txhash
    }
  end

  deffixture root_chain_contract_config(geth, contract) do
    # prevent warnings
    :ok = geth

    Application.put_env(:omisego_eth, :contract, contract.address, persistent: true)
    Application.put_env(:omisego_eth, :omg_addr, contract.from, persistent: true)
    Application.put_env(:omisego_eth, :txhash_contract, contract.txhash, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omisego_eth)

    on_exit fn ->
      Application.put_env(:omisego_eth, :contract, "0x0")
      Application.put_env(:omisego_eth, :omg_addr, "0x0")
      Application.put_env(:omisego_eth, :txhash_contract, "0x0")
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  deffixture db_initialized(db_path_config) do
    :ok = db_path_config
    :ok = OmiseGO.DB.multi_update([{:put, :last_deposit_block_height, 0}])
    # FIXME the latter doesn't work yet
    # OmiseGO.DB.multi_update([{:put, :child_top_block_number, 0}])
    :ok
  end

  deffixture omisego(root_chain_contract_config, db_initialized) do
    :ok = root_chain_contract_config
    :ok = db_initialized
    {:ok, started_apps} = Application.ensure_all_started(:omisego_api)

    on_exit fn ->
      started_apps
        |> Enum.reverse()
        |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end
    :ok
  end

  # FIXME dry the fixtures for entities
  import OmiseGO.API.TestHelper

  deffixture entities do
    %{
      alice: generate_entity(),
      bob: generate_entity(),
      carol: generate_entity(),
    }
  end

  deffixture(alice(entities), do: entities.alice)
  deffixture(bob(entities), do: entities.bob)
  deffixture(carol(entities), do: entities.carol)

  @tag fixtures: [:alice, :bob, :omisego]
  test "deposit, spend, exit, restart etc works fine", %{alice: alice, bob: bob} do

    tx =
      %Transaction{
        blknum1: 1, txindex1: 0, oindex1: 0, blknum2: 0, txindex2: 0, oindex2: 0,
        newowner1: bob.addr, amount1: 7, newowner2: alice.addr, amount2: 3, fee: 0,
      }
      |> Transaction.sign(alice.priv, <<>>)
      |> Transaction.Signed.encode()

    {:error, :utxo_not_found} = OmiseGO.API.submit(tx)

    # FIXME should actually be called from Eth-driven Depositor
    :ok = OmiseGO.API.State.deposit([%{owner: alice.addr, amount: 10, blknum: 1}])

    :ok = OmiseGO.API.submit(tx)

    # FIXME: should actuallly be called by the Eth-driven BlockQueue
    # FIXME: block hash should be axquired from the contract too
    {:ok, block_hash} = OmiseGO.API.State.form_block(1000, 2000)

    assert :not_found = OmiseGO.API.get_block(<<0::size(256)>>)
    assert %OmiseGO.API.Block{hash: ^block_hash} = OmiseGO.API.get_block(block_hash)

    # FIXME - should actually stop and start apps to check if persistence works fine
    assert {:ok, [
      %{{1000, 0, 0} => %{amount: 7, owner: bob.addr}},
      %{{1000, 0, 1} => %{amount: 3, owner: alice.addr}}
    ]} == DB.utxos()

    {:error, :utxo_not_found} = OmiseGO.API.submit(tx)

    {:ok, _block_hash} = OmiseGO.API.State.form_block(2000, 3000)
  end

end
