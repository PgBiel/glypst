import glypst
import glypst/compile.{DiagnosticError, Span, TypstError, TypstWarning}
import gleeunit
import gleeunit/should
import gleam/option.{Some}

pub fn main() {
  gleeunit.main()
}

pub fn compiles_ok_test() {
  let assert [] =
    glypst.compile_to_file(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/ok.typ"),
      to: "./test/samples/ok.pdf",
      with: [],
    )
    |> should.be_ok
    |> should.be_ok
}

pub fn compiles_with_warnings_test() {
  let assert [first_warn, second_warn] =
    glypst.compile_to_file(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/warn_ok.typ"),
      to: "./test/samples/warn_ok.pdf",
      with: [],
    )
    |> should.be_ok
    |> should.be_ok

  first_warn
  |> should.equal(TypstWarning(
    span: Some(Span(file: "test/samples/warn_ok.typ", line: 4, column: 0)),
    message: "no text within underscores",
  ))

  second_warn
  |> should.equal(TypstWarning(
    span: Some(Span(file: "test/samples/warn_ok.typ", line: 3, column: 0)),
    message: "no text within stars",
  ))
}

pub fn compilation_fails_with_error_test() {
  let assert [err] =
    glypst.compile_to_file(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/err.typ"),
      to: "./test/samples/err.pdf",
      with: [],
    )
    |> should.be_ok
    |> should.be_error

  err
  |> should.equal(
    DiagnosticError(TypstError(
      span: Some(Span(file: "test/samples/err.typ", line: 1, column: 1)),
      message: "panicked with: \"Oh no!\"",
    )),
  )
}
