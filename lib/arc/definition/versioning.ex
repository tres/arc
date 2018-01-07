defmodule Arc.Definition.Versioning do
  defmacro __using__(_) do
    quote do
      @versions [:original]
      @before_compile Arc.Definition.Versioning
    end
  end
  
  def resolve_file_name(definition, version, {file, scope}, options \\ []) do
    name = definition.filename(version, {file, scope})
    conversion = definition.transform(version, {file, scope})
    saved_versions = definition.saved_versions(scope)

    # 1 behave as we always have if legacy behavior is invoked
    # 2 if no frame is selected and more than one is available, then return the name with the first frame embedded using the filename from the stored set
    # 3 if a frame is selected, and it is available, then return the filename from the stored set
    # 4 if a filename is requested and saved_versions is populated, but no matching version is found, we should raise an exception.
    case conversion do
      {_, _, ext} -> converted_file_name(name, ext, saved_versions, options)
       _          -> "#{name}#{Path.extname(file.file_name)}"
    end
  end

  defp converted_file_name(name, ext, saved_versions, options) do
    case saved_versions do
      v when v in [nil, []] -> "#{name}.#{ext}" #legacy behavior when there's no saved versions available
      _ ->  converted_file_name_with_frame(name, ext, saved_versions, options)
    end
  end

  defp converted_file_name_with_frame(name, ext, saved_versions, options) do
    name_with_ext = "#{name}.#{ext}"
    if (Enum.member?(saved_versions, name_with_ext)), do: name_with_ext, else: filename(name, ext, saved_versions, options)
  end

  defp filename(name, ext, saved_versions, %{frame: frame }) do
    frame_num = case Integer.parse("#{frame}") do
      {num, ""} -> num
      _ -> 0
    end

    name_with_frame = "#{name}-#{frame}.#{ext}"
    if (Enum.member?(saved_versions, name_with_frame)), do: name_with_frame, else: nil
  end

  defp filename(name, ext, saved_versions, _) do
    filename(name, ext, saved_versions, %{frame: 0})
  end


  defmacro __before_compile__(_env) do
    quote do
      def transform(_, _), do: :noaction
      def saved_versions(_), do: :noaction
      def __versions, do: @versions
    end
  end
end
