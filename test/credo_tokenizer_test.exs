defmodule CredoTokenizerTest do
  use ExUnit.Case
  doctest CredoTokenizer

  test "should give correct token position for regexes" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      {"\""}

        Regex.run(~r/(\A\s+|\@[a-zA-Z0-9\_]+\.?|[\|\\\{\[\(\,\:\>\<\=\+\-\*\/])\s*$/ , "\n
          \"" )
      ''')

    # regex ends at 77 (last char is at 76)
    # comma at 78
    # string ends at 88 (double quote is at 87)
    # closing paren at 89

    expected = [
      {{:"{", nil}, {1, 1, 1, 2}, "{", nil},
      {{:string, :binary}, {1, 2, 1, 6}, ["\""], nil},
      {{:"}", nil}, {1, 6, 1, 7}, "}", nil},
      {{:eol, nil}, {1, 7, 2, 1}, 1, nil},
      {{:eol, nil}, {2, 1, 3, 1}, 1, nil},
      {{:alias, nil}, {3, 3, 3, 8}, :Regex, nil},
      {{:., nil}, {3, 8, 3, 9}, ".", nil},
      {{:paren_identifier, nil}, {3, 9, 3, 12}, :run, nil},
      {{:"(", nil}, {3, 12, 3, 13}, "(", nil},
      {{:sigil, "r"}, {3, 13, 3, 79},
       ["(\\A\\s+|\\@[a-zA-Z0-9\\_]+\\.?|[\\|\\\\\\{\\[\\(\\,\\:\\>\\<\\=\\+\\-\\*/])\\s*$"],
       %{modifiers: [], delimiter: "/", indent: nil}},
      {{:",", nil}, {3, 80, 3, 81}, 0, nil},
      {{:string, :binary}, {3, 82, 4, 8}, ["\\n\n    \""], nil},
      {{:")", nil}, {4, 9, 4, 10}, ")", nil},
      {{:eol, nil}, {4, 10, 5, 1}, 1, nil}
    ]

    assert tokens == expected
  end

  test "should give correct token position for strings" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      "#{a} #{a}"
      :"b_#{a}_"
      ''')

    expected = [
      {{:string, :binary}, {1, 1, 1, 12},
       [
         {{1, 2, nil}, {1, 5, nil}, [{:identifier, {1, 4, ~c"a", 1, 5}, :a}]},
         " ",
         {{1, 7, nil}, {1, 10, nil}, [{:identifier, {1, 9, ~c"a", 1, 10}, :a}]}
       ], nil},
      {{:eol, nil}, {1, 12, 2, 1}, 1, nil},
      {{:atom_unsafe, nil}, {2, 1, 2, 11},
       ["b_", {{2, 5, nil}, {2, 8, nil}, [{:identifier, {2, 7, ~c"a", 2, 8}, :a}]}, "_"], nil},
      {{:eol, nil}, {2, 11, 3, 1}, 1, nil}
    ]

    assert tokens == expected
  end

  test "should give correct token position for heredocs" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      Mix.raise("""
      Unused dependencies in mix.lock file:

      This is a "static" heredoc.
      """)
      ''')

    was_fully_tokenized? = Enum.count(tokens) > 5

    assert was_fully_tokenized?
  end

  test "should give correct token position for heredocs with `fn` inside interpolations" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      """
      Unused dependencies in mix.lock file:

      #{fn x -> x end}
      """
      ''')

    assert [] != tokens
  end

  test "should give correct token position for heredocs with `if` inside interpolations" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      """
      Unused dependencies in mix.lock file:

      #{if a do
        :test
      end}
      """
      ''')

    assert [] != tokens
  end

  test "should give correct token position for heredocs with interpolations" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      Mix.raise("""
      Unused dependencies in mix.lock file:

      #{Enum.map_join(unused_apps, "\n", fn app -> "  * #{inspect(app)}" end)}
      """)
      ''')

    assert [] != tokens
  end

  test "should give correct token position for heredocs with simple interpolation" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      Mix.raise("""
      Unused dependencies in mix.lock file:

      #{MyModule.fun(unused_apps)}
      """)
      ''')

    assert [] != tokens
  end

  test "should give correct token position for heredocs with simple interpolation containing a string" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      Mix.raise("""
      Unused dependencies in mix.lock file:

      #{MyModule.fun(unused_apps, "test")}
      """)
      ''')

    assert [] != tokens
  end

  test "should give correct token position for expected code" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      test "add microseconds" do
        time = Timex.to_datetime({{2015, 6, 24}, {14, 27, 52}})
        time = %{time | microsecond: {900_000, 6}}
        added = Timex.add(time, Duration.from_microseconds(42))
        assert added.microsecond === {900_042, 6}
      end
      ''')

    assert [] != tokens
  end

  test "should give correct token position for @ as keyword in list" do
    tokens = CredoTokenizer.tokenize!("[@: 1]")

    expected = [
      {{:"[", nil}, {1, 1, 1, 2}, "[", nil},
      {{:kw_identifier, nil}, {1, 2, 1, 4}, :@, nil},
      {{:int, nil}, {1, 5, 1, 6}, ~c"1", nil},
      {{:"]", nil}, {1, 6, 1, 7}, "]", nil}
    ]

    assert tokens == expected
  end

  test "should give correct token position for ==" do
    tokens = CredoTokenizer.tokenize!("a == b")

    expected = [
      {{:identifier, nil}, {1, 1, 1, 2}, :a, nil},
      {{:comp_op, nil}, {1, 3, 1, 5}, :==, nil},
      {{:identifier, nil}, {1, 6, 1, 7}, :b, nil}
    ]

    assert tokens == expected
  end

  test "should give correct token position for fn" do
    tokens = CredoTokenizer.tokenize!("fn x -> x end")

    expected = [
      {{:fn, nil}, {1, 1, 1, 3}, "fn", nil},
      {{:identifier, nil}, {1, 4, 1, 5}, :x, nil},
      {{:stab_op, nil}, {1, 6, 1, 8}, :->, nil},
      {{:identifier, nil}, {1, 9, 1, 10}, :x, nil},
      {{:end, nil}, {1, 11, 1, 14}, "end", nil}
    ]

    assert tokens == expected
  end

  test "should give correct token position for function call" do
    tokens = CredoTokenizer.tokenize!("[ ]")

    expected = [
      {{:"[", nil}, {1, 1, 1, 2}, "[", nil},
      {{:"]", nil}, {1, 3, 1, 4}, "]", nil}
    ]

    assert tokens == expected
  end

  # @dir "tmp/elixir"
  # test "should tokenize all files in dir" do
  #   "#{@dir}/**/*.{ex,exs}"
  #   |> Path.wildcard()
  #   |> Enum.map(fn filename ->
  #     source = File.read!(filename)
  #     tokens = CredoTokenizer.tokenize!(source, filename)

  #     # For this we need to make sure that the used `:elixir_tokenizer` is the one we forked from.
  #     #
  #     # elixir_tokens =
  #     #   source
  #     #   |> String.to_charlist()
  #     #   |> :elixir_tokenizer.tokenize(1, file: filename, unescape: false)
  #     #   |> case do
  #     #     {:ok, _, _, _, tokens, _} -> tokens
  #     #     error -> flunk("Could not elixir_tokenize filename: #{filename}\n\n#{inspect(error, pretty: true)}")
  #     #   end
  #     #
  #     # assert length(tokens) == length(elixir_tokens),
  #     #        "Token count does not match for #{filename}: #{length(tokens)} != #{length(elixir_tokens)}"

  #     raw_tokens =
  #       tokens
  #       |> Enum.filter(fn
  #         {_, {_, _, _}} -> true
  #         {_, {_, _, _}, _} -> true
  #         {_, {_, _, _}, _, _} -> true
  #         {_, {_, _, _}, _, _, _} -> true
  #         {_, {_, _, _}, _, _, _, _} -> true
  #         _ -> false
  #       end)
  #       |> Enum.group_by(fn
  #         {kind, {_, _, _}} -> kind
  #         {kind, {_, _, _}, _} -> kind
  #         {kind, {_, _, _}, _, _} -> kind
  #         {kind, {_, _, _}, _, _, _} -> kind
  #         {kind, {_, _, _}, _, _, _, _} -> kind
  #         _ -> false
  #       end)
  #       |> Map.values()
  #       |> Enum.map(fn list -> List.first(list) end)

  #     if raw_tokens == [] do
  #       nil
  #     else
  #       {filename, raw_tokens}
  #     end
  #   end)
  #   |> Enum.reject(&is_nil/1)
  #   |> then(fn non_normalized_tokens ->
  #     assert [] == non_normalized_tokens
  #   end)
  # end

  # test "should tokenize fixture" do
  #   "test/fixtures/learnelixir.ex"
  #   |> File.read!()
  #   |> CredoTokenizer.tokenize()
  #   |> Enum.map(&elem(&1, 0))
  #   |> Enum.uniq()
  #   |> dbg
  # end
end
