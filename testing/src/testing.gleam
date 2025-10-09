import gleam/int
import gleam/io

pub fn main() -> Nil {
  let my_id = 1
  let succ = 3
  let id = 4

  let bool = { id <= succ } && { id > my_id }
  echo bool

  // int.compare()
  io.println("Hello from testing!")
}
