import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  Clause, Constant, CustomType, Definition, Field, Import, Module, Private,
  Public, Type, Variant,
}
import glam/doc.{Document}

/// Stringify a gleam module
pub fn print(module module: Module) -> String {
  // Imports get reversed when parsed, so reverse them back
  // and pretty print them separated by newlines
  let imports =
    module.imports
    |> list.reverse
    |> list.map(pretty_import)
    |> doc.join(with: doc.from_string("\n"))

  doc.empty
  |> doc.append(imports)
  |> doc.to_string(80)
}

// Pretty print an import statement
fn pretty_import(import_: Definition(Import)) -> Document {
  let Definition(_, Import(module, alias, unqualifieds)) = import_

  let unqualifieds = case unqualifieds {
    [] -> doc.empty
    _ ->
      unqualifieds
      |> list.map(fn(uq) {
        doc.concat([doc.from_string(uq.name), pretty_import_alias(uq.alias)])
      })
      |> doc.join(with: comma())
      |> parenthesize_breaking(".{", "}")
  }

  doc.from_string("import " <> module)
  |> doc.append(unqualifieds)
  |> doc.append(pretty_import_alias(alias))
}

// Pretty print the " as whatever" bit of an import statement
fn pretty_import_alias(alias: Option(String)) -> Document {
  case alias {
    Some(alias_str) -> doc.from_string(" as " <> alias_str)
    None -> doc.empty
  }
}

// Helpers ---------------------------------------------

fn comma() -> Document {
  doc.concat([doc.from_string(","), doc.space])
}

fn parenthesize_breaking(
  input: Document,
  open_symbol: String,
  close_symbol: String,
) -> Document {
  let open =
    doc.from_string(open_symbol)
    |> doc.append(doc.soft_break)
  let close =
    doc.from_string(close_symbol)
    |> doc.prepend(doc.soft_break)
  doc.concat([open, input, close])
}
