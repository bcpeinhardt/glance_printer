import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  Clause, Constant, CustomType, Definition, Field, FunctionType, Import, Module,
  NamedType, Private, Public, Publicity, TupleType, Type, TypeAlias, Variant,
}
import glam/doc.{Document}
import gleam/io

/// Stringify a gleam module
pub fn print(module module: Module) -> String {
  let imports = case module.imports {
    [] -> None
    _ ->
      Some(
        module.imports
        |> list.reverse
        |> list.map(pretty_import)
        |> doc.join(with: doc.line),
      )
  }

  let custom_types =
    module.custom_types
    |> list.map(pretty_custom_type)

  let type_aliases =
    module.type_aliases
    |> list.map(pretty_type_alias)

  let the_rest =
    [custom_types, type_aliases]
    |> list.filter(fn(lst) { !list.is_empty(lst) })

  let the_rest = case the_rest {
    [] -> None
    _ -> {
      Some(
        the_rest
        |> list.map(list.reverse)
        |> list.map(doc.join(_, with: doc.concat([doc.line, doc.line])))
        |> doc.join(with: doc.concat([doc.line, doc.line])),
      )
    }
  }

  case imports, the_rest {
    None, None -> doc.empty
    None, Some(rest) -> rest
    Some(imports), None -> imports
    Some(imports), Some(the_rest) -> {
      [imports, the_rest]
      |> doc.join(with: doc.concat([doc.line, doc.line]))
    }
  }
  |> doc.append(doc.line)
  |> doc.to_string(80)
}

// Type Alias

fn pretty_type_alias(type_alias: Definition(TypeAlias)) -> Document {
  let Definition(_, TypeAlias(name, publicity, parameters, aliased)) =
    type_alias

  pretty_publicity(publicity)
  |> doc.append(doc.from_string("type " <> name <> " ="))
  |> doc.append(doc.line)
  |> doc.nest(2)
  |> doc.append(pretty_type(aliased))
}

// Type

fn pretty_type(type_: Type) -> Document {
  case type_ {
    NamedType(name, module, parameters) -> {
      let module =
        module
        |> option.map(fn(mod) { mod <> "." })
        |> option.map(doc.from_string)
        |> option.unwrap(or: doc.empty)

      let parameters = case parameters {
        [] -> doc.empty
        _ -> {
          parameters
          |> list.map(pretty_type)
          |> comma_separated
          |> parenthesize_breaking("(", ")")
        }
      }

      module
      |> doc.append(doc.from_string(name))
      |> doc.append(parameters)
    }
    TupleType(elements) -> {
      elements
      |> list.map(pretty_type)
      |> comma_separated
      |> parenthesize_breaking("#(", ")")
    }
    FunctionType(parameters, return) -> {
      let parameters =
        parameters
        |> list.map(pretty_type)
        |> comma_separated
        |> parenthesize_breaking("(", ")")
      let return = pretty_type(return)

      doc.from_string("fn")
      |> doc.append(parameters)
      |> doc.append(doc.from_string(" -> "))
      |> doc.append(return)
    }
    _ -> todo
  }
}

// Custom Types --------------------------------------

fn pretty_custom_type(type_: Definition(CustomType)) -> Document {
  // Destructure
  let Definition(_, CustomType(name, publicity, opaque_, parameters, variants)) =
    type_

  // Public or Private
  let publicity = pretty_publicity(publicity)

  // Opaque or not
  let opaque_ = case opaque_ {
    True -> "opaque "
    False -> ""
  }

  // Type paramters
  let parameters = case parameters {
    [] -> doc.empty
    _ ->
      parameters
      |> list.map(doc.from_string)
      |> comma_separated
      |> parenthesize_breaking("(", ")")
  }

  // Custom types variants
  let variants =
    variants
    |> list.map(pretty_variant)
    |> doc.join(with: doc.line)
    |> doc.prepend(doc.concat([doc.from_string("{"), doc.line]))
    |> doc.nest(2)
    |> doc.append(doc.concat([doc.line, doc.from_string("}")]))
    |> doc.group

  doc.from_string(opaque_ <> "type " <> name)
  |> doc.prepend(publicity)
  |> doc.append(parameters)
  |> doc.append(doc.from_string(" "))
  |> doc.append(variants)
}

fn pretty_variant(variant: Variant) -> Document {
  let Variant(name, fields) = variant
  fields
  |> list.map(fn(field) {
    let Field(label, type_) = field
    let label = case label {
      Some(l) -> doc.from_string(l <> ": ")
      None -> doc.empty
    }
    [label, pretty_type(type_)]
    |> doc.concat
  })
  |> comma_separated
  |> parenthesize_breaking("(", ")")
  |> doc.prepend(doc.from_string(name))
}

// Imports --------------------------------------------

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
      |> comma_separated
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

fn pretty_publicity(publicity: Publicity) -> Document {
  case publicity {
    Public -> doc.from_string("pub ")
    Private -> doc.empty
  }
}

// Helpers ---------------------------------------------

fn comma_separated(input: List(Document)) -> Document {
  let comma = doc.concat([doc.from_string(","), doc.space])
  input
  |> doc.join(with: comma)
  |> doc.group
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
  input
  |> doc.prepend(open)
  |> doc.nest(by: 2)
  |> doc.append(close)
  |> doc.group
}
