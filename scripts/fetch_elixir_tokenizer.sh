#!/bin/bash

# common setup

set -e

DIRNAME=$( cd "$( dirname "$0" )" && pwd )
PROJECT_ROOT=$( cd "$DIRNAME/.." && pwd )

# script specific sources, variables and function definitions

# setup

cd $PROJECT_ROOT

mkdir -p tmp/elixir
cd tmp

rm -fr elixir/

git clone --depth 1 --branch v1.19.4 git@github.com:elixir-lang/elixir.git || echo ""

cd elixir/lib/elixir/

git co .

cp src/elixir_interpolation.erl $PROJECT_ROOT/src/credo_elixir_interpolation.erl
cp src/elixir_tokenizer.erl $PROJECT_ROOT/src/credo_elixir_tokenizer.erl
cp src/elixir_tokenizer.hrl $PROJECT_ROOT/src/credo_elixir_tokenizer.hrl
cp src/elixir.hrl $PROJECT_ROOT/src/credo_elixir.hrl

cd $PROJECT_ROOT/src/

find . -type f -exec sed -i 's/elixir_tokenizer/credo_elixir_tokenizer/g' {} \;
find . -type f -exec sed -i 's/elixir_interpolation/credo_elixir_interpolation/g' {} \;
find . -type f -exec sed -i 's/elixir\.hrl/credo_elixir.hrl/g' {} \;
