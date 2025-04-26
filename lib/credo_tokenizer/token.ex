defmodule CredoTokenizer.Token do
  #
  #
  #

  def normalize({kind, {line, column, nil, line_after, column_after}}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      to_string(kind),
      nil
    }
  end

  def normalize({kind, {line, column, value, line_after, column_after}}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      value,
      nil
    }
  end

  def normalize({:char, {line, column, value, line_after, column_after}, _}) do
    {
      to_kind(:char),
      {line, column, line_after, column_after},
      to_string(value),
      nil
    }
  end

  def normalize({kind, {line, column, _, line_after, column_after}, value}) do
    {
      to_kind(kind),
      {line, column, line_after, column_after},
      value,
      nil
    }
  end

  def normalize({:bin_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:bin_heredoc),
      {line, column, line_after, column_after},
      heredoc_contents,
      %{
        indent: indent
      }
    }
  end

  def normalize({:list_heredoc, {line, column, nil, line_after, column_after}, indent, [_ | _] = heredoc_contents}) do
    {
      to_kind(:list_heredoc),
      {line, column, line_after, column_after},
      heredoc_contents,
      %{
        indent: indent
      }
    }
  end

  def normalize(
        {:sigil, {line, column, nil, line_after, column_after}, sigil_name, [_ | _] = sigil_contents, modifiers, indent,
         delimiter}
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
