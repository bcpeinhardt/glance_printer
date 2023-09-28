pub type Pet {
  Cat(name: String, color: String)
}

fn record_update() {
  let dutchess = Cat(name: "Dutchess", color: "Brown")
  let updated = Cat(..dutchess, color: "Calico")
}
