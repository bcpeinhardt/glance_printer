import gleam/string
import glance
import glance_printer
import simplifile
import gleam/list
import testbldr
import gap

pub fn main() {
  testbldr.new
  |> testbldr.tests(file_based_tests())
  |> testbldr.run
}

fn file_based_tests() {
  let assert Ok(files) = simplifile.list_contents(of: "./test/gleam_examples")
  use file <- list.map(files)
  let assert Ok(gleam_src) = simplifile.read("./test/gleam_examples/" <> file)
  let assert Ok(test_name) =
    file
    |> string.split(".")
    |> list.first
  #(test_name, fn() { identity(gleam_src) })
}

// Takes in gleam source code, parses it using
// glance, prints it using glance_printer,
// and verifies the strings match.
fn identity(src: String) {
  let assert Ok(module) = glance.module(src)
  let printed = glance_printer.print(module)
  case printed == src {
    True -> testbldr.pass()
    False -> {
      let comparison =
        gap.compare_strings(src, printed)
        |> gap.to_styled
      testbldr.fail(
        "\n\nlhs:\n" <> comparison.first <> "\nrhs:\n" <> comparison.second,
      )
    }
  }
}
