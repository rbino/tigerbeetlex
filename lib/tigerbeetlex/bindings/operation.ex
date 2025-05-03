defmodule TigerBeetlex.Operation do
  @moduledoc """
  This module contains utility functions around tb_client Operation enum.
  It allows retrieving all available operations and convert between their
  atom and integer representation.
  """

  @doc """
  Obtain the list of atoms with all available operations.
  """
  def available_operations do
    [
      :create_accounts,
      :create_transfers,
      :lookup_accounts,
      :lookup_transfers,
      :get_account_transfers,
      :get_account_balances,
      :query_accounts,
      :query_transfers
    ]
  end

  @doc """
  Obtains the integer representation of an operation from its atom value.
  """
  def from_atom(:create_accounts), do: 138
  def from_atom(:create_transfers), do: 139
  def from_atom(:lookup_accounts), do: 140
  def from_atom(:lookup_transfers), do: 141
  def from_atom(:get_account_transfers), do: 142
  def from_atom(:get_account_balances), do: 143
  def from_atom(:query_accounts), do: 144
  def from_atom(:query_transfers), do: 145
end
