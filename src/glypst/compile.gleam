//// Types and functions for the `typst compile` command.

import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_builder.{type StringBuilder}
import gleam/regex

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

/// The source span at the start of a diagnostic, if it is attached to one.
pub type Span {
  Span(file: String, line: Int, column: Int)
}

/// A Typst compilation warning. Does not interrupt compilation and can be
/// returned even on success.
pub type TypstWarning {
  TypstWarning(span: Option(Span), message: String)
}

/// A Typst compilation error. Interrupts compilation.
pub type TypstError {
  TypstError(span: Option(Span), message: String)
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

/// Parses lines of Typst diagnostics in the short form, which may either have a span:
/// /path/to/file.typ:1:10: warning: something
/// Or not:
/// error: something
///
/// Returns the lines before the first diagnostic as a single string and the
/// list of parsed diagnostics.
fn parse_typst_diagnostics_aux(
  output_lines: List(String),
  initial_output: StringBuilder,
  diagnostics: List(Diagnostic),
) -> #(StringBuilder, List(Diagnostic)) {
  case output_lines {
    [""] -> parse_typst_diagnostics_aux([], initial_output, diagnostics)
    [line, ..lines] -> {
      let assert Ok(pattern) =
        regex.from_string("(?:(.+):(\\d+):(\\d+): )?(warning|error): (.+)")
      let matches =
        line
        |> regex.scan(with: pattern)

      case matches {
        [
          regex.Match(
            submatches: [
              Some(file),
              Some(start),
              Some(end),
              Some(diagnostic_kind),
              Some(message),
            ],
            ..,
          ),
        ] -> {
          let assert Ok(start) = int.parse(start)
          let assert Ok(end) = int.parse(end)
          let span = Span(file, start, end)
          let diagnostic = case diagnostic_kind {
            "warning" -> DiagnosticWarning(TypstWarning(Some(span), message))
            "error" -> DiagnosticError(TypstError(Some(span), message))
            _ -> panic as "invalid diagnostic kind received"
          }

          parse_typst_diagnostics_aux(lines, initial_output, [
            diagnostic,
            ..diagnostics
          ])
        }

        [
          regex.Match(
            submatches: [
              _file,
              _start,
              _end,
              Some(diagnostic_kind),
              Some(message),
            ],
            ..,
          ),
        ] -> {
          let diagnostic = case diagnostic_kind {
            "warning" -> DiagnosticWarning(TypstWarning(None, message))
            "error" -> DiagnosticError(TypstError(None, message))
            _ -> panic as "invalid diagnostic kind received"
          }

          parse_typst_diagnostics_aux(lines, initial_output, [
            diagnostic,
            ..diagnostics
          ])
        }

        _ ->
          case diagnostics {
            [DiagnosticWarning(TypstWarning(span, message)), ..tail_diagnostics] -> {
              // An invalid diagnostic line is assumed to be part of the previous one.
              let new_diagnostic =
                DiagnosticWarning(TypstWarning(span, message <> "\n" <> line))

              parse_typst_diagnostics_aux(lines, initial_output, [
                new_diagnostic,
                ..tail_diagnostics
              ])
            }

            [DiagnosticError(TypstError(span, message)), ..tail_diagnostics] -> {
              let new_diagnostic =
                DiagnosticError(TypstError(span, message <> "\n" <> line))

              parse_typst_diagnostics_aux(lines, initial_output, [
                new_diagnostic,
                ..tail_diagnostics
              ])
            }

            [] -> {
              // No diagnostics yet, so this line is part of the initial output.
              let initial_output =
                initial_output
                |> string_builder.append("\n" <> line)

              parse_typst_diagnostics_aux(lines, initial_output, [])
            }
          }
      }
    }

    [] -> #(initial_output, diagnostics)
  }
}

/// Parses the output of `typst compile --diagnostic-format short` into a
/// string (output before the first diagnostic) and a list of diagnostics.
pub fn parse_typst_diagnostics(
  output: String,
) -> #(StringBuilder, List(Diagnostic)) {
  let lines =
    output
    |> string.split(on: "\n")

  parse_typst_diagnostics_aux(lines, string_builder.new(), [])
}
