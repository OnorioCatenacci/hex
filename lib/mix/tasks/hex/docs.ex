defmodule Mix.Tasks.Hex.Docs do
  use Mix.Task
  alias Mix.Hex.Utils

  @shortdoc "Publishes docs for package"

  @moduledoc """
  Publishes documentation for the current project and version.

  The documentation will be accessible at `https://hexdocs.pm/my_package/1.0.0`,
  `https://hexdocs.pm/my_package` will always redirect to the latest published
  version.

  Documentation will be generated by running the `mix docs` task. `ex_doc`
  provides this task by default, but any library can be used. Or an alias can be
  used to extend the documentation generation. The expected result of the task
  is the generated documentation located in the `docs/` directory with an
  `index.html` file.

  ## Command line options

    * `--revert VERSION` - Revert given version
    * `open --package PACKAGE --version VERSION` - Opens the docs for specified package in the default web browser. Defaults to current package and version.
    * `fetch --package PACKAGE  --version VERSION` - Gets a copy of the docs for the specified package and version to the local machine. Defaults to current package and version.
  """

  @switches [revert: :string, progress: :boolean, package: :string, version: :string]

  def run(args) do
    Hex.start
      
    Hex.Utils.ensure_registry(fetch: false)

    {opts, args, _} = OptionParser.parse(args, switches: @switches)
    auth = Utils.auth_info()
    Mix.Project.get!
    config  = Mix.Project.config
    name    = config[:package][:name] || config[:app]
    version = config[:version]

    package_name = if (opts[:package]), do: Atom.to_string(opts[:package]), else: Atom.to_string(name)
    package_version  = if (opts[:version]), do: opts[:version], else: version
    if revert = opts[:revert] do
      revert(name, revert, auth)
    else
      case args do
        ["open"] ->
          open_docs(package_name, package_version)
        ["fetch"] ->
          fetch_hex_docs(package_name, package_version)
        _ -> Mix.raise "Invalid arguments, expected one of:\n" <>
            "mix hex.docs open --package [PackageName] --version [PackageVersion] \n" <>
            "mix.hex.docs fetch --package [PackageName] --version [PackageVersion] \n"
      end
    end
  end
  

  defp open_docs(name,version) do
    doc_index = "#{Utils.get_docs_directory(name,version)}/index.html"
    unless File.exists?(doc_index) do
      Mix.raise "Documentation file not found: #{doc_index}"
    end
    start_browser_command =
      case (:os.type()) do
        {:win32,_} -> "start"
        {:unix,_} -> "xdg-open"
      end
  
    :os.cmd('#{start_browser_command} #{doc_index}')
  end
  
  defp fetch_hex_docs(name, version) do
    doc_dir = Utils.get_docs_directory(name,version)
    base_archive_name = "#{name}-#{version}.tar.gz"  
    doc_file_archive = "#{doc_dir}/#{base_archive_name}"
    doc_archive_url = "https://repo.hex.pm/docs/#{base_archive_name}"
    case (Utils.fetch_remote_file(doc_archive_url, nil)) do
          {:ok, resp} -> 
            unless File.exists?(doc_dir), do: :ok = File.mkdir_p(doc_dir)
            File.write!(doc_file_archive, resp)
            File.cd!(doc_dir, fn -> :erl_tar.extract(base_archive_name,[:compressed]) end)
          
          {:error, message} -> 
            Mix.raise("Unable to fetch documentation. Message returned is #{message}")
      end    
  end
    
  defp revert(name, version, auth) do
    version = Utils.clean_version(version)

    case Hex.API.ReleaseDocs.delete(name, version, auth) do
      {code, _, _} when code in 200..299 ->
        Hex.Shell.info "Reverted docs for #{name} #{version}"
      {code, body, _} ->
        Hex.Shell.error "Reverting docs for #{name} #{version} failed"
        Hex.Utils.print_error_result(code, body)
    end
  end

  defp files(directory) do
    "#{directory}/**"
    |> Path.wildcard
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&{relative_path(&1, directory), File.read!(&1)})
  end

  defp relative_path(file, dir) do
    Path.relative_to(file, dir)
    |> String.to_char_list
  end

  defp docs_dir do
    cond do
      File.exists?("doc") ->
        "doc"
      File.exists?("docs") ->
        "docs"
      true ->
        Mix.raise("Documentation could not be found. Please ensure documentation is in the doc/ or docs/ directory")
    end
  end
end
