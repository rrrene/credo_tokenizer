defmodule CredoTokenizerTest do
  use ExUnit.Case
  doctest CredoTokenizer

  test "should give correct token position for regexes" do
    source = ~S'''
    {"\""}

      Regex.run(~r/(\A\s+|\@[a-zA-Z0-9\_]+\.?|[\|\\\{\[\(\,\:\>\<\=\+\-\*\/])\s*$/ , "\n
        \"" )
    '''

    tokens = CredoTokenizer.tokenize(source)

    # regex ends at 77 (last char is at 76)
    # comma at 78
    # string ends at 88 (double quote is at 87)
    # closing paren at 89

    expected = []

    assert tokens == expected
  end

  test "should give correct token position for strings" do
    source = ~S'''
    "#{a} #{a}"
    :"b_#{a}_"
    '''

    tokens = CredoTokenizer.tokenize(source)

    # regex ends at 77 (last char is at 76)
    # comma at 78
    # string ends at 88 (double quote is at 87)
    # closing paren at 89

    expected = []

    tokens == expected
  end

  @dir "../credo/master"
  test "should tokenize all files in dir" do
    Path.wildcard("#{@dir}/**/*.{ex,exs}")
    |> Enum.map(fn filename ->
      tokens =
        filename
        |> File.read!()
        |> CredoTokenizer.tokenize(filename)
        |> Enum.filter(fn
          {_, {_, _, _}} -> true
          {_, {_, _, _}, _} -> true
          {_, {_, _, _}, _, _} -> true
          {_, {_, _, _}, _, _, _} -> true
          {_, {_, _, _}, _, _, _, _} -> true
          _ -> false
        end)
        |> Enum.group_by(fn
          {kind, {_, _, _}} -> kind
          {kind, {_, _, _}, _} -> kind
          {kind, {_, _, _}, _, _} -> kind
          {kind, {_, _, _}, _, _, _} -> kind
          {kind, {_, _, _}, _, _, _, _} -> kind
          _ -> false
        end)
        |> Map.values()
        |> Enum.map(fn list -> List.first(list) end)

      if tokens == [] do
        nil
      else
        {filename, tokens}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> dbg(limit: :infinity)
  end

  test "should tokenize fixture" do
    "test/fixtures/learnelixir.ex"
    |> File.read!()
    |> CredoTokenizer.tokenize()
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
    |> dbg
  end
end
