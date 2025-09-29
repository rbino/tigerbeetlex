# TigerBeetlex

Elixir client for [TigerBeetle](https://github.com/tigerbeetle/tigerbeetle).

## Usage

Check out the documentation on [HexDocs](https://hexdocs.pm/tigerbeetlex). It also includes a
walkthrough that can be executed on LiveBook.

## Installation

The package can be installed by adding `tigerbeetlex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tigerbeetlex, "~> 0.16.60"}
  ]
end
```

### Client versioning

TigerBeetle requires the client to have the same or lower version than the server.

TigerBeetlex uses the same version number as the underlying Zig TigerBeetle client to
simplify selecting the right version. This also implies that we need to wait for a new
TigerBeetle release to cut a new release, but this shouldn't be a problem since TigerBeetle
has a fixed weekly release schedule.

If/when TigerBeetle switches to a slower release cadence, we might evaluate using different
version numbers.

## Contributing

### Setup

Clone the repo and fetch dependencies:

```bash
$ git clone https://github.com/rbino/tigerbeetlex.git
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

Copyright 2023-2025 Riccardo Binetti

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at
<https://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
