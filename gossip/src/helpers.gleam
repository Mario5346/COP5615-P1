import gleam/erlang/process
import gossalg
import pushsum

pub type SubjectTypes(a) {
  GossipActor(process.Subject(gossalg.Message(a)))
  PushSumActor(process.Subject(pushsum.PushSumMessage(a)))
}
