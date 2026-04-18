# Adapted from the Meeseeks library (https://hex.pm/packages/meeseeks).

defmodule Mirage.CSS.Element do
  @moduledoc false
  defstruct selectors: [], combinator: nil
end

defmodule Mirage.CSS.Element.Tag do
  @moduledoc false
  defstruct value: nil
end

defmodule Mirage.CSS.Element.Namespace do
  @moduledoc false
  defstruct value: nil
end
