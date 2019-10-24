# FeatureFlag

[![Build Status](https://secure.travis-ci.org/MainShayne233/feature_flag.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/feature_flag)
[![Hex Version](http://img.shields.io/hexpm/v/executor.svg?style=flat)](https://hex.pm/packages/feature_flag)


`FeatureFlag` provides a macro that allows for conditional branching at the function level via configuration values.

In other words, you can change what a function does at runtime by setting/modifying a config value.

## Use Case

The goal of this library was to provide an elegant and consistent mechanism for changing what a function does depending on a value that can easily be modified (i.e. a configuration value).

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

However, the same code can be rewritten as such using `FeatureFlag`

```elixir
defmodule MyApp do
  def math(x, y), feature_flag do
    :add -> x + y
    :multiply -> x * y
    :subtract x - y
  end
end
```

When called, each case will attempt to match on the current value of `Application.fetch_env!(:feature_flag, :flags)[{MyApp, :math, 2}])`.

Beyond removing a marginal amount of code, `FeatureFlag` provides a consistent interface for defining functions with config-based branching.

## Usage

Add FeatureFlag as a dependency in your `mix.exs` file.

```elixir
def deps do
  [
    {:feature_flag, "~> 0.1.2"}
  ]
end
```

After that's done, run `mix deps.get`, and then you can define a feature flag'd function!

Here's a simple example:

```elixir
defmodule MyApp
  use FeatureFlag

  def get(key), feature_flag do
    :cache ->
      get_from_cache(key)

    :database ->
      get_from_database(key)
  end
end
```

The function `MyApp.get/1` will perform different procedures depending on a config value you can set via:

```elixir
# config/{dev,test,prod}.exs
config FeatureFlag, :flags, %{{MyApp, :get, 1} => :cache}
```

or, you can set/change this value at runtime via:

```elixir
FeatureFlag.set({MyApp, :get, 1}, :database)
```


If your function is only going to do one of two things based on a boolean feature flag, you can simplify
your function like so:

```elixir
def get(key), feature_flag do
  get_from_cache(key)
else
  get_from_database(key)
end
```

The first block will get called if `Application.fetch_env!(FeatureFlag, {MyApp, :get, 1}) == true`, and the `else` block will get called if it's `false`.

## Mentions

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@zph](https://github.com/zph)

I'd also like to thank [@Packlane](https://github.com/Packlane) for giving me time to work on and share this software.

