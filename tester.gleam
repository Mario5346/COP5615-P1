import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/string
import sample

// Import the reddit engine module (assuming it's in a separate file)
// For this example, we'll assume the types and functions are available

// ========== Message Types for Actor Communication ==========

pub type EngineMessage {
  // User operations
  RegisterUser(username: String, reply_to: Subject(EngineResponse))

  // Subreddit operations
  CreateSubreddit(
    creator_id: String,
    name: String,
    description: String,
    reply_to: Subject(EngineResponse),
  )
  JoinSubreddit(
    user_id: String,
    subreddit_id: String,
    reply_to: Subject(EngineResponse),
  )
  LeaveSubreddit(
    user_id: String,
    subreddit_id: String,
    reply_to: Subject(EngineResponse),
  )

  // Post operations
  CreatePost(
    author_id: String,
    subreddit_id: String,
    title: String,
    content: String,
    timestamp: Int,
    reply_to: Subject(EngineResponse),
  )

  // Comment operations
  CreateComment(
    author_id: String,
    post_id: String,
    parent_comment_id: Option(String),
    content: String,
    timestamp: Int,
    reply_to: Subject(EngineResponse),
  )

  // Voting operations
  UpvotePost(post_id: String, reply_to: Subject(EngineResponse))
  DownvotePost(post_id: String, reply_to: Subject(EngineResponse))
  UpvoteComment(comment_id: String, reply_to: Subject(EngineResponse))
  DownvoteComment(comment_id: String, reply_to: Subject(EngineResponse))

  // Feed operations
  GetUserFeed(user_id: String, reply_to: Subject(EngineResponse))

  // Message operations
  SendMessage(
    from_user_id: String,
    to_user_id: String,
    content: String,
    timestamp: Int,
    reply_to: Subject(EngineResponse),
  )
  GetUserMessages(user_id: String, reply_to: Subject(EngineResponse))

  // Stats
  GetStats(reply_to: Subject(EngineResponse))

  // Shutdown
  Shutdown
}

pub type EngineResponse {
  UserRegistered(user_id: String)
  SubredditCreated(subreddit_id: String)
  PostCreated(post_id: String)
  CommentCreated(comment_id: String)
  MessageSent(message_id: String)
  FeedRetrieved(posts: List(String))
  MessagesRetrieved(messages: List(String))
  OperationSuccess
  OperationFailed(error: String)
  Stats(users: Int, subreddits: Int, posts: Int, comments: Int, messages: Int)
}

pub type ClientMessage {
  StartSimulation
  StopSimulation
  GetClientStats(reply_to: Subject(ClientStats))
}

pub type ClientStats {
  ClientStats(
    client_id: Int,
    user_id: String,
    posts_created: Int,
    comments_created: Int,
    messages_sent: Int,
    is_online: Bool,
  )
}

// ========== Zipf Distribution ==========

pub type ZipfConfig {
  ZipfConfig(n: Int, s: Float, precalc_sum: Float)
}

pub fn create_zipf_config(n: Int, s: Float) -> ZipfConfig {
  let sum =
    list.range(1, n)
    |> list.fold(0.0, fn(acc, k) {
      acc +. 1.0 /. int_pow_float(int.to_float(k), s)
    })
  ZipfConfig(n: n, s: s, precalc_sum: sum)
}

fn int_pow_float(base: Float, exp: Float) -> Float {
  // Simple power function for positive integers
  case exp {
    e if e <=. 0.0 -> 1.0
    _ -> {
      let iterations = float.truncate(exp)
      list.range(1, iterations)
      |> list.fold(1.0, fn(acc, _) { acc *. base })
    }
  }
}

pub fn zipf_rank_to_value(config: ZipfConfig, rank: Int) -> Float {
  case rank >= 1 && rank <= config.n {
    True -> {
      let numerator = 1.0 /. int_pow_float(int.to_float(rank), config.s)
      numerator /. config.precalc_sum
    }
    False -> 0.0
  }
}

// ========== Simple Random Number Generator ==========

pub type RNG {
  RNG(seed: Int)
}

pub fn new_rng(seed: Int) -> RNG {
  RNG(seed: seed)
}

pub fn next_int(rng: RNG, max: Int) -> #(Int, RNG) {
  // Linear congruential generator
  let a = 1_103_515_245
  let c = 12_345
  let m = 2_147_483_647
  let new_seed = { a * rng.seed + c } % m
  let value = new_seed % max
  #(int.absolute_value(value), RNG(seed: new_seed))
}

