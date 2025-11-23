import gleam/dynamic
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import mist
import regretdit.{
  type EngineMessage, CreateComment, CreatePost, CreateSubregretdit,
  DownvoteComment, DownvotePost, GetAllSubregretdits, GetPost, GetStats,
  GetSubregretdit, GetUser, GetUserFeed, GetUserMessages, JoinSubregretdit,
  LeaveSubregretdit, RegisterUser, ReplyToMessage, SendMessage, UpvoteComment,
  UpvotePost,
}
import wisp.{type Request, type Response}

pub type Context {
  Context(engine: Subject(EngineMessage))
}

// JSON encoding helpers
fn encode_user(user: regretdit.User) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("username", json.string(user.username)),
    #("karma", json.int(user.karma)),
    #(
      "joined_subregretdits",
      json.array(user.joined_subregretdits, json.string),
    ),
  ])
}

fn encode_subregretdit(sub: regretdit.Subregretdit) -> json.Json {
  json.object([
    #("id", json.string(sub.id)),
    #("name", json.string(sub.name)),
    #("description", json.string(sub.description)),
    #("members", json.array(sub.members, json.string)),
    #("posts", json.array(sub.posts, json.string)),
  ])
}

fn encode_post(post: regretdit.Post) -> json.Json {
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
  ])
}

fn encode_message(msg: regretdit.DirectMessage) -> json.Json {
  json.object([
    #("id", json.string(msg.id)),
    #("from_user_id", json.string(msg.from_user_id)),
    #("to_user_id", json.string(msg.to_user_id)),
    #("content", json.string(msg.content)),
    #("timestamp", json.int(msg.timestamp)),
    #("is_read", json.bool(msg.is_read)),
  ])
}

fn encode_stats(stats: regretdit.Stats) -> json.Json {
  json.object([
    #("posts", json.int(stats.posts)),
    #("comments", json.int(stats.comments)),
    #("upvotes", json.int(stats.upvotes)),
    #("downvotes", json.int(stats.downvotes)),
    #("dms", json.int(stats.dms)),
    #("subs_joined", json.int(stats.subs_joined)),
  ])
}

