import gleam/int
import gleam/io
import gleam/list

fn use_statement() {
  use number <- list.each([1, 2, 3, 4, 5])
  Nil
}
