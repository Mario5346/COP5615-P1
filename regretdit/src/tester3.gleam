import sample2.{
  type EngineMessage, type SubredditId, type UserId, CreateComment, CreatePost,
  CreateSubreddit, DownvotePost, GetAllSubreddits, GetUser, GetUserFeed,
  GetUserMessages, JoinSubreddit, RegisterUser, SendMessage, Shutdown,
  UpvotePost,
}

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

pub type SimulatorConfig {
  SimulatorConfig(
    num_users: Int,
    num_subreddits: Int,
    simulation_ticks: Int,
    zipf_exponent: Float,
  )
}

// Generate Zipf distribution values
fn zipf_distribution(n: Int, exponent: Float) -> List(Float) {
  let ranks = list.range(1, n)
  let sum =
    list.fold(ranks, 0.0, fn(acc, rank) {
      let rank_float = int.to_float(rank)
      let pow = float.power(rank_float, exponent)
      let value = case pow {
        Ok(res) -> acc +. { 1.0 /. res }
        _ -> 0.0
      }
    })

  list.map(ranks, fn(rank) {
    let rank_float = int.to_float(rank)
    let pow = float.power(rank_float, exponent)
    let value = case pow {
      Ok(res) -> 1.0 /. res
      _ -> 1.0
    }
    value /. sum
  })
}

// Simple pseudo-random number generator
fn pseudo_random(seed: Int, max: Int) -> Int {
  case max {
    0 -> 0
    _ -> {
      let a = 1_103_515
      let c = 1235
      let m = 214_746
      let result = { seed * a + c } % m
      case result < 0 {
        True -> { result + m } % max
        False -> result % max
      }
    }
  }
}

fn random_float(seed: Int) -> Float {
  int.to_float(pseudo_random(seed, 10_000)) /. 10_000.0
}

fn pick_random(lst: List(a), seed: Int) -> Option(a) {
  let len = list.length(lst)
  case len {
    0 -> None
    _ -> {
      let index = pseudo_random(seed, len)
      list.drop(lst, index) |> list.first |> option.from_result
    }
  }
}

// Create sample post content
fn generate_post_title(seed: Int) -> String {
  let titles = [
    "Just discovered something amazing!",
    "Thought you all might find this interesting",
    "Hot take: I love gleam",
    "The more I grow up, the less I care about new versions of tech",
    "This changed my perspective completely",
    "Am I the only one who thinks this?",
    "Finally figured this out after years",
    "Should I tell my friend that his wife cheated on him?",
    "PSA: Everyone needs to know this",
    "Shower thought: what if...",
  ]
  case pick_random(titles, seed) {
    Some(title) -> title
    None -> "Interesting post #" <> int.to_string(seed)
  }
}

fn generate_post_content(seed: Int) -> String {
  let contents = [
    "I've been thinking about this for a while and wanted to share my thoughts.",
    "Long time lurker, first time poster. This really resonated with me.",
    "After extensive research, I believe I've found the answer we've been looking for.",
    "Just my two cents, but I think this is worth discussing.",
    "I know this might be controversial, but hear me out...",
    "TL;DR at the bottom for those who want the quick version.",
    "Update: Thanks for all the feedback! Really appreciate this community.",
    "Edit: Wow, didn't expect this to blow up! Thanks for the upvotes!",
  ]
  case pick_random(contents, seed) {
    Some(content) -> content
    None -> "Post content " <> int.to_string(seed)
  }
}

fn generate_comment_content(seed: Int) -> String {
  let comments = [
    "This is exactly what I was thinking!",
    "Great point, never thought of it that way.",
    "I hate gleam, here's why...",
    "Can you provide a source for that claim?",
    "Thanks for sharing this!",
    "Underrated comment right here.",
    "This needs to be higher up!",
    "ELI5 please?",
  ]
  case pick_random(comments, seed) {
    Some(comment) -> comment
    None -> "Comment " <> int.to_string(seed)
  }
}

fn safe_modulo(value: Int, divisor: Int) -> Int {
  case divisor {
    0 -> 0
    _ -> value % divisor
  }
}