fn encode_error(error: regretdit.Error) -> json.Json {
  let msg = case error {
    regretdit.UserNotFound -> "User not found"
    regretdit.SubregretditNotFound -> "Subregretdit not found"
    regretdit.PostNotFound -> "Post not found"
    regretdit.CommentNotFound -> "Comment not found"
    regretdit.MessageNotFound -> "Message not found"
    regretdit.AlreadyJoined -> "Already joined"
    regretdit.NotAMember -> "Not a member"
    regretdit.Unauthorized -> "Unauthorized"
    regretdit.InvalidInput -> "Invalid input"
  }
  json.object([#("error", json.string(msg))])
}

fn json_response(data: json.Json, status: Int) -> Response {
  wisp.json_response(json.to_string(data), status)
}

// Helper to get string from dynamic
fn get_string(dyn: dynamic.Dynamic, field: String) -> String {
  dynamic.field(dyn, field, dynamic.string)
  |> result.unwrap("")
}

// Helper to get int from dynamic
fn get_int(dyn: dynamic.Dynamic, field: String) -> Int {
  dynamic.field(dyn, field, dynamic.int)
  |> result.unwrap(0)
}

// Helper to get optional string from dynamic
fn get_optional_string(
  dyn: dynamic.Dynamic,
  field: String,
) -> option.Option(String) {
  case dynamic.field(dyn, field, dynamic.string) {
    Ok(s) -> option.Some(s)
    Error(_) -> option.None
  }
}

// Route handlers
pub fn handle_request(req: Request, ctx: Context) -> Response {
  case wisp.path_segments(req) {
    // User routes
    ["api", "users"] -> handle_users(req, ctx)
    ["api", "users", user_id] -> handle_user(req, ctx, user_id)
    ["api", "users", user_id, "feed"] -> handle_user_feed(req, ctx, user_id)
    ["api", "users", user_id, "messages"] ->
      handle_user_messages(req, ctx, user_id)

    // Subregretdit routes
    ["api", "subregretdits"] -> handle_subregretdits(req, ctx)
    ["api", "subregretdits", sub_id] -> handle_subregretdit(req, ctx, sub_id)
    ["api", "subregretdits", sub_id, "join"] ->
      handle_join_subregretdit(req, ctx, sub_id)
    ["api", "subregretdits", sub_id, "leave"] ->
      handle_leave_subregretdit(req, ctx, sub_id)

    // Post routes
    ["api", "posts"] -> handle_posts(req, ctx)
    ["api", "posts", post_id] -> handle_post(req, ctx, post_id)
    ["api", "posts", post_id, "upvote"] ->
      handle_post_vote(req, ctx, post_id, True)
    ["api", "posts", post_id, "downvote"] ->
      handle_post_vote(req, ctx, post_id, False)
    ["api", "posts", post_id, "comments"] ->
      handle_post_comments(req, ctx, post_id)

    // Comment routes
    ["api", "comments", comment_id, "upvote"] ->
      handle_comment_vote(req, ctx, comment_id, True)
    ["api", "comments", comment_id, "downvote"] ->
      handle_comment_vote(req, ctx, comment_id, False)

    // Message routes
    ["api", "messages"] -> handle_send_message(req, ctx)
    ["api", "messages", msg_id, "reply"] ->
      handle_reply_message(req, ctx, msg_id)

    // Stats route
    ["api", "stats"] -> handle_stats(req, ctx)

    _ -> wisp.not_found()
  }
}

// POST /api/users - Register user
fn handle_users(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      use json <- wisp.require_json(req)

      let username = get_string(json, "username")

      let reply = process.new_subject()
      process.send(ctx.engine, RegisterUser(username, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(user_id)) ->
          json_response(json.object([#("user_id", json.string(user_id))]), 201)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// GET /api/users/:user_id
fn handle_user(req: Request, ctx: Context, user_id: String) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetUser(user_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(user)) -> json_response(encode_user(user), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 404)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// GET /api/users/:user_id/feed
fn handle_user_feed(req: Request, ctx: Context, user_id: String) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetUserFeed(user_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(posts)) -> json_response(json.array(posts, encode_post), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 404)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// GET /api/users/:user_id/messages
fn handle_user_messages(req: Request, ctx: Context, user_id: String) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetUserMessages(user_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(messages)) ->
          json_response(json.array(messages, encode_message), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 404)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// GET /api/subregretdits - List all
// POST /api/subregretdits - Create new
fn handle_subregretdits(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetAllSubregretdits(reply))

      case process.receive(reply, 5000) {
        Ok(subs) -> json_response(json.array(subs, encode_subregretdit), 200)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let creator_id = get_string(json_data, "creator_id")
      let name = get_string(json_data, "name")
      let description = get_string(json_data, "description")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreateSubregretdit(creator_id, name, description, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(sub_id)) ->
          json_response(
            json.object([#("subregretdit_id", json.string(sub_id))]),
            201,
          )
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get, http.Post])
  }
}

// GET /api/subregretdits/:sub_id
fn handle_subregretdit(req: Request, ctx: Context, sub_id: String) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetSubregretdit(sub_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(sub)) -> json_response(encode_subregretdit(sub), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 404)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// POST /api/subregretdits/:sub_id/join
fn handle_join_subregretdit(
  req: Request,
  ctx: Context,
  sub_id: String,
) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let user_id = get_string(json_data, "user_id")

      let reply = process.new_subject()
      process.send(ctx.engine, JoinSubregretdit(user_id, sub_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(_)) ->
          json_response(json.object([#("success", json.bool(True))]), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/subregretdits/:sub_id/leave
fn handle_leave_subregretdit(
  req: Request,
  ctx: Context,
  sub_id: String,
) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let user_id = get_string(json_data, "user_id")

      let reply = process.new_subject()
      process.send(ctx.engine, LeaveSubregretdit(user_id, sub_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(_)) ->
          json_response(json.object([#("success", json.bool(True))]), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/posts
fn handle_posts(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let author_id = get_string(json_data, "author_id")
      let subregretdit_id = get_string(json_data, "subregretdit_id")
      let title = get_string(json_data, "title")
      let content = get_string(json_data, "content")
      let timestamp = get_int(json_data, "timestamp")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreatePost(author_id, subregretdit_id, title, content, timestamp, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(post_id)) ->
          json_response(json.object([#("post_id", json.string(post_id))]), 201)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// GET /api/posts/:post_id
fn handle_post(req: Request, ctx: Context, post_id: String) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetPost(post_id, reply))

      case process.receive(reply, 5000) {
        Ok(Ok(post)) -> json_response(encode_post(post), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 404)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

// POST /api/posts/:post_id/upvote or /downvote
fn handle_post_vote(
  req: Request,
  ctx: Context,
  post_id: String,
  is_upvote: Bool,
) -> Response {
  case req.method {
    http.Post -> {
      let reply = process.new_subject()
      case is_upvote {
        True -> process.send(ctx.engine, UpvotePost(post_id, reply))
        False -> process.send(ctx.engine, DownvotePost(post_id, reply))
      }

      case process.receive(reply, 5000) {
        Ok(Ok(_)) ->
          json_response(json.object([#("success", json.bool(True))]), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/posts/:post_id/comments
fn handle_post_comments(req: Request, ctx: Context, post_id: String) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let author_id = get_string(json_data, "author_id")
      let content = get_string(json_data, "content")
      let parent_comment_id =
        get_optional_string(json_data, "parent_comment_id")
      let timestamp = get_int(json_data, "timestamp")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        CreateComment(
          author_id,
          post_id,
          parent_comment_id,
          content,
          timestamp,
          reply,
        ),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(comment_id)) ->
          json_response(
            json.object([#("comment_id", json.string(comment_id))]),
            201,
          )
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/comments/:comment_id/upvote or /downvote
fn handle_comment_vote(
  req: Request,
  ctx: Context,
  comment_id: String,
  is_upvote: Bool,
) -> Response {
  case req.method {
    http.Post -> {
      let reply = process.new_subject()
      case is_upvote {
        True -> process.send(ctx.engine, UpvoteComment(comment_id, reply))
        False -> process.send(ctx.engine, DownvoteComment(comment_id, reply))
      }

      case process.receive(reply, 5000) {
        Ok(Ok(_)) ->
          json_response(json.object([#("success", json.bool(True))]), 200)
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/messages
fn handle_send_message(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let from_user_id = get_string(json_data, "from_user_id")
      let to_user_id = get_string(json_data, "to_user_id")
      let content = get_string(json_data, "content")
      let timestamp = get_int(json_data, "timestamp")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        SendMessage(from_user_id, to_user_id, content, timestamp, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(msg_id)) ->
          json_response(
            json.object([#("message_id", json.string(msg_id))]),
            201,
          )
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// POST /api/messages/:msg_id/reply
fn handle_reply_message(req: Request, ctx: Context, msg_id: String) -> Response {
  case req.method {
    http.Post -> {
      use json_data <- wisp.require_json(req)

      let content = get_string(json_data, "content")
      let timestamp = get_int(json_data, "timestamp")

      let reply = process.new_subject()
      process.send(
        ctx.engine,
        ReplyToMessage(msg_id, content, timestamp, reply),
      )

      case process.receive(reply, 5000) {
        Ok(Ok(new_msg_id)) ->
          json_response(
            json.object([#("message_id", json.string(new_msg_id))]),
            201,
          )
        Ok(Error(e)) -> json_response(encode_error(e), 400)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

// GET /api/stats
fn handle_stats(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Get -> {
      let reply = process.new_subject()
      process.send(ctx.engine, GetStats(reply))

      case process.receive(reply, 5000) {
        Ok(stats) -> json_response(encode_stats(stats), 200)
        Error(_) ->
          json_response(json.object([#("error", json.string("Timeout"))]), 500)
      }
    }
    _ -> wisp.method_not_allowed([http.Get])
  }
}

pub fn main() {
  wisp.configure_logger()

  case regretdit.start() {
    Ok(engine) -> {
      let ctx = Context(engine: engine.data)

      let secret_key_base = wisp.random_string(64)

      let assert Ok(_) =
        wisp.mist_handler(handle_request(_, ctx), secret_key_base)
        |> mist.new
        |> mist.port(8000)
        |> mist.start

      io.println("Server started on http://localhost:8000")
      process.sleep_forever()
    }
    Error(_) -> {
      io.println("Failed to start engine")
    }
  }
}
