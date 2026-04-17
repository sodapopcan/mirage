defmodule Holography.Browser do
  @moduledoc false

  alias Holography.Session
  alias Holography.DOM

  @spec open_browser(Session.t(), (String.t() -> any())) :: Session.t()
  def open_browser(%Session{} = session, open_fun \\ &open_with_system_cmd/1) do
    html = ast_to_html(session.ast)

    path =
      Path.join(
        System.tmp_dir!(),
        "holography_#{System.unique_integer([:positive])}.html"
      )

    File.write!(path, html)
    open_fun.(path)
    session
  end

  defp ast_to_html(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &ast_to_html/1)
  end

  defp ast_to_html({:text, text}), do: text

  defp ast_to_html({:element, tag, attrs, children}) do
    attr_str =
      Enum.map_join(attrs, "", fn {name, value} ->
        " #{name}=\"#{DOM.attr_to_string(value)}\""
      end)

    inner = ast_to_html(children)
    "<#{tag}#{attr_str}>#{inner}</#{tag}>"
  end

  defp ast_to_html({:public_comment, children}) do
    "<!--#{ast_to_html(children)}-->"
  end

  defp ast_to_html(_other), do: ""

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
