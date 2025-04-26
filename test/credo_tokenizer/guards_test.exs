defmodule CredoTokenizer.GuardsTest do
  use ExUnit.Case
  doctest CredoTokenizer.Guards

  import CredoTokenizer.Guards

  test "should apply guard for opening parens correctly" do
    Enum.each(["(", "[", "{"], fn source ->
      [token] = CredoTokenizer.tokenize(source)

      assert is_opening_paren(token)
      refute is_closing_paren(token)
    end)
  end

  test "should apply guard for closing parens correctly" do
    Enum.each([")", "]", "}"], fn source ->
      [token] = CredoTokenizer.tokenize(source)

      assert is_closing_paren(token)
      refute is_opening_paren(token)
    end)
  end

  test "should apply guard for opening and closing parens correctly" do
    Enum.each(["()", "[]", "{}"], fn source ->
      [left, right] = CredoTokenizer.tokenize(source)

      assert is_opening_paren(left)
      assert is_closing_paren(right)
      assert no_space_between(left, right)
    end)
  end

  test "should apply guard for opening and closing parens correctly with horizontal spacing" do
    Enum.each(["( )", "[ ]", "{ }"], fn source ->
      [left, right] = CredoTokenizer.tokenize(source)

      assert is_opening_paren(left)
      assert is_closing_paren(right)
      refute no_space_between(left, right)
    end)
  end

  test "should apply guard for opening and closing parens correctly with vertical spacing" do
    Enum.each(["(\n )", "[\n ]", "{\n }"], fn source ->
      tokens = CredoTokenizer.tokenize(source)
      left = List.first(tokens)
      right = List.last(tokens)

      assert is_opening_paren(left)
      assert is_closing_paren(right)
      refute no_space_between(left, right)
    end)
  end

  test "should apply guard for eol" do
    [token] = CredoTokenizer.tokenize("\n")

    assert is_eol(token)
  end
end
