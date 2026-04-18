# Adapted from the Meeseeks library (https://hex.pm/packages/meeseeks).
# see lib/mirage/css/LISENCE.txt

defmodule Mirage.CSS do
  @moduledoc false

  alias Mirage.CSS.Parser

  def compile_selectors(selector) when is_binary(selector) do
    selector
    |> tokenize()
    |> Parser.parse_elements()
    |> unwrap_single_selector()
  end

  defp tokenize(selector) do
    chars =
      selector
      |> String.trim()
      |> String.to_charlist()

    case :mirage_css_tokenizer.string(chars) do
      {:ok, tokens, _} ->
        tokens

      {:error, {_, _, reason}, _} ->
        raise "CSS selector tokenize error: #{inspect(reason)} in #{inspect(selector)}"
    end
  end

  defp unwrap_single_selector([selector]), do: selector
  defp unwrap_single_selector(selectors), do: selectors
end
