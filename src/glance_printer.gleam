import gleam/list
import gleam/string
import gleam/option.{None, Option, Some}
import glance.{
  AddFloat, AddInt, And, Assert, Assignment, AssignmentName, Attribute,
  BigOption, BinaryOperator, BinaryOption, BitString, BitStringOption,
  BitStringSegmentOption, Block, Call, Case, Clause, Concatenate, Constant,
  CustomType, Definition, Discarded, DivFloat, DivInt, Eq, Expression, Field,
  FieldAccess, Float, FloatOption, Fn, FnCapture, FnParameter, Function,
  FunctionParameter, FunctionType, GtEqFloat, GtEqInt, GtFloat, GtInt, Import,
  Int, IntOption, Let, LittleOption, LtEqFloat, LtEqInt, LtFloat, LtInt, Module,
  MultFloat, MultInt, Named, NamedType, NativeOption, NegateBool, NegateInt,
  NotEq, Or, Panic, Pattern, PatternAssignment, PatternBitString,
  PatternConcatenate, PatternConstructor, PatternDiscard, PatternFloat,
  PatternInt, PatternList, PatternString, PatternTuple, PatternVariable, Pipe,
  Private, Public, Publicity, RecordUpdate, RemainderInt, SignedOption,
  SizeOption, SizeValueOption, Statement, String, SubFloat, SubInt, Todo, Tuple,
  TupleIndex, TupleType, Type, TypeAlias, UnitOption, UnsignedOption, Use,
  Utf16CodepointOption, Utf16Option, Utf32CodepointOption, Utf32Option,
  Utf8CodepointOption, Utf8Option, Variable, VariableType, Variant,
}
import glam/doc.{Document}
import internal/doc_extras.{
  comma_separated_in_parentheses, nbsp, nest, trailing_comma,
}
import gleam/int

/// Pretty print a gleam module
pub fn print(module module: Module) -> String {
  let Module(
    imports,
    custom_types,
    type_aliases,
    constants,
    _external_types,
    _external_functions,
    functions,
  ) = module

  // Handle imports separately because they're joined with only on line break
  let imports =
    imports
    |> list.reverse
    |> list.map(pretty_import)
    |> doc.join(with: doc.line)

  // Everything elses gets separated by an empty line (2 line breaks)
  let the_rest =
    [
      list.map(custom_types, pretty_custom_type),
      list.map(type_aliases, pretty_type_alias),
      list.map(constants, pretty_constant),
      list.map(functions, pretty_function),
    ]
    |> list.filter(fn(lst) { !list.is_empty(lst) })
    |> list.map(list.reverse)
    |> list.map(doc.join(_, with: doc.lines(2)))

  [imports, ..the_rest]
  |> doc.join(with: doc.lines(2))
  |> doc.to_string(80)
  |> string.trim <> "\n"
}

fn pretty_definition(
  definition: Definition(inner),
  inner_to_doc: fn(inner) -> Document,
) -> Document {
  let Definition(attributes, definition) = definition
  attributes
  |> list.map(pretty_attribute)
  |> list.append([inner_to_doc(definition)])
  |> doc.join(with: doc.line)
}

fn pretty_attribute(attribute: Attribute) -> Document {
  let Attribute(name, arguments) = attribute
  let arguments =
    arguments
    |> list.map(pretty_expression)
    |> doc_extras.comma_separated_in_parentheses
  [doc.from_string("@" <> name), arguments]
  |> doc.concat
}

/// Pretty print a top level function.
fn pretty_function(function: Definition(Function)) -> Document {
  use Function(name, publicity, parameters, return, statements, _) <- pretty_definition(
    function,
  )

  let parameters =
    parameters
    |> list.map(pretty_function_parameter)
    |> comma_separated_in_parentheses

  let statements = case statements {
    [] -> doc.empty
    _ ->
      [nbsp(), pretty_block(of: statements)]
      |> doc.concat
  }

  [
    pretty_public(publicity),
    doc.from_string("fn " <> name),
    parameters,
    pretty_return_signature(return),
    statements,
  ]
  |> doc.concat
}

// Pretty print a parameter of a top level function
// For printing an anonymous function paramater, see `pretty_fn_parameter`
fn pretty_function_parameter(parameter: FunctionParameter) -> Document {
  let FunctionParameter(label, name, type_) = parameter
  let label = case label {
    Some(l) -> doc.from_string(l <> " ")
    None -> doc.empty
  }

  [label, pretty_assignment_name(name), pretty_type_annotation(type_)]
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

      [
        let_declaration,
        pretty_pattern(pattern),
        pretty_type_annotation(annotation),
        doc.from_string(" = "),
        pretty_expression(value),
      ]
      |> doc.concat
    }
    Use(patterns, function) -> {
      let patterns =
        patterns
        |> list.map(pretty_pattern)
        |> doc.join(with: doc.from_string(", "))

      [
        doc.from_string("use "),
        patterns,
        doc.from_string(" <- "),
        pretty_expression(function),
      ]
      |> doc.concat
    }
  }
}