pub fn next_float(rng: RNG) -> #(Float, RNG) {
  let #(val, new_rng) = next_int(rng, 1_000_000)
  #(int.to_float(val) /. 1_000_000.0, new_rng)
}

pub fn next_bool(rng: RNG, probability: Float) -> #(Bool, RNG) {
  let #(val, new_rng) = next_float(rng)
  #(val <. probability, new_rng)
}

// ========== Content Generation ==========

pub fn generate_username(id: Int) -> String {
  let prefixes = [
    "Cool", "Super", "Mega", "Ultra", "Pro", "Epic", "Awesome", "Great", "Happy",
    "Lucky", "Swift", "Brave", "Wise", "Bold", "Noble",
  ]
  let suffixes = [
    "User", "Redditor", "Poster", "Commenter", "Lurker", "Fan", "Master", "King",
    "Queen", "Lord", "Knight", "Wizard", "Ninja", "Warrior",
  ]

  let prefix_idx = id % list.length(prefixes)
  let suffix_idx = { id / list.length(prefixes) } % list.length(suffixes)

  let prefix = case list.at(prefixes, prefix_idx) {
    Ok(p) -> p
    Error(_) -> "User"
  }
  let suffix = case list.at(suffixes, suffix_idx) {
    Ok(s) -> s
    Error(_) -> "Name"
  }

  prefix <> suffix <> int.to_string(id)
}

pub fn generate_subreddit_name(id: Int) -> String {
  let topics = [
    "Programming", "Gaming", "Movies", "Music", "Sports", "Technology",
    "Science", "Art", "Photography", "Cooking", "Fitness", "Travel", "Books",
    "Fashion", "Pets", "Cars", "DIY", "News", "Politics", "Memes",
  ]

  let idx = id % list.length(topics)
  let topic = case list.at(topics, idx) {
    Ok(t) -> t
    Error(_) -> "General"
  }

  "r/" <> topic <> int.to_string(id)
}

pub fn generate_post_title(rng: RNG, is_repost: Bool) -> #(String, RNG) {
  let templates = [
    "TIL about an interesting fact",
    "Check out this cool thing I found",
    "Discussion: What do you think about this?",
    "I just realized something amazing",
    "Can we talk about this topic?",
    "This is actually pretty interesting",
    "Unpopular opinion: here's my take",
    "Does anyone else feel this way?",
    "Just discovered this and had to share",
    "This needs more attention",
  ]

  let #(idx, new_rng) = next_int(rng, list.length(templates))
  let template = case list.at(templates, idx) {
    Ok(t) -> t
    Error(_) -> "Interesting post"
  }

  let title = case is_repost {
    True -> "[REPOST] " <> template
    False -> template
  }

  #(title, new_rng)
}

pub fn generate_post_content(rng: RNG) -> #(String, RNG) {
  let contents = [
    "This is a really interesting topic that deserves more discussion. What are your thoughts?",
    "I've been thinking about this for a while and wanted to share my perspective.",
    "Here's something I discovered recently that blew my mind.",
    "Can someone explain this to me? I'm genuinely curious.",
    "This is an important issue that we should all be aware of.",
    "Just wanted to share this with the community. Hope you find it useful!",
    "After years of experience, here's what I've learned about this.",
    "This might be controversial, but I think it's worth discussing.",
  ]

  let #(idx, new_rng) = next_int(rng, list.length(contents))
  let content = case list.at(contents, idx) {
    Ok(c) -> c
    Error(_) -> "Interesting content here."
  }

  #(content, new_rng)
}

pub fn generate_comment_content(rng: RNG) -> #(String, RNG) {
  let comments = [
    "Great point! I totally agree with this.",
    "This is actually not quite right. Let me explain...",
    "Thanks for sharing! This is really helpful.",
    "I have a different perspective on this topic.",
    "Can you elaborate on this? I'm interested to know more.",
    "This made me laugh, thanks for posting!",
    "I've had a similar experience and can relate.",
    "This is exactly what I needed to hear today.",
    "Interesting take, but I'm not sure I agree.",
    "Thanks for the detailed explanation!",
  ]

  let #(idx, new_rng) = next_int(rng, list.length(comments))
  let comment = case list.at(comments, idx) {
    Ok(c) -> c
    Error(_) -> "Interesting comment."
  }

  #(comment, new_rng)
}

