import gleeunit
import gleeunit/should
import glance
import glance_printer

pub fn main() {
  gleeunit.main()
}

// Takes in gleam source code, parses it using
// glance, prints it using glance_printer,
// and verifies the strings match.
fn identity(src: String) {
  let assert Ok(import_stmt) = glance.module(src)
  import_stmt
  |> glance_printer.print
  |> should.equal(src)
}

// ------------- Import Tests ---------------------------

pub fn basic_import_test() {
  identity("import gleam/io")
}

pub fn import_with_alias_test() {
  identity("import gleam/io as printing_stuff")
}

pub fn import_with_single_unqualified_import_test() {
  identity("import gleam/option.{Option}")
}

pub fn import_with_multiple_unqualified_import_test() {
  identity("import gleam/option.{Option, Some, None}")
}

pub fn import_with_unqualified_and_alias_test() {
  identity("import gleam/option.{Option} as optional")
}

pub fn import_with_alias_for_unqualified_test() {
  identity("import gleam/option.{Option as Optional}")
}

pub fn import_with_multiple_unqualified_imports_with_aliases_test() {
  identity("import gleam/option.{Option as Optional, Some, None as Nothing}")
}

pub fn multiple_imports_test() {
  identity("import gleam/io\nimport gleam/option as option_stuff")
}
// ------- Custom Types -----------------------

// pub fn custom_type_test() {
//   identity(
//     "pub opaque type Cardinal(a, b) {\n  North\n East\n  South\n West\n}",
//   )
// }
