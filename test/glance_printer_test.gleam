import gleam/string
import gleeunit
import gleeunit/should
import glance
import glance_printer
import simplifile
import gleam/io
import gleam/list

pub fn main() {
  gleeunit.main()
}

// Reads in gleam source code from ./test/gleam_examples and verifies that when parsed
// and reprinted the format is unchanged
pub fn file_runner_test() {
  // For each file in gleam examples
  let assert Ok(files) = simplifile.list_contents(of: "./test/gleam_examples")
  let files =
    files
    |> list.map(fn(filename) { "./test/gleam_examples/" <> filename })
  use file <- list.each(files)
  let assert Ok(gleam_src) = simplifile.read(file)
  identity(gleam_src)
}

// Takes in gleam source code, parses it using
// glance, prints it using glance_printer,
// and verifies the strings match.
fn identity(src: String) {
  let assert Ok(module) = glance.module(src)
  module
  |> glance_printer.print
  |> should.equal(src)
}
