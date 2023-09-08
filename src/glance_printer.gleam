import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  Block, Clause, Constant, CustomType, Definition, Discarded, Expression,
  ExternalFunction, ExternalType, Field, Float, Fn, FnParameter, Function,
  FunctionParameter, FunctionType, Import, Int, Module, Named, NamedType,
  NegateBool, NegateInt, Panic, Private, Public, Publicity, Statement, String,
  Todo, Tuple, TupleType, Type, TypeAlias, Variable, VariableType, Variant,
}
import glam/doc.{Document}
import gleam/io

/// Pretty print a gleam module
pub fn print(module module: Module) -> String {
  let Module(
    imports,
    custom_types,
    type_aliases,
    constants,
    external_types,
    external_functions,
    functions,
  ) = module

  let double_line_break = doc.concat([doc.line, doc.line])

  // Everything gets reversed during parsing (lists, am I right?)
  // so we re-reverse them
  // Imports get added separately because they're separated with one
  // line break not two
  [
    list.map(custom_types, pretty_custom_type),
    list.map(type_aliases, pretty_type_alias),
    list.map(constants, pretty_constant),
    list.map(functions, pretty_function),
  ]
  |> list.filter(fn(lst) { !list.is_empty(lst) })
  |> list.map(list.reverse)
  |> list.map(doc.join(_, with: double_line_break))
  |> list.prepend(
    imports
    |> list.reverse
    |> list.map(pretty_import)
    |> doc.join(with: doc.line),
  )
  |> doc.join(with: double_line_break)
  |> doc.to_string(80)
  |> string.trim <> "\n"
}

// Functions --------------------------------------

fn pretty_function(function: Definition(Function)) -> Document {
  let Definition(_, Function(name, publicity, parameters, return, body, _)) =
    function

  let parameters =
    parameters
    |> list.map(pretty_function_parameters)
    |> comma_separated
    |> parenthesize_breaking("(", ")", False)

  let return = case return {
    Some(type_) ->
      doc.from_string(" -> ")
      |> doc.append(pretty_type(type_))
    None -> doc.empty
  }

  let body =
    body
    |> list.map(pretty_statement)
    |> doc.join(with: doc.line)
    |> doc.prepend(doc.concat([doc.space, doc.from_string("{"), doc.line]))
    |> doc.nest(2)
    |> doc.append(doc.concat([doc.line, doc.from_string("}")]))

  pretty_publicity(publicity)
  |> doc.append(doc.from_string("fn " <> name))
  |> doc.append(parameters)
  |> doc.append(return)
  |> doc.append(body)
}

fn pretty_statement(statement: Statement) -> Document {
  case statement {
    Expression(expression) -> pretty_expression(expression)
    _ -> todo
  }
}

fn pretty_function_parameters(parameter: FunctionParameter) -> Document {
  let FunctionParameter(label, name, type_) = parameter
  let label = case label {
    Some(l) -> doc.from_string(l <> " ")
    None -> doc.empty
  }
  let name = case name {
    Named(n) -> doc.from_string(n)
    Discarded(_) -> doc.empty
  }
  let type_ = case type_ {
    Some(t) ->
      pretty_type(t)
      |> doc.prepend(doc.from_string(": "))
    None -> doc.empty
  }

  label
  |> doc.append(name)
  |> doc.append(type_)
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
    Block(statements) -> {
      statements
      |> list.map(pretty_statement)
      |> doc.join(with: doc.line)
      |> doc.prepend(doc.concat([doc.from_string("{"), doc.line]))
      |> doc.nest(2)
      |> doc.append(doc.concat([doc.line, doc.from_string("}")]))
    }
    Panic(msg) -> {
      case msg {
        Some(str) -> doc.from_string("panic as \"" <> str <> "\"")
        None -> doc.from_string("panic")
      }
    }
    Todo(msg) -> {
      case msg {
        Some(str) -> doc.from_string("todo as \"" <> str <> "\"")
        None -> doc.from_string("todo")
      }
    }
    Tuple(expressions) -> {
      expressions
      |> list.map(pretty_expression)
      |> comma_separated
      |> parenthesize_breaking("#(", ")", False)
    }
    glance.List(elements, rest) -> {
      let rest =
        rest
        |> option.map(fn(expr) {
          doc.from_string("..")
          |> doc.append(pretty_expression(expr))
        })

      let elements =
        elements
        |> list.map(pretty_expression)

      let elements = case rest {
        Some(document) -> list.append(elements, [document])
        None -> elements
      }

      elements
      |> comma_separated
      |> parenthesize_breaking("[", "]", False)
    }
    Fn(arguments, return_annotation, body) -> {
      let arguments =
        arguments
        |> list.map(pretty_fn_parameter)
        |> comma_separated
        |> parenthesize_breaking("(", ")", False)

      let return = case return_annotation {
        Some(type_) ->
          doc.from_string(" -> ")
          |> doc.append(pretty_type(type_))
        None -> doc.empty
      }

      let body =
        body
        |> list.map(pretty_statement)
        |> doc.join(with: doc.line)
        |> doc.prepend(doc.concat([doc.from_string(" {"), doc.line]))
        |> doc.nest(2)
        |> doc.append(doc.concat([doc.line, doc.from_string("}")]))

      doc.from_string("fn")
      |> doc.append(arguments)
      |> doc.append(return)
      |> doc.append(body)
    }
    _ -> todo
  }
}

fn pretty_fn_parameter(fn_parameter: FnParameter) -> Document {
  let FnParameter(name, type_) = fn_parameter
  case name, type_ {
    Named(str), Some(t) -> {
      doc.from_string(str <> ": ")
      |> doc.append(pretty_type(t))
    }
    Named(str), None -> doc.from_string(str)
    Discarded(_), _ -> panic as "This should be unreachable"
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
      |> parenthesize_breaking("#(", ")", False)
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
      |> parenthesize_breaking("(", ")", False)
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
      |> parenthesize_breaking("(", ")", False)
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
  |> parenthesize_breaking("(", ")", False)
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
      |> parenthesize_breaking(".{", "}", False)
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
  use_inner_spaces: Bool,
) -> Document {
  let padding = case use_inner_spaces {
    True -> doc.space
    False -> doc.soft_break
  }

  let open =
    doc.from_string(open_symbol)
    |> doc.append(padding)
  let close =
    doc.from_string(close_symbol)
    |> doc.prepend(padding)
  input
  |> doc.prepend(open)
  |> doc.nest(by: 2)
  |> doc.append(close)
  |> doc.group
}
