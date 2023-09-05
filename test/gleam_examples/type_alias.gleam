import gleam/option

pub type Header =
  fn(option.Option(#(String, String))) -> #(String, String)

pub type NoParamsFun =
  fn() -> Int

pub type GenericFun(a, b) =
  fn(a) -> b
