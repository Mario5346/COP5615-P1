import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

const actor_number = 6000

pub type Message(element) {
  Shutdown

  Sequence(start: Int, end: Int, k: Int)

  GetSequences(reply_with: process.Subject(List(String)))
}

fn handler(
  list: List(String),
  message: Message(e),
) -> actor.Next(List(String), Message(e)) {
  case message {
    Shutdown -> actor.stop()

    Sequence(start, end, k) -> {
      case end {
        0 -> {
          //process.send(client, Error(Nil))
          actor.continue([])
        }
        _ -> {
          let new_state = find_sequence(start, end, k, [])
          //process.send(client, Ok(new_state))
          actor.continue(new_state)
        }
      }
    }
    GetSequences(client) -> {
      actor.send(client, list)
      actor.continue(list)
    }
  }
}

// alternatively, we can use the formula for sum of squares. It doesn't yield better performance though

// pub fn sum_of_squares_helper(start: Int) -> Int {
//   start * { start + 1 } * { 2 * start + 1 } / 6
// }

// pub fn sum_of_squares(start: Int, k: Int) -> Int {
//   // io.println("this " <> int.to_string(start * start))
//   let lower = sum_of_squares_helper(start - 1)
//   let upper = sum_of_squares_helper(start + k - 1)
//   upper - lower
// }

pub fn sum_of_squares(start: Int, k: Int) -> Int {
  case k {
    0 -> 0
    _ -> {
      // io.println("this " <> int.to_string(start * start))
      start * start + sum_of_squares(start + 1, k - 1)
    }
  }
}

pub fn is_perfect_square(n) -> Bool {
  //let root = 0
  case int.square_root(n) {
    Ok(result) -> {
      // io.println("checking " <> int.to_string(n))
      float.truncate(result) * float.truncate(result) == n
    }

    Error(_error_message) -> False
  }
}

pub fn find_sequence(start: Int, n: Int, k: Int, results: List(String)) {
  case int.compare(start, n) {
    order.Gt -> results
    _ -> {
      let total = sum_of_squares(start, k)
      case is_perfect_square(total) {
        True -> {
          // io.println("is perfect square match  " <> int.to_string(total))
          let results = list.append(results, [int.to_string(start)])
          find_sequence(start + 1, n, k, results)
        }
        _ -> find_sequence(start + 1, n, k, results)
      }
    }
  }
}

pub fn initialize_actors(start: Int, end: Int, n: Int, k: Int, chunk_size: Int) {
  case int.compare(start, n) {
    order.Gt -> []
    _ -> {
      let assert Ok(actor) =
        actor.new([]) |> actor.on_message(handler) |> actor.start
      let subject = actor.data
      process.send(subject, Sequence(start, end, k))

      let val =
        initialize_actors(
          start + chunk_size,
          end + chunk_size,
          n,
          k,
          chunk_size,
        )
      let result = process.call(subject, 10_000_000, GetSequences)
      let final = list.append(result, val)
      // list.each(result, io.println)
      final
    }
  }
}

pub fn main() {
  case argv.load().arguments {
    ["lukas", first, second] -> {
      case int.parse(first) {
        Ok(result) -> {
          let n = result
          case int.parse(second) {
            Ok(result) -> {
              io.println(
                "Finding before " <> first <> " with length " <> second,
              )
              // let cpu_start = statistics("runtime")
              let k = result
              // let final_results = find_sequence(1, n, k, [])
              //let final_results = []

              case int.compare(n, actor_number) {
                order.Gt -> {
                  let chunk = n / actor_number
                  let final_results = initialize_actors(1, chunk, n, k, chunk)
                  list.each(final_results, io.println)
                }
                _ -> {
                  let final_results = find_sequence(1, n, k, [])
                  list.each(final_results, io.println)
                }
              }
              //list.each(final_results, io.println)
              // let cpu_end = statistics("runtime")
              // io.println(
              //   " -------CPU TIME: " <> int.to_string(cpu_end - cpu_start),
              // )
              io.println("END")
            }
            _ -> io.println("k is not int")
          }
        }
        _ -> io.println("n is not int")
      }
    }
    _ -> io.println("usage: gleam run lukas <n> <k>")
  }
}
