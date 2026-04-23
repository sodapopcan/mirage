defmodule Mirage.Component do
  defmacro __using__(_) do
    quote do
      import Mirage

      import Hologram.Template, only: [sigil_HOLO: 2]
    end
  end
end
