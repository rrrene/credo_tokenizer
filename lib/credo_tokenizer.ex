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

      {:error, warnings, _, _, tokens} ->
        IO.warn("Could not tokenize: #{filename}")
        IO.inspect(warnings)
        tokens
    end
    |> Enum.reverse()
    |> Enum.map(fn tokens ->
      try do
        normalize(tokens)
      rescue
        e ->
          IO.inspect(filename)
          IO.inspect(e)
          reraise(e, __STACKTRACE__)
      end
    end)
  end

  # `normalize/1` normalizes the tokens into the following format:
  #
  #     {
  #       kind,       # {type, sub_type},
  #       location,   # {line, column, line_after, column_after},
  #       contents,   # binary or list
  #       meta        # map with more info
  #     }
  #

  defp normalize({kind, {line, column, nil, line_after, column_after}}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      to_string(kind),
      nil
    }
  end

  defp normalize({kind, {line, column, value, line_after, column_after}}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      value,
      nil
    }
  end

  defp normalize({:char, {line, column, value, line_after, column_after}, _}) do
    {
      to_kind(:char),
      {line, column, line_after, column_after},
      to_string(value),
      nil
    }
  end

  defp normalize({kind, {line, column, _, line_after, column_after}, value}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      value,
      nil
    }
  end

  defp normalize({:bin_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:bin_heredoc),
      {line, column, line_after, column_after},
      heredoc_contents,
      %{
        indent: indent
      }
    }
  end

  defp normalize({:list_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:list_heredoc),
      {line, column, line_after, column_after},
      heredoc_contents,
      %{
        indent: indent
      }
    }
  end

  defp normalize(
         {:sigil, {line, column, nil, line_after, column_after}, sigil_name, [_ | _] = sigil_contents, modifiers,
          indent, delimiter}
       ) do
    {
      to_kind(:sigil, sigil_name),
      {line, column, line_after, column_after},
      sigil_contents,
      %{
        indent: indent,
        modifiers: modifiers,
        delimiter: delimiter
      }
    }
  end

  defp normalize({:"(", {line, column, nil}}) do
    {
      to_kind(:"("),
      {line, column, line, column + 1},
      "(",
      nil
    }
  end

  defp normalize({:"[", {line, column, nil}}) do
    {
      to_kind(:"["),
      {line, column, line, column + 1},
      "[",
      nil
    }
  end

  defp normalize({:"{", {line, column, nil}}) do
    {
      to_kind(:"{"),
      {line, column, line, column + 1},
      "{",
      nil
    }
  end

  defp normalize({:")", {line, column, nil}}) do
    {
      to_kind(:")"),
      {line, column, line, column + 1},
      ")",
      nil
    }
  end

  defp normalize({:"]", {line, column, nil}}) do
    {
      to_kind(:"]"),
      {line, column, line, column + 1},
      "]",
      nil
    }
  end

  defp normalize({:"}", {line, column, nil}}) do
    {
      to_kind(:"}"),
      {line, column, line, column + 1},
      "}",
      nil
    }
  end

  defp normalize({:"<<", {line, column, nil}}) do
    {
      to_kind(:"<<"),
      {line, column, line, column + 2},
      "<<",
      nil
    }
  end

  defp normalize({:">>", {line, column, nil}}) do
    {
      to_kind(:">>"),
      {line, column, line, column + 2},
      ">>",
      nil
    }
  end

  defp to_kind(:bin_string), do: {:string, :binary}
  defp to_kind(:list_string), do: {:string, :list}
  defp to_kind(:bin_heredoc), do: {:heredoc, :binary}
  defp to_kind(:list_heredoc), do: {:heredoc, :list}
  defp to_kind(kind), do: {kind, nil}

  # Kernel sigils
  defp to_kind(:sigil, :sigil_c), do: {:sigil, "c"}
  defp to_kind(:sigil, :sigil_C), do: {:sigil, "C"}
  defp to_kind(:sigil, :sigil_D), do: {:sigil, "D"}
  defp to_kind(:sigil, :sigil_N), do: {:sigil, "N"}
  defp to_kind(:sigil, :sigil_r), do: {:sigil, "r"}
  defp to_kind(:sigil, :sigil_R), do: {:sigil, "R"}
  defp to_kind(:sigil, :sigil_s), do: {:sigil, "s"}
  defp to_kind(:sigil, :sigil_S), do: {:sigil, "S"}
  defp to_kind(:sigil, :sigil_T), do: {:sigil, "T"}
  defp to_kind(:sigil, :sigil_U), do: {:sigil, "U"}
  defp to_kind(:sigil, :sigil_w), do: {:sigil, "w"}
  defp to_kind(:sigil, :sigil_W), do: {:sigil, "W"}

  # other sigils
  defp to_kind(:sigil, sigil_name), do: {:sigil, String.replace("#{sigil_name}", ~r/^sigil_/, "")}

  defp to_kind(kind, sub), do: {kind, sub}
end
