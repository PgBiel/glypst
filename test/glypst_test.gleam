import glypst
import glypst/compile.{CompilationFailure, CompileError, CompileWarning, Span}
import glypst/query
import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import gleam/dynamic
import gleam/string_builder
import gleam/json

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
      with_export: [],
    )
    |> should.be_ok
}

pub fn compiles_with_warnings_test() {
  let assert [first_warn, second_warn] =
    glypst.compile_to_file(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/warn_ok.typ"),
      to: "./test/samples/warn_ok.pdf",
      with: [],
      with_export: [],
    )
    |> should.be_ok

  first_warn
  |> should.equal(CompileWarning(
    span: Some(Span(file: "test/samples/warn_ok.typ", line: 4, column: 0)),
    message: "no text within underscores",
  ))

  second_warn
  |> should.equal(CompileWarning(
    span: Some(Span(file: "test/samples/warn_ok.typ", line: 3, column: 0)),
    message: "no text within stars",
  ))
}

pub fn compilation_fails_with_error_test() {
  let assert CompilationFailure([err]) =
    glypst.compile_to_file(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/err.typ"),
      to: "./test/samples/err.pdf",
      with: [],
      with_export: [],
    )
    |> should.be_error

  err
  |> should.equal(CompileError(
    span: Some(Span(file: "test/samples/err.typ", line: 1, column: 1)),
    message: "panicked with: \"Oh no!\"",
  ))
}

pub fn compilation_without_root_fails_test() {
  glypst.compile_to_file(
    glypst.FromEnv,
    from: compile.SourceFile("./test/samples/import/imports.typ"),
    to: "./test/samples/import/imports.pdf",
    with: [],
    with_export: [],
  )
  |> should.be_error
}

pub fn compilation_with_root_succeeds_test() {
  glypst.compile_to_file(
    glypst.FromEnv,
    from: compile.SourceFile("./test/samples/import/imports.typ"),
    to: "./test/samples/import/imports.pdf",
    with: [compile.Root("./test/samples")],
    with_export: [],
  )
  |> should.be_ok
}

pub fn query_heading_succeeds_test() {
  let assert #(query_result, _) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "heading",
      with_compile: [],
      with_query: [],
    )
    |> should.be_ok

  let matched_labels =
    query_result
    |> string_builder.to_string
    |> json.decode(
      dynamic.list(dynamic.field(named: "label", of: dynamic.string)),
    )

  matched_labels
  |> should.be_ok
  |> should.equal(["<lblA>", "<lblB>"])
}

pub fn query_heading_label_succeeds_test() {
  let assert #(query_result, _) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "heading",
      with_compile: [],
      with_query: [query.Field("label")],
    )
    |> should.be_ok

  let matched_labels =
    query_result
    |> string_builder.to_string
    |> json.decode(dynamic.list(of: dynamic.string))

  matched_labels
  |> should.be_ok
  |> should.equal(["<lblA>", "<lblB>"])
}

pub fn query_unknown_label_succeeds_test() {
  let assert #(query_result, _) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "<lalalala>",
      with_compile: [],
      with_query: [query.Field("label")],
    )
    |> should.be_ok

  let matched_labels =
    query_result
    |> string_builder.to_string
    |> json.decode(dynamic.list(of: dynamic.string))

  matched_labels
  |> should.be_ok
  |> should.equal([])
}

pub fn query_one_label_succeeds_test() {
  let assert #(query_result, _) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "<a>",
      with_compile: [],
      with_query: [query.One],
    )
    |> should.be_ok

  let matched_labels =
    query_result
    |> string_builder.to_string
    |> json.decode(dynamic.field(named: "label", of: dynamic.string))

  matched_labels
  |> should.be_ok
  |> should.equal("<a>")
}

pub fn query_one_label_with_yaml_succeeds_test() {
  let assert #(query_result, _) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "<a>",
      with_compile: [],
      with_query: [query.Format(query.Yaml)],
    )
    |> should.be_ok

  query_result
  |> string_builder.to_string
  |> should.equal(
    "\n- func: metadata
  value: a
  label: <a>\n",
  )
}

pub fn query_one_heading_fails_test() {
  let assert CompilationFailure(errors) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "heading",
      with_compile: [],
      with_query: [query.One],
    )
    |> should.be_error

  errors
  |> should.equal([
    CompileError(span: None, message: "expected exactly one element, found 2"),
  ])
}

pub fn query_one_unknown_figure_fails_test() {
  let assert CompilationFailure(errors) =
    glypst.query(
      glypst.FromEnv,
      from: compile.SourceFile("./test/samples/query.typ"),
      matching: "figure.where(kind: \"unknown\")",
      with_compile: [],
      with_query: [query.One],
    )
    |> should.be_error

  errors
  |> should.equal([
    CompileError(span: None, message: "expected exactly one element, found 0"),
  ])
}
