import argv
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

pub type Message(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(Message(e)))
  ReceiveMessage(s: Float, w: Float)
  GetNeighbors(
    reply_to: process.Subject(dict.Dict(Int, process.Subject(Message(e)))),
  )
}

pub type StateHolder(e) {
  StateHolder(
    neighbors: dict.Dict(Int, process.Subject(Message(e))),
    id: Int,
    request_num: Int,
    max_num: Int,
    //end_subject: process.Subject(RunMessage(e)),
  )
}