// Simulator main function
pub fn run_simulation(engine: Subject(EngineMessage), config: SimulatorConfig) {
  io.println("\n========== REGRETDIT SIMULATOR ==========")
  io.println(
    "Starting simulation with "
    <> int.to_string(config.num_users)
    <> " users and "
    <> int.to_string(config.num_subreddits)
    <> " subreddits",
  )

  // Step 1: Create users
  io.println("\n[Phase 1] Creating users...")
  let user_ids =
    list.range(1, config.num_users)
    |> list.filter_map(fn(i) {
      let reply = process.new_subject()
      process.send(engine, RegisterUser("user_" <> int.to_string(i), reply))
      case process.receive(reply, 1000) {
        Ok(Ok(user_id)) -> {
          case safe_modulo(i, 100) {
            0 -> io.println("  Created " <> int.to_string(i) <> " users...")
            _ -> Nil
          }
          Ok(user_id)
        }
        _ -> Error(Nil)
      }
    })
  io.println(
    "Successfully Created " <> int.to_string(list.length(user_ids)) <> " users",
  )

  // Step 2: Create subreddits with diverse topics
  io.println("\n[Phase 2] Creating subreddits...")
  let subreddit_names = [
    "GleamHateClub", "Gaming", "GleamAgainstDevs", "Dobra", "Agony", "Movies",
    "TractorFanClub", "Food", "Actors", "Fitness", "Art", "Project4", "Regret",
    "StackOverflow", "Funny", "Memes", "Cats", "SrikarMarioBros", "Sports",
    "DevsAgainstGleam",
  ]

  let max_subs = case config.num_subreddits < list.length(subreddit_names) {
    True -> config.num_subreddits
    False -> list.length(subreddit_names)
  }

  let subreddit_ids =
    list.range(0, max_subs - 1)
    |> list.filter_map(fn(i) {
      case pick_random(user_ids, i) {
        Some(creator_id) -> {
          let name = case list.drop(subreddit_names, i) |> list.first {
            Ok(n) -> n
            Error(_) -> "Community" <> int.to_string(i)
          }
          let reply = process.new_subject()
          process.send(
            engine,
            CreateSubreddit(
              creator_id,
              "r/" <> name,
              "A community for " <> name <> " enthusiasts",
              reply,
            ),
          )
          case process.receive(reply, 1000) {
            Ok(Ok(sub_id)) -> Ok(sub_id)
            _ -> Error(Nil)
          }
        }
        None -> Error(Nil)
      }
    })
  io.println(
    "Successfully Created "
    <> int.to_string(list.length(subreddit_ids))
    <> " subreddits",
  )

  // Step 3: Apply Zipf distribution for subreddit membership
  io.println(
    "\n[Phase 3] Simulating Zipf distribution for subreddit popularity...",
  )
  let zipf_values =
    zipf_distribution(list.length(subreddit_ids), config.zipf_exponent)

  list.index_map(subreddit_ids, fn(subreddit_id, idx) {
    let popularity = case list.drop(zipf_values, idx) |> list.first {
      Ok(val) -> val
      Error(_) -> 0.01
    }

    let num_members_float = popularity *. int.to_float(config.num_users)
    let num_members = float.round(num_members_float)
    // |> float.truncate

    list.range(0, num_members - 1)
    |> list.each(fn(i) {
      case pick_random(user_ids, idx * 1000 + i) {
        Some(user_id) -> {
          let reply = process.new_subject()
          process.send(engine, JoinSubreddit(user_id, subreddit_id, reply))
          let _ = process.receive(reply, 1000)
          Nil
        }
        None -> Nil
      }
    })

    case safe_modulo(idx, 5) {
      0 ->
        io.println(
          "  Subreddit "
          <> int.to_string(idx + 1)
          <> " has "
          <> int.to_string(num_members)
          <> " members",
        )
      _ -> Nil
    }
  })
  io.println(
    "Successfully Users joined subreddits according to Zipf distribution",
  )

  // Step 4: Get subreddit member counts for post generation
  io.println(
    "\n[Phase 4] Generating posts (more posts for popular subreddits)...",
  )
  let reply = process.new_subject()
  process.send(engine, GetAllSubreddits(reply))
  let subreddits = case process.receive(reply, 1000) {
    Ok(subs) -> subs
    Error(_) -> []
  }

  let total_posts =
    list.index_fold(subreddits, 0, fn(acc, subreddit, idx) {
      let member_count = list.length(subreddit.members)
      let num_posts = case member_count > 10 {
        True -> member_count / 10
        False -> 1
      }

      list.range(0, num_posts - 1)
      |> list.each(fn(post_idx) {
        case pick_random(subreddit.members, idx * 10_000 + post_idx) {
          Some(author_id) -> {
            let seed = idx * 1000 + post_idx
            let title = generate_post_title(seed)
            let content = generate_post_content(seed)

            // Simulate reposts (10% chance)
            let is_repost = pseudo_random(seed, 10) == 0
            let final_title = case is_repost {
              True -> "[REPOST] " <> title
              False -> title
            }

            let post_reply = process.new_subject()
            process.send(
              engine,
              CreatePost(
                author_id,
                subreddit.id,
                final_title,
                content,
                seed,
                post_reply,
              ),
            )
            let _ = process.receive(post_reply, 1000)
            Nil
          }
          None -> Nil
        }
      })

      acc + num_posts
    })
  io.println(
    "Successfully Generated " <> int.to_string(total_posts) <> " posts",
  )

  // Step 5: Simulate user activity over time
  io.println("\n[Phase 5] Simulating user activity cycles...")
  list.range(0, config.simulation_ticks - 1)
  |> list.each(fn(tick) {
    // Simulate online/offline cycles (60% online at any given time)
    let active_users =
      list.filter(user_ids, fn(user_id) {
        let seed = tick * 1000 + string.length(user_id)
        random_float(seed) <. 0.6
      })

    // Active users perform actions
    list.each(active_users, fn(user_id) {
      let seed = tick * 10_000 + string.length(user_id)
      let action = pseudo_random(seed, 100)

      // 40% chance: vote on something
      case action < 40 {
        True -> {
          let feed_reply = process.new_subject()
          process.send(engine, GetUserFeed(user_id, feed_reply))
          case process.receive(feed_reply, 1000) {
            Ok(Ok(posts)) ->
              case pick_random(posts, seed) {
                Some(post) -> {
                  let vote_reply = process.new_subject()
                  case pseudo_random(seed + 1, 2) {
                    0 -> process.send(engine, UpvotePost(post.id, vote_reply))
                    _ -> process.send(engine, DownvotePost(post.id, vote_reply))
                  }
                  let _ = process.receive(vote_reply, 1000)
                  Nil
                }
                None -> Nil
              }
            _ -> Nil
          }
        }
        False -> Nil
      }

      // 30% chance: comment on a post
      case action >= 40 && action < 70 {
        True -> {
          let feed_reply = process.new_subject()
          process.send(engine, GetUserFeed(user_id, feed_reply))
          case process.receive(feed_reply, 1000) {
            Ok(Ok(posts)) ->
              case pick_random(posts, seed) {
                Some(post) -> {
                  let comment_reply = process.new_subject()
                  let content = generate_comment_content(seed)
                  process.send(
                    engine,
                    CreateComment(
                      user_id,
                      post.id,
                      None,
                      content,
                      tick,
                      comment_reply,
                    ),
                  )
                  let _ = process.receive(comment_reply, 1000)
                  Nil
                }
                None -> Nil
              }
            _ -> Nil
          }
        }
        False -> Nil
      }

      // 20% chance: read messages
      case action >= 70 && action < 90 {
        True -> {
          let msg_reply = process.new_subject()
          process.send(engine, GetUserMessages(user_id, msg_reply))
          let _ = process.receive(msg_reply, 1000)
          Nil
        }
        False -> Nil
      }

      // 10% chance: send a direct message
      case action >= 90 {
        True ->
          case pick_random(user_ids, seed) {
            Some(recipient_id) -> {
              let msg_reply = process.new_subject()
              process.send(
                engine,
                SendMessage(
                  user_id,
                  recipient_id,
                  "Hey, check out this cool post!",
                  tick,
                  msg_reply,
                ),
              )
              let _ = process.receive(msg_reply, 1000)
              Nil
            }
            None -> Nil
          }
        False -> Nil
      }
    })

    case safe_modulo(tick, 10) {
      0 ->
        io.println(
          "  Tick "
          <> int.to_string(tick)
          <> ": "
          <> int.to_string(list.length(active_users))
          <> " users active",
        )
      _ -> Nil
    }
  })

  // Step 6: Print final statistics
  io.println("\n[Phase 6] Collecting final statistics...")

  // Get sample user stats
  case list.first(user_ids) {
    Ok(sample_user_id) -> {
      let user_reply = process.new_subject()
      process.send(engine, GetUser(sample_user_id, user_reply))
      case process.receive(user_reply, 1000) {
        Ok(Ok(user)) ->
          io.println(
            "\nSample User Stats:\n  Username: "
            <> user.username
            <> "\n  Karma: "
            <> int.to_string(user.karma)
            <> "\n  Joined Subreddits: "
            <> int.to_string(list.length(user.joined_subreddits)),
          )
        _ -> Nil
      }
    }
    Error(_) -> Nil
  }

  io.println("\n========== SIMULATION COMPLETE ==========\n")
}

// Example usage function
pub fn main() {
  case sample2.start() {
    Ok(engine) -> {
      let config =
        SimulatorConfig(
          num_users: 500,
          num_subreddits: 20,
          simulation_ticks: 50,
          zipf_exponent: 1.5,
        )

      run_simulation(engine.data, config)

      // Shutdown the engine
      process.send(engine.data, Shutdown)
      Nil
    }
    Error(_) -> {
      io.println("Failed to start engine")
      Nil
    }
  }
}
