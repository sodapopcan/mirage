defmodule HoloTest.Assertions do
  @moduledoc false

  alias HoloTest.DOM
  alias HoloTest.Session

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
    if collect_elements(ast) |> Enum.all?(&(String.trim(DOM.inner_text(&1)) != text)) do
      raise "No element found with text: #{inspect(text)}"
    end
  end

  defp assert_text(ast, text, at) when is_integer(at) do
    elements = collect_elements(ast)
    count = length(elements)

    if at < 1 or at > count do
      raise "Expected element at position #{at} but only found #{count} elements"
    end

    element = Enum.at(elements, at - 1)
    actual = String.trim(DOM.inner_text(element))

    if actual != text do
      raise "Expected element at position #{at} to have text #{inspect(text)} but found #{inspect(actual)}"
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
    if collect_elements(ast) |> Enum.any?(&(String.trim(DOM.inner_text(&1)) == text)) do
      raise "Expected no element with text: #{inspect(text)}"
    end
  end

  defp refute_text(ast, text, at) when is_integer(at) do
    elements = collect_elements(ast)
    count = length(elements)

    if at >= 1 and at <= count do
      actual = String.trim(DOM.inner_text(Enum.at(elements, at - 1)))

      if actual == text do
        raise "Expected element at position #{at} not to have text #{inspect(text)}"
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

  defp collect_elements(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_elements/1)
  end

  defp collect_elements({:element, _tag, _attrs, children} = node) do
    [node | collect_elements(children)]
  end

  defp collect_elements(_other), do: []

  defp collect_inputs(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &collect_inputs/1)
  end

  defp collect_inputs({:element, tag, _attrs, children} = node)
       when tag in ["input", "textarea", "select"] do
    [node | collect_inputs(children)]
  end

  defp collect_inputs({:element, _tag, _attrs, children}) do
    collect_inputs(children)
  end

  defp collect_inputs(_other), do: []
end
