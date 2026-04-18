defmodule Mirage.Browser do
  @moduledoc false

  alias Mirage.Session
  alias Mirage.DOM

  def open_browser(%Session{} = session, open_fun \\ &open_with_system_cmd/1) do
    config = %{
      static_dir: Path.join(File.cwd!(), "priv/static"),
      checked_radios: session.checked_radios
    }

    html = ast_to_html(session.ast, config)

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
    attr_str = attrs |> maybe_check_radio(config.checked_radios) |> attrs_to_string()
    "<input#{attr_str}>#{ast_to_html(children, config)}</input>"
  end

  defp ast_to_html({:element, tag, attrs, children}, config) do
    "<#{tag}#{attrs_to_string(attrs)}>#{ast_to_html(children, config)}</#{tag}>"
  end

  defp ast_to_html({:public_comment, children}, config) do
    "<!--#{ast_to_html(children, config)}-->"
  end

  defp ast_to_html(_other, _config), do: ""

  # Adds `checked` to a radio input based on session-tracked selections,
  # but only when the template hasn't already bound `checked` itself.
  defp maybe_check_radio(attrs, checked_radios) do
    type = attrs |> DOM.find_attr("type") |> attr_string()

    already_has_checked = Enum.any?(attrs, fn {name, _} -> name == "checked" end)

    if type == "radio" and not already_has_checked do
      name = attrs |> DOM.find_attr("name") |> attr_string()
      value = attrs |> DOM.find_attr("value") |> attr_string()

      if Map.get(checked_radios, name) == value do
        attrs ++ [{"checked", true}]
      else
        attrs
      end
    else
      attrs
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