/// Pretty print a "pattern" (anything that could go in a pattern match branch)
fn pretty_pattern(pattern: Pattern) -> Document {
  case pattern {
    // Basic patterns
    PatternInt(val) | PatternFloat(val) | PatternVariable(val) ->
      doc.from_string(val)

    PatternString(val) -> doc.from_string("\"" <> val <> "\"")

    // A discarded value should start with an underscore
    PatternDiscard(val) -> doc.from_string("_" <> val)

    // A tuple pattern
    PatternTuple(elements) ->
      elements
      |> list.map(pretty_pattern)
      |> pretty_tuple

    // A list pattern
    PatternList(elements, tail) ->
      pretty_list(
        of: list.map(elements, pretty_pattern),
        with_tail: option.map(tail, pretty_pattern),
      )

    // Pattern for renaming something with "as"
    PatternAssignment(pattern, name) -> {
      [pretty_pattern(pattern), pretty_as(Some(name))]
      |> doc.concat
    }

    // Pattern for pulling off the front end of a string
    PatternConcatenate(left, right) -> {
      [doc.from_string("\"" <> left <> "\" <> "), pretty_assignment_name(right)]
      |> doc.concat
    }

    PatternBitString(segments) -> pretty_bitstring(segments, pretty_pattern)

    PatternConstructor(module, constructor, arguments, with_spread) -> {
      let module =
        module
        |> option.map(doc.from_string)
        |> option.unwrap(or: doc.empty)

      let arguments = list.map(arguments, pretty_field(_, pretty_pattern))

      let arguments =
        case with_spread {
          True -> list.append(arguments, [doc.from_string("..")])
          False -> arguments
        }
        |> comma_separated_in_parentheses

      [module, doc.from_string(constructor), arguments]
      |> doc.concat
    }
  }
}

// Pretty print a constant
fn pretty_constant(constant: Definition(Constant)) -> Document {
  use Constant(name, publicity, annotation, value) <- pretty_definition(
    constant,
  )

  [
    pretty_public(publicity),
    doc.from_string("const " <> name),
    pretty_type_annotation(annotation),
    doc.from_string(" ="),
    doc.space,
    pretty_expression(value),
  ]
  |> doc.concat
}

/// Pretty print a block of statements
fn pretty_block(of statements: List(Statement)) -> Document {
  // Statements are separated by a single line
  let statements =
    statements
    |> list.map(pretty_statement)
    |> doc.join(with: doc.line)

  // A block gets wrapped in squiggly brackets and indented
  doc.concat([doc.from_string("{"), doc.line])
  |> doc.append(statements)
  |> nest
  |> doc.append_docs([doc.line, doc.from_string("}")])
}

// Pretty print a tuple of types, expressions, or patterns
fn pretty_tuple(with elements: List(Document)) -> Document {
  let comma_separated_elements =
    elements
    |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))

  doc.concat([doc.from_string("#("), doc.soft_break])
  |> doc.append(comma_separated_elements)
  |> nest
  |> doc.append(doc.concat([trailing_comma(), doc.from_string(")")]))
  |> doc.group
}

// Pretty print a list of expressions or patterns
fn pretty_list(
  of elements: List(Document),
  with_tail tail: Option(Document),
) -> Document {
  let tail =
    tail
    |> option.map(doc.prepend(_, doc.from_string("..")))

  let comma_separated_items =
    elements
    |> list.append(option.values([tail]))
    |> doc.concat_join([doc.from_string(","), doc.space])

  doc.concat([doc.from_string("["), doc.soft_break])
  |> doc.append(comma_separated_items)
  |> nest
  |> doc.append_docs([doc.soft_break, doc.from_string("]")])
  |> doc.group
}

// Expression -------------------------------------

