#######################################################
# This file was auto-generated by elixir_bindings.zig #
#              Do not manually modify.                #
#######################################################

defmodule TigerBeetlex.AccountFilterFlags do
  import Bitwise

  @moduledoc """
  See [AccountFilterFlags](https://docs.tigerbeetle.com/reference/account-filter#flags).
  """

  @doc """
  See [debits](https://docs.tigerbeetle.com/reference/account-filter#flagsdebits).
  """
  def debits(current \\ 0) do
    current ||| 1 <<< 0
  end

  @doc """
  See [credits](https://docs.tigerbeetle.com/reference/account-filter#flagscredits).
  """
  def credits(current \\ 0) do
    current ||| 1 <<< 1
  end

  @doc """
  See [reversed](https://docs.tigerbeetle.com/reference/account-filter#flagsreversed).
  """
  def reversed(current \\ 0) do
    current ||| 1 <<< 2
  end

  @doc """
  Given an integer flags value, returns a list of atoms indicating which flags are set.
  """
  def int_to_flags(int_value) when is_integer(int_value) do
    flags = []

    flags =
      if (int_value &&& debits()) != 0 do
        [:debits | flags]
      else
        flags
      end

    flags =
      if (int_value &&& credits()) != 0 do
        [:credits | flags]
      else
        flags
      end

    flags =
      if (int_value &&& reversed()) != 0 do
        [:reversed | flags]
      else
        flags
      end

    Enum.reverse(flags)
  end
end