// ========== Engine Actor State ==========

pub type EngineState {
  EngineState(engine: RedditEngine, total_requests: Int, start_time: Int)
}

pub type RedditEngine {
  RedditEngine(
    users: Dict(String, User),
    subreddits: Dict(String, Subreddit),
    posts: Dict(String, Post),
    comments: Dict(String, Comment),
    messages: Dict(String, DirectMessage),
    next_id: Int,
  )
}

pub type User {
  User(
    id: String,
    username: String,
    karma: Int,
    joined_subreddits: List(String),
  )
}

pub type Subreddit {
  Subreddit(
    id: String,
    name: String,
    description: String,
    members: List(String),
    posts: List(String),
  )
}

pub type Post {
  Post(
    id: String,
    author_id: String,
    subreddit_id: String,
    title: String,
    content: String,
    upvotes: Int,
    downvotes: Int,
    comments: List(String),
    timestamp: Int,
  )
}

pub type Comment {
  Comment(
    id: String,
    author_id: String,
    post_id: String,
    parent_comment_id: Option(String),
    content: String,
    upvotes: Int,
    downvotes: Int,
    replies: List(String),
    timestamp: Int,
  )
}

pub type DirectMessage {
  DirectMessage(
    id: String,
    from_user_id: String,
    to_user_id: String,
    content: String,
    timestamp: Int,
    is_read: Bool,
  )
}

fn new_engine() -> RedditEngine {
  RedditEngine(
    users: dict.new(),
    subreddits: dict.new(),
    posts: dict.new(),
    comments: dict.new(),
    messages: dict.new(),
    next_id: 1,
  )
}

fn generate_id(engine: RedditEngine, prefix: String) -> #(String, RedditEngine) {
  let id = prefix <> int.to_string(engine.next_id)
  let new_engine = RedditEngine(..engine, next_id: engine.next_id + 1)
  #(id, new_engine)
}

// ========== Engine Actor Implementation ==========