fn pretty_expression(expression: Expression) -> Document {
  case expression {
    // Int, Float and Variable simply print as their string value
    Int(str) | Float(str) | Variable(str) -> doc.from_string(str)

    // A string literal needs to bee wrapped in quotes
    String(val) -> doc.from_string("\"" <> val <> "\"")

    // Negate int gets a - in front
    NegateInt(expr) ->
      [doc.from_string("-"), pretty_expression(expr)]
      |> doc.concat

    // Negate bool gets a ! in front
    NegateBool(expr) ->
      [doc.from_string("!"), pretty_expression(expr)]
      |> doc.concat

    // A block of statements
    Block(statements) -> pretty_block(of: statements)

    // Pretty print a panic
    Panic(msg) -> {
      case msg {
        Some(str) -> doc.from_string("panic as \"" <> str <> "\"")
        None -> doc.from_string("panic")
      }
    }

    // Pretty print a todo
    Todo(msg) -> {
      case msg {
        Some(str) -> doc.from_string("todo as \"" <> str <> "\"")
        None -> doc.from_string("todo")
      }
    }

    // Pretty print a tuple
    Tuple(expressions) ->
      expressions
      |> list.map(pretty_expression)
      |> pretty_tuple

    // Pretty print a list
    glance.List(elements, rest) ->
      pretty_list(
        list.map(elements, pretty_expression),
        option.map(rest, pretty_expression),
      )

    // Pretty print a function
    Fn(arguments, return, body) -> pretty_fn(arguments, return, body)

    // Pretty print a record update expression
    RecordUpdate(module, constructor, record, fields) -> {
      let module = case module {
        Some(str) -> doc.from_string(str)
        None -> doc.empty
      }

      let record =
        [doc.from_string(".."), pretty_expression(record)]
        |> doc.concat

      let fields =
        list.map(
          fields,
          fn(field) {
            let #(name, expr) = field
            [doc.from_string(name <> ": "), pretty_expression(expr)]
            |> doc.concat
          },
        )
        |> list.prepend(record)
        |> comma_separated_in_parentheses

      [module, doc.from_string(constructor), fields]
      |> doc.concat
    }

    FieldAccess(container, label) -> {
      [pretty_expression(container), doc.from_string("." <> label)]
      |> doc.concat
    }

    Call(function, arguments) -> {
      let arguments =
        arguments
        |> list.map(pretty_field(_, pretty_expression))
        |> comma_separated_in_parentheses
      [pretty_expression(function), arguments]
      |> doc.concat
    }

    TupleIndex(tuple, index) -> {
      [pretty_expression(tuple), doc.from_string("." <> int.to_string(index))]
      |> doc.concat
    }

    FnCapture(label, function, arguments_before, arguments_after) -> {
      let arguments_before =
        list.map(arguments_before, pretty_field(_, pretty_expression))
      let arguments_after =
        list.map(arguments_after, pretty_field(_, pretty_expression))
      let placeholder = case label {
        Some(str) -> doc.from_string(str <> ": _")
        None -> doc.from_string("_")
      }
      let in_parens =
        arguments_before
        |> list.append([placeholder])
        |> list.append(arguments_after)
        |> comma_separated_in_parentheses

      [pretty_expression(function), in_parens]
      |> doc.concat
    }
    BitString(segments) -> pretty_bitstring(segments, pretty_expression)
    Case(subjects, clauses) -> {
      let subjects =
        subjects
        |> list.map(pretty_expression)
        |> doc.join(with: doc.from_string(", "))

      let clauses =
        {
          use Clause(lolo_patterns, guard, body) <- list.map(clauses)

          let lolo_patterns =
            list.map(lolo_patterns, list.map(_, pretty_pattern))

          let lolo_patterns =
            list.map(lolo_patterns, doc.join(_, with: doc.from_string(", ")))
            |> doc.join(with: doc.from_string(" | "))

          let guard =
            option.map(guard, pretty_expression)
            |> option.map(doc.prepend(_, doc.from_string(" if ")))
            |> option.unwrap(or: doc.empty)

          [
            lolo_patterns,
            guard,
            doc.from_string(" -> "),
            pretty_expression(body),
          ]
          |> doc.concat
        }
        |> doc.join(with: doc.line)

      doc.from_string("case ")
      |> doc.append(subjects)
      |> doc.append_docs([doc.from_string(" {"), doc.line])
      |> doc.append(clauses)
      |> nest
      |> doc.append_docs([doc.line, doc.from_string("}")])
    }
    BinaryOperator(name, left, right) -> {
      [
        pretty_expression(left),
        nbsp(),
        pretty_binary_operator(name),
        nbsp(),
        pretty_expression(right),
      ]
      |> doc.concat
    }
  }
}

