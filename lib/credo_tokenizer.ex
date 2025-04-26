defmodule CredoTokenizer do
  @moduledoc false

  @doc false
  def tokenize(source \\ "", filename \\ "nofile") do
    source
    |> String.to_charlist()
    |> :credo_elixir_tokenizer.tokenize(1, file: filename, unescape: false)
    |> case do
      {:ok, _, _, _, tokens, _} ->
        tokens

      {:error, all, _, _, tokens} ->
        IO.warn("Could not tokenize")
        dbg(all)
        tokens
    end
    |> Enum.reverse()
    |> Enum.map(&CredoTokenizer.Token.normalize/1)
  end
end