pub fn engine_actor_loop(
  message: EngineMessage,
  state: EngineState,
) -> actor.Next(EngineMessage, EngineState) {
  case message {
    RegisterUser(username, reply_to) -> {
      let #(user_id, new_engine) = generate_id(state.engine, "user_")
      let user =
        User(id: user_id, username: username, karma: 0, joined_subreddits: [])
      let updated_users = dict.insert(new_engine.users, user_id, user)
      let final_engine = RedditEngine(..new_engine, users: updated_users)

      process.send(reply_to, UserRegistered(user_id))
      actor.continue(
        EngineState(
          ..state,
          engine: final_engine,
          total_requests: state.total_requests + 1,
        ),
      )
    }

    CreateSubreddit(creator_id, name, description, reply_to) -> {
      case dict.get(state.engine.users, creator_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("User not found"))
          actor.continue(state)
        }
        Ok(user) -> {
          let #(sub_id, new_engine) = generate_id(state.engine, "sub_")
          let subreddit =
            Subreddit(
              id: sub_id,
              name: name,
              description: description,
              members: [creator_id],
              posts: [],
            )
          let updated_subreddits =
            dict.insert(new_engine.subreddits, sub_id, subreddit)
          let updated_user =
            User(..user, joined_subreddits: [sub_id, ..user.joined_subreddits])
          let updated_users =
            dict.insert(new_engine.users, creator_id, updated_user)
          let final_engine =
            RedditEngine(
              ..new_engine,
              subreddits: updated_subreddits,
              users: updated_users,
            )

          process.send(reply_to, SubredditCreated(sub_id))
          actor.continue(
            EngineState(
              ..state,
              engine: final_engine,
              total_requests: state.total_requests + 1,
            ),
          )
        }
      }
    }

    JoinSubreddit(user_id, subreddit_id, reply_to) -> {
      case dict.get(state.engine.users, user_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("User not found"))
          actor.continue(state)
        }
        Ok(user) ->
          case dict.get(state.engine.subreddits, subreddit_id) {
            Error(_) -> {
              process.send(reply_to, OperationFailed("Subreddit not found"))
              actor.continue(state)
            }
            Ok(subreddit) -> {
              let already_member = list.contains(subreddit.members, user_id)
              case already_member {
                True -> {
                  process.send(reply_to, OperationFailed("Already a member"))
                  actor.continue(state)
                }
                False -> {
                  let updated_subreddit =
                    Subreddit(..subreddit, members: [
                      user_id,
                      ..subreddit.members
                    ])
                  let updated_subreddits =
                    dict.insert(
                      state.engine.subreddits,
                      subreddit_id,
                      updated_subreddit,
                    )
                  let updated_user =
                    User(..user, joined_subreddits: [
                      subreddit_id,
                      ..user.joined_subreddits
                    ])
                  let updated_users =
                    dict.insert(state.engine.users, user_id, updated_user)
                  let final_engine =
                    RedditEngine(
                      ..state.engine,
                      subreddits: updated_subreddits,
                      users: updated_users,
                    )

                  process.send(reply_to, OperationSuccess)
                  actor.continue(
                    EngineState(
                      ..state,
                      engine: final_engine,
                      total_requests: state.total_requests + 1,
                    ),
                  )
                }
              }
            }
          }
      }
    }

    CreatePost(author_id, subreddit_id, title, content, timestamp, reply_to) -> {
      case dict.get(state.engine.subreddits, subreddit_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("Subreddit not found"))
          actor.continue(state)
        }
        Ok(subreddit) -> {
          let is_member = list.contains(subreddit.members, author_id)
          case is_member {
            False -> {
              process.send(reply_to, OperationFailed("Not a member"))
              actor.continue(state)
            }
            True -> {
              let #(post_id, new_engine) = generate_id(state.engine, "post_")
              let post =
                Post(
                  id: post_id,
                  author_id: author_id,
                  subreddit_id: subreddit_id,
                  title: title,
                  content: content,
                  upvotes: 0,
                  downvotes: 0,
                  comments: [],
                  timestamp: timestamp,
                )
              let updated_posts = dict.insert(new_engine.posts, post_id, post)
              let updated_subreddit =
                Subreddit(..subreddit, posts: [post_id, ..subreddit.posts])
              let updated_subreddits =
                dict.insert(
                  new_engine.subreddits,
                  subreddit_id,
                  updated_subreddit,
                )
              let final_engine =
                RedditEngine(
                  ..new_engine,
                  posts: updated_posts,
                  subreddits: updated_subreddits,
                )

              process.send(reply_to, PostCreated(post_id))
              actor.continue(
                EngineState(
                  ..state,
                  engine: final_engine,
                  total_requests: state.total_requests + 1,
                ),
              )
            }
          }
        }
      }
    }

    CreateComment(
      author_id,
      post_id,
      parent_comment_id,
      content,
      timestamp,
      reply_to,
    ) -> {
      case dict.get(state.engine.posts, post_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("Post not found"))
          actor.continue(state)
        }
        Ok(post) -> {
          let #(comment_id, new_engine) = generate_id(state.engine, "comment_")
          let comment =
            Comment(
              id: comment_id,
              author_id: author_id,
              post_id: post_id,
              parent_comment_id: parent_comment_id,
              content: content,
              upvotes: 0,
              downvotes: 0,
              replies: [],
              timestamp: timestamp,
            )
          let updated_comments =
            dict.insert(new_engine.comments, comment_id, comment)
          let updated_post =
            Post(..post, comments: [comment_id, ..post.comments])
          let updated_posts =
            dict.insert(new_engine.posts, post_id, updated_post)

          let final_comments = case parent_comment_id {
            None -> updated_comments
            Some(parent_id) ->
              case dict.get(updated_comments, parent_id) {
                Ok(parent_comment) -> {
                  let updated_parent =
                    Comment(..parent_comment, replies: [
                      comment_id,
                      ..parent_comment.replies
                    ])
                  dict.insert(updated_comments, parent_id, updated_parent)
                }
                Error(_) -> updated_comments
              }
          }

          let final_engine =
            RedditEngine(
              ..new_engine,
              comments: final_comments,
              posts: updated_posts,
            )

          process.send(reply_to, CommentCreated(comment_id))
          actor.continue(
            EngineState(
              ..state,
              engine: final_engine,
              total_requests: state.total_requests + 1,
            ),
          )
        }
      }
    }

    UpvotePost(post_id, reply_to) -> {
      case dict.get(state.engine.posts, post_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("Post not found"))
          actor.continue(state)
        }
        Ok(post) -> {
          let updated_post = Post(..post, upvotes: post.upvotes + 1)
          let updated_posts =
            dict.insert(state.engine.posts, post_id, updated_post)

          let final_engine = case dict.get(state.engine.users, post.author_id) {
            Ok(author) -> {
              let updated_author = User(..author, karma: author.karma + 1)
              let updated_users =
                dict.insert(state.engine.users, post.author_id, updated_author)
              RedditEngine(
                ..state.engine,
                posts: updated_posts,
                users: updated_users,
              )
            }
            Error(_) -> RedditEngine(..state.engine, posts: updated_posts)
          }

          process.send(reply_to, OperationSuccess)
          actor.continue(
            EngineState(
              ..state,
              engine: final_engine,
              total_requests: state.total_requests + 1,
            ),
          )
        }
      }
    }

    GetUserFeed(user_id, reply_to) -> {
      case dict.get(state.engine.users, user_id) {
        Error(_) -> {
          process.send(reply_to, OperationFailed("User not found"))
          actor.continue(state)
        }
        Ok(user) -> {
          let post_ids =
            list.flat_map(user.joined_subreddits, fn(sub_id) {
              case dict.get(state.engine.subreddits, sub_id) {
                Ok(sub) -> sub.posts
                Error(_) -> []
              }
            })

          process.send(reply_to, FeedRetrieved(post_ids))
          actor.continue(
            EngineState(..state, total_requests: state.total_requests + 1),
          )
        }
      }
    }

    GetStats(reply_to) -> {
      let stats =
        Stats(
          users: dict.size(state.engine.users),
          subreddits: dict.size(state.engine.subreddits),
          posts: dict.size(state.engine.posts),
          comments: dict.size(state.engine.comments),
          messages: dict.size(state.engine.messages),
        )
      process.send(reply_to, stats)
      actor.continue(state)
    }

    SendMessage(from_user_id, to_user_id, content, timestamp, reply_to) -> {
      let #(msg_id, new_engine) = generate_id(state.engine, "msg_")
      let message =
        DirectMessage(
          id: msg_id,
          from_user_id: from_user_id,
          to_user_id: to_user_id,
          content: content,
          timestamp: timestamp,
          is_read: False,
        )
      let updated_messages = dict.insert(new_engine.messages, msg_id, message)
      let final_engine = RedditEngine(..new_engine, messages: updated_messages)

      process.send(reply_to, MessageSent(msg_id))
      actor.continue(
        EngineState(
          ..state,
          engine: final_engine,
          total_requests: state.total_requests + 1,
        ),
      )
    }

    GetUserMessages(user_id, reply_to) -> {
      let message_ids =
        dict.values(state.engine.messages)
        |> list.filter(fn(msg) { msg.to_user_id == user_id })
        |> list.map(fn(msg) { msg.id })

      process.send(reply_to, MessagesRetrieved(message_ids))
      actor.continue(
        EngineState(..state, total_requests: state.total_requests + 1),
      )
    }

    _ -> actor.continue(state)
  }
}

