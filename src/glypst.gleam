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

/// Format of the document output produced by Typst.
pub type ExportFormat {
  /// Generate a PDF containing all pages.
  Pdf
  /// Generate one PNG per page.
  /// Requires a filename of the form 'name-{n}.png', for example
  /// 'output-{n}.png', if there can be more than one page. Then, Typst will
  /// replace the {n} by the page number.
  Png
  /// Generate one SVG per page.
  /// Use {n} to indicate the page number in the exported filenames, just as
  /// for the PNG format.
  Svg
}

/// Optional parameters when compiling a Typst document.
pub type CompileOption {
  /// The root of the virtual filesystem exposed to Typst scripts.
  /// This path will be `/` within Typst, and files outside it cannot be
  /// accessed, unless there are symbolic links to them or their directories
  /// within this path.
  Root(path: String)
  /// Paths with extra font files for Typst to check and make available when
  /// compiling. Typst will check these directories recursively looking for
  /// valid font files (such as `.ttf` or `.otf`). You can use the `fonts`
  /// command to find out which font files Typst can find in these paths.
  FontPaths(List(String))
  /// The document format to export the Typst document to.
  Format(ExportFormat)
  /// The resolution of the exported image in pixels-per-inch.
  Ppi(Int)
  /// Generate performance data during the document's compilation and save it
  /// as a JSON file in the given output path. The data can be visualized using
  /// tools such as Perfetto.
  Timings(output_path: String)
}

/// A Typst compilation warning. Does not interrupt compilation and can be
/// returned even on success.
pub type TypstWarning {
  TypstWarning(file: String, start: Int, end: Int, message: String)
}

/// A Typst compilation error. Interrupts compilation.
pub type TypstError {
  TypstError(file: String, start: Int, end: Int, message: String)
}

/// A diagnostic returned by Typst during compilation.
pub type Diagnostic {
  /// A warning. This does not interrupt compilation.
  DiagnosticWarning(TypstWarning)
  /// An error. This interrupts compilation.
  DiagnosticError(TypstError)
}

/// Possible Typst source code forms.
pub type TypstSource {
  /// Use a file's contents as source.
  /// Typst files usually have the `.typ` extension, but it isn't required.
  SourceFile(path: String)
}

/// Converts a compilation option to the relevant paths.
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
    |> list.flat_map(convert_option_to_flags)
    |> list.append(["--diagnostic-format", "short", output])

  case run_typst_cli(typst, ["compile", source.path, ..args]) {
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
