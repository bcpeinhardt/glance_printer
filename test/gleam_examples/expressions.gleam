import gleam/list

const x = 5

fn foo() {
  -x
  7
  8.7
  "Hello"
  x
  !True
  {
    2
    3
  }
  panic
  panic as "Some message"
  todo
  todo as "Some message"
  #(1, "text", True, x)
  #(
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
  )
  [1, 2, 3, 4, ..[5, 6, 7]]
  fn(input: Int, another_input) -> Int {
    input
    another_input
    10
  }
  #(1, 2).0
  let x = #(3, 4)
  x.1
  let identity = list.map(_, fn(x) { x })
  let drop = fn(thing) { todo }
  <<"hello":utf8>>
  <<
    0:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1,
    1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1, 1:1,
  >>
  <<3:size(4)-unit(4)>>
  let assert <<"Hello Gleam 💫":utf8>> = <<"Hello Gleam 💫":utf8>>
  case 2, 3 {
    2, 3 | 2, 4 -> True
    _, _ if False -> False
    _, _ -> True
  }
  4 == 2 + 2
}