// ========== Client Actor State ==========

pub type ClientState {
  ClientState(
    client_id: Int,
    engine: Subject(EngineMessage),
    user_id: Option(String),
    joined_subreddits: List(String),
    my_posts: List(String),
    rng: RNG,
    is_online: Bool,
    posts_created: Int,
    comments_created: Int,
    messages_sent: Int,
    timestamp: Int,
  )
}

pub fn client_actor_loop(
  message: ClientMessage,
  state: ClientState,
) -> actor.Next(ClientMessage, ClientState) {
  case message {
    StartSimulation -> {
      // Simulate one action cycle
      let new_state = simulate_user_action(state)
      actor.continue(new_state)
    }

    GetClientStats(reply_to) -> {
      let user_id = case state.user_id {
        Some(id) -> id
        None -> "none"
      }
      let stats =
        ClientStats(
          client_id: state.client_id,
          user_id: user_id,
          posts_created: state.posts_created,
          comments_created: state.comments_created,
          messages_sent: state.messages_sent,
          is_online: state.is_online,
        )
      process.send(reply_to, stats)
      actor.continue(state)
    }

    StopSimulation -> actor.Stop(process.Normal)
  }
}

fn simulate_user_action(state: ClientState) -> ClientState {
  let new_timestamp = state.timestamp + 1

  // Random chance to toggle online/offline (10% chance)
  let #(should_toggle, rng1) = next_bool(state.rng, 0.1)
  let is_online = case should_toggle {
    True -> !state.is_online
    False -> state.is_online
  }

  // If offline, just update timestamp
  case is_online {
    False ->
      ClientState(
        ..state,
        rng: rng1,
        is_online: is_online,
        timestamp: new_timestamp,
      )
    True -> {
      // Decide what action to take
      let #(action_roll, rng2) = next_float(rng1)

      case action_roll {
        r if r <. 0.3 -> create_post_action(state, rng2, new_timestamp)
        r if r <. 0.6 -> create_comment_action(state, rng2, new_timestamp)
        r if r <. 0.8 -> vote_action(state, rng2, new_timestamp)
        _ -> check_feed_action(state, rng2, new_timestamp)
      }
    }
  }
}

