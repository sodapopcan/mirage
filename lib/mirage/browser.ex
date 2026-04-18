defmodule Mirage.Browser do
  @moduledoc false

  alias Mirage.Session
  alias Mirage.DOM

  def open_browser(%Session{} = session, open_fun \\ &open_with_system_cmd/1) do
    static_dir = Path.join(File.cwd!(), "priv/static")
    html = ast_to_html(session.ast, static_dir)

    path =
      Path.join(
        System.tmp_dir!(),
        "mirage_#{System.unique_integer([:positive])}.html"
      )

    File.write!(path, html)
    open_fun.(path)
    session
  end

  defp ast_to_html(nodes, static_dir) when is_list(nodes) do
    Enum.map_join(nodes, "", &ast_to_html(&1, static_dir))
  end

  defp ast_to_html({:text, text}, _static_dir), do: text

  defp ast_to_html({:element, "link", attrs, children}, static_dir) do
    attr_str = attrs |> rewrite_attr("href", static_dir) |> attrs_to_string()
    "<link#{attr_str}>#{ast_to_html(children, static_dir)}</link>"
  end

  defp ast_to_html({:element, "img", attrs, children}, static_dir) do
    attr_str = attrs |> rewrite_attr("src", static_dir) |> attrs_to_string()
    "<img#{attr_str}>#{ast_to_html(children, static_dir)}</img>"
  end

  defp ast_to_html({:element, tag, attrs, children}, static_dir) do
    "<#{tag}#{attrs_to_string(attrs)}>#{ast_to_html(children, static_dir)}</#{tag}>"
  end

  defp ast_to_html({:public_comment, children}, static_dir) do
    "<!--#{ast_to_html(children, static_dir)}-->"
  end

  defp ast_to_html(_other, _static_dir), do: ""

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
    Enum.map_join(attrs, "", fn {name, value} ->
      " #{name}=\"#{DOM.attr_to_string(value)}\""
    end)
  end

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
