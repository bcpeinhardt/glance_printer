import gleam/int
import gleam/io
import gleam/list
import gleam/result

fn use_statement() {
  use number <- list.each([1, 2, 3, 4, 5])
  Nil
}

fn use_statement_typed() {
  use num: Int <- result.try(Ok(123))
  Ok(num)
}