fn create_post_action(
  state: ClientState,
  rng: RNG,
  timestamp: Int,
) -> ClientState {
  case state.user_id, list.length(state.joined_subreddits) > 0 {
    Some(user_id), True -> {
      let #(sub_idx, rng1) = next_int(rng, list.length(state.joined_subreddits))
      case list.at(state.joined_subreddits, sub_idx) {
        Ok(subreddit_id) -> {
          let #(is_repost, rng2) = next_bool(rng1, 0.15)
          let #(title, rng3) = generate_post_title(rng2, is_repost)
          let #(content, rng4) = generate_post_content(rng3)

          let response_subject = process.new_subject()
          process.send(
            state.engine,
            CreatePost(
              user_id,
              subreddit_id,
              title,
              content,
              timestamp,
              response_subject,
            ),
          )

          ClientState(
            ..state,
            rng: rng4,
            posts_created: state.posts_created + 1,
            timestamp: timestamp,
          )
        }
        Error(_) -> ClientState(..state, rng: rng, timestamp: timestamp)
      }
    }
    _, _ -> ClientState(..state, rng: rng, timestamp: timestamp)
  }
}

fn create_comment_action(
  state: ClientState,
  rng: RNG,
  timestamp: Int,
) -> ClientState {
  case state.user_id, list.length(state.my_posts) > 0 {
    Some(user_id), True -> {
      let #(post_idx, rng1) = next_int(rng, list.length(state.my_posts))
      case list.at(state.my_posts, post_idx) {
        Ok(post_id) -> {
          let #(comment_text, rng2) = generate_comment_content(rng1)

          let response_subject = process.new_subject()
          process.send(
            state.engine,
            CreateComment(
              user_id,
              post_id,
              None,
              comment_text,
              timestamp,
              response_subject,
            ),
          )

          ClientState(
            ..state,
            rng: rng2,
            comments_created: state.comments_created + 1,
            timestamp: timestamp,
          )
        }
        Error(_) -> ClientState(..state, rng: rng, timestamp: timestamp)
      }
    }
    _, _ -> ClientState(..state, rng: rng, timestamp: timestamp)
  }
}

fn vote_action(state: ClientState, rng: RNG, timestamp: Int) -> ClientState {
  case list.length(state.my_posts) > 0 {
    True -> {
      let #(post_idx, rng1) = next_int(rng, list.length(state.my_posts))
      case list.at(state.my_posts, post_idx) {
        Ok(post_id) -> {
          let #(upvote, rng2) = next_bool(rng1, 0.7)
          let response_subject = process.new_subject()

          case upvote {
            True ->
              process.send(state.engine, UpvotePost(post_id, response_subject))
            False ->
              process.send(
                state.engine,
                DownvotePost(post_id, response_subject),
              )
          }

          ClientState(..state, rng: rng2, timestamp: timestamp)
        }
        Error(_) -> ClientState(..state, rng: rng, timestamp: timestamp)
      }
    }
    False -> ClientState(..state, rng: rng, timestamp: timestamp)
  }
}

fn check_feed_action(
  state: ClientState,
  rng: RNG,
  timestamp: Int,
) -> ClientState {
  case state.user_id {
    Some(user_id) -> {
      let response_subject = process.new_subject()
      process.send(state.engine, GetUserFeed(user_id, response_subject))

      ClientState(..state, rng: rng, timestamp: timestamp)
    }
    None -> ClientState(..state, rng: rng, timestamp: timestamp)
  }
}

