pub opaque type Pet(a, b) {
  Cat(name: String, color: String)
  Dog(barks: Bool)
}

fn constructors() {
  let x = Cat("Dutchess", "Brown")
  let assert Cat("Dutchess", "Brown") = x
}

fn constructors_shorthands() {
  let name = "Dutchess"
  let color = "Brown"
  let x = Cat(name:, color:)
  let assert Cat("Dutchess", "Brown") = x
}
