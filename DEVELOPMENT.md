# CredoTokenizer

Elixir's tokenizer is a private API of the compiler, so it is no surprise that it is not geared towards utility for analysis tools, but rather, well, compiling o_O

> **IMPORTANT**: This is still evolving. For the time being, this should be considered an experimental private API of Credo.

## Normalized Tokens made for matching locations

This tokenizer's token format tries to provide tokens made for analysis (Credo's use case):

```elixir
{
  {type, sub_type},                         # kind
  {line, column, line_after, column_after}, # location
  contents,                                 # atom, binary or list
  info                                      # map with more info
}
```

- `type` and `subtype` should make it easy to match "all binaries" or "all upcase single-letter sigils" (this is still an evolving part of the API).

- `line_after` and `column_after` describe the cursor position *after* the token, so it is easy to match if the current token and the next one are right next to each other.

- `contents` is a representation of the token in the source code.

- `info` collects all metadata not expressed in the first 3 elements, e.g. delimiter and modifiers for a sigil or the indentation for a heredoc.

