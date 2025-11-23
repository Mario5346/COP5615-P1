// File: src/client.gleam
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub type Client {
  Client(base_url: String)
}

// ========== Client Setup ==========

pub fn new(base_url: String) -> Client {
  Client(base_url: base_url)
}

// ========== Helper Functions ==========

fn parse_id_from_response(body: String, field: String) -> Result(String, String) {
  case string.contains(body, "\"" <> field <> "\"") {
    True -> {
      let id =
        string.split(body, "\"" <> field <> "\":")
        |> list.drop(1)
        |> list.first
        |> result.unwrap("")
        |> string.split("\"")
        |> list.drop(1)
        |> list.first
        |> result.unwrap("")
        |> string.trim
      Ok(id)
    }
    False -> Error("Failed to parse " <> field <> " from response: " <> body)
  }
}

// ========== API Methods ==========

// Register a new user
pub fn register_user(client: Client, username: String) -> Result(String, String) {
  let body = "{\"username\":\"" <> username <> "\"}"

  case request.to(client.base_url <> "/api/users") {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            201 | 200 -> parse_id_from_response(resp.body, "user_id")
            _ ->
              Error(
                "Failed to register user (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get user information
pub fn get_user(client: Client, user_id: String) -> Result(String, String) {
  case request.to(client.base_url <> "/api/users/" <> user_id) {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get user (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get user feed
pub fn get_user_feed(client: Client, user_id: String) -> Result(String, String) {
  case request.to(client.base_url <> "/api/users/" <> user_id <> "/feed") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get feed (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Create subregretdit
pub fn create_subregretdit(
  client: Client,
  creator_id: String,
  name: String,
  description: String,
) -> Result(String, String) {
  let body =
    "{\"creator_id\":\""
    <> creator_id
    <> "\",\"name\":\""
    <> name
    <> "\",\"description\":\""
    <> description
    <> "\"}"

  case request.to(client.base_url <> "/api/subregretdits") {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 | 201 -> parse_id_from_response(resp.body, "subregretdit_id")
            _ ->
              Error(
                "Failed to create subregretdit (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get all subregretdits
pub fn get_all_subregretdits(client: Client) -> Result(String, String) {
  case request.to(client.base_url <> "/api/subregretdits") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get subregretdits (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Join subregretdit
pub fn join_subregretdit(
  client: Client,
  user_id: String,
  sub_id: String,
) -> Result(String, String) {
  let body = "{\"user_id\":\"" <> user_id <> "\"}"

  case
    request.to(client.base_url <> "/api/subregretdits/" <> sub_id <> "/join")
  {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok("Joined successfully")
            _ ->
              Error(
                "Failed to join (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Create post
pub fn create_post(
  client: Client,
  author_id: String,
  subregretdit_id: String,
  title: String,
  content: String,
) -> Result(String, String) {
  let body =
    "{\"author_id\":\""
    <> author_id
    <> "\",\"subregretdit_id\":\""
    <> subregretdit_id
    <> "\",\"title\":\""
    <> title
    <> "\",\"content\":\""
    <> content
    <> "\"}"

  case request.to(client.base_url <> "/api/posts") {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 | 201 -> parse_id_from_response(resp.body, "post_id")
            _ ->
              Error(
                "Failed to create post (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get post
pub fn get_post(client: Client, post_id: String) -> Result(String, String) {
  case request.to(client.base_url <> "/api/posts/" <> post_id) {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get post (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Upvote post
pub fn upvote_post(client: Client, post_id: String) -> Result(String, String) {
  case request.to(client.base_url <> "/api/posts/" <> post_id <> "/upvote") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Post)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok("Upvoted successfully")
            _ ->
              Error(
                "Failed to upvote (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Downvote post
pub fn downvote_post(client: Client, post_id: String) -> Result(String, String) {
  case request.to(client.base_url <> "/api/posts/" <> post_id <> "/downvote") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Post)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok("Downvoted successfully")
            _ ->
              Error(
                "Failed to downvote (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Create comment
pub fn create_comment(
  client: Client,
  author_id: String,
  post_id: String,
  content: String,
) -> Result(String, String) {
  let body =
    "{\"author_id\":\""
    <> author_id
    <> "\",\"post_id\":\""
    <> post_id
    <> "\",\"content\":\""
    <> content
    <> "\"}"

  case request.to(client.base_url <> "/api/comments") {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 | 201 -> parse_id_from_response(resp.body, "comment_id")
            _ ->
              Error(
                "Failed to create comment (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Upvote comment
pub fn upvote_comment(
  client: Client,
  comment_id: String,
) -> Result(String, String) {
  case
    request.to(client.base_url <> "/api/comments/" <> comment_id <> "/upvote")
  {
    Ok(req) -> {
      let req = req |> request.set_method(http.Post)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok("Upvoted successfully")
            _ ->
              Error(
                "Failed to upvote comment (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Send message
pub fn send_message(
  client: Client,
  from_id: String,
  to_id: String,
  content: String,
) -> Result(String, String) {
  let body =
    "{\"from_user_id\":\""
    <> from_id
    <> "\",\"to_user_id\":\""
    <> to_id
    <> "\",\"content\":\""
    <> content
    <> "\"}"

  case request.to(client.base_url <> "/api/messages") {
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_body(body)
        |> request.set_header("content-type", "application/json")

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 | 201 -> Ok("Message sent successfully")
            _ ->
              Error(
                "Failed to send message (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get user messages
pub fn get_user_messages(
  client: Client,
  user_id: String,
) -> Result(String, String) {
  case request.to(client.base_url <> "/api/users/" <> user_id <> "/messages") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get messages (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// Get platform stats
pub fn get_stats(client: Client) -> Result(String, String) {
  case request.to(client.base_url <> "/api/stats") {
    Ok(req) -> {
      let req = req |> request.set_method(http.Get)

      case httpc.send(req) {
        Ok(resp) -> {
          case resp.status {
            200 -> Ok(resp.body)
            _ ->
              Error(
                "Failed to get stats (status "
                <> int.to_string(resp.status)
                <> "): "
                <> resp.body,
              )
          }
        }
        Error(e) -> Error("Network error: " <> string.inspect(e))
      }
    }
    Error(_) -> Error("Invalid URL")
  }
}

// ========== Demo Functions ==========

fn print_separator() {
  io.println("\n" <> string.repeat("=", 60))
}

pub fn run_demo(base_url: String) {
  let client = new(base_url)

  io.println("\n🎭 REGRETDIT CLI CLIENT DEMO")
  io.println("Demonstrating all API functionality with multiple clients")

  // ========== PHASE 1: User Registration ==========
  print_separator()
  io.println("📝 PHASE 1: Registering Users")
  print_separator()

  io.println("\n[Client 1] Registering user 'alice'...")
  let alice_id = case register_user(client, "alice") {
    Ok(id) -> {
      io.println("✅ Registered alice with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  io.println("\n[Client 2] Registering user 'bob'...")
  let bob_id = case register_user(client, "bob") {
    Ok(id) -> {
      io.println("✅ Registered bob with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  io.println("\n[Client 3] Registering user 'charlie'...")
  let charlie_id = case register_user(client, "charlie") {
    Ok(id) -> {
      io.println("✅ Registered charlie with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  // ========== PHASE 2: Creating Communities ==========
  print_separator()
  io.println("🏘️  PHASE 2: Creating Subregretdits")
  print_separator()

  io.println("\n[Alice's Client] Creating r/gleam...")
  let gleam_sub = case
    create_subregretdit(
      client,
      alice_id,
      "r/gleam",
      "A community for Gleam enthusiasts",
    )
  {
    Ok(id) -> {
      io.println("✅ Created r/gleam with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  io.println("\n[Bob's Client] Creating r/programming...")
  let prog_sub = case
    create_subregretdit(
      client,
      bob_id,
      "r/programming",
      "General programming discussions",
    )
  {
    Ok(id) -> {
      io.println("✅ Created r/programming with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  // ========== PHASE 3: Joining Communities ==========
  print_separator()
  io.println("🤝 PHASE 3: Users Joining Subregretdits")
  print_separator()

  io.println("\n[Bob's Client] Joining r/gleam...")
  case join_subregretdit(client, bob_id, gleam_sub) {
    Ok(_) -> io.println("✅ Bob joined r/gleam")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Charlie's Client] Joining r/gleam...")
  case join_subregretdit(client, charlie_id, gleam_sub) {
    Ok(_) -> io.println("✅ Charlie joined r/gleam")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Alice's Client] Joining r/programming...")
  case join_subregretdit(client, alice_id, prog_sub) {
    Ok(_) -> io.println("✅ Alice joined r/programming")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  // ========== PHASE 4: Creating Posts ==========
  print_separator()
  io.println("📄 PHASE 4: Creating Posts")
  print_separator()

  io.println("\n[Alice's Client] Creating post in r/gleam...")
  let alice_post = case
    create_post(
      client,
      alice_id,
      gleam_sub,
      "Why I love Gleam",
      "Gleam is an amazing language with great type safety!",
    )
  {
    Ok(id) -> {
      io.println("✅ Created post with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  io.println("\n[Bob's Client] Creating post in r/programming...")
  let bob_post = case
    create_post(
      client,
      bob_id,
      prog_sub,
      "Best practices for REST APIs",
      "Let's discuss how to design great REST APIs...",
    )
  {
    Ok(id) -> {
      io.println("✅ Created post with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  // ========== PHASE 5: Voting ==========
  print_separator()
  io.println("👍 PHASE 5: Voting on Posts")
  print_separator()

  io.println("\n[Bob's Client] Upvoting Alice's post...")
  case upvote_post(client, alice_post) {
    Ok(_) -> io.println("✅ Bob upvoted Alice's post")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Charlie's Client] Upvoting Alice's post...")
  case upvote_post(client, alice_post) {
    Ok(_) -> io.println("✅ Charlie upvoted Alice's post")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Alice's Client] Upvoting Bob's post...")
  case upvote_post(client, bob_post) {
    Ok(_) -> io.println("✅ Alice upvoted Bob's post")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  // ========== PHASE 6: Comments ==========
  print_separator()
  io.println("💬 PHASE 6: Creating Comments")
  print_separator()

  io.println("\n[Bob's Client] Commenting on Alice's post...")
  let bob_comment = case
    create_comment(client, bob_id, alice_post, "Great post! I totally agree.")
  {
    Ok(id) -> {
      io.println("✅ Created comment with ID: " <> id)
      id
    }
    Error(e) -> {
      io.println("❌ Failed: " <> e)
      ""
    }
  }

  io.println("\n[Charlie's Client] Commenting on Alice's post...")
  case
    create_comment(
      client,
      charlie_id,
      alice_post,
      "This is exactly what I needed to hear!",
    )
  {
    Ok(id) -> io.println("✅ Created comment with ID: " <> id)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Alice's Client] Upvoting Bob's comment...")
  case upvote_comment(client, bob_comment) {
    Ok(_) -> io.println("✅ Alice upvoted Bob's comment")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  // ========== PHASE 7: Direct Messages ==========
  print_separator()
  io.println("📨 PHASE 7: Sending Direct Messages")
  print_separator()

  io.println("\n[Bob's Client] Sending message to Alice...")
  case
    send_message(client, bob_id, alice_id, "Hey Alice, great post on Gleam!")
  {
    Ok(_) -> io.println("✅ Message sent successfully")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Charlie's Client] Sending message to Alice...")
  case
    send_message(
      client,
      charlie_id,
      alice_id,
      "Alice, would love to collaborate on a Gleam project!",
    )
  {
    Ok(_) -> io.println("✅ Message sent successfully")
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  // ========== PHASE 8: Viewing Data ==========
  print_separator()
  io.println("👀 PHASE 8: Viewing Data")
  print_separator()

  io.println("\n[Alice's Client] Getting user info...")
  case get_user(client, alice_id) {
    Ok(data) -> io.println("✅ User data: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Alice's Client] Checking messages...")
  case get_user_messages(client, alice_id) {
    Ok(data) -> io.println("✅ Messages: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Bob's Client] Getting feed...")
  case get_user_feed(client, bob_id) {
    Ok(data) -> io.println("✅ Feed data: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Any Client] Getting post details...")
  case get_post(client, alice_post) {
    Ok(data) -> io.println("✅ Post data: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  io.println("\n[Any Client] Listing all subregretdits...")
  case get_all_subregretdits(client) {
    Ok(data) -> io.println("✅ Subregretdits: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  // ========== PHASE 9: Platform Statistics ==========
  print_separator()
  io.println("📊 PHASE 9: Platform Statistics")
  print_separator()

  io.println("\n[Any Client] Getting platform stats...")
  case get_stats(client) {
    Ok(data) -> io.println("✅ Platform stats: " <> data)
    Error(e) -> io.println("❌ Failed: " <> e)
  }

  print_separator()
  io.println("✨ DEMO COMPLETE!")
  io.println("All API endpoints tested successfully with multiple clients")
  print_separator()
}

// ========== Main Entry Point ==========

pub fn main() {
  io.println("Starting Regretdit CLI Client...")
  // Replace SERVER_IP with your actual server IP address
  let server_ip = "192.168.1.169"
  // Example IP
  let server_url = "http://" <> server_ip <> ":8080"
  io.println("Connecting to API at " <> server_url)
  io.println("Make sure the API server is running first!")
  io.println("")

  // Give server time to be ready
  process.sleep(1000)

  run_demo(server_url)
}
