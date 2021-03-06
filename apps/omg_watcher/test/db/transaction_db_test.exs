# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.DB.TransactionDBTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OMG.API.Fixtures
  use Plug.Test

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.DB.TransactionDB
  alias OMG.Watcher.DB.TxOutputDB

  require Utxo

  @eth Crypto.zero_address()

  describe "Transaction database" do
    @tag fixtures: [:initial_blocks]
    test "verifies all expected transaction were inserted", %{initial_blocks: initial_blocks} do
      initial_blocks
      |> Enum.each(fn {blknum, txindex, txhash, recovered_tx} ->
        %Transaction.Recovered{signed_tx: %Transaction.Signed{signed_tx_bytes: txbytes}} = recovered_tx

        assert %TransactionDB{
                 txhash: ^txhash,
                 blknum: ^blknum,
                 txindex: ^txindex,
                 txbytes: ^txbytes
               } = TransactionDB.get(txhash)
      end)
    end

    @tag fixtures: [:initial_blocks]
    test "gets all transactions from a block", %{initial_blocks: initial_blocks} do
      [tx0, tx1] = TransactionDB.get_by_blknum(3000)

      tx_hashes =
        initial_blocks
        |> Enum.filter(&(elem(&1, 0) == 3000))
        |> Enum.map(&elem(&1, 2))

      assert tx_hashes == [tx0, tx1] |> Enum.map(& &1.txhash)

      assert [] == TransactionDB.get_by_blknum(5000)
    end

    @tag fixtures: [:initial_blocks, :alice, :bob]
    test "gets transaction that spends utxo", %{alice: alice, bob: bob, initial_blocks: initial_blocks} do
      alice_deposit_pos = Utxo.position(1, 0, 0)
      alice_deposit_hash = OMG.Watcher.DB.EthEventDB.generate_unique_key(alice_deposit_pos, :deposit)
      bob_deposit_pos = Utxo.position(2, 0, 0)
      alice_addr = alice.addr
      bob_addr = bob.addr

      assert {:error, :utxo_not_spent} = TransactionDB.get_transaction_challenging_utxo(bob_deposit_pos)

      {blknum, txindex, spending_tx, _tx} = initial_blocks |> Enum.at(0)

      assert {:ok,
              %TransactionDB{
                txhash: ^spending_tx,
                blknum: ^blknum,
                txindex: ^txindex,
                inputs: [
                  %TxOutputDB{creating_deposit: ^alice_deposit_hash, owner: ^alice_addr, currency: @eth, amount: 333}
                ],
                outputs: [%TxOutputDB{creating_txhash: ^spending_tx, owner: ^bob_addr, currency: @eth, amount: 300}]
              }} = TransactionDB.get_transaction_challenging_utxo(alice_deposit_pos)

      alice_spent = Utxo.position(1000, 1, 0)
      {_blknum, _txindex, creating_tx, _tx} = initial_blocks |> Enum.find(&(elem(&1, 1) == 1))
      {blknum, txindex, spending_tx, _tx} = initial_blocks |> Enum.find(&(elem(&1, 0) == 2000))

      assert {:ok,
              %TransactionDB{
                txhash: ^spending_tx,
                blknum: ^blknum,
                txindex: ^txindex,
                inputs: [%TxOutputDB{creating_txhash: ^creating_tx, owner: ^alice_addr, currency: @eth, amount: 100}],
                outputs: [
                  %TxOutputDB{creating_txhash: ^spending_tx, owner: ^bob_addr, currency: @eth, amount: 99},
                  %TxOutputDB{creating_txhash: ^spending_tx, owner: ^alice_addr, currency: @eth, amount: 1}
                ]
              }} = TransactionDB.get_transaction_challenging_utxo(alice_spent)
    end

    @tag fixtures: [:initial_blocks, :bob]
    test "transaction does not defend against double-spend", %{bob: bob} do
      # This intends to make you aware that DB-layer does not protect against double spending
      spent_txo = Utxo.position(1000, 1, 1)
      {:ok, %TransactionDB{txhash: spent_txhash}} = TransactionDB.get_transaction_challenging_utxo(spent_txo)

      assert %TxOutputDB{
               spending_txhash: ^spent_txhash
             } = TxOutputDB.get_by_position(spent_txo)

      [{:ok, %TransactionDB{txhash: double_spent_txhash}}] =
        TransactionDB.update_with(%{
          transactions: [OMG.API.TestHelper.create_recovered([{1000, 1, 1, bob}], @eth, [{bob, 200}])],
          blknum: 11_000,
          eth_height: 10
        })

      assert %TxOutputDB{
               spending_txhash: ^double_spent_txhash
             } = TxOutputDB.get_by_position(spent_txo)
    end
  end
end
