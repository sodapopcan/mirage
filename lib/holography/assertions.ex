defmodule Holography.Assertions do
  @moduledoc false

  alias Holography.DOM
  alias Holography.Session

  def assert_has(session, text_or_opts), do: assert_has(session, text_or_opts, [])

  def assert_has(%Session{} = session, text, opts) when is_binary(text) do
    if Keyword.has_key?(opts, :value) do
      raise ArgumentError, "assert_has/3 accepts text or :value, not both"
    end

    assert_text(session.ast, text, Keyword.get(opts, :at))
    session
  end

  def assert_has(%Session{} = session, opts, []) when is_list(opts) do
    value = Keyword.get(opts, :value)
    at = Keyword.get(opts, :at)

    if is_nil(value) do
      raise ArgumentError, "assert_has/2 requires text or :value"
    end

    assert_value(session.ast, value, at)
    session
  end

  def refute_has(session, text_or_opts), do: refute_has(session, text_or_opts, [])

  def refute_has(%Session{} = session, text, opts) when is_binary(text) do
    if Keyword.has_key?(opts, :value) do
      raise ArgumentError, "refute_has/3 accepts text or :value, not both"
    end

    refute_text(session.ast, text, Keyword.get(opts, :at))
    session
  end

  def refute_has(%Session{} = session, opts, []) when is_list(opts) do
    value = Keyword.get(opts, :value)
    at = Keyword.get(opts, :at)

    if is_nil(value) do
      raise ArgumentError, "refute_has/2 requires text or :value"
    end

    refute_value(session.ast, value, at)
    session
  end

  defp assert_text(ast, text, nil) do
    if collect_all_elements(ast) |> Enum.all?(&(String.trim(DOM.inner_text(&1)) != text)) do
      raise "No element found with text: #{inspect(text)}"
    end
  end

  defp assert_text(ast, text, at) when is_integer(at) do
    case find_text_siblings(ast, text) do
      nil ->
        raise "No element found with text: #{inspect(text)}"

      siblings ->
        count = length(siblings)

        if at < 1 or at > count do
          raise "Expected element at position #{at} but only found #{count} text elements"
        end

        element = Enum.at(siblings, at - 1)
        actual = String.trim(DOM.inner_text(element))

        if actual != text do
          raise "Expected element at position #{at} to have text #{inspect(text)} but found #{inspect(actual)}"
        end
    end
  end

  defp assert_value(ast, value, nil) do
    if collect_inputs(ast) |> Enum.all?(&(input_value(&1) != value)) do
      raise "No element found with value: #{inspect(value)}"
    end
  end

  defp assert_value(ast, value, at) when is_integer(at) do
    inputs = collect_inputs(ast)
    count = length(inputs)

    if at < 1 or at > count do
      raise "Expected input at position #{at} but only found #{count} inputs"
    end

    actual = input_value(Enum.at(inputs, at - 1))

    if actual != value do
      raise "Expected input at position #{at} to have value #{inspect(value)} but found #{inspect(actual)}"
    end
  end

  defp refute_text(ast, text, nil) do
    if collect_all_elements(ast) |> Enum.any?(&(String.trim(DOM.inner_text(&1)) == text)) do
      raise "Expected no element with text: #{inspect(text)}"
    end
  end

  defp refute_text(ast, text, at) when is_integer(at) do
    case find_text_siblings(ast, text) do
      nil ->
        :ok

      siblings ->
        count = length(siblings)

        if at >= 1 and at <= count do
          actual = String.trim(DOM.inner_text(Enum.at(siblings, at - 1)))

          if actual == text do
            raise "Expected element at position #{at} not to have text #{inspect(text)}"
          end
        end
    end
  end

  defp refute_value(ast, value, nil) do
    if collect_inputs(ast) |> Enum.any?(&(input_value(&1) == value)) do
      raise "Expected no input with value: #{inspect(value)}"
    end
  end

  defp refute_value(ast, value, at) when is_integer(at) do
    inputs = collect_inputs(ast)
    count = length(inputs)

    if at >= 1 and at <= count do
      actual = input_value(Enum.at(inputs, at - 1))

      if actual == value do
        raise "Expected input at position #{at} not to have value #{inspect(value)}"
      end
    end
  end

  defp input_value({:element, _tag, attrs, _children}) do
    DOM.attr_to_string(DOM.find_attr(attrs, "value"))
  end

  # All elements in DFS order — used for without-:at existence checks.
  defp collect_all_elements(nodes) when is_list(nodes) do
    nodes |> collect_all_elements([]) |> :lists.reverse()
  end

  defp collect_all_elements([], acc), do: acc

  defp collect_all_elements([{:element, _, _, children} = node | rest], acc) do
    collect_all_elements(rest, collect_all_elements(children, [node | acc]))
  end

  defp collect_all_elements([_ | rest], acc), do: collect_all_elements(rest, acc)

  # Finds the first element whose inner text matches `text`, then returns
  # the text-bearing element siblings at that level (children of the same
  # parent). Returns nil if no match is found.
  defp find_text_siblings(nodes, text) when is_list(nodes) do
    if Enum.any?(nodes, &text_match?(&1, text)) do
      text_bearing_elements(nodes)
    else
      Enum.find_value(nodes, fn
        {:element, _, _, children} -> find_text_siblings(children, text)
        _ -> nil
      end)
    end
  end

  defp text_match?({:element, _, _, _} = el, text) do
    String.trim(DOM.inner_text(el)) == text
  end

  defp text_match?(_, _), do: false

  defp text_bearing_elements(nodes) do
    Enum.filter(nodes, fn
      {:element, _, _, children} -> Enum.any?(children, &non_blank_text?/1)
      _ -> false
    end)
  end

  defp non_blank_text?({:text, text}), do: String.trim(text) != ""
  defp non_blank_text?(_), do: false

  defp collect_inputs(nodes) when is_list(nodes) do
    nodes |> collect_inputs([]) |> :lists.reverse()
  end

  defp collect_inputs([], acc), do: acc

  defp collect_inputs([{:element, tag, _attrs, children} = node | rest], acc)
       when tag in ["input", "textarea", "select"] do
    collect_inputs(rest, collect_inputs(children, [node | acc]))
  end

  defp collect_inputs([{:element, _tag, _attrs, children} | rest], acc) do
    collect_inputs(rest, collect_inputs(children, acc))
  end

  defp collect_inputs([_ | rest], acc), do: collect_inputs(rest, acc)
end
