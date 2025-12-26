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

  test "should give correct token position for intepolations in strings" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      "#{a} #{a ++ b}"
      :"b_#{ a }_"
      ''')

    expected = [
      {
        {:string, :binary},
        {1, 1, 1, 17},
        [
          {{:interpol, nil}, {1, 2, 1, 6}, [{{:identifier, nil}, {1, 4, 1, 5}, :a, nil}], nil},
          " ",
          {{:interpol, nil}, {1, 7, 1, 16},
           [
             {{:identifier, nil}, {1, 9, 1, 10}, :a, nil},
             {{:concat_op, nil}, {1, 11, 1, 13}, :++, nil},
             {{:identifier, nil}, {1, 14, 1, 15}, :b, nil}
           ], nil}
        ],
        nil
      },
      {{:eol, nil}, {1, 17, 2, 1}, 1, nil},
      {
        {:atom_unsafe, nil},
        {2, 1, 2, 13},
        ["b_", {{:interpol, nil}, {2, 5, 2, 11}, [{{:identifier, nil}, {2, 8, 2, 9}, :a, nil}], nil}, "_"],
        nil
      },
      {{:eol, nil}, {2, 13, 3, 1}, 1, nil}
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

      #{Enum.map_join(unused_apps, "\n", fn app -> "  * #{inspect(app)}" end)} !

      end
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

  test "should give correct token position for expected code including comment" do
    tokens =
      CredoTokenizer.tokenize!(~S'''
      a = 1
      #this is comment

      b = a + 2
      ''')

    assert [
             {{:identifier, nil}, {1, 1, 1, 2}, :a, nil},
             {{:match_op, nil}, {1, 3, 1, 4}, :=, nil},
             {{:int, nil}, {1, 5, 1, 6}, ~c"1", nil},
             {{:eol, nil}, {1, 6, 2, 1}, 1, nil},
             {{:comment, nil}, {2, 1, 2, 17}, "#this is comment", nil},
             {{:eol, nil}, {2, 17, 3, 1}, 1, nil},
             {{:eol, nil}, {3, 1, 4, 1}, 1, nil},
             {{:identifier, nil}, {4, 1, 4, 2}, :b, nil},
             {{:match_op, nil}, {4, 3, 4, 4}, :=, nil},
             {{:identifier, nil}, {4, 5, 4, 6}, :a, nil},
             {{:dual_op, nil}, {4, 7, 4, 9}, :+, nil},
             {{:int, nil}, {4, 9, 4, 10}, ~c"2", nil},
             {{:eol, nil}, {4, 10, 5, 1}, 1, nil}
           ] == tokens
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

  test "should tokenize fixture" do
    "test/fixtures/learnelixir.ex"
    |> File.read!()
    |> CredoTokenizer.tokenize!()

    # |> Enum.map(&elem(&1, 0))
    # |> Enum.uniq()
    # |> dbg
  end

  # Tests for keywords and control flow structures
  test "should tokenize if-else-end" do
    {:ok, tokens} = CredoTokenizer.tokenize("if true do :ok else :error end")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize unless-do-end" do
    {:ok, tokens} = CredoTokenizer.tokenize("unless false do :ok end")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize case-when" do
    source = """
    case x do
      1 -> :one
      2 -> :two
      _ -> :other
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize cond" do
    source = """
    cond do
      1 + 1 == 2 -> :ok
      true -> :fallback
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize with statement" do
    source = """
    with {:ok, x} <- fetch(),
         {:ok, y} <- process(x) do
      {:ok, x + y}
    else
      error -> error
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize try-rescue-catch-after" do
    source = """
    try do
      risky_operation()
    rescue
      e in RuntimeError -> {:error, e}
    catch
      :throw, value -> value
    after
      cleanup()
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize receive block" do
    source = """
    receive do
      {:msg, content} -> content
      :stop -> :ok
    after
      1000 -> :timeout
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for module definition constructs
  test "should tokenize defmodule" do
    source = """
    defmodule MyModule do
      def hello, do: :world
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize def and defp" do
    source = """
    def public_function(x), do: private_function(x)
    defp private_function(x), do: x * 2
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize defmacro and defmacrop" do
    source = """
    defmacro public_macro(x) do
      quote do: unquote(x)
    end
    defmacrop private_macro(x), do: x
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize defstruct" do
    source = """
    defmodule User do
      defstruct name: nil, age: 0, email: ""
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize defexception" do
    source = """
    defmodule MyError do
      defexception message: "default error"
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize defprotocol and defimpl" do
    source = """
    defprotocol Reversible do
      def reverse(term)
    end

    defimpl Reversible, for: List do
      def reverse(list), do: Enum.reverse(list)
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for special forms
  test "should tokenize import" do
    {:ok, tokens} = CredoTokenizer.tokenize("import Enum, only: [map: 2]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize require" do
    {:ok, tokens} = CredoTokenizer.tokenize("require Logger")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize alias" do
    {:ok, tokens} = CredoTokenizer.tokenize("alias My.Long.Module.Name, as: Name")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize use" do
    {:ok, tokens} = CredoTokenizer.tokenize("use GenServer")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize quote and unquote" do
    source = """
    quote do
      def name, do: unquote(value)
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize super" do
    source = """
    def callback(arg) do
      result = super(arg)
      result
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for operators
  test "should tokenize arithmetic operators" do
    {:ok, tokens} = CredoTokenizer.tokenize("a + b - c * d / e")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize comparison operators" do
    {:ok, tokens} = CredoTokenizer.tokenize("a == b != c < d > e <= f >= g === h !== i")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize boolean operators" do
    {:ok, tokens} = CredoTokenizer.tokenize("a and b or c not d && e || f")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize pipe operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("value |> transform() |> process()")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize match operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("{:ok, result} = fetch()")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize pin operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("case x do ^y -> :match end")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize capture operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("&(&1 + &2)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize range operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("1..10")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize concat operators" do
    {:ok, tokens} = CredoTokenizer.tokenize("[1] ++ [2] -- [3] <> \"text\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize in operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("x in [1, 2, 3]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize type operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("1 :: integer")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for data structures
  test "should tokenize list" do
    {:ok, tokens} = CredoTokenizer.tokenize("[1, 2, 3, 4, 5]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize list with head and tail" do
    {:ok, tokens} = CredoTokenizer.tokenize("[head | tail]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize tuple" do
    {:ok, tokens} = CredoTokenizer.tokenize("{:ok, :error, :pending}")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize map" do
    {:ok, tokens} = CredoTokenizer.tokenize("%{key: :value, \"string\" => 123}")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize map update syntax" do
    {:ok, tokens} = CredoTokenizer.tokenize("%{map | key: new_value}")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize struct" do
    {:ok, tokens} = CredoTokenizer.tokenize("%User{name: \"John\", age: 30}")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize keyword list" do
    {:ok, tokens} = CredoTokenizer.tokenize("[name: \"John\", age: 30, active: true]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize charlist" do
    {:ok, tokens} = CredoTokenizer.tokenize("~c\"hello\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for literals
  test "should tokenize atoms" do
    {:ok, tokens} = CredoTokenizer.tokenize(":atom :another_atom :\"atom with spaces\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize integers" do
    {:ok, tokens} = CredoTokenizer.tokenize("123 0x1F 0o17 0b1010 1_000_000")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize floats" do
    {:ok, tokens} = CredoTokenizer.tokenize("1.0 3.14 1.0e10 1.5e-5")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize boolean atoms" do
    {:ok, tokens} = CredoTokenizer.tokenize("true false nil")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize single char" do
    {:ok, tokens} = CredoTokenizer.tokenize("?a ?1 ?\\n")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for comprehensions
  test "should tokenize for comprehension" do
    {:ok, tokens} = CredoTokenizer.tokenize("for x <- [1, 2, 3], do: x * 2")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize for comprehension with filter" do
    {:ok, tokens} = CredoTokenizer.tokenize("for x <- 1..10, x > 5, do: x")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize for comprehension with multiple generators" do
    {:ok, tokens} = CredoTokenizer.tokenize("for x <- [1, 2], y <- [3, 4], do: x * y")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize for comprehension with into" do
    {:ok, tokens} = CredoTokenizer.tokenize("for x <- [1, 2, 3], into: %{}, do: {x, x * 2}")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for module attributes
  test "should tokenize module attributes" do
    source = """
    @moduledoc \"Module documentation\"
    @doc \"Function documentation\"
    @spec add(integer, integer) :: integer
    @type my_type :: integer
    @custom_attribute :value
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize callback attribute" do
    source = """
    @callback handle(term) :: term
    @macrocallback my_macro(term) :: Macro.t()
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize compile attributes" do
    {:ok, tokens} = CredoTokenizer.tokenize("@compile :inline")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for guards
  test "should tokenize guards in function definition" do
    source = """
    def process(x) when is_integer(x) and x > 0 do
      x * 2
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize multiple guard clauses" do
    source = """
    def valid?(x) when is_binary(x) or is_atom(x) do
      true
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for bitstrings and binaries
  test "should tokenize binary" do
    {:ok, tokens} = CredoTokenizer.tokenize("<<1, 2, 3>>")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize binary pattern matching" do
    {:ok, tokens} = CredoTokenizer.tokenize("<<x::8, y::16, rest::binary>> = data")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize binary with modifiers" do
    {:ok, tokens} = CredoTokenizer.tokenize("<<value::size(8)-unsigned-integer>>")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize utf8 binary" do
    {:ok, tokens} = CredoTokenizer.tokenize("<<\"hello\"::utf8>>")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for sigils
  test "should tokenize sigil_c charlist" do
    {:ok, tokens} = CredoTokenizer.tokenize("~c\"charlist\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_s string" do
    {:ok, tokens} = CredoTokenizer.tokenize("~s\"string with \\\"quotes\\\"\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_w word list" do
    {:ok, tokens} = CredoTokenizer.tokenize("~w(one two three)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_w with atoms modifier" do
    {:ok, tokens} = CredoTokenizer.tokenize("~w(one two three)a")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_D date" do
    {:ok, tokens} = CredoTokenizer.tokenize("~D[2024-01-15]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_T time" do
    {:ok, tokens} = CredoTokenizer.tokenize("~T[13:45:30]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_N naive datetime" do
    {:ok, tokens} = CredoTokenizer.tokenize("~N[2024-01-15 13:45:30]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize sigil_U datetime" do
    {:ok, tokens} = CredoTokenizer.tokenize("~U[2024-01-15 13:45:30Z]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize custom sigil" do
    {:ok, tokens} = CredoTokenizer.tokenize("~x{custom sigil}abc")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  # Tests for Elixir idioms and patterns
  test "should tokenize pipe chain" do
    source = """
    [1, 2, 3]
    |> Enum.map(&(&1 * 2))
    |> Enum.filter(&(&1 > 2))
    |> Enum.sum()
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize anonymous function with multiple clauses" do
    source = """
    fn
      {:ok, value} -> value
      {:error, _} -> nil
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize pattern matching in function head" do
    source = """
    def handle({:ok, result}), do: result
    def handle({:error, reason}), do: {:error, reason}
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize default arguments" do
    {:ok, tokens} = CredoTokenizer.tokenize("def greet(name \\\\ \"World\"), do: \"Hello, #{name}!\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize module nesting" do
    source = """
    defmodule Outer do
      defmodule Inner do
        def nested, do: :ok
      end
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize multiline function with do-end" do
    source = """
    def complex_function(arg1, arg2) do
      temp = arg1 + arg2
      result = temp * 2
      {:ok, result}
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize typespecs" do
    source = """
    @type user :: %{name: String.t(), age: non_neg_integer()}
    @spec get_user(id :: integer) :: {:ok, user} | {:error, term}
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize behaviour definition" do
    source = """
    defmodule MyBehaviour do
      @callback init(term) :: {:ok, term} | {:error, term}
      @callback handle(term, term) :: term
    end
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize documentation with examples" do
    source = """
    @doc \"\"\"
    Adds two numbers together.

    ## Examples

        iex> add(1, 2)
        3

    \"\"\"
    def add(a, b), do: a + b
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize access protocol" do
    {:ok, tokens} = CredoTokenizer.tokenize("map[:key]")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize dot access" do
    {:ok, tokens} = CredoTokenizer.tokenize("map.field")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize kernel inspect" do
    {:ok, tokens} = CredoTokenizer.tokenize("inspect(value, pretty: true)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize raise and throw" do
    source = """
    raise "error message"
    throw :value
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize send and spawn" do
    source = """
    send(pid, {:message, data})
    spawn(fn -> work() end)
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize apply and function references" do
    source = """
    apply(Mod, :fun, [arg1, arg2])
    &Mod.fun/2
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize stream operations" do
    {:ok, tokens} = CredoTokenizer.tokenize("1..100 |> Stream.map(&(&1 * 2)) |> Enum.take(5)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize erlang interop" do
    {:ok, tokens} = CredoTokenizer.tokenize(":erlang.system_info(:process_count)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize multiline strings" do
    source = """
    "This is a
    multiline
    string"
    """
    {:ok, tokens} = CredoTokenizer.tokenize(source)
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize escape sequences" do
    {:ok, tokens} = CredoTokenizer.tokenize("\"\\n\\t\\r\\\\\\\"\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize unicode" do
    {:ok, tokens} = CredoTokenizer.tokenize("\"Hello 世界 🌍\"")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize underscored variables" do
    {:ok, tokens} = CredoTokenizer.tokenize("_unused_var = compute()")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize question mark functions" do
    {:ok, tokens} = CredoTokenizer.tokenize("valid? empty? present?")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize exclamation mark functions" do
    {:ok, tokens} = CredoTokenizer.tokenize("Enum.fetch! File.read! String.to_integer!")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize backslash default parameter operator" do
    {:ok, tokens} = CredoTokenizer.tokenize("def func(a, b \\\\ nil, c \\\\ [])")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end

  test "should tokenize arrow in lambda" do
    {:ok, tokens} = CredoTokenizer.tokenize("Enum.map([1, 2, 3], fn x -> x * 2 end)")
    assert is_list(tokens)
    assert Enum.all?(tokens, fn token -> tuple_size(token) == 4 end)
  end
end
