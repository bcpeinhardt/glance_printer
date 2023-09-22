import gleam/list
import gleam/string_builder.{StringBuilder}
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  Assert, Assignment, AssignmentName, Block, Clause, Constant, CustomType,
  Definition, Discarded, Expression, ExternalFunction, ExternalType, Field,
  Float, Fn, FnParameter, Function, FunctionParameter, FunctionType, Import, Int,
  Let, Module, Named, NamedType, NegateBool, NegateInt, Panic, Pattern,
  PatternAssignment, PatternConcatenate, PatternDiscard, PatternFloat,
  PatternInt, PatternList, PatternString, PatternTuple, PatternVariable, Private,
  Public, Publicity, RecordUpdate, Statement, String, Todo, Tuple, TupleType,
  Type, TypeAlias, Variable, VariableType, Variant,
}
import glam/doc.{Document}
import gleam/io
import gleam/int

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
  |> list.map(doc.join(_, with: doc.lines(2)))
  |> list.prepend(
    imports
    |> list.reverse
    |> list.map(pretty_import)
    |> doc.join(with: doc.line),
  )
  |> doc.join(with: doc.lines(2))
  |> doc.to_string(80)
  |> string.trim <> "\n"
}

/// Pretty print a top level function
fn pretty_function(function: Definition(Function)) -> Document {
  let Definition(
    _,
    Function(name, publicity, parameters, return, statements, _),
  ) = function

  let comma_separated_parameters =
    parameters
    |> list.map(pretty_function_parameters)
    |> doc.concat_join([doc.from_string(","), doc.space])
    |> doc.group

  let wrapped_parameters =
    doc.concat([doc.from_string("("), doc.soft_break])
    |> doc.append(comma_separated_parameters)
    |> doc.nest(by: 2)
    |> doc.append_docs([doc.soft_break, doc.from_string(")")])

  let return_signature = case return {
    Some(type_) -> doc.concat([doc.from_string(" -> "), pretty_type(type_)])
    None -> doc.empty
  }

  let statements =
    statements
    |> list.map(pretty_statement)
    |> doc.join(with: doc.line)

  let body =
    doc.concat([doc.from_string(" {"), doc.line])
    |> doc.append(statements)
    |> doc.nest(2)
    |> doc.append_docs([doc.line, doc.from_string("}")])

  [
    pretty_public(publicity),
    doc.from_string("fn " <> name),
    wrapped_parameters,
    return_signature,
    body,
  ]
  |> doc.concat
}

/// Pretty print a statement
fn pretty_statement(statement: Statement) -> Document {
  case statement {
    Expression(expression) -> pretty_expression(expression)
    Assignment(kind, pattern, annotation, value) -> {
      let let_declaration = case kind {
        Let -> doc.from_string("let ")
        Assert -> doc.from_string("let assert ")
      }

      let type_annotation = case annotation {
        Some(t) -> doc.concat([doc.from_string(": "), pretty_type(t)])
        None -> doc.empty
      }

      [
        let_declaration,
        pretty_pattern(pattern),
        type_annotation,
        doc.from_string(" = "),
        pretty_expression(value),
      ]
      |> doc.concat
    }
    _ -> todo
  }
}

/// Pretty print a "pattern" (anything that could go in a pattern match branch)
fn pretty_pattern(pattern: Pattern) -> Document {
  case pattern {
    // Basic patterns
    PatternInt(val)
    | PatternFloat(val)
    | PatternString(val)
    | PatternVariable(val) -> doc.from_string(val)

    // A discarded value should start with an underscore
    PatternDiscard(val) -> doc.from_string("_" <> val)

    // A tuple pattern
    PatternTuple(elements) -> {
      let comma_separated_elements =
        elements
        |> list.map(pretty_pattern)
        |> doc.concat_join([doc.from_string(","), doc.space])
        |> doc.group

      doc.concat([doc.from_string("#("), doc.soft_break])
      |> doc.append(comma_separated_elements)
      |> doc.nest(2)
      |> doc.append_docs([trailing_comma(), doc.from_string(")")])
      |> doc.group
    }

    // A list pattern
    PatternList(elements, tail) -> {
      let tail =
        tail
        |> option.map(pretty_pattern)
        |> option.map(doc.prepend(_, doc.from_string("..")))

      let comma_separated_items =
        elements
        |> list.map(pretty_pattern)
        |> list.append(option.values([tail]))
        |> doc.concat_join([doc.from_string(","), doc.space])
        |> doc.group

      doc.concat([doc.from_string("["), doc.soft_break])
      |> doc.append(comma_separated_items)
      |> doc.nest(by: 2)
      |> doc.append_docs([doc.soft_break, doc.from_string("]")])
      |> doc.group
    }

    // Pattern for renaming something with "as"
    PatternAssignment(pattern, name) -> {
      [pretty_pattern(pattern), doc.from_string(" as " <> name)]
      |> doc.concat
    }

    // Pattern for pulling off the front end of a string
    PatternConcatenate(left, right) -> {
      [doc.from_string("\"" <> left <> "\" <> "), pretty_assignment_name(right)]
      |> doc.concat
    }
    _ -> todo
  }
}

