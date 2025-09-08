import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

// @external(erlang, "erlang", "statistics")
// pub fn statistics(stat: String) -> Int

const actor_number = 50

// First step of implementing the stack Actor is to define the message type that
// it can receive.
//
// The type of the elements in the stack is not fixed so a type parameter
// is used for it instead of a concrete type such as `String` or `Int`.
pub type Message(element) {
  // The `Shutdown` message is used to tell the actor to stop.
  // It is the simplest message type, it contains no data.
  //
  // Most the time we don't define an API to shut down an actor, but in this
  // example we do to show how it can be done.
  Shutdown

  // // The `Push` message is used to add a new element to the stack.
  // // It contains the item to add, the type of which is the `element`
  // // parameterised type.
  // Push(push: element)
  // // The `Pop` message is used to remove an element from the stack.
  // // It contains a `Subject`, which is used to send the response back to the
  // // message sender. In this case the reply is of type `Result(element, Nil)`.
  // Pop(reply_with: process.Subject(Result(element, Nil)))
  Sequence(start: Int, end: Int, k: Int)

  GetSequences(reply_with: process.Subject(List(String)))
}

//The last part is to implement the `handle_message` callback function.
//
// This function is called by the Actor for each message it receives.
// Actors are single threaded only doing one thing at a time, so they handle
// messages sequentially one at a time, in the order they are received.
//
// The function takes the current state and a message, and returns a data
// structure that indicates what to do next, along with the new state.
// fn handle_message(
//   stack: List(e),
//   message: Message(e),
// ) -> actor.Next(List(e), Message(e)) {
//   case message {
//     // For the `Shutdown` message we return the `actor.stop` value, which causes
//     // the actor to discard any remaining messages and stop.
//     // We may chose to do some clean-up work here, but this actor doesn't need
//     // to do this.
//     Shutdown -> actor.stop()

//     // For the `Push` message we add the new element to the stack and return
//     // `actor.continue` with this new stack, causing the actor to process any
//     // queued messages or wait for more.
//     // Push(value) -> {
//     //   let new_state = [value, ..stack]
//     //   actor.continue(new_state)
//     // }

//     // // For the `Pop` message we attempt to remove an element from the stack,
//     // // sending it or an error back to the caller, before continuing.
//     // Pop(client) -> {
//     //   case stack {
//     //     [] -> {
//     //       // When the stack is empty we can't pop an element, so we send an
//     //       // error back.
//     //       process.send(client, Error(Nil))
//     //       actor.continue([])
//     //     }

//     //     [first, ..rest] -> {
//     //       // Otherwise we send the first element back and use the remaining
//     //       // elements as the new state.
//     //       io.println("pooped")
//     //       process.send(client, Ok(first))
//     //       actor.continue(rest)
//     //     }
//     //   }
//     // }
//     // Sequence(start, end, k, client)->{
//     //   let new_state = find_sequence(start, end, k, [])
//     //   process.send(client, Ok(new_state))
//     //   actor.continue(new_state)
//     // }
//   }
// }

fn handler(
  list: List(String),
  message: Message(e),
) -> actor.Next(List(String), Message(e)) {
  case message {
    // For the `Shutdown` message we return the `actor.stop` value, which causes
    // the actor to discard any remaining messages and stop.
    // We may chose to do some clean-up work here, but this actor doesn't need
    // to do this.
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

// pub fn print_sequence

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
  // Start the actor with initial state of an empty list, and the
  // `handle_message` callback function (defined below).
  // We assert that it starts successfully.
  // 
  // In real-world Gleam OTP programs we would likely write a wrapper functions
  // called `start`, `push` `pop`, `shutdown` to start and interact with the
  // Actor. We are not doing that here for the sake of showing how the Actor 
  // API works.
  // let assert Ok(actor) =
  //   actor.new([]) |> actor.on_message(handle_message) |> actor.start
  // let subject = actor.data

  // // We can send a message to the actor to push elements onto the stack.
  // process.send(subject, Push("Joe"))
  // process.send(subject, Push("Mike"))
  // process.send(subject, Push("Robert"))

  // // The `Push` message expects no response, these messages are sent purely for
  // // the side effect of mutating the state held by the actor.
  // //
  // // We can also send the `Pop` message to take a value off of the actor's
  // // stack. This message expects a response, so we use `process.call` to send a
  // // message and wait until a reply is received.
  // //
  // // In this instance we are giving the actor 10 milliseconds to reply, if the
  // // `call` function doesn't get a reply within this time it will panic and
  // // crash the client process.
  //  let assert Ok("Robert") = process.call(subject, 10, Pop)
  // let assert Ok("Mike") = process.call(subject, 10, Pop)
  // let assert Ok("Joe") = process.call(subject, 10, Pop)

  // The stack is now empty, so if we pop again the actor replies with an error.
  //let assert Error(Nil) = process.call(subject, 10, Pop)

  // Lastly, we can send a message to the actor asking it to shut down.
  // process.send(subject, Shutdown)
}
