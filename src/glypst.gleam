//// Glypst is a library which lets you easily interact with the Typst CLI
//// through Gleam, using the amazing `shellout` library under the hood.

import glypst/compile.{
  type CompileOption, type Diagnostic, type ExportOption, type TypstCommandError,
  type TypstSource, CliError, CompilationFailure, Pdf, Png, Svg,
}
import glypst/query.{type QueryOption}
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import shellout

/// The Typst installation to use for commands.
pub type Typst {
  /// Use the `typst` binary in the current $PATH.
  /// Requires Typst to be installed, or the environment to be properly
  /// configured.
  FromEnv

  /// Use the `typst` binary at the specified path.
  FromPath(path: String)
}

/// Possible result from compilation with the CLI.
/// Refers to errors produced by the CLI itself (e.g. invalid arguments)
/// and not to Typst compilation errors.
pub type CliResult(a) =
  Result(a, #(Int, String))

/// Internal utility function to run Typst with the given arguments at the
/// current directory.
fn run_typst_cli(
  typst: Typst,
  with arguments: List(String),
) -> CliResult(String) {
  let typst_path = case typst {
    FromEnv -> "typst"
    FromPath(path) -> path
  }

  shellout.command(run: typst_path, with: arguments, in: ".", opt: [])
}

/// Runs the Typst CLI command and assumes it may output diagnostics based on
/// the given Typst source code.
///
/// If it is successful (status code 0), parses the returned output looking for
/// diagnostics, and separates the initial output from the found diagnostics.
///
/// If it is not successful and exits with status code 1, parses the returned
/// output looking for diagnostics (usually there was an error then).
///
/// If it exits with some other status code, the code and the output are
/// directly returned.
fn run_typst_cli_with_diagnostics(
  typst: Typst,
  with arguments: List(String),
) -> Result(#(StringBuilder, List(Diagnostic)), TypstCommandError) {
  case run_typst_cli(typst, arguments) {
    Ok(output) ->
      Ok({
        output
        |> compile.parse_typst_diagnostics
      })

    Error(#(status, err)) ->
      case status {
        1 ->
          Error({
            let #(_, diagnostics) =
              err
              |> compile.parse_typst_diagnostics

            CompilationFailure(diagnostics)
          })

        // CLI error (not Typst error)
        _ -> Error(CliError(status, err))
      }
  }
}

/// Converts a compilation option to the relevant args.
fn convert_compile_option_to_flags(option: CompileOption) -> List(String) {
  case option {
    compile.Root(root) -> ["--root", root]
    compile.FontPaths(paths) ->
      list.flat_map(paths, fn(path) { ["--font-path", path] })

    compile.Inputs(inputs) ->
      inputs
      |> dict.to_list
      |> list.flat_map(fn(pair) {
        let #(key, value) = pair
        case string.contains(does: key, contain: "=") {
          True ->
            panic as {
              "Typst input keys cannot contain the equals sign (=). Got: "
              <> key
            }
          False -> ["--input", key <> "=" <> value]
        }
      })
  }
}

/// Converts an export option to the relevant args.
fn convert_export_option_to_flags(option: ExportOption) -> List(String) {
  case option {
    compile.Format(Pdf) -> ["--format", "pdf"]
    compile.Format(Png) -> ["--format", "png"]
    compile.Format(Svg) -> ["--format", "svg"]
    compile.Ppi(ppi) -> ["--ppi", int.to_string(ppi)]
    compile.Timings(output_path) -> ["--timings", output_path]
  }
}

/// Converts a query option to the relevant args.
fn convert_query_option_to_flags(option: QueryOption) -> List(String) {
  case option {
    query.Format(query.Json) -> ["--format", "json"]
    query.Format(query.Yaml) -> ["--format", "yaml"]
    query.Field(field) -> ["--field", field]
    query.One -> ["--one"]
  }
}

/// Compiles some Typst source code to a file.
/// At the moment, the source must be in a file.
///
/// When the Typst CLI itself fails (e.g. due to an invalid parameter value),
/// the process status code is different from 0 (not successful) and from 1
/// (compilation error). Therefore, the status code and the resulting message
/// are directly returned under `CliError` (variant of `TypstCommandError`) in
/// such a case.
///
/// When the command is valid and accepted, the compilation is run, and the
/// warnings and errors are collected. When there are only warnings, the
/// compilation succeeds and they are returned via a list. When there's at
/// least one error, it and other errors and warnings are returned in the same
/// list, under `CompilationFailure` (also a `TypstCommandError`).
pub fn compile_to_file(
  typst typst: Typst,
  from source: TypstSource,
  to output: String,
  with options: List(CompileOption),
  with_export export_options: List(ExportOption),
) -> Result(List(Diagnostic), TypstCommandError) {
  let compile_args =
    options
    |> list.flat_map(convert_compile_option_to_flags)

  let export_args =
    export_options
    |> list.flat_map(convert_export_option_to_flags)

  let args =
    compile_args
    |> list.append(export_args)
    |> list.append(["--diagnostic-format", "short", output])

  run_typst_cli_with_diagnostics(typst, ["compile", source.path, ..args])
  |> result.map(fn(output_with_warnings) {
    let #(_, warnings) = output_with_warnings
    warnings
  })
}

/// Queries all elements in the given Typst document matching the given selector
/// expression (must be valid Typst syntax). Note that this requires compiling
/// the document first, so compilation options are accepted as well.
///
/// See the documentation for the `compile` function to see in which
/// circumstances an error may be returned by this function.
/// This function will additionally error with a `CompilationFailure` if the
/// selector is invalid.
/// When the query succeeds, a tuple with the query output and the list of produced warnings
/// (if any) is returned.
pub fn query(
  typst typst: Typst,
  from source: TypstSource,
  matching selector: String,
  with_compile compile_options: List(CompileOption),
  with_query query_options: List(QueryOption),
) -> Result(#(StringBuilder, List(Diagnostic)), TypstCommandError) {
  let compile_args =
    compile_options
    |> list.flat_map(convert_compile_option_to_flags)

  let query_args =
    query_options
    |> list.flat_map(convert_query_option_to_flags)

  let args =
    compile_args
    |> list.append(query_args)
    |> list.append(["--diagnostic-format", "short", selector])

  run_typst_cli_with_diagnostics(typst, ["query", source.path, ..args])
}

/// Lists all fonts found by Typst in the default font paths of the system.
/// Also includes any fonts within the directories in the given list of font
/// paths, if given.
pub fn fonts(
  typst typst: Typst,
  include font_paths: List(String),
) -> CliResult(List(String)) {
  let font_path_args =
    font_paths
    |> list.flat_map(with: fn(path) { ["--font-path", path] })

  use output <- result.try(run_typst_cli(typst, ["fonts", ..font_path_args]))

  // Output of 'typst fonts' has one font per line.
  Ok(string.split(output, on: "\n"))
}
