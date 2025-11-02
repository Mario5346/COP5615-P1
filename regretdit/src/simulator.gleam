import regretdit.{
  type EngineMessage, CreateComment, CreatePost, CreateSubregretdit,
  DownvoteComment, DownvotePost, GetAllSubregretdits, GetStats, GetUser,
  GetUserFeed, JoinSubregretdit, RegisterUser, SendMessage, Shutdown,
  UpvoteComment, UpvotePost,
}

// import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type SimulatorConfig {
  SimulatorConfig(
    num_users: Int,
    num_subregretdits: Int,
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
      let _value = case pow {
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

fn random_float() -> Float {
  int.to_float(int.random(10_000)) /. 10_000.0
}

fn pick_random(lst: List(a)) -> Option(a) {
  let len = list.length(lst)
  case len {
    0 -> None
    _ -> {
      let index = int.random(len)
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
  case pick_random(titles) {
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
  case pick_random(contents) {
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
  case pick_random(comments) {
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
    <> int.to_string(config.num_subregretdits)
    <> " subregretdits",
  )

  // Step 1: Create users
  io.println("\n[Phase 1] Creating users: ")
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

  // Step 2: Create subregretdits with diverse topics
  io.println("\n[Phase 2] Creating subregretdits...")
  let subregretdit_names = [
    "GleamHateClub", "Gaming", "GleamAgainstDevs", "Dobra", "Agony", "Movies",
    "TractorFanClub", "Food", "Actors", "Fitness", "Art", "Project4", "Regret",
    "StackOverflow", "Funny", "Memes", "Cats", "SrikarMarioBros", "Sports",
    "DevsAgainstGleam",
  ]

  let max_subs = case
    config.num_subregretdits < list.length(subregretdit_names)
  {
    True -> config.num_subregretdits
    False -> list.length(subregretdit_names)
  }

  let subregretdit_ids =
    list.range(0, max_subs - 1)
    |> list.filter_map(fn(i) {
      case pick_random(user_ids) {
        Some(creator_id) -> {
          let name = case list.drop(subregretdit_names, i) |> list.first {
            Ok(n) -> n
            Error(_) -> "Community" <> int.to_string(i)
          }
          let reply = process.new_subject()
          process.send(
            engine,
            CreateSubregretdit(
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
    <> int.to_string(list.length(subregretdit_ids))
    <> " subregretdits",
  )

  // Step 3: Apply Zipf distribution for subregretdit membership
  io.println(
    "\n[Phase 3] Simulating Zipf distribution for subregretdit popularity: ",
  )
  let zipf_values =
    zipf_distribution(list.length(subregretdit_ids), config.zipf_exponent)

  list.index_map(subregretdit_ids, fn(subregretdit_id, idx) {
    let popularity = case list.drop(zipf_values, idx) |> list.first {
      Ok(val) -> val
      Error(_) -> 0.01
    }

    let num_members_float = popularity *. int.to_float(config.num_users)
    let num_members = float.round(num_members_float)
    // |> float.truncate

    list.range(0, num_members - 1)
    |> list.each(fn(_i) {
      case pick_random(user_ids) {
        Some(user_id) -> {
          let reply = process.new_subject()
          process.send(
            engine,
            JoinSubregretdit(user_id, subregretdit_id, reply),
          )
          let _ = process.receive(reply, 1000)
          Nil
        }
        None -> Nil
      }
    })

    case safe_modulo(idx, 5) {
      0 ->
        io.println(
          "  Subregretdit "
          <> int.to_string(idx + 1)
          <> " has "
          <> int.to_string(num_members)
          <> " members",
        )
      _ -> Nil
    }
  })
  io.println(
    "Users joined subregretdits according to Zipf distribution successfully.",
  )

  // Step 4: Get subregretdit member counts for post generation
  io.println("\n[Phase 4] Generating posts (more posts for popular subs): ")
  let reply = process.new_subject()
  process.send(engine, GetAllSubregretdits(reply))
  let subregretdits = case process.receive(reply, 1000) {
    Ok(subs) -> subs
    Error(_) -> []
  }

  let total_posts =
    list.index_fold(subregretdits, 0, fn(acc, subregretdit, idx) {
      let member_count = list.length(subregretdit.members)
      let num_posts = case member_count > 10 {
        True -> member_count / 10
        False -> 1
      }

      list.range(0, num_posts - 1)
      |> list.each(fn(post_idx) {
        case pick_random(subregretdit.members) {
          Some(author_id) -> {
            let seed = idx * 1000 + post_idx
            let title = generate_post_title(seed)
            let content = generate_post_content(seed)

            // Simulate reposts (10% chance)
            let is_repost = int.random(10) == 0
            let final_title = case is_repost {
              True -> "[REPOST] " <> title
              False -> title
            }

            let post_reply = process.new_subject()
            process.send(
              engine,
              CreatePost(
                author_id,
                subregretdit.id,
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
    "Successfully Generated " <> int.to_string(total_posts) <> " starting posts",
  )

  // Step 5: Simulate user activity over time
  io.println("\n[Phase 5] Simulating user activity: ")
  list.range(0, config.simulation_ticks - 1)
  |> list.each(fn(tick) {
    // Simulate online/offline cycles (60% online at any given time)
    let active_users =
      list.filter(user_ids, fn(_user_id) { random_float() <. 0.6 })

    // Active users perform actions
    list.each(active_users, fn(user_id) {
      let seed = tick * 10_000 + string.length(user_id)
      let action = int.random(100)

      // 40% chance: vote on something
      case action < 40 {
        True -> {
          let feed_reply = process.new_subject()
          process.send(engine, GetUserFeed(user_id, feed_reply))
          case process.receive(feed_reply, 1000) {
            Ok(Ok(posts)) ->
              case pick_random(posts) {
                Some(post) -> {
                  let vote_reply = process.new_subject()
                  case int.random(3) {
                    0 -> {
                      // io.println("downvoting post")
                      process.send(engine, DownvotePost(post.id, vote_reply))
                    }
                    _ -> {
                      // io.println("upvoting post")
                      process.send(engine, UpvotePost(post.id, vote_reply))
                    }
                  }
                  let _ = process.receive(vote_reply, 1000)
                  case pick_random(post.comments) {
                    Some(comment) -> {
                      let comment_vote_reply = process.new_subject()
                      case int.random(3) {
                        0 ->
                          process.send(
                            engine,
                            DownvoteComment(comment, comment_vote_reply),
                          )
                        _ ->
                          process.send(
                            engine,
                            UpvoteComment(comment, comment_vote_reply),
                          )
                      }
                      let _ = process.receive(comment_vote_reply, 1000)
                      Nil
                    }
                    None -> Nil
                  }
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
              case pick_random(posts) {
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

      // // 20% chance: read messages
      // case action >= 70 && action < 90 {
      //   True -> {
      //     let msg_reply = process.new_subject()
      //     process.send(engine, GetUserMessages(user_id, msg_reply))
      //     let _ = process.receive(msg_reply, 1000)
      //     Nil
      //   }
      //   False -> Nil
      // }

      // 10% chance: create a new post
      case action >= 70 && action < 80 {
        True -> {
          let user_reply = process.new_subject()
          process.send(engine, GetUser(user_id, user_reply))
          case process.receive(user_reply, 1000) {
            Ok(Ok(user)) ->
              case pick_random(user.joined_subregretdits) {
                Some(sub_id) -> {
                  let title = generate_post_title(seed)
                  let content = generate_post_content(seed)
                  let post_reply = process.new_subject()
                  process.send(
                    engine,
                    CreatePost(
                      user_id,
                      sub_id,
                      title,
                      content,
                      tick,
                      post_reply,
                    ),
                  )
                  let _ = process.receive(post_reply, 1000)
                  Nil
                }
                None -> Nil
              }
            _ -> Nil
          }
        }
        False -> Nil
      }

      // 2% chance: join another subregretdit
      case action >= 80 && action < 82 {
        True ->
          case pick_random(subregretdit_ids) {
            Some(sub_id) -> {
              let join_reply = process.new_subject()
              process.send(
                engine,
                JoinSubregretdit(user_id, sub_id, join_reply),
              )
              let _ = process.receive(join_reply, 1000)
              Nil
            }
            None -> Nil
          }
        False -> Nil
      }

      // 18% chance: send a direct message
      case action >= 82 {
        True ->
          case pick_random(user_ids) {
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
  io.println("\n[Phase 6] Collecting final statistics: ")

  // Get sample user stats
  case list.first(user_ids) {
    Ok(_sample_user_id) -> {
      let user_reply = process.new_subject()
      let stats_reply = process.new_subject()
      // process.send(engine, GetUser(sample_user_id, user_reply))
      process.sleep(1000)
      process.send(engine, GetUser("user_400", user_reply))
      process.send(engine, GetStats(stats_reply))
      case process.receive(user_reply, 10_000) {
        Ok(Ok(user)) -> {
          io.println(
            "\n--Sample User Stats:\n  Username: "
            <> user.username
            <> "\n  Karma: "
            <> int.to_string(user.karma)
            <> "\n  Joined Subregretdits: "
            <> int.to_string(list.length(user.joined_subregretdits)),
          )
        }
        _ -> Nil
      }
      case process.receive(stats_reply, 10_000) {
        Ok(stats) -> {
          // echo stats
          io.println(
            "\n--Stats Snapshot:\n  Total Posts: "
            <> int.to_string(stats.posts)
            <> "\n  Total Comments: "
            <> int.to_string(stats.comments)
            <> "\n  Total Upvotes: "
            <> int.to_string(stats.upvotes)
            <> "\n  Total Downvotes: "
            <> int.to_string(stats.downvotes)
            <> "\n  Total Subs Joined: "
            <> int.to_string(stats.subs_joined)
            <> "\n  Total Dms Sent: "
            <> int.to_string(stats.dms),
          )
        }
        _ -> Nil
      }
    }
    Error(_) -> Nil
  }

  io.println("\n========== SIMULATION COMPLETE ==========\n")
}

// Example usage function
pub fn main() {
  case regretdit.start() {
    Ok(engine) -> {
      let config =
        SimulatorConfig(
          num_users: 500,
          num_subregretdits: 20,
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
