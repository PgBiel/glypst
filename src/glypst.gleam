//// Glypst is a library which lets you easily interact with the Typst CLI
//// through Gleam, using the amazing `shellout` library under the hood.
import glypst/compile.{
  type CompileOption, type Diagnostic, type TypstSource, type TypstWarning,
  DiagnosticWarning, Pdf, Png, Svg,
}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import shellout

/// Possible result from compilation with the CLI.
/// Refers to errors produced by the CLI itself (e.g. invalid arguments)
/// and not to Typst compilation errors.
pub type CliResult(a) =
  Result(a, #(Int, String))

/// Internal utility function to run Typst with the given arguments at the
/// current directory.
fn run_typst_cli(
  typst: Option(String),
  with arguments: List(String),
) -> CliResult(String) {
  shellout.command(
    run: option.unwrap(typst, or: "typst"),
    with: arguments,
    in: ".",
    opt: [],
  )
}

/// Converts a compilation option to the relevant paths.
fn convert_compile_option_to_flags(option: CompileOption) -> List(String) {
  case option {
    compile.Root(root) -> ["--root", root]
    compile.FontPaths(paths) ->
      list.flat_map(paths, fn(path) { ["--font-path", path] })
    compile.Format(Pdf) -> ["--format", "pdf"]
    compile.Format(Png) -> ["--format", "png"]
    compile.Format(Svg) -> ["--format", "svg"]
    compile.Ppi(ppi) -> ["--ppi", int.to_string(ppi)]
    compile.Timings(output_path) -> ["--timings", output_path]
  }
}

/// Compiles some Typst source code to a file.
/// At the moment, the source must be in a file.
///
/// When the Typst CLI itself fails (e.g. due to an invalid parameter value),
/// the process status code is different from 0 (not successful) and from 1
/// (compilation error). Therefore, the status code and the resulting message
/// are directly returned in such a case.
///
/// When the command is valid and accepted, the compilation is run, and the
/// warnings and errors are collected. When there are only warnings, the
/// compilation succeeds and they are returned via a list. When there's at
/// least one error, it and other errors and warnings are returned in the same
/// list.
pub fn compile_to_file(
  typst: Option(String),
  from source: TypstSource,
  to output: String,
  with options: List(CompileOption),
) -> CliResult(Result(List(TypstWarning), List(Diagnostic))) {
  let args =
    options
    |> list.flat_map(convert_compile_option_to_flags)
    |> list.append(["--diagnostic-format", "short", output])

  case run_typst_cli(typst, ["compile", source.path, ..args]) {
    Ok(output) ->
      Ok(Ok(
        output
        |> compile.parse_typst_diagnostics
        |> list.map(fn(diagnostic) {
          // When the Typst command is successful, only warnings remain.
          let assert DiagnosticWarning(warning) = diagnostic
          warning
        }),
      ))
    Error(#(status, err)) ->
      case status {
        1 ->
          Ok(Error(
            err
            |> compile.parse_typst_diagnostics,
          ))

        // CLI error (not Typst error)
        _ -> Error(#(status, err))
      }
  }
}

/// Lists all fonts found by Typst in the default font paths of the system.
/// Also includes any fonts in the paths of the given list of font paths, if
/// any.
///
/// The first option must either be the path to a valid Typst binary, or None
/// to use `typst` from the current PATH.
pub fn fonts(
  typst: Option(String),
  font_paths: List(String),
) -> CliResult(List(String)) {
  let font_path_args =
    font_paths
    |> list.flat_map(with: fn(path) { ["--font-path", path] })

  use output <- result.try(run_typst_cli(typst, ["fonts", ..font_path_args]))

  // Output of 'typst fonts' has one font per line.
  Ok(string.split(output, on: "\n"))
}
