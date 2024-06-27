import glance
import glance_printer
import gleam/list
import gleam/string
import simplifile
import testbldr

pub fn main() {
  let test_runner = testbldr.test_runner_default()
  test_runner
  |> testbldr.run(file_based_tests())
}

fn file_based_tests() {
  let assert Ok(files) = simplifile.read_directory(at: "./test/gleam_examples")
  use file <- list.map(files)
  let assert Ok(gleam_src) = simplifile.read("./test/gleam_examples/" <> file)
  let assert Ok(test_name) =
    file
    |> string.split(".")
    |> list.first
  use <- testbldr.named(test_name)
  identity(gleam_src)
}

// Takes in gleam source code, parses it using
// glance, prints it using glance_printer,
// and verifies the strings match.
fn identity(src: String) {
  let assert Ok(module) = glance.module(src)
  let printed = glance_printer.print(module)
  case printed == src {
    True -> testbldr.Pass
    False -> {
      testbldr.Fail("\n\nexpected:\n" <> src <> "\ngot:\n" <> printed <> "\n")
    }
  }
}
