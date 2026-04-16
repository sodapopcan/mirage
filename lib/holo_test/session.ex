defmodule HoloTest.Session do
  @moduledoc """
  Represents a test session — the state of a page after a `HoloTest.visit/2`.

  Fields:

    * `:page` — the initialized `Hologram.Component` struct for the page,
      produced by calling the page module's `init/3` callback.
    * `:ast` — the expanded template DOM for the page (layout-wrapped),
      with components recursively resolved down to elements and text.
  """

  alias Hologram.Component

  defstruct [:page, :ast]

  @type t :: %__MODULE__{
          page: Component.t(),
          ast: any
        }
end
