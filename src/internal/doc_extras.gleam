//// Not usually big on util files like this, but I figured it would be good
//// to separate out helpers that don't actually have anything
//// to do with glance.

import glam/doc.{Document}

/// The indent for nesting is always 2 spaces, so we don't
/// need to keep typing it all the time.
pub fn nest(input: Document) -> Document {
  doc.nest(input, by: 2)
}

/// A comma that only prints when the 
/// group is broken
pub fn trailing_comma() -> Document {
  doc.break("", ",")
}

/// A non breaking space
pub fn nbsp() -> Document {
  doc.from_string(" ")
}

pub fn comma_separated_in_parentheses(arguments: List(Document)) -> Document {
  let comma_separated_arguments =
    arguments
    |> doc.join(with: doc.concat([doc.from_string(","), doc.space]))

  doc.concat([doc.from_string("("), doc.soft_break])
  |> doc.append(comma_separated_arguments)
  |> doc.nest(by: 2)
  |> doc.append_docs([trailing_comma(), doc.from_string(")")])
  |> doc.group
}
