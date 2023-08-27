import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/option.{None, Some}
import glance.{Definition, Import, Module}

/// Stringify a gleam module
pub fn print(module module: Module) -> String {
  // Imports
  print_imports(module.imports)
}

// Print a list of gleam imports
fn print_imports(imports: List(Definition(Import))) -> String {
  imports
  |> list.map(fn(import_) {
    let Definition(_attribute, import_) = import_
    print_import(import_)
  })
  // Glance is reversign the imports when it parses them,
  // so we reverse them back
  |> list.reverse
  |> delimited_by("\n")
  |> string_builder.to_string
}

fn print_import(input: Import) -> StringBuilder {
  let Import(module, alias, unqualified_imports) = input
  // Start with import keyword plus the module name
  string_builder.from_string("import ")
  |> string_builder.append(module)
  // Handle unqualified imports
  |> case unqualified_imports {
    // No unqualified imports
    [] -> append_nothing()

    // Some unqualified imports
    unqualifieds -> string_builder.append_builder(
      _,
      // Unqualified imports are wrapped in squiggly brackets
      string_builder.from_string(".{")
      |> string_builder.append_builder(
        unqualifieds
        |> list.map(fn(unqualified) {
          // Add the name of each import
          string_builder.from_string(unqualified.name)
          // Add the alias of each import if it has one
          |> case unqualified.alias {
            Some(alias) -> string_builder.append(_, " as " <> alias)
            None -> append_nothing()
          }
        })
        // Unqualified imports are separated by commas
        |> delimited_by(", "),
      )
      |> string_builder.append("}"),
    )
  }
  |> case alias {
    Some(alias_str) -> string_builder.append(_, " as " <> alias_str)
    None -> append_nothing()
  }
}

// -------- Helpers -------------

fn append_nothing() {
  string_builder.append(_, "")
}

pub fn delimited_by(
  input: List(StringBuilder),
  delimiter: String,
) -> StringBuilder {
  do_delimited_by(input, delimiter, string_builder.from_string(""))
}

fn do_delimited_by(
  input: List(StringBuilder),
  delimiter: String,
  acc: StringBuilder,
) -> StringBuilder {
  case input {
    [] -> acc
    [single_item] ->
      acc
      |> string_builder.append_builder(single_item)
    [item, ..rest] ->
      do_delimited_by(
        rest,
        delimiter,
        acc
        |> string_builder.append_builder(
          item
          |> string_builder.append(delimiter),
        ),
      )
  }
}