// ========== Simulation Orchestrator ==========

pub type SimulationConfig {
  SimulationConfig(
    num_clients: Int,
    num_subreddits: Int,
    simulation_steps: Int,
    zipf_s: Float,
  )
}

pub fn run_simulation(config: SimulationConfig) -> Nil {
  io.println("=== Starting Reddit Engine Simulation ===")
  io.println(
    "Clients: "
    <> int.to_string(config.num_clients)
    <> ", Subreddits: "
    <> int.to_string(config.num_subreddits),
  )
  io.println("Zipf parameter s: " <> float.to_string(config.zipf_s))
  io.println("")

  // Start engine actor
  io.println("Starting engine actor...")
  let assert Ok(engine_subject) =
    actor.start(
      EngineState(engine: new_engine(), total_requests: 0, start_time: 0),
      engine_actor_loop,
    )

  io.println("Engine started!")
  io.println("")

  // Create Zipf distribution for subreddit popularity
  let zipf_config = create_zipf_config(config.num_subreddits, config.zipf_s)

  // Phase 1: Register users
  io.println(
    "Phase 1: Registering " <> int.to_string(config.num_clients) <> " users...",
  )
  let user_ids =
    list.range(1, config.num_clients)
    |> list.map(fn(i) {
      let username = generate_username(i)
      let response_subject = process.new_subject()
      process.send(engine_subject, RegisterUser(username, response_subject))

      case process.receive(response_subject, 1000) {
        Ok(UserRegistered(user_id)) -> Some(user_id)
        _ -> None
      }
    })
    |> list.filter_map(fn(opt) {
      case opt {
        Some(id) -> Ok(id)
        None -> Error(Nil)
      }
    })

  io.println("Registered " <> int.to_string(list.length(user_ids)) <> " users")
  io.println("")

  // Phase 2: Create subreddits
  io.println(
    "Phase 2: Creating "
    <> int.to_string(config.num_subreddits)
    <> " subreddits...",
  )
  let subreddit_data =
    list.range(1, config.num_subreddits)
    |> list.map(fn(i) {
      let name = generate_subreddit_name(i)
      let description = "A community for " <> name

      // Pick a random user as creator
      let creator_idx = { i * 7 } % list.length(user_ids)
      case list.at(user_ids, creator_idx) {
        Ok(creator_id) -> {
          let response_subject = process.new_subject()
          process.send(
            engine_subject,
            CreateSubreddit(creator_id, name, description, response_subject),
          )

          case process.receive(response_subject, 1000) {
            Ok(SubredditCreated(sub_id)) -> {
              let popularity = zipf_rank_to_value(zipf_config, i)
              Some(#(sub_id, popularity))
            }
            _ -> None
          }
        }
        Error(_) -> None
      }
    })
    |> list.filter_map(fn(opt) {
      case opt {
        Some(data) -> Ok(data)
        None -> Error(Nil)
      }
    })

  io.println(
    "Created " <> int.to_string(list.length(subreddit_data)) <> " subreddits",
  )
  io.println("")

  // Phase 3: Users join subreddits based on Zipf distribution
  io.println("Phase 3: Users joining subreddits (Zipf distribution)...")
  let user_subreddit_map =
    list.index_map(user_ids, fn(user_id, user_idx) {
      let rng = new_rng(user_idx + 1000)
      let joined = []

      // Each user joins 3-8 subreddits, biased toward popular ones
      let #(num_to_join, new_rng) = next_int(rng, 6)
      let rng = new_rng
      let num_to_join = num_to_join + 3

      let _ =
        list.range(1, num_to_join)
        |> list.each(fn(_) {
          let #(rand_val, rng1) = next_float(rng)
          let rng = rng1

          // Find subreddit based on Zipf probability
          let cumulative = 0.0
          let selected_sub = None

          let _ =
            list.each(subreddit_data, fn(sub_data) {
              case selected_sub {
                Some(_) -> Nil
                None -> {
                  let #(sub_id, popularity) = sub_data
                  let cumulative = cumulative +. popularity
                  case rand_val <. cumulative {
                    True -> {
                      let selected_sub = Some(sub_id)
                      Nil
                    }
                    False -> Nil
                  }
                }
              }
            })

          case selected_sub {
            Some(sub_id) -> {
              let response_subject = process.new_subject()
              process.send(
                engine_subject,
                JoinSubreddit(user_id, sub_id, response_subject),
              )
              let _ = process.receive(response_subject, 1000)
              let joined = [sub_id, ..joined]
              Nil
            }
            None -> Nil
          }
        })

      #(user_id, joined)
    })

  io.println("Users joined subreddits based on Zipf distribution")
  io.println("")

  // Phase 4: Start client actors
  io.println(
    "Phase 4: Starting "
    <> int.to_string(config.num_clients)
    <> " client actors...",
  )
  let client_subjects =
    list.index_map(user_ids, fn(user_id, idx) {
      let joined_subs = case
        list.find(user_subreddit_map, fn(pair) {
          let #(uid, _) = pair
          uid == user_id
        })
      {
        Ok(#(_, subs)) -> subs
        Error(_) -> []
      }

      let initial_state =
        ClientState(
          client_id: idx,
          engine: engine_subject,
          user_id: Some(user_id),
          joined_subreddits: joined_subs,
          my_posts: [],
          rng: new_rng(idx + 5000),
          is_online: True,
          posts_created: 0,
          comments_created: 0,
          messages_sent: 0,
          timestamp: 0,
        )

      case actor.start(initial_state, client_actor_loop) {
        Ok(subject) -> Some(subject)
        Error(_) -> None
      }
    })
    |> list.filter_map(fn(opt) {
      case opt {
        Some(subj) -> Ok(subj)
        None -> Error(Nil)
      }
    })

  io.println(
    "Started "
    <> int.to_string(list.length(client_subjects))
    <> " client actors",
  )
  io.println("")

  // Phase 5: Run simulation steps
  io.println(
    "Phase 5: Running simulation for "
    <> int.to_string(config.simulation_steps)
    <> " steps...",
  )
  io.println("")

  list.range(1, config.simulation_steps)
  |> list.each(fn(step) {
    // Trigger all clients to perform actions
    list.each(client_subjects, fn(client) {
      process.send(client, StartSimulation)
    })

    // Print progress every 100 steps
    case step % 100 == 0 {
      True -> {
        let response_subject = process.new_subject()
        process.send(engine_subject, GetStats(response_subject))

        case process.receive(response_subject, 2000) {
          Ok(Stats(users, subreddits, posts, comments, messages)) -> {
            io.println(
              "Step "
              <> int.to_string(step)
              <> " - Users: "
              <> int.to_string(users)
              <> ", Subreddits: "
              <> int.to_string(subreddits)
              <> ", Posts: "
              <> int.to_string(posts)
              <> ", Comments: "
              <> int.to_string(comments)
              <> ", Messages: "
              <> int.to_string(messages),
            )
          }
          _ -> Nil
        }
      }
      False -> Nil
    }

    // Small delay to prevent overwhelming the system
    process.sleep(10)
  })

  io.println("")
  io.println("=== Simulation Complete ===")

  // Final statistics
  let response_subject = process.new_subject()
  process.send(engine_subject, GetStats(response_subject))

  case process.receive(response_subject, 2000) {
    Ok(Stats(users, subreddits, posts, comments, messages)) -> {
      io.println("")
      io.println("Final Statistics:")
      io.println("  Total Users: " <> int.to_string(users))
      io.println("  Total Subreddits: " <> int.to_string(subreddits))
      io.println("  Total Posts: " <> int.to_string(posts))
      io.println("  Total Comments: " <> int.to_string(comments))
      io.println("  Total Messages: " <> int.to_string(messages))
      io.println("")

      let avg_posts_per_user = case users > 0 {
        True -> float.to_string(int.to_float(posts) /. int.to_float(users))
        False -> "0"
      }
      let avg_comments_per_post = case posts > 0 {
        True -> float.to_string(int.to_float(comments) /. int.to_float(posts))
        False -> "0"
      }

      io.println("  Avg Posts per User: " <> avg_posts_per_user)
      io.println("  Avg Comments per Post: " <> avg_comments_per_post)
    }
    _ -> io.println("Could not retrieve final statistics")
  }

  io.println("")
  io.println("Simulation finished!")
}

// ========== Main Entry Point ==========

pub fn main() {
  let config =
    SimulationConfig(
      num_clients: 1000,
      num_subreddits: 50,
      simulation_steps: 500,
      zipf_s: 1.5,
    )

  run_simulation(config)
}
