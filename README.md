# TigerBeetlex

Elixir client for [TigerBeetle](https://github.com/tigerbeetledb/tigerbeetle).

## Usage

More documentation is coming, for now check out the integration test in the `test` directory.

## Installation

The package can be installed by adding `tigerbeetlex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tigerbeetlex, github: "rbino/tigerbeetlex", submodules: true}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tigerbeetlex>.

## Contributing

### Setup

Clone the repo and fetch dependencies:

```bash
$ git clone --recurse-submodules https://github.com/rbino/tigerbeetlex.git
$ cd tigerbeetlex
$ mix deps.get
```

In a new terminal session, download TigerBeetle using the right command for your OS:

```bash
# Linux
curl -Lo tigerbeetle.zip https://linux.tigerbeetle.com && unzip tigerbeetle.zip

# macOS
curl -Lo tigerbeetle.zip https://mac.tigerbeetle.com && unzip tigerbeetle.zip

# Windows
powershell -command "curl.exe -Lo tigerbeetle.zip https://windows.tigerbeetle.com; Expand-Archive tigerbeetle.zip"
```

Then create the data file and start your development cluster

```bash
./tigerbeetle format --cluster=0 --replica=0 --replica-count=1 --development 0_0.tigerbeetle
./tigerbeetle start --addresses=3000 --development 0_0.tigerbeetle
```

See the [TigerBeetle documentation](https://docs.tigerbeetle.com/) for more info.

Finally, in the first terminal, ensure the tests pass:

```bash
$ mix test
```

## License

Copyright 2023-2024 Riccardo Binetti

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at
<https://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
