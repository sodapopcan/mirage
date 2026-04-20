defmodule Mirage.Browser do
  @moduledoc false

  alias Mirage.Session
  alias Mirage.DOM

  # sobelow_skip ["Traversal.FileModule"]
  def open_browser(%Session{} = session, open_fun \\ &open_with_system_cmd/1) do
    config =
      Map.merge(session.bookkeeping, %{
        static_dir: Path.join(File.cwd!(), "priv/static"),
        current_select_values: MapSet.new()
      })

    body = ast_to_html(session.ast, config)

    html =
      if function_exported?(session.page_module, :__layout_module__, 0) do
        body
      else
        wrap_in_layout(body, config.static_dir)
      end

    path =
      Path.join(
        System.tmp_dir!(),
        "mirage_#{System.unique_integer([:positive])}.html"
      )

    File.write!(path, html)
    open_fun.(path)
    session
  end

  defp ast_to_html(nodes, config) when is_list(nodes) do
    Enum.map_join(nodes, "", &ast_to_html(&1, config))
  end

  defp ast_to_html({:text, text}, _config), do: text

  defp ast_to_html({:element, "link", attrs, children}, config) do
    attr_str = attrs |> rewrite_attr("href", config.static_dir) |> attrs_to_string()
    "<link#{attr_str}>#{ast_to_html(children, config)}</link>"
  end

  defp ast_to_html({:element, "img", attrs, children}, config) do
    attr_str = attrs |> rewrite_attr("src", config.static_dir) |> attrs_to_string()
    "<img#{attr_str}>#{ast_to_html(children, config)}</img>"
  end

  defp ast_to_html({:element, "input", attrs, children}, config) do
    attr_str = attrs |> maybe_check_radio(config) |> attrs_to_string()
    "<input#{attr_str}>#{ast_to_html(children, config)}</input>"
  end

  defp ast_to_html({:element, "select", attrs, children}, config) do
    name =
      case DOM.find_attr(attrs, "name") do
        nil -> nil
        v -> DOM.attr_to_string(v)
      end

    selected_values = Map.get(config.selected_options, name, MapSet.new())
    inner_config = Map.put(config, :current_select_values, selected_values)
    "<select#{attrs_to_string(attrs)}>#{ast_to_html(children, inner_config)}</select>"
  end

  defp ast_to_html({:element, "option", attrs, children}, config) do
    text = String.trim(ast_to_html(children, config))

    value =
      case DOM.find_attr(attrs, "value") do
        nil -> text
        v -> DOM.attr_to_string(v)
      end

    already_selected = Enum.any?(attrs, fn {name, _} -> name == "selected" end)

    attrs =
      if not already_selected and MapSet.member?(config.current_select_values, value) do
        attrs ++ [{"selected", true}]
      else
        attrs
      end

    "<option#{attrs_to_string(attrs)}>#{ast_to_html(children, config)}</option>"
  end

  defp ast_to_html({:element, tag, attrs, children}, config) do
    "<#{tag}#{attrs_to_string(attrs)}>#{ast_to_html(children, config)}</#{tag}>"
  end

  defp ast_to_html({:public_comment, children}, config) do
    "<!--#{ast_to_html(children, config)}-->"
  end

  defp ast_to_html(_other, _config), do: ""

  # Adds `checked` to radio/checkbox inputs based on session-tracked selections,
  # but only when the template hasn't already bound `checked` itself.
  defp maybe_check_radio(attrs, config) do
    type = attrs |> DOM.find_attr("type") |> attr_string()
    already_has_checked = Enum.any?(attrs, fn {name, _} -> name == "checked" end)

    if already_has_checked do
      attrs
    else
      name = attrs |> DOM.find_attr("name") |> attr_string()
      value = attrs |> DOM.find_attr("value") |> attr_string()

      checked =
        case type do
          "radio" ->
            Map.get(config.checked_radios, name) == value

          "checkbox" ->
            value_key = value || "on"
            MapSet.member?(config.checked_checkboxes, {name, value_key})

          _ ->
            false
        end

      if checked, do: attrs ++ [{"checked", true}], else: attrs
    end
  end

  defp attr_string(nil), do: nil
  defp attr_string(value), do: DOM.attr_to_string(value)

  defp rewrite_attr(attrs, name, static_dir) do
    Enum.map(attrs, fn
      {^name, value} ->
        case DOM.attr_to_string(value) do
          "/" <> rest -> {name, "#{static_dir}/#{rest}"}
          _ -> {name, value}
        end

      other ->
        other
    end)
  end

  defp attrs_to_string(attrs) do
    Enum.reduce(attrs, "", fn {name, value}, acc ->
      case boolean_value(value) do
        {:ok, true} -> acc <> " #{name}"
        {:ok, false} -> acc
        :not_boolean -> acc <> " #{name}=\"#{DOM.attr_to_string(value)}\""
      end
    end)
  end

  defp boolean_value([{:expression, {true}}]), do: {:ok, true}
  defp boolean_value([{:expression, {false}}]), do: {:ok, false}
  defp boolean_value(true), do: {:ok, true}
  defp boolean_value(false), do: {:ok, false}
  defp boolean_value(_), do: :not_boolean

  defp wrap_in_layout(body, static_dir) do
    css =
      static_dir
      |> Path.join("**/*.css")
      |> Path.wildcard()
      |> Enum.map_join("\n", fn path ->
        ~s(<link rel="stylesheet" href="#{path}">)
      end)

    """
    <!DOCTYPE html>
    <html>
    <head>#{css}</head>
    <body>#{body}</body>
    </html>
    """
  end

  # sobelow_skip ["CI.System"]
  defp open_with_system_cmd(path) do
    {cmd, args} =
      case :os.type() do
        {:win32, _} ->
          {"cmd", ["/c", "start", path]}

        {:unix, :darwin} ->
          {"open", [path]}

        {:unix, _} ->
          if path =~ "\\" and System.find_executable("cmd.exe") != nil do
            {"cmd.exe", ["/c", "start", path]}
          else
            {"xdg-open", [path]}
          end
      end

    System.cmd(cmd, args)
  end
end