fn pretty_binary_operator(operator: BinaryOperator) -> Document {
  case operator {
    And -> doc.from_string("&&")
    Or -> doc.from_string("||")
    Eq -> doc.from_string("==")
    NotEq -> doc.from_string("!=")
    LtInt -> doc.from_string("<")
    LtEqInt -> doc.from_string("<=")
    LtFloat -> doc.from_string("<.")
    LtEqFloat -> doc.from_string("<=.")
    GtEqInt -> doc.from_string(">=")
    GtInt -> doc.from_string(">")
    GtEqFloat -> doc.from_string(">=.")
    GtFloat -> doc.from_string(">.")
    Pipe -> doc.from_string("|>")
    AddInt -> doc.from_string("+")
    AddFloat -> doc.from_string("+.")
    SubInt -> doc.from_string("-")
    SubFloat -> doc.from_string("-.")
    MultInt -> doc.from_string("*")
    MultFloat -> doc.from_string("*.")
    DivInt -> doc.from_string("/")
    DivFloat -> doc.from_string("/.")
    RemainderInt -> doc.from_string("%")
    Concatenate -> doc.from_string("<>")
  }
}

fn pretty_bitstring(
  segments: List(#(as_doc, List(BitStringSegmentOption(as_doc)))),
  to_doc: fn(as_doc) -> Document,
) -> Document {
  let segments =
    {
      use segment <- list.map(segments)
      let #(expr, options) = segment
      let options =
        options
        |> list.map(pretty_bitstring_option(_, to_doc))
        |> doc.join(with: doc.from_string("-"))

      [to_doc(expr), doc.from_string(":"), options]
      |> doc.concat
    }
    |> doc.concat_join([doc.from_string(","), doc.flex_break(" ", "")])

  [doc.from_string("<<"), doc.soft_break]
  |> doc.concat
  |> doc.append(segments)
  |> nest
  |> doc.append_docs([trailing_comma(), doc.from_string(">>")])
  |> doc.group
}

fn pretty_bitstring_option(
  bitstring_option: BitStringSegmentOption(as_doc),
  fun: fn(as_doc) -> Document,
) -> Document {
  case bitstring_option {
    BinaryOption -> doc.from_string("binary")
    IntOption -> doc.from_string("int")
    FloatOption -> doc.from_string("float")
    BitStringOption -> doc.from_string("bit_string")
    Utf8Option -> doc.from_string("utf8")
    Utf16Option -> doc.from_string("utf16")
    Utf32Option -> doc.from_string("utf32")
    Utf8CodepointOption -> doc.from_string("utf8_codepoint")
    Utf16CodepointOption -> doc.from_string("utf16_codepoint")
    Utf32CodepointOption -> doc.from_string("utf32_codepoint")
    SignedOption -> doc.from_string("signed")
    UnsignedOption -> doc.from_string("unsigned")
    BigOption -> doc.from_string("big")
    LittleOption -> doc.from_string("little")
    NativeOption -> doc.from_string("native")
    SizeValueOption(n) ->
      [doc.from_string("size("), fun(n), doc.from_string(")")]
      |> doc.concat
    SizeOption(n) -> doc.from_string(int.to_string(n))
    UnitOption(n) -> doc.from_string("unit(" <> int.to_string(n) <> ")")
  }
}

// Pretty print an anonymous functions.
// For a top level function, see `pretty_function`
fn pretty_fn(
  arguments: List(FnParameter),
  return: Option(Type),
  body: List(Statement),
) -> Document {
  let arguments =
    arguments
    |> list.map(pretty_fn_parameter)
    |> comma_separated_in_parentheses

  let body = case body {
    // This never actually happens because the compiler will insert a todo
    [] -> doc.from_string("{}")

    // If there's only one statement, it might be on one line
    [statement] ->
      doc.concat([doc.from_string("{"), doc.space])
      |> doc.append(pretty_statement(statement))
      |> nest
      |> doc.append_docs([doc.space, doc.from_string("}")])
      |> doc.group

    // Multiple statements always break to multiple lines
    multiple_statements -> pretty_block(multiple_statements)
  }

  [
    doc.from_string("fn"),
    arguments,
    pretty_return_signature(return),
    nbsp(),
    body,
  ]
  |> doc.concat
}

// Pretty print an anonymous function parameter.
// For a top level function parameter, see `pretty_function_parameter`
fn pretty_fn_parameter(fn_parameter: FnParameter) -> Document {
  let FnParameter(name, type_) = fn_parameter
  [pretty_assignment_name(name), pretty_type_annotation(type_)]
  |> doc.concat
}

// Type Alias -------------------------------------

fn pretty_type_alias(type_alias: Definition(TypeAlias)) -> Document {
  use TypeAlias(name, publicity, parameters, aliased) <- pretty_definition(
    type_alias,
  )

  let parameters = case parameters {
    [] -> doc.empty
    _ -> {
      parameters
      |> list.map(doc.from_string)
      |> comma_separated_in_parentheses
    }
  }

  pretty_public(publicity)
  |> doc.append(doc.from_string("type " <> name))
  |> doc.append(parameters)
  |> doc.append(doc.from_string(" ="))
  |> doc.append(doc.line)
  |> nest
  |> doc.append(pretty_type(aliased))
}

// Type -------------------------------------------------

fn pretty_type(type_: Type) -> Document {
  case type_ {
    NamedType(name, module, parameters) -> {
      let parameters = case parameters {
        [] -> doc.empty
        _ ->
          parameters
          |> list.map(pretty_type)
          |> comma_separated_in_parentheses
      }

      module
      |> option.map(fn(mod) { mod <> "." })
      |> option.map(doc.from_string)
      |> option.unwrap(or: doc.empty)
      |> doc.append(doc.from_string(name))
      |> doc.append(parameters)
    }
    TupleType(elements) ->
      elements
      |> list.map(pretty_type)
      |> pretty_tuple
    FunctionType(parameters, return) -> {
      doc.from_string("fn")
      |> doc.append(
        parameters
        |> list.map(pretty_type)
        |> comma_separated_in_parentheses,
      )
      |> doc.append(pretty_return_signature(Some(return)))
    }
    VariableType(name) -> doc.from_string(name)
  }
}

fn pretty_custom_type(type_: Definition(CustomType)) -> Document {
  use CustomType(name, publicity, opaque_, parameters, variants) <- pretty_definition(
    type_,
  )

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
      |> comma_separated_in_parentheses
    }
  }

  // Custom types variants
  let variants =
    variants
    |> list.map(pretty_variant)
    |> doc.join(with: doc.line)

  let type_body =
    doc.concat([doc.from_string("{"), doc.line])
    |> doc.append(variants)
    |> nest
    |> doc.append_docs([doc.line, doc.from_string("}")])
    |> doc.group

  [
    pretty_public(publicity),
    doc.from_string(opaque_ <> "type " <> name),
    parameters,
    nbsp(),
    type_body,
  ]
  |> doc.concat
}

