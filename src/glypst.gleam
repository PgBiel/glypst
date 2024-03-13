import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import shellout

type TypstResult(a) =
  Result(a, #(Int, String))

fn run_typst(
  typst: Option(String),
  with arguments: List(String),
) -> TypstResult(String) {
  shellout.command(
    run: option.unwrap(typst, or: "typst"),
    with: arguments,
    in: ".",
    opt: [],
  )
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
) -> TypstResult(List(String)) {
  let font_path_args =
    font_paths
    |> list.flat_map(with: fn(path) { ["--font-path", path] })

  use output <- result.try(run_typst(typst, ["fonts", ..font_path_args]))

  // Output of 'typst fonts' has one font per line.
  Ok(string.split(output, on: "\n"))
}

pub type ExportFormat {
  Pdf
  Png
  Svg
}

pub type CompileOption {
  Root(path: String)
  FontPaths(List(String))
  Format(ExportFormat)
  Ppi(Int)
  Timings(output_path: String)
}

pub type Diagnostic {
  TypstWarning(file: String, start: Int, end: Int, message: String)
  TypstError(file: String, start: Int, end: Int, message: String)
}

fn convert_option_to_flags(option: CompileOption) -> List(String) {
  case option {
    Root(root) -> ["--root", root]
    FontPaths(paths) -> list.flat_map(paths, fn(path) { ["--font-path", path] })
    Format(Pdf) -> ["--format", "pdf"]
    Format(Png) -> ["--format", "png"]
    Format(Svg) -> ["--format", "svg"]
    Ppi(ppi) -> ["--ppi", int.to_string(ppi)]
    Timings(output_path) -> ["--timings", output_path]
  }
}

pub fn compile_to_file(
  typst: Option(String),
  from source: String,
  to output: String,
  with options: List(CompileOption),
) -> TypstResult(Result(List(Diagnostic), List(Diagnostic))) {
  let args =
    options
    |> list.flat_map(convert_option_to_flags)
    |> list.append(["--diagnostic-format", "short", output])

  case run_typst(typst, ["compile", source, ..args]) {
    // TODO: Parse diagnostics
    Ok(_) -> Ok(Ok([]))
    Error(#(status, err)) ->
      case status {
        // TODO: Parse diagnostics
        1 -> Ok(Error([]))
        // CLI error (not Typst error)
        _ -> Error(#(status, err))
      }
  }
}
