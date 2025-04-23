defmodule CredoTokenizer do
  @moduledoc false
  [
    {:identifier, {1, 1, ~c"line"}, :line},
    {:arrow_op, {3, 1, 1}, :|>},
    {:alias, {3, 4, ~c"String"}, :String},
    {:., {3, 10, nil}},
    {:paren_identifier, {3, 11, ~c"slice"}, :slice},
    {:"(", {3, 16, nil}},
    {:int, {3, 17, 0}, ~c"0"},
    {:range_op, {3, 18, nil}, :..},
    {:"(", {3, 20, nil}},
    {:identifier, {3, 21, ~c"column"}, :column},
    {:dual_op, {3, 28, nil}, :-},
    {:int, {3, 30, 2}, ~c"2"},
    {:")", {3, 31, nil}},
    {:")", {3, 32, nil}},
    {:arrow_op, {4, 1, 1}, :|>},
    {:alias, {4, 4, ~c"String"}, :String},
    {:., {4, 10, nil}},
    {:paren_identifier, {4, 11, ~c"match?"}, :match?},
    {:"(", {4, 17, nil}},
    {:sigil, {4, 18, nil}, :sigil_r,
     ["(\\A\\s+|\\@[a-zA-Z0-9\\_]+\\.?|[\\|\\\\\\{\\[\\(\\,\\:\\>\\<\\=\\+\\-\\*/])\\s*$"], [], nil, "/"},
    {:")", {4, 84, nil}},
    {:eol, {4, 85, 1}}
  ]

  @doc false
  def tokenize(source \\ "", filename \\ "nofile") do
    source
    |> String.to_charlist()
    |> :credo_elixir_tokenizer.tokenize(1, file: filename, unescape: false)
    |> case do
      {:ok, _, _, _, tokens, _} ->
        Enum.reverse(tokens)

      {:error, _, _, _, tokens} ->
        tokens
    end
  end
end
