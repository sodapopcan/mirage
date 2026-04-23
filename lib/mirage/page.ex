defmodule Mirage.Page do
  defmacro __using__(_) do
    quote do
      import Mirage

      setup do
        %{server: %Hologram.Server{}}
      end
    end
  end
end
