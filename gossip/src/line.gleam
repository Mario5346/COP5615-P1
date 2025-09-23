import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/order
import gossalg
import pushsum

pub fn line_network_gossip(
  start: Int,
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) {
  case int.compare(start, dict.size(nodes)) {
    order.Gt -> Nil
    _ -> {
      let curr = start
      let left = nodes |> dict.get(start - 1)
      let right = nodes |> dict.get(start + 1)
      let subject = nodes |> dict.get(start)

      case subject {
        Ok(result) -> {
          case left {
            Ok(l) -> process.send(result, gossalg.AddNeighbor(l))
            Error(e) -> Nil
          }
          case right {
            Ok(r) -> process.send(result, gossalg.AddNeighbor(r))
            Error(e) -> Nil
          }
        }
        Error(e) -> Nil
      }
      //io.print("-- ADDED NEIGHBORS TO " <> int.to_string(start))
      line_network_gossip(start + 1, nodes)
    }
  }
}

// ---------------------------------------------------------

pub fn line_network_pushsum(
  start: Int,
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) {
  case int.compare(start, dict.size(nodes)) {
    order.Lt -> {
      let curr = start
      let left = nodes |> dict.get(start - 1)
      let right = nodes |> dict.get(start + 1)
      let subject = nodes |> dict.get(start)

      case subject {
        Ok(result) -> {
          case left {
            Ok(l) -> {
              process.send(result, pushsum.AddNeighbor(start - 1, l))
            }
            Error(e) -> Nil
          }
          case right {
            Ok(r) -> {
              process.send(result, pushsum.AddNeighbor(start + 1, r))
            }
            Error(e) -> Nil
          }
        }
        Error(e) -> Nil
      }
      //io.print("-- ADDED NEIGHBORS TO " <> int.to_string(start))
      line_network_pushsum(start + 1, nodes)
    }
    _ -> Nil
  }
}
