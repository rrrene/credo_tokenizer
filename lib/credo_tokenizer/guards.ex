defmodule CredoTokenizer.Guards do
  defguard is_eol(token) when elem(token, 0) == {:eol, nil}

  defguard is_opening_paren(token) when elem(token, 0) in [{:"(", nil}, {:"{", nil}, {:"[", nil}]
  defguard is_closing_paren(token) when elem(token, 0) in [{:")", nil}, {:"}", nil}, {:"]", nil}]

  defguard is_same_line(t0, t1) when elem(elem(t0, 1), 2) == elem(elem(t1, 1), 0)

  defguard no_space_between(t0, t1) when is_same_line(t0, t1) and elem(elem(t0, 1), 3) == elem(elem(t1, 1), 1)
end
