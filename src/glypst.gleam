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
