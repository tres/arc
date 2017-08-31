defmodule Arc.Actions.Store do
  defmacro __using__(_) do
    quote do
      def store(args), do: Arc.Actions.Store.store(__MODULE__, args)
    end
  end

  def store(definition, {file, scope}) when is_binary(file) or is_map(file) do
    put(definition, {Arc.File.new(file), scope})
  end

  def store(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    store(definition, {filepath, nil})
  end

  #
  # Private
  #

  defp put(_definition, { error = {:error, _msg}, _scope}), do: error
  defp put(definition, {%Arc.File{}=file, scope}) do
    case definition.validate({file, scope}) do
      true -> put_versions(definition, {file, scope})
      _    -> {:error, :invalid_file}
    end
  end

  defp put_versions(definition, {file, scope}) do
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)    -> async_put_version(definition, r, {file, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> handle_responses(file.file_name)
    else
      definition.__versions
      |> Enum.map(fn(version) -> put_version(definition, version, {file, scope}) end)
      |> handle_responses(file.file_name)
    end
  end

  defp handle_responses(responses, filename) do
    errors = Enum.map(responses, fn(response) -> handle_response(response, filename, [])  end)
             |> List.flatten
    if Enum.empty?(errors), do: {:ok, filename}, else: {:error, errors}
  end

  defp handle_response([head | tail], filename, errors) do
    handle_response(tail, filename, errors ++ [handle_response(head, filename, errors)])
  end

  defp handle_response({:error, err}, filename, errors) do
    Enum.map(fn(err) -> elem(err, 1) end)
  end

  defp handle_response(_, _, errors) do
    errors
  end


  defp version_timeout do
    Application.get_env(:arc, :version_timeout) || 15_000
  end

  defp async_put_version(definition, version, {file, scope}) do
    Task.async(fn ->
      put_version(definition, version, {file, scope})
    end)
  end

  defp put_version(definition, version, {file, scope}) do
    case Arc.Processor.process(definition, version, {file, scope}) do
      {:error, error} -> {:error, error}
      {:ok, file} ->
        if is_list(file) do
          files = Enum.with_index(file)
          |> Enum.map(fn({f, idx}) ->
                            file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {f, scope}, idx)
                            file      = %Arc.File{f | file_name: file_name} end)
          definition.__storage.put(definition, version, {files, scope})
        else
          file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
          file      = %Arc.File{file | file_name: file_name}
          definition.__storage.put(definition, version, {file, scope})
        end
    end
  end
end