fn pretty_function_parameters(parameter: FunctionParameter) -> Document {
  let FunctionParameter(label, name, type_) = parameter
  let label = case label {
    Some(l) -> doc.from_string(l <> " ")
    None -> doc.empty
  }
  let type_ = case type_ {
    Some(t) ->
      pretty_type(t)
      |> doc.prepend(doc.from_string(": "))
    None -> doc.empty
  }

  label
  |> doc.append(pretty_assignment_name(name))
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

  pretty_public(publicity)
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
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.prepend(doc.concat([doc.from_string("#("), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([trailing_comma(), doc.from_string(")")]))
      |> doc.group
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
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.group
      |> doc.prepend(doc.concat([doc.from_string("["), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([doc.soft_break, doc.from_string("]")]))
      |> doc.group
    }
    Fn(arguments, return_annotation, body) -> {
      let arguments =
        arguments
        |> list.map(pretty_fn_parameter)
        |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
        |> doc.group
        |> doc.prepend(doc.concat([doc.from_string("("), doc.soft_break]))
        |> doc.nest(by: 2)
        |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
        |> doc.group

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
    RecordUpdate(module, constructor, record, fields) -> {
      doc.empty
    }
    _ -> todo
  }
}

fn pretty_fn_parameter(fn_parameter: FnParameter) -> Document {
  let FnParameter(name, type_) = fn_parameter
  let type_ =
    type_
    |> option.map(pretty_type)
    |> option.map(doc.prepend(_, doc.from_string(": ")))
  [pretty_assignment_name(name)]
  |> list.append(option.values([type_]))
  |> doc.concat
}

// Type Alias -------------------------------------

fn pretty_type_alias(type_alias: Definition(TypeAlias)) -> Document {
  let Definition(_, TypeAlias(name, publicity, parameters, aliased)) =
    type_alias

  let parameters = case parameters {
    [] -> doc.empty
    _ -> {
      parameters
      |> list.map(doc.from_string)
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.prepend(doc.concat([doc.from_string("("), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
    }
  }

  pretty_public(publicity)
  |> doc.append(doc.from_string("type " <> name))
  |> doc.append(parameters)
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
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.group
      |> doc.prepend(doc.concat([doc.from_string("#("), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
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
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.group
      |> doc.prepend(doc.concat([doc.from_string("("), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
    }
  }
}

// Custom Types --------------------------------------

fn pretty_custom_type(type_: Definition(CustomType)) -> Document {
  // Destructure
  let Definition(_, CustomType(name, publicity, opaque_, parameters, variants)) =
    type_

  // Opaque or not
  let opaque_ = case opaque_ {
    True -> "opaque "
    False -> ""
  }

  let parameters = case parameters {
    [] -> doc.empty
    _ -> {
      parameters
      |> list.map(doc.from_string)
      |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
      |> doc.prepend(doc.concat([doc.from_string("("), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
    }
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
  |> doc.prepend(pretty_public(publicity))
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
  |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))
  |> doc.group
  |> doc.prepend(doc.concat([doc.from_string("("), doc.soft_break]))
  |> doc.nest(by: 2)
  |> doc.append(doc.concat([doc.soft_break, doc.from_string(")")]))
  |> doc.prepend(doc.from_string(name))
}

// Imports --------------------------------------------

// Pretty print an import statement
fn pretty_import(import_: Definition(Import)) -> Document {
  let Definition(_, Import(module, alias, unqualifieds)) = import_

  // An aliassed import is renamed with the as keyword
  let pretty_alias = fn(alias) {
    case alias {
      Some(str) -> doc.from_string(" as " <> str)
      None -> doc.empty
    }
  }

  let unqualifieds = case unqualifieds {
    [] -> doc.empty
    _ ->
      unqualifieds
      |> list.map(fn(uq) {
        doc.concat([doc.from_string(uq.name), pretty_alias(uq.alias)])
      })
      |> doc.join(with: doc.concat([
        doc.from_string(","),
        doc.flex_break(" ", ""),
      ]))
      |> doc.group
      |> doc.prepend(doc.concat([doc.from_string(".{"), doc.soft_break]))
      |> doc.nest(by: 2)
      |> doc.append(doc.concat([trailing_comma(), doc.from_string("}")]))
      |> doc.group
  }

  doc.from_string("import " <> module)
  |> doc.append(unqualifieds)
  |> doc.append(pretty_alias(alias))
}

// -------------- Helpers -------------------------

// Prints the pub keyword
fn pretty_public(publicity: Publicity) -> Document {
  case publicity {
    Public -> doc.from_string("pub ")
    Private -> doc.empty
  }
}

fn pretty_assignment_name(assignment_name: AssignmentName) -> Document {
  case assignment_name {
    Named(str) -> doc.from_string(str)
    Discarded(str) -> doc.from_string("_" <> str)
  }
}

// A comma that only prints when the 
// group is broken
fn trailing_comma() -> Document {
  doc.break("", ",")
}
