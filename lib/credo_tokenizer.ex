defmodule CredoTokenizer do
  @moduledoc false

  @doc false
  def tokenize(source \\ "", filename \\ "nofile") do
    source
    |> String.to_charlist()
    |> :credo_elixir_tokenizer.tokenize(1, file: filename, unescape: false)
    |> case do
      {:ok, _, _, _, tokens, _} ->
        {:ok, normalize(tokens, [])}

      {:error, warnings, _, _, raw_tokens} ->
        # IO.warn("Could not tokenize: #{filename}")
        # IO.inspect(warnings)
        {:error, warnings, raw_tokens}
    end
  end

  @doc false
  def tokenize!(source \\ "", filename \\ "nofile") do
    case tokenize(source, filename) do
      {:ok, tokens} -> tokens
      error -> raise "Could not tokenize: #{filename}\n\n#{inspect(error, pretty: true)}"
    end
  end

  def normalize([], acc) do
    acc
  end

  # The opening "token" of a map consists of two tokens when coming in from credo_elixir_tokenizer:
  #     {:%{}, _}
  #     {:"{", _}
  #
  # We remove the second token as it does nothing for our use case.
  #
  # def normalize([{:"{", _} = _to_be_removed, {:%{}, _} = token | rest], acc) do
  #   normalize(rest, [normalize(token) | acc])
  # end

  def normalize([token | rest], acc) do
    normalize(rest, [normalize(token) | acc])
  end

  # defp normalize({:%{}, {line, column, nil, line_after, column_after}}) do
  #   {
  #     to_kind(:"%{"),
  #     {line, column, line_after, column_after},
  #     "%{",
  #     nil
  #   }
  # end

  # `normalize/1` normalizes the tokens into the following format:
  #
  #     {
  #       kind,       # {type, sub_type},
  #       location,   # {line, column, line_after, column_after},
  #       contents,   # binary or list
  #       info        # map with more info
  #     }
  #

  defp normalize({bool_or_nil, {line, column, _, line_after, column_after}}) when bool_or_nil in [true, false, nil] do
    {
      to_kind(bool_or_nil),
      {line, column, line_after, column_after},
      bool_or_nil,
      nil
    }
  end

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

  defp normalize({:int, {line, column, number, line_after, column_after}, value}) do
    {
      to_kind(:int),
      {line, column, line_after, column_after},
      to_string(value),
      %{value: number}
    }
  end

  defp normalize({:flt, {line, column, number, line_after, column_after}, value}) do
    {
      to_kind(:flt),
      {line, column, line_after, column_after},
      to_string(value),
      %{value: number}
    }
  end

  defp normalize({:comment, {line, column, nil, line_after, column_after}, value}) do
    {
      to_kind(:comment),
      {line, column, line_after, column_after},
      to_string(value),
      nil
    }
  end

  defp normalize({kind, {line, column, _, line_after, column_after}, value}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      normalize_interpol(value),
      nil
    }
  end

  defp normalize({:bin_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:bin_heredoc),
      {line, column, line_after, column_after},
      normalize_interpol(heredoc_contents),
      %{
        indent: indent
      }
    }
  end

  defp normalize({:list_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:list_heredoc),
      {line, column, line_after, column_after},
      normalize_interpol(heredoc_contents),
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
      normalize_interpol(sigil_contents),
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

  defp normalize_interpol({{line, column, nil}, {line_after, column_after, nil}, contents}) do
    {
      to_kind(:interpol),
      {line, column, line_after, column_after},
      normalize_interpol(contents),
      nil
    }
  end

  defp normalize_interpol([_ | _] = contents) do
    Enum.map(contents, &normalize_interpol/1)
  end

  defp normalize_interpol(v) when is_atom(v) or is_binary(v) or is_map(v) or is_number(v) do
    v
  end

  defp normalize_interpol(value) do
    normalize(value)
  end

  defp to_kind(true), do: {:bool, nil}
  defp to_kind(false), do: {:bool, nil}
  defp to_kind(nil), do: {nil, nil}

  defp to_kind(:int), do: {:number, :integer}
  defp to_kind(:flt), do: {:number, :float}

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
end
