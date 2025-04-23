defmodule CredoTokenizerTest do
  use ExUnit.Case
  doctest CredoTokenizer

  # {{_type, _start, _end}, _meta, _token}
  # {_type, _meta, _token}

  test "should give correct token position for regexes" do
    tokens =
      CredoTokenizer.tokenize(~S'''
      Regex.run(~r/(\A\s+|\@[a-zA-Z0-9\_]+\.?|[\|\\\{\[\(\,\:\>\<\=\+\-\*\/])\s*$/ , "\n
        \"" )
      ''')

    # regex ends at 77 (last char is at 76)
    # comma at 78
    # string ends at 88 (double quote is at 87)
    # closing paren at 89

    expected = []

    assert tokens == expected
  end
end
