// File: src/api_server.gleam
import gleam/bit_array
import gleam/bytes_tree

// import gleam/dict
// import gleam/dynamic
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import mist
import regretdit.{
  type EngineMessage, CreateComment, CreatePost, CreateSubregretdit,
  DownvoteComment, DownvotePost, GetAllSubregretdits, GetPost, GetStats,
  GetSubregretdit, GetUser, GetUserFeed, GetUserMessages, GetUserPublicKey,
  JoinSubregretdit, LeaveSubregretdit, RegisterUser, SendMessage, UpvoteComment,
  UpvotePost,
}

pub type ApiContext {
  ApiContext(engine: Subject(EngineMessage))
}

// ========== Response Helpers ==========

fn json_response(status: Int, body: String) -> Response(mist.ResponseData) {
  let body_tree = bytes_tree.from_string(body)
  response.new(status)
  |> response.set_body(mist.Bytes(body_tree))
  |> response.set_header("content-type", "application/json")
  |> response.set_header("access-control-allow-origin", "*")
}

fn error_response(status: Int, message: String) -> Response(mist.ResponseData) {
  let body =
    json.object([#("error", json.string(message))])
    |> json.to_string
  json_response(status, body)
}

fn success_response(data: json.Json) -> Response(mist.ResponseData) {
  json_response(200, json.to_string(data))
}

// ========== Request Body Parsing ==========

fn read_body_as_string(req: Request(mist.Connection)) -> Result(String, Nil) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      // mist.read_body returns a Request(BitArray), access the body field directly
      case bit_array.to_string(req_with_body.body) {
        Ok(str) -> Ok(str)
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

// Simple JSON field extraction (you could use a proper JSON decoder)
fn extract_field(body: String, field_name: String) -> Result(String, Nil) {
  // Look for "field_name":"value"
  case string.split(body, "\"" <> field_name <> "\":") {
    [_, rest, ..] -> {
      // Extract the value between quotes
      case string.split(rest, "\"") {
        [_, value, ..] -> {
          case value {
            "" -> Error(Nil)
            v -> Ok(string.trim(v))
          }
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

// ========== API Handlers ==========

// POST /api/users - Register new user
fn handle_register_user(
  ctx: ApiContext,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let username = extract_field(body, "username") |> result.unwrap("")
      let public_key = extract_field(body, "public_key") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(ctx.engine, RegisterUser(username, public_key, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(user_id)) -> {
          let data =
            json.object([
              #("success", json.bool(True)),
              #("user_id", json.string(user_id)),
              #("username", json.string(username)),
            ])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

fn handle_get_user_public_key(
  ctx: ApiContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetUserPublicKey(user_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(public_key)) -> {
      let data =
        json.object([
          #("user_id", json.string(user_id)),
          #("public_key", json.string(public_key)),
        ])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// GET /api/users/:id - Get user info
fn handle_get_user(
  ctx: ApiContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetUser(user_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(user)) -> {
      let data =
        json.object([
          #("id", json.string(user.id)),
          #("username", json.string(user.username)),
          #("karma", json.int(user.karma)),
          #(
            "joined_subregretdits",
            json.array(user.joined_subregretdits, json.string),
          ),
          #("public_key", json.string(user.public_key)),
        ])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// GET /api/users/:id/feed - Get user's feed
fn handle_get_user_feed(
  ctx: ApiContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetUserFeed(user_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(posts)) -> {
      let posts_json =
        json.array(posts, fn(post) {
          json.object([
            #("id", json.string(post.id)),
            #("author_id", json.string(post.author_id)),
            #("subregretdit_id", json.string(post.subregretdit_id)),
            #("title", json.string(post.title)),
            #("content", json.string(post.content)),
            #("upvotes", json.int(post.upvotes)),
            #("downvotes", json.int(post.downvotes)),
            #("comments", json.array(post.comments, json.string)),
            #("timestamp", json.int(post.timestamp)),
            #("signature", json.string(post.signature)),
          ])
        })
      success_response(posts_json)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// GET /api/users/:id/messages - Get user's messages
fn handle_get_user_messages(
  ctx: ApiContext,
  user_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetUserMessages(user_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(messages)) -> {
      let messages_json =
        json.array(messages, fn(msg) {
          json.object([
            #("id", json.string(msg.id)),
            #("from_user_id", json.string(msg.from_user_id)),
            #("to_user_id", json.string(msg.to_user_id)),
            #("content", json.string(msg.content)),
            #("timestamp", json.int(msg.timestamp)),
            #("is_read", json.bool(msg.is_read)),
          ])
        })
      success_response(messages_json)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/subregretdits - Create subregretdit
fn handle_create_subregretdit(
  ctx: ApiContext,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let creator_id = extract_field(body, "creator_id") |> result.unwrap("")
      let name = extract_field(body, "name") |> result.unwrap("Unnamed")
      let description = extract_field(body, "description") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreateSubregretdit(creator_id, name, description, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(sub_id)) -> {
          let data =
            json.object([
              #("success", json.bool(True)),
              #("subregretdit_id", json.string(sub_id)),
            ])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// GET /api/subregretdits - Get all subregretdits
fn handle_get_all_subregretdits(ctx: ApiContext) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetAllSubregretdits(reply))

  case process.receive(reply, 5000) {
    Ok(subs) -> {
      let subs_json =
        json.array(subs, fn(sub) {
          json.object([
            #("id", json.string(sub.id)),
            #("name", json.string(sub.name)),
            #("description", json.string(sub.description)),
            #("members_count", json.int(list.length(sub.members))),
            #("posts_count", json.int(list.length(sub.posts))),
          ])
        })
      success_response(subs_json)
    }
    Error(_) -> error_response(500, "Request timeout")
  }
}

// GET /api/subregretdits/:id - Get subregretdit info
fn handle_get_subregretdit(
  ctx: ApiContext,
  sub_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetSubregretdit(sub_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(sub)) -> {
      let data =
        json.object([
          #("id", json.string(sub.id)),
          #("name", json.string(sub.name)),
          #("description", json.string(sub.description)),
          #("members", json.array(sub.members, json.string)),
          #("posts", json.array(sub.posts, json.string)),
        ])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/subregretdits/:id/join - Join subregretdit
fn handle_join_subregretdit(
  ctx: ApiContext,
  sub_id: String,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let user_id = extract_field(body, "user_id") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(ctx.engine, JoinSubregretdit(user_id, sub_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(_)) -> {
          let data = json.object([#("success", json.bool(True))])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// POST /api/subregretdits/:id/leave - Leave subregretdit
fn handle_leave_subregretdit(
  ctx: ApiContext,
  sub_id: String,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let user_id = extract_field(body, "user_id") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(ctx.engine, LeaveSubregretdit(user_id, sub_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(_)) -> {
          let data = json.object([#("success", json.bool(True))])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// POST /api/posts - Create post
fn handle_create_post(
  ctx: ApiContext,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let author_id = extract_field(body, "author_id") |> result.unwrap("")
      let sub_id = extract_field(body, "subregretdit_id") |> result.unwrap("")
      let title = extract_field(body, "title") |> result.unwrap("")
      let content = extract_field(body, "content") |> result.unwrap("")
      let signature = extract_field(body, "signature") |> result.unwrap("")
      let timestamp =
        extract_field(body, "timestamp")
        |> result.unwrap("0")
        |> int.parse
        |> result.unwrap(0)

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreatePost(
          author_id,
          sub_id,
          title,
          content,
          timestamp,
          signature,
          reply,
        ),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(post_id)) -> {
          let data =
            json.object([
              #("success", json.bool(True)),
              #("post_id", json.string(post_id)),
            ])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// GET /api/posts/:id - Get post
fn handle_get_post(
  ctx: ApiContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetPost(post_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(post)) -> {
      let data =
        json.object([
          #("id", json.string(post.id)),
          #("author_id", json.string(post.author_id)),
          #("subregretdit_id", json.string(post.subregretdit_id)),
          #("title", json.string(post.title)),
          #("content", json.string(post.content)),
          #("upvotes", json.int(post.upvotes)),
          #("downvotes", json.int(post.downvotes)),
          #("comments", json.array(post.comments, json.string)),
          #("timestamp", json.int(post.timestamp)),
          #("signature", json.string(post.signature)),
        ])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(404, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/posts/:id/upvote - Upvote post
fn handle_upvote_post(
  ctx: ApiContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, UpvotePost(post_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(_)) -> {
      let data = json.object([#("success", json.bool(True))])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(400, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/posts/:id/downvote - Downvote post
fn handle_downvote_post(
  ctx: ApiContext,
  post_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, DownvotePost(post_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(_)) -> {
      let data = json.object([#("success", json.bool(True))])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(400, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/comments - Create comment
fn handle_create_comment(
  ctx: ApiContext,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let author_id = extract_field(body, "author_id") |> result.unwrap("")
      let post_id = extract_field(body, "post_id") |> result.unwrap("")
      let content = extract_field(body, "content") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreateComment(author_id, post_id, None, content, 0, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(comment_id)) -> {
          let data =
            json.object([
              #("success", json.bool(True)),
              #("comment_id", json.string(comment_id)),
            ])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// POST /api/comments/:id/upvote - Upvote comment
fn handle_upvote_comment(
  ctx: ApiContext,
  comment_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, UpvoteComment(comment_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(_)) -> {
      let data = json.object([#("success", json.bool(True))])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(400, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/comments/:id/downvote - Downvote comment
fn handle_downvote_comment(
  ctx: ApiContext,
  comment_id: String,
) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, DownvoteComment(comment_id, reply))

  case process.receive(reply, 5000) {
    Ok(Ok(_)) -> {
      let data = json.object([#("success", json.bool(True))])
      success_response(data)
    }
    Ok(Error(err)) -> error_response(400, error_to_string(err))
    Error(_) -> error_response(500, "Request timeout")
  }
}

// POST /api/messages - Send message
fn handle_send_message(
  ctx: ApiContext,
  req: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  case read_body_as_string(req) {
    Ok(body) -> {
      let from_id = extract_field(body, "from_user_id") |> result.unwrap("")
      let to_id = extract_field(body, "to_user_id") |> result.unwrap("")
      let content = extract_field(body, "content") |> result.unwrap("")

      let reply = process.new_subject()
      process.send(ctx.engine, SendMessage(from_id, to_id, content, 0, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(msg_id)) -> {
          let data =
            json.object([
              #("success", json.bool(True)),
              #("message_id", json.string(msg_id)),
            ])
          success_response(data)
        }
        Ok(Error(err)) -> error_response(400, error_to_string(err))
        Error(_) -> error_response(500, "Request timeout")
      }
    }
    Error(_) -> error_response(400, "Invalid request body")
  }
}

// GET /api/stats - Get platform statistics
fn handle_get_stats(ctx: ApiContext) -> Response(mist.ResponseData) {
  let reply = process.new_subject()
  process.send(ctx.engine, GetStats(reply))

  case process.receive(reply, 5000) {
    Ok(stats) -> {
      let data =
        json.object([
          #("posts", json.int(stats.posts)),
          #("comments", json.int(stats.comments)),
          #("upvotes", json.int(stats.upvotes)),
          #("downvotes", json.int(stats.downvotes)),
          #("dms", json.int(stats.dms)),
          #("subs_joined", json.int(stats.subs_joined)),
        ])
      success_response(data)
    }
    Error(_) -> error_response(500, "Request timeout")
  }
}

// ========== Main Request Handler ==========

fn handle_request(
  req: Request(mist.Connection),
  ctx: ApiContext,
) -> Response(mist.ResponseData) {
  let path = request.path_segments(req)

  case req.method, path {
    // Users
    http.Post, ["api", "users"] -> handle_register_user(ctx, req)
    http.Get, ["api", "users", user_id] -> handle_get_user(ctx, user_id)
    http.Get, ["api", "users", user_id, "feed"] ->
      handle_get_user_feed(ctx, user_id)
    http.Get, ["api", "users", user_id, "messages"] ->
      handle_get_user_messages(ctx, user_id)
    http.Get, ["api", "users", user_id, "publickey"] ->
      handle_get_user_public_key(ctx, user_id)

    // Subregretdits
    http.Post, ["api", "subregretdits"] -> handle_create_subregretdit(ctx, req)
    http.Get, ["api", "subregretdits"] -> handle_get_all_subregretdits(ctx)
    http.Get, ["api", "subregretdits", sub_id] ->
      handle_get_subregretdit(ctx, sub_id)
    http.Post, ["api", "subregretdits", sub_id, "join"] ->
      handle_join_subregretdit(ctx, sub_id, req)
    http.Post, ["api", "subregretdits", sub_id, "leave"] ->
      handle_leave_subregretdit(ctx, sub_id, req)

    // Posts
    http.Post, ["api", "posts"] -> handle_create_post(ctx, req)
    http.Get, ["api", "posts", post_id] -> handle_get_post(ctx, post_id)
    http.Post, ["api", "posts", post_id, "upvote"] ->
      handle_upvote_post(ctx, post_id)
    http.Post, ["api", "posts", post_id, "downvote"] ->
      handle_downvote_post(ctx, post_id)

    // Comments
    http.Post, ["api", "comments"] -> handle_create_comment(ctx, req)
    http.Post, ["api", "comments", comment_id, "upvote"] ->
      handle_upvote_comment(ctx, comment_id)
    http.Post, ["api", "comments", comment_id, "downvote"] ->
      handle_downvote_comment(ctx, comment_id)

    // Messages
    http.Post, ["api", "messages"] -> handle_send_message(ctx, req)

    // Stats
    http.Get, ["api", "stats"] -> handle_get_stats(ctx)

    // Health check
    http.Get, ["health"] -> json_response(200, "{\"status\":\"healthy\"}")

    // 404 for unknown routes
    _, _ -> error_response(404, "Endpoint not found")
  }
}

// ========== Utility Functions ==========

fn error_to_string(err: regretdit.Error) -> String {
  case err {
    regretdit.UserNotFound -> "User not found"
    regretdit.SubregretditNotFound -> "Subregretdit not found"
    regretdit.PostNotFound -> "Post not found"
    regretdit.CommentNotFound -> "Comment not found"
    regretdit.MessageNotFound -> "Message not found"
    regretdit.AlreadyJoined -> "Already joined this subregretdit"
    regretdit.NotAMember -> "Not a member of this subregretdit"
    regretdit.Unauthorized -> "Unauthorized action"
    regretdit.InvalidInput -> "Invalid input provided"
    regretdit.InvalidSignature -> "Invalid digital signature"
    regretdit.CryptoError -> "Cryptographic error"
  }
}

// ========== Server Start ==========

pub fn start_server(engine: Subject(EngineMessage), port: Int) {
  let ctx = ApiContext(engine)
  let handler = fn(req) { handle_request(req, ctx) }

  let assert Ok(_) =
    mist.new(handler)
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  io.println(
    "[-OK-] Regretdit API Server started on http://0.0.0.0:"
    <> int.to_string(port),
  )
  io.println("---- API Documentation:")
  io.println("   POST   /api/users                    - Register user")
  io.println("   GET    /api/users/:id                - Get user")
  io.println("   GET    /api/users/:id/feed           - Get user feed")
  io.println("   POST   /api/subregretdits            - Create subregretdit")
  io.println("   GET    /api/subregretdits            - List all subregretdits")
  io.println("   POST   /api/subregretdits/:id/join   - Join subregretdit")
  io.println("   POST   /api/posts                    - Create post")
  io.println("   GET    /api/posts/:id                - Get post")
  io.println("   POST   /api/posts/:id/upvote         - Upvote post")
  io.println("   POST   /api/comments                 - Create comment")
  io.println("   GET    /api/stats                    - Platform statistics")
  io.println("   GET    /api/users/:id/publickey       - Get user public key")
  io.println("")
}

pub fn main() {
  case regretdit.start() {
    Ok(engine) -> {
      start_server(engine.data, 8080)
      process.sleep_forever()
    }
    Error(_) -> {
      io.println("[-X-] Failed to start Regretdit engine")
      Nil
    }
  }
}
