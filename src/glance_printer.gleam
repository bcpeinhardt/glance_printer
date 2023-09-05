import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  Clause, Constant, CustomType, Definition, Expression, ExternalFunction,
  ExternalType, Field, Float, FunctionType, Import, Int, Module, NamedType,
  NegateBool, NegateInt, Private, Public, Publicity, String, TupleType, Type,
  TypeAlias, Variable, VariableType, Variant,
}
import glam/doc.{Document}
import gleam/io

/// Stringify a gleam module
pub fn print(module module: Module) -> String {
  // Imports joined separately because they're only separated by one line
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

  let constants =
    module.constants
    |> list.map(pretty_constant)

  let external_types =
    module.external_types
    |> list.map(pretty_external_type)

  let the_rest =
    [custom_types, type_aliases, constants, external_types]
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

// External Type ----------------------------------

fn pretty_external_type(external_type: Definition(ExternalType)) -> Document {
  let Definition(attrs, ExternalType(name, publicity, paramters)) =
    external_type

  doc.empty
}

// Constant ---------------------------------------

fn pretty_constant(constant: Definition(Constant)) -> Document {
  let Definition(_, Constant(name, publicity, annotation, value)) = constant

  let annotation = case annotation {
    Some(type_) -> {
      doc.from_string(": ")
      |> doc.append(pretty_type(type_))
    }
    None -> doc.empty
  }

  pretty_publicity(publicity)
  |> doc.append(doc.from_string("const " <> name))
  |> doc.append(annotation)
  |> doc.append(doc.from_string(" ="))
  |> doc.append(doc.space)
  |> doc.append(pretty_expression(value))
}

// Expression -------------------------------------

fn pretty_expression(expression: Expression) -> Document {
  case expression {
    Int(val) -> doc.from_string(val)
    Float(val) -> doc.from_string(val)
    String(val) -> doc.from_string("\"" <> val <> "\"")
    Variable(name) -> doc.from_string(name)
    NegateInt(expr) ->
      doc.from_string("-")
      |> doc.append(pretty_expression(expr))
    NegateBool(expr) ->
      doc.from_string("!")
      |> doc.append(pretty_expression(expr))
    _ -> todo
  }
}

// Type Alias -------------------------------------

fn pretty_type_alias(type_alias: Definition(TypeAlias)) -> Document {
  let Definition(_, TypeAlias(name, publicity, parameters, aliased)) =
    type_alias

  pretty_publicity(publicity)
  |> doc.append(doc.from_string("type " <> name))
  |> doc.append(pretty_generic_type_parameters(parameters))
  |> doc.append(doc.from_string(" ="))
  |> doc.append(doc.line)
  |> doc.nest(2)
  |> doc.append(pretty_type(aliased))
}

// Type -------------------------------------------------

fn pretty_type(type_: Type) -> Document {
  case type_ {
    NamedType(name, module, parameters) -> {
      module
      |> option.map(fn(mod) { mod <> "." })
      |> option.map(doc.from_string)
      |> option.unwrap(or: doc.empty)
      |> doc.append(doc.from_string(name))
      |> doc.append(
        parameters
        |> pretty_function_type_parameters(parenthesize_if_empty: False),
      )
    }
    TupleType(elements) -> {
      elements
      |> list.map(pretty_type)
      |> comma_separated
      |> parenthesize_breaking("#(", ")")
    }
    FunctionType(parameters, return) -> {
      doc.from_string("fn")
      |> doc.append(
        parameters
        |> pretty_function_type_parameters(parenthesize_if_empty: True),
      )
      |> doc.append(doc.from_string(" -> "))
      |> doc.append(
        return
        |> pretty_type,
      )
    }
    VariableType(name) -> doc.from_string(name)
  }
}

// Generic type parameters are comma separated strings, wrapped in parentheses.
fn pretty_generic_type_parameters(parameters: List(String)) -> Document {
  case parameters {
    [] -> doc.empty
    _ -> {
      parameters
      |> list.map(doc.from_string)
      |> comma_separated
      |> parenthesize_breaking("(", ")")
    }
  }
}

// Function parameters are comma separated types wrapped in parentheses.
// If the list is empty, parentheses may or may not be rendered depending on the situation 
// (normal function -> yes, type constructor -> no, etc.)
fn pretty_function_type_parameters(
  parameters: List(Type),
  parenthesize_if_empty pie: Bool,
) -> Document {
  case parameters, pie {
    [], False -> doc.empty
    [], True -> doc.from_string("()")
    _, _ -> {
      parameters
      |> list.map(pretty_type)
      |> comma_separated
      |> parenthesize_breaking("(", ")")
    }
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
  |> doc.append(
    parameters
    |> pretty_generic_type_parameters,
  )
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
