pub fn foo(first, second: Int, labelled third: Int) -> Int {
  -6
}

fn bar() {
  1
}

@target(javascript)
@external(javascript, "./test/test_external.mjs", "isFile")
fn do_is_file(filepath: String) -> Bool

@target(erlang)
@external(erlang, "filelib", "is_dir")
fn do_is_directory(path: String) -> Bool
