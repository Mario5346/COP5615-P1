import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/order
import gossalg
import pushsum

pub fn full_network_gossip(
  start: Int,
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) {
  case int.compare(start, dict.size(nodes)) {
    order.Gt -> Nil
    _ -> {
      let curr = start
      dict.each(nodes, fn(k, v) {
        case k {
          // curr ->
          //   io.println("- NOT ADDED NEIGHBORS TO " <> int.to_string(start))
          _ -> {
            let subject = nodes |> dict.get(start)
            case subject {
              Ok(result) -> {
                process.send(result, gossalg.AddNeighbor(v))
                // io.println("-- ADDED NEIGHBORS TO " <> int.to_string(start))
              }
              Error(e) -> Nil
            }
          }
        }
      })

      full_network_gossip(start + 1, nodes)
    }
  }
}

pub fn full_network_pushsum(
  start: Int,
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) {
  case int.compare(start, dict.size(nodes)) {
    order.Gt -> Nil
    _ -> {
      dict.each(nodes, fn(k, v) {
        case int.compare(k, start) {
          order.Eq -> Nil
          _ -> {
            let subject = nodes |> dict.get(start)
            case subject {
              Ok(result) -> {
                process.send(result, pushsum.AddNeighbor(k, v))
                process.send(v, pushsum.AddNeighbor(start, result))
              }
              Error(e) -> Nil
            }
          }
        }
      })

      full_network_pushsum(start + 1, nodes)
    }
  }
}
