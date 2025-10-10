defmodule TigerBeetlex.Operation do
  @moduledoc false

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

  def from_atom_func(:create_accounts), do: 138
  def from_atom_func(:create_transfers), do: 139
  def from_atom_func(:lookup_accounts), do: 140
  def from_atom_func(:lookup_transfers), do: 141
  def from_atom_func(:get_account_transfers), do: 142
  def from_atom_func(:get_account_balances), do: 143
  def from_atom_func(:query_accounts), do: 144
  def from_atom_func(:query_transfers), do: 145

  defmacro from_atom(atom) when is_atom(atom) do
    from_atom_func(atom)
  end

  defmacro from_atom(other) do
    quote do
      unquote(__MODULE__).from_atom_func(unquote(other))
    end
  end
end
