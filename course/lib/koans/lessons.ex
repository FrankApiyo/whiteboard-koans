defmodule Koans.Lessons do
  @moduledoc false

  alias Koans.ApiCheck
  alias Koans.Ts.ApiCheck, as: TsApiCheck

  @kinds [
    {:ts, "source/assets/koans/[0-9][0-9]_*.test.ts", "TypeScript and Svelte"},
    {:ex, "source/test/koans/[0-9][0-9]_*_test.exs", "Elixir"}
  ]

  def build(root) do
    files =
      for {kind, glob, _label} <- @kinds,
          path <- root |> Path.join(glob) |> Path.wildcard(),
          do: {path |> Path.basename() |> String.slice(0, 2), kind, path}

    files
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn {nn, files} -> chapter(nn, files, root) end)
    |> page()
  end

  defp chapter(nn, files, root) do
    [first | others] = for {_nn, kind, path} <- files, do: lesson(kind, path)
    [head | more] = first.body
    {title, remainder} = split_title(head)
    body = if remainder == "", do: more, else: [remainder | more]
    lessons = [%{first | body: body} | others]

    %{
      nn: nn,
      title: title,
      lessons: lessons |> label(length(lessons) > 1) |> attach_figures(nn, root)
    }
  end

  defp lesson(kind, path) do
    text = File.read!(path)
    raw = if kind == :ts, do: TsApiCheck.lesson(text), else: ApiCheck.lesson(text)
    {files, rest} = raw |> String.trim() |> String.split("\n") |> split_files()
    {body, api_and_picture} = Enum.split_while(rest, &(String.trim(&1) != "API you'll use"))
    {api, picture} = Enum.split_while(api_and_picture, &(not String.starts_with?(&1, "Picture:")))
    %{kind: kind, files: files, body: body, api: Enum.drop(api, 1), picture: picture}
  end

  defp label(lessons, false), do: Enum.map(lessons, &Map.put(&1, :label, nil))

  defp label(lessons, true) do
    labels = Map.new(@kinds, fn {kind, _glob, label} -> {kind, label} end)
    Enum.map(lessons, &Map.put(&1, :label, labels[&1.kind]))
  end

  defp attach_figures(lessons, nn, root) do
    lessons
    |> Enum.map_reduce([], fn lesson, seen ->
      case picture_file(lesson.picture, root) do
        nil ->
          {Map.put(lesson, :figure, nil), seen}

        file ->
          if file in seen do
            {Map.put(lesson, :figure, nil), seen}
          else
            key = if seen == [], do: nn, else: "#{nn}-#{length(seen) + 1}"
            {Map.put(lesson, :figure, {key, scope_svg(File.read!(file), key)}), [file | seen]}
          end
      end
    end)
    |> elem(0)
  end

  defp picture_file(["Picture: " <> ref | _], root) do
    file = Path.join(root, String.trim(ref))
    if String.ends_with?(file, ".svg") and File.exists?(file), do: file
  end

  defp picture_file(_picture, _root), do: nil

  defp split_files(["Files this chapter touches" | rest]) do
    {files, after_files} = Enum.split_while(rest, &String.starts_with?(&1, " "))

    entries =
      for line <- files,
          entry = line |> String.trim() |> String.trim_leading("- "),
          entry != "",
          do: entry

    {entries, Enum.drop_while(after_files, &(String.trim(&1) == ""))}
  end

  defp split_files(lesson), do: {[], lesson}

  defp split_title(line) do
    case String.split(line, ~r/\.(?:\s+|$)/, parts: 2) do
      [title, remainder] -> {title, remainder}
      [title] -> {title, ""}
    end
  end

  defp scope_svg(svg, nn) do
    ids = Regex.scan(~r/\bid="([^"]+)"/, svg) |> Enum.map(&List.last/1)

    ~r/<style>(.*?)<\/style>/s
    |> Regex.replace(svg, fn _, css -> "<style>#{scope_css(css, nn)}</style>" end)
    |> rename_ids(ids, nn)
    |> String.trim()
  end

  defp scope_css(css, nn) do
    Regex.replace(~r/([^{}]+)\{/, css, fn whole, selector ->
      trimmed = String.trim(selector)

      if String.starts_with?(trimmed, "@") do
        whole
      else
        scoped =
          trimmed
          |> String.split(",")
          |> Enum.map_join(", ", &scope_selector(String.trim(&1), nn))

        "\n    #{scoped} {"
      end
    end)
  end

  defp scope_selector(":root", nn), do: ".fig#{nn}"
  defp scope_selector(selector, nn), do: ".fig#{nn} #{selector}"

  defp rename_ids(svg, ids, nn) do
    Enum.reduce(ids, svg, fn id, acc ->
      acc
      |> String.replace(~s(id="#{id}"), ~s(id="c#{nn}-#{id}"))
      |> String.replace("url(##{id})", "url(#c#{nn}-#{id})")
      |> String.replace(~s(href="##{id}"), ~s(href="#c#{nn}-#{id}"))
    end)
  end

  defp page(chapters) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Easel koans lessons</title>
    <style>
    #{css()}
    </style>
    </head>
    <body>
    <main>
    <h1>Easel koans lessons</h1>
    <nav aria-label="Chapters">
    <ol>
    #{Enum.map_join(chapters, "\n", &index_entry/1)}
    </ol>
    </nav>
    #{Enum.map_join(chapters, "\n", &section/1)}
    </main>
    </body>
    </html>
    """
  end

  defp index_entry(%{nn: nn, title: title}),
    do: ~s(<li><a href="#ch#{nn}">#{nn} #{esc(title)}</a></li>)

  defp section(%{nn: nn, title: title, lessons: lessons}) do
    """
    <section class="chapter" id="ch#{nn}">
    <h2><span class="num">#{nn}</span> #{esc(title)}</h2>
    #{Enum.map_join(lessons, &lesson_html/1)}</section>
    """
  end

  defp lesson_html(lesson) do
    kind_heading(lesson.label) <>
      files_block(lesson.files) <>
      blocks(lesson.body) <> "\n" <> api_block(lesson.api) <> figure(lesson.figure)
  end

  defp kind_heading(nil), do: ""
  defp kind_heading(label), do: ~s(<h3 class="kind">#{label}</h3>\n)

  defp files_block([]), do: ""

  defp files_block(files) do
    items = Enum.map_join(files, "\n", &"<li>#{&1 |> esc() |> inline_path()}</li>")
    "<h3>Files this chapter touches</h3>\n<ul class=\"files\">\n#{items}\n</ul>\n"
  end

  defp inline_path(entry) do
    case String.split(entry, ": ", parts: 2) do
      [path, rest] -> "<code>#{path}</code>: #{inline_code(rest)}"
      [path] -> "<code>#{path}</code>"
    end
  end

  defp api_block(api) do
    case api |> Enum.join("\n") |> String.trim_trailing() |> String.trim_leading("\n") do
      "" -> ""
      text -> "<h3>API you'll use</h3>\n<pre>#{esc(text)}</pre>\n"
    end
  end

  defp figure(nil), do: ""

  defp figure({key, svg}),
    do: ~s(<figure class="fig fig#{key}" id="fig-#{key}">\n#{svg}\n</figure>\n)

  defp blocks(lines) do
    lines
    |> Enum.chunk_by(&code_line?/1)
    |> merge_code_gaps()
    |> Enum.map_join("\n", fn
      {:code, group} ->
        "<pre>#{group |> trim_blank() |> dedent() |> Enum.join("\n") |> esc()}</pre>"

      {:text, group} ->
        text_paragraphs(group)
    end)
  end

  defp code_line?(line), do: String.starts_with?(line, "    ")

  defp merge_code_gaps(chunks) do
    chunks
    |> Enum.map(fn group -> {if(code_line?(hd(group)), do: :code, else: :text), group} end)
    |> join_code_across_blanks()
  end

  defp join_code_across_blanks([{:code, a}, {:text, gap}, {:code, b} | rest]),
    do:
      if(blank_only?(gap),
        do: join_code_across_blanks([{:code, a ++ gap ++ b} | rest]),
        else: [{:code, a}, {:text, gap} | join_code_across_blanks([{:code, b} | rest])]
      )

  defp join_code_across_blanks([first | rest]), do: [first | join_code_across_blanks(rest)]
  defp join_code_across_blanks([]), do: []

  defp dedent(lines) do
    indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&(byte_size(&1) - byte_size(String.trim_leading(&1))))
      |> Enum.min(fn -> 0 end)

    Enum.map(lines, &String.slice(&1, indent..-1//1))
  end

  defp blank_only?(group), do: Enum.all?(group, &(String.trim(&1) == ""))

  defp trim_blank(group),
    do:
      group
      |> Enum.drop_while(&(&1 == ""))
      |> Enum.reverse()
      |> Enum.drop_while(&(&1 == ""))
      |> Enum.reverse()

  defp text_paragraphs(group) do
    group
    |> Enum.chunk_by(&(String.trim(&1) == ""))
    |> Enum.reject(&blank_only?/1)
    |> Enum.map_join("\n", fn para ->
      "<p>#{para |> Enum.map_join(" ", &String.trim/1) |> esc() |> inline_code()}</p>"
    end)
  end

  defp inline_code(text), do: Regex.replace(~r/`([^`]+)`/, text, "<code>\\1</code>")

  defp esc(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp css do
    """
    :root { --bg: #ffffff; --fg: #1f2933; --muted: #52606d; --code-bg: #f1f4f8; --border: #d5dbe3; --link: #1a56b0; }
    @media (prefers-color-scheme: dark) {
      :root { --bg: #1b1f23; --fg: #e6e9ec; --muted: #9aa5b1; --code-bg: #262c33; --border: #3a424b; --link: #7ab3ff; }
    }
    * { box-sizing: border-box; }
    html { -webkit-text-size-adjust: 100%; }
    body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.55 system-ui, sans-serif; }
    main { max-width: 46rem; margin: 0 auto; padding: 1rem 16px 4rem; }
    a { color: var(--link); }
    nav ol { columns: 16rem; list-style: none; padding: 0; margin: 0 0 2rem; }
    nav li { padding: 0.15rem 0; break-inside: avoid; }
    .chapter { border-top: 1px solid var(--border); padding-top: 1rem; margin-top: 2rem; }
    h2 { font-size: 1.3rem; margin: 0 0 0.75rem; overflow-wrap: anywhere; }
    h3 { font-size: 1rem; color: var(--muted); margin: 1.25rem 0 0.25rem; }
    h3.kind { font-size: 1.05rem; color: var(--fg); margin-top: 1.75rem; }
    .num { color: var(--muted); font-variant-numeric: tabular-nums; }
    ul.files { margin: 0.25rem 0 0.6rem; padding-left: 1.25rem; }
    p { margin: 0.6rem 0; overflow-wrap: anywhere; }
    code, pre { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 0.875rem; }
    code { background: var(--code-bg); padding: 0.05rem 0.25rem; border-radius: 3px; }
    pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 6px; padding: 0.6rem 0.8rem; overflow-x: auto; margin: 0.6rem 0; }
    figure { margin: 1rem 0 0; }
    figure svg { display: block; max-width: 100%; height: auto; border: 1px solid var(--border); border-radius: 6px; }
    """
    |> String.trim_trailing()
  end
end
