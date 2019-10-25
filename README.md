# FeatureFlag

[![Build Status](https://secure.travis-ci.org/MainShayne233/feature_flag.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/feature_flag)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/feature_flag/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/feature_flag?branch=master)
[![Hex Version](http://img.shields.io/hexpm/v/executor.svg?style=flat)](https://hex.pm/packages/feature_flag)

## The What

`FeatureFlag` allows you to write functions that can have their behavior changed by setting/modifying a config value.

For instance, using `FeatureFlag`, you can define a function like so:

```elixir
defmodule MyApp do
  use FeatureFlag

  def math(x, y), feature_flag do
    :add -> x + y
    :multiply -> x * y
    :subtract -> x - y
  end
end
```

This function will do one of three things depending on its feature flag value. You must set this value in your config like:

```elixir
config :feature_flag, :flags, %{
  # the key here is {module_name, function_name, arity}
  {MyApp, :add, 2} => :add
}
```

At this point, the function would behave like so:

```elixir
iex> MyApp.math(3, 4)
7
```

At runtime, you can change feature flag value using `FeatureFlag.set/2`, like so:

```
FeatureFlag.set({MyApp, :add, 2}, :multiply)
```

And now the function would behave like so:

```elixir
iex> MyApp.math(3, 4)
12
```

### Boolean feature flags

If a function's feature flag will only ever be `true` or `false`, you can definie your function like so:

```elixir
defmodule MyApp do
  use FeatureFlag

  def get(key), feature_flag do
    get_from_cache(key)
  else
    get_from_db(key)
  end
end
```

## Use Case

The goal of this library is to ~~make Elixir less pure~~ provide an elegant and consistent mechanism for changing what a function does depending on a value that can easily be modified (i.e. a configuration value).

This could very easily be done in plain Elixir via a simple `case` statement:

```elixir
defmodule MyApp do
  def math(x, y) do
    case Application.fetch_env!(:my_app, :math) do
      :add -> x + y
      :multiply -> x * y
      :subtract x - y
    end
  end
end
```

There's nothing wrong with this approach, and really no need to reach for anything else.

However, beyond removing a marginal amount of code, `FeatureFlag` provides a consistent interface for defining functions with this config-based branching.

## Usage

Add FeatureFlag as a dependency in your `mix.exs` file.

```elixir
def deps do
  [
    {:feature_flag, "~> 0.1.3"}
  ]
end
```

Run `mix deps.get`, then define your function:

```elixir
defmodule MyApp
  use FeatureFlag

  def get(key), feature_flag do
    :old_database ->
      get_from_old_database(key)

    :new_database ->
      get_from_new_database(key)
      
    :get_from_newer_database ->
      get_from_newer_database(key)
  end
end
```

If you attempt to compile now, it will fail, because you need to explictly declare the feature flag value for this function in your config:

```elixir
# config/{dev,test,prod}.exs

config :feature_flag, :flags, %{
  {MyApp, :get, 1} => :old_database
}
```

Then you're done! Initially, this function will simply execute the `:old_database` block. You can change this at runtime by running:

```elixir
FeatureFlag.set({MyApp, :get, 1}, :new_database)
```

## Mentions

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@zph](https://github.com/zph)

I'd also like to thank [@Packlane](https://github.com/Packlane) for giving me time to work on and share this software.