fn pretty_variant(variant: Variant) -> Document {
  let Variant(name, fields) = variant
  fields
  |> list.map(pretty_field(_, pretty_type))
  |> comma_separated_in_parentheses
  |> doc.prepend(doc.from_string(name))
}

fn pretty_field(field: Field(a), a_to_doc: fn(a) -> Document) -> Document {
  let Field(label, type_) = field
  case label {
    Some(l) -> doc.from_string(l <> ": ")
    None -> doc.empty
  }
  |> doc.append(a_to_doc(type_))
}

// Imports --------------------------------------------

// Pretty print an import statement
fn pretty_import(import_: Definition(Import)) -> Document {
  use Import(module, alias, unqualifieds) <- pretty_definition(import_)

  let unqualifieds = case unqualifieds {
    [] -> doc.empty
    _ ->
      unqualifieds
      |> list.map(fn(uq) {
        doc.concat([doc.from_string(uq.name), pretty_as(uq.alias)])
      })
      |> doc.concat_join([doc.from_string(","), doc.flex_break(" ", "")])
      |> doc.group
      |> doc.prepend(doc.concat([doc.from_string(".{"), doc.soft_break]))
      |> nest
      |> doc.append(doc.concat([trailing_comma(), doc.from_string("}")]))
      |> doc.group
  }

  doc.from_string("import " <> module)
  |> doc.append(unqualifieds)
  |> doc.append(pretty_as(alias))
}

// --------- Little Pieces -------------------------------

// Prints the pub keyword
fn pretty_public(publicity: Publicity) -> Document {
  case publicity {
    Public -> doc.from_string("pub ")
    Private -> doc.empty
  }
}

// Simply prints an assignment name normally or prefixed with
// an underscore if it is unused
fn pretty_assignment_name(assignment_name: AssignmentName) -> Document {
  case assignment_name {
    Named(str) -> doc.from_string(str)
    Discarded(str) -> doc.from_string("_" <> str)
  }
}

// Pretty prints an optional type annotation
fn pretty_type_annotation(type_: Option(Type)) -> Document {
  case type_ {
    Some(t) ->
      [doc.from_string(": "), pretty_type(t)]
      |> doc.concat
    None -> doc.empty
  }
}

// Pretty return signature
fn pretty_return_signature(type_: Option(Type)) -> Document {
  case type_ {
    Some(t) ->
      [doc.from_string(" -> "), pretty_type(t)]
      |> doc.concat
    None -> doc.empty
  }
}

// Pretty print "as" keyword alias
fn pretty_as(name: Option(String)) -> Document {
  case name {
    Some(str) -> doc.from_string(" as " <> str)
    None -> doc.empty
  }
}
