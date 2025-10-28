import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string

// ========== Types ==========

pub type UserId =
  String

pub type SubredditId =
  String

pub type PostId =
  String

pub type CommentId =
  String

pub type MessageId =
  String

pub type User {
  User(
    id: UserId,
    username: String,
    karma: Int,
    joined_subreddits: List(SubredditId),
  )
}

pub type Subreddit {
  Subreddit(
    id: SubredditId,
    name: String,
    description: String,
    members: List(UserId),
    posts: List(PostId),
  )
}

pub type Post {
  Post(
    id: PostId,
    author_id: UserId,
    subreddit_id: SubredditId,
    title: String,
    content: String,
    upvotes: Int,
    downvotes: Int,
    comments: List(CommentId),
    timestamp: Int,
  )
}

pub type Comment {
  Comment(
    id: CommentId,
    author_id: UserId,
    post_id: PostId,
    parent_comment_id: Option(CommentId),
    content: String,
    upvotes: Int,
    downvotes: Int,
    replies: List(CommentId),
    timestamp: Int,
  )
}

pub type DirectMessage {
  DirectMessage(
    id: MessageId,
    from_user_id: UserId,
    to_user_id: UserId,
    content: String,
    timestamp: Int,
    is_read: Bool,
  )
}

pub type EngineState {
  EngineState(
    users: Dict(UserId, User),
    subreddits: Dict(SubredditId, Subreddit),
    posts: Dict(PostId, Post),
    comments: Dict(CommentId, Comment),
    messages: Dict(MessageId, DirectMessage),
    next_id: Int,
  )
}

pub type Error {
  UserNotFound
  SubredditNotFound
  PostNotFound
  CommentNotFound
  MessageNotFound
  AlreadyJoined
  NotAMember
  Unauthorized
  InvalidInput
}

// ========== Actor Messages ==========

pub type EngineMessage {
  RegisterUser(username: String, reply: Subject(Result(UserId, Error)))
  CreateSubreddit(
    creator_id: UserId,
    name: String,
    description: String,
    reply: Subject(Result(SubredditId, Error)),
  )
  JoinSubreddit(
    user_id: UserId,
    subreddit_id: SubredditId,
    reply: Subject(Result(Nil, Error)),
  )
  LeaveSubreddit(
    user_id: UserId,
    subreddit_id: SubredditId,
    reply: Subject(Result(Nil, Error)),
  )
  CreatePost(
    author_id: UserId,
    subreddit_id: SubredditId,
    title: String,
    content: String,
    timestamp: Int,
    reply: Subject(Result(PostId, Error)),
  )
  CreateComment(
    author_id: UserId,
    post_id: PostId,
    parent_comment_id: Option(CommentId),
    content: String,
    timestamp: Int,
    reply: Subject(Result(CommentId, Error)),
  )
  UpvotePost(post_id: PostId, reply: Subject(Result(Nil, Error)))
  DownvotePost(post_id: PostId, reply: Subject(Result(Nil, Error)))
  UpvoteComment(comment_id: CommentId, reply: Subject(Result(Nil, Error)))
  DownvoteComment(comment_id: CommentId, reply: Subject(Result(Nil, Error)))
  GetUserFeed(user_id: UserId, reply: Subject(Result(List(Post), Error)))
  SendMessage(
    from_user_id: UserId,
    to_user_id: UserId,
    content: String,
    timestamp: Int,
    reply: Subject(Result(MessageId, Error)),
  )
  GetUserMessages(
    user_id: UserId,
    reply: Subject(Result(List(DirectMessage), Error)),
  )
  ReplyToMessage(
    message_id: MessageId,
    content: String,
    timestamp: Int,
    reply: Subject(Result(MessageId, Error)),
  )
  GetUser(user_id: UserId, reply: Subject(Result(User, Error)))
  GetPost(post_id: PostId, reply: Subject(Result(Post, Error)))
  GetSubreddit(
    subreddit_id: SubredditId,
    reply: Subject(Result(Subreddit, Error)),
  )
  GetAllSubreddits(reply: Subject(List(Subreddit)))
  Shutdown
}

// ========== Actor Implementation ==========

fn handle_message(
  state: EngineState,
  message: EngineMessage,
) -> actor.Next(EngineState, EngineMessage) {
  case message {
    RegisterUser(username, reply) -> {
      let result = register_user(state, username)
      case result {
        Ok(#(user_id, new_state)) -> {
          process.send(reply, Ok(user_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    CreateSubreddit(creator_id, name, description, reply) -> {
      let result = create_subreddit(state, creator_id, name, description)
      case result {
        Ok(#(subreddit_id, new_state)) -> {
          process.send(reply, Ok(subreddit_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    JoinSubreddit(user_id, subreddit_id, reply) -> {
      let result = join_subreddit(state, user_id, subreddit_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    LeaveSubreddit(user_id, subreddit_id, reply) -> {
      let result = leave_subreddit(state, user_id, subreddit_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    CreatePost(author_id, subreddit_id, title, content, timestamp, reply) -> {
      let result =
        create_post(state, author_id, subreddit_id, title, content, timestamp)
      case result {
        Ok(#(post_id, new_state)) -> {
          process.send(reply, Ok(post_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    CreateComment(
      author_id,
      post_id,
      parent_comment_id,
      content,
      timestamp,
      reply,
    ) -> {
      let result =
        create_comment(
          state,
          author_id,
          post_id,
          parent_comment_id,
          content,
          timestamp,
        )
      case result {
        Ok(#(comment_id, new_state)) -> {
          process.send(reply, Ok(comment_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    UpvotePost(post_id, reply) -> {
      let result = upvote_post(state, post_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    DownvotePost(post_id, reply) -> {
      let result = downvote_post(state, post_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    UpvoteComment(comment_id, reply) -> {
      let result = upvote_comment(state, comment_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    DownvoteComment(comment_id, reply) -> {
      let result = downvote_comment(state, comment_id)
      case result {
        Ok(new_state) -> {
          process.send(reply, Ok(Nil))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    GetUserFeed(user_id, reply) -> {
      let result = get_user_feed(state, user_id)
      process.send(reply, result)
      actor.continue(state)
    }

    SendMessage(from_user_id, to_user_id, content, timestamp, reply) -> {
      let result =
        send_message(state, from_user_id, to_user_id, content, timestamp)
      case result {
        Ok(#(message_id, new_state)) -> {
          process.send(reply, Ok(message_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    GetUserMessages(user_id, reply) -> {
      let result = get_user_messages(state, user_id)
      process.send(reply, result)
      actor.continue(state)
    }

    ReplyToMessage(message_id, content, timestamp, reply) -> {
      let result = reply_to_message(state, message_id, content, timestamp)
      case result {
        Ok(#(new_message_id, new_state)) -> {
          process.send(reply, Ok(new_message_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    GetUser(user_id, reply) -> {
      let result = get_user(state, user_id)
      process.send(reply, result)
      actor.continue(state)
    }

    GetPost(post_id, reply) -> {
      let result = get_post(state, post_id)
      process.send(reply, result)
      actor.continue(state)
    }

    GetSubreddit(subreddit_id, reply) -> {
      let result = get_subreddit(state, subreddit_id)
      process.send(reply, result)
      actor.continue(state)
    }

    GetAllSubreddits(reply) -> {
      let subreddits = dict.values(state.subreddits)
      process.send(reply, subreddits)
      actor.continue(state)
    }

    Shutdown -> actor.stop()
  }
}

pub fn start() {
  let initial_state =
    EngineState(
      users: dict.new(),
      subreddits: dict.new(),
      posts: dict.new(),
      comments: dict.new(),
      messages: dict.new(),
      next_id: 1,
    )
  actor.new(initial_state)
  |> actor.on_message(handle_message)
  |> actor.start
  // actor.start(initial_state, handle_message)
}

// ========== Internal Functions ==========

fn generate_id(state: EngineState, prefix: String) -> #(String, EngineState) {
  let id = prefix <> int.to_string(state.next_id)
  let new_state = EngineState(..state, next_id: state.next_id + 1)
  #(id, new_state)
}

fn register_user(
  state: EngineState,
  username: String,
) -> Result(#(UserId, EngineState), Error) {
  case string.is_empty(username) {
    True -> Error(InvalidInput)
    False -> {
      let #(user_id, new_state) = generate_id(state, "user_")
      let user =
        User(id: user_id, username: username, karma: 0, joined_subreddits: [])
      let updated_users = dict.insert(new_state.users, user_id, user)
      Ok(#(user_id, EngineState(..new_state, users: updated_users)))
    }
  }
}

fn get_user(state: EngineState, user_id: UserId) -> Result(User, Error) {
  case dict.get(state.users, user_id) {
    Ok(user) -> Ok(user)
    Error(_) -> Error(UserNotFound)
  }
}

fn get_subreddit(
  state: EngineState,
  subreddit_id: SubredditId,
) -> Result(Subreddit, Error) {
  case dict.get(state.subreddits, subreddit_id) {
    Ok(subreddit) -> Ok(subreddit)
    Error(_) -> Error(SubredditNotFound)
  }
}

fn create_subreddit(
  state: EngineState,
  creator_id: UserId,
  name: String,
  description: String,
) -> Result(#(SubredditId, EngineState), Error) {
  case get_user(state, creator_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case string.is_empty(name) {
        True -> Error(InvalidInput)
        False -> {
          let #(subreddit_id, new_state) = generate_id(state, "sub_")
          let subreddit =
            Subreddit(
              id: subreddit_id,
              name: name,
              description: description,
              members: [creator_id],
              posts: [],
            )
          let updated_subreddits =
            dict.insert(new_state.subreddits, subreddit_id, subreddit)

          case dict.get(new_state.users, creator_id) {
            Ok(user) -> {
              let updated_user =
                User(..user, joined_subreddits: [
                  subreddit_id,
                  ..user.joined_subreddits
                ])
              let updated_users =
                dict.insert(new_state.users, creator_id, updated_user)
              Ok(#(
                subreddit_id,
                EngineState(
                  ..new_state,
                  subreddits: updated_subreddits,
                  users: updated_users,
                ),
              ))
            }
            Error(_) -> Error(UserNotFound)
          }
        }
      }
  }
}

fn join_subreddit(
  state: EngineState,
  user_id: UserId,
  subreddit_id: SubredditId,
) -> Result(EngineState, Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(state.subreddits, subreddit_id) {
        Error(_) -> Error(SubredditNotFound)
        Ok(subreddit) ->
          case list.contains(subreddit.members, user_id) {
            True -> Error(AlreadyJoined)
            False -> {
              let updated_subreddit =
                Subreddit(..subreddit, members: [user_id, ..subreddit.members])
              let updated_subreddits =
                dict.insert(state.subreddits, subreddit_id, updated_subreddit)

              let updated_user =
                User(..user, joined_subreddits: [
                  subreddit_id,
                  ..user.joined_subreddits
                ])
              let updated_users =
                dict.insert(state.users, user_id, updated_user)

              Ok(
                EngineState(
                  ..state,
                  subreddits: updated_subreddits,
                  users: updated_users,
                ),
              )
            }
          }
      }
  }
}

fn leave_subreddit(
  state: EngineState,
  user_id: UserId,
  subreddit_id: SubredditId,
) -> Result(EngineState, Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(state.subreddits, subreddit_id) {
        Error(_) -> Error(SubredditNotFound)
        Ok(subreddit) ->
          case list.contains(subreddit.members, user_id) {
            False -> Error(NotAMember)
            True -> {
              let updated_subreddit =
                Subreddit(
                  ..subreddit,
                  members: list.filter(subreddit.members, fn(id) {
                    id != user_id
                  }),
                )
              let updated_subreddits =
                dict.insert(state.subreddits, subreddit_id, updated_subreddit)

              let updated_user =
                User(
                  ..user,
                  joined_subreddits: list.filter(user.joined_subreddits, fn(id) {
                    id != subreddit_id
                  }),
                )
              let updated_users =
                dict.insert(state.users, user_id, updated_user)

              Ok(
                EngineState(
                  ..state,
                  subreddits: updated_subreddits,
                  users: updated_users,
                ),
              )
            }
          }
      }
  }
}

fn create_post(
  state: EngineState,
  author_id: UserId,
  subreddit_id: SubredditId,
  title: String,
  content: String,
  timestamp: Int,
) -> Result(#(PostId, EngineState), Error) {
  case get_user(state, author_id) {
    Error(e) -> Error(e)
    Ok(_user) ->
      case dict.get(state.subreddits, subreddit_id) {
        Error(_) -> Error(SubredditNotFound)
        Ok(subreddit) ->
          case list.contains(subreddit.members, author_id) {
            False -> Error(NotAMember)
            True ->
              case string.is_empty(title) {
                True -> Error(InvalidInput)
                False -> {
                  let #(post_id, new_state) = generate_id(state, "post_")
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
                  let updated_posts =
                    dict.insert(new_state.posts, post_id, post)

                  let updated_subreddit =
                    Subreddit(..subreddit, posts: [post_id, ..subreddit.posts])
                  let updated_subreddits =
                    dict.insert(
                      new_state.subreddits,
                      subreddit_id,
                      updated_subreddit,
                    )

                  Ok(#(
                    post_id,
                    EngineState(
                      ..new_state,
                      posts: updated_posts,
                      subreddits: updated_subreddits,
                    ),
                  ))
                }
              }
          }
      }
  }
}

fn get_post(state: EngineState, post_id: PostId) -> Result(Post, Error) {
  case dict.get(state.posts, post_id) {
    Ok(post) -> Ok(post)
    Error(_) -> Error(PostNotFound)
  }
}

fn create_comment(
  state: EngineState,
  author_id: UserId,
  post_id: PostId,
  parent_comment_id: Option(CommentId),
  content: String,
  timestamp: Int,
) -> Result(#(CommentId, EngineState), Error) {
  case get_user(state, author_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case dict.get(state.posts, post_id) {
        Error(_) -> Error(PostNotFound)
        Ok(post) ->
          case string.is_empty(content) {
            True -> Error(InvalidInput)
            False -> {
              case parent_comment_id {
                Some(parent_id) ->
                  case dict.get(state.comments, parent_id) {
                    Error(_) -> Error(CommentNotFound)
                    Ok(_) ->
                      create_comment_internal(
                        state,
                        author_id,
                        post_id,
                        parent_comment_id,
                        content,
                        timestamp,
                        post,
                      )
                  }
                None ->
                  create_comment_internal(
                    state,
                    author_id,
                    post_id,
                    parent_comment_id,
                    content,
                    timestamp,
                    post,
                  )
              }
            }
          }
      }
  }
}

fn create_comment_internal(
  state: EngineState,
  author_id: UserId,
  post_id: PostId,
  parent_comment_id: Option(CommentId),
  content: String,
  timestamp: Int,
  post: Post,
) -> Result(#(CommentId, EngineState), Error) {
  let #(comment_id, new_state) = generate_id(state, "comment_")
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
  let updated_comments = dict.insert(new_state.comments, comment_id, comment)

  let updated_post = Post(..post, comments: [comment_id, ..post.comments])
  let updated_posts = dict.insert(new_state.posts, post_id, updated_post)

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

  Ok(#(
    comment_id,
    EngineState(..new_state, comments: final_comments, posts: updated_posts),
  ))
}

fn upvote_post(
  state: EngineState,
  post_id: PostId,
) -> Result(EngineState, Error) {
  case dict.get(state.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, upvotes: post.upvotes + 1)
      let updated_posts = dict.insert(state.posts, post_id, updated_post)

      case dict.get(state.users, post.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma + 1)
          let updated_users =
            dict.insert(state.users, post.author_id, updated_author)
          Ok(EngineState(..state, posts: updated_posts, users: updated_users))
        }
        Error(_) -> Ok(EngineState(..state, posts: updated_posts))
      }
    }
  }
}

fn downvote_post(
  state: EngineState,
  post_id: PostId,
) -> Result(EngineState, Error) {
  case dict.get(state.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, downvotes: post.downvotes + 1)
      let updated_posts = dict.insert(state.posts, post_id, updated_post)

      case dict.get(state.users, post.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma - 1)
          let updated_users =
            dict.insert(state.users, post.author_id, updated_author)
          Ok(EngineState(..state, posts: updated_posts, users: updated_users))
        }
        Error(_) -> Ok(EngineState(..state, posts: updated_posts))
      }
    }
  }
}

fn upvote_comment(
  state: EngineState,
  comment_id: CommentId,
) -> Result(EngineState, Error) {
  case dict.get(state.comments, comment_id) {
    Error(_) -> Error(CommentNotFound)
    Ok(comment) -> {
      let updated_comment = Comment(..comment, upvotes: comment.upvotes + 1)
      let updated_comments =
        dict.insert(state.comments, comment_id, updated_comment)

      case dict.get(state.users, comment.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma + 1)
          let updated_users =
            dict.insert(state.users, comment.author_id, updated_author)
          Ok(
            EngineState(
              ..state,
              comments: updated_comments,
              users: updated_users,
            ),
          )
        }
        Error(_) -> Ok(EngineState(..state, comments: updated_comments))
      }
    }
  }
}

fn downvote_comment(
  state: EngineState,
  comment_id: CommentId,
) -> Result(EngineState, Error) {
  case dict.get(state.comments, comment_id) {
    Error(_) -> Error(CommentNotFound)
    Ok(comment) -> {
      let updated_comment = Comment(..comment, downvotes: comment.downvotes + 1)
      let updated_comments =
        dict.insert(state.comments, comment_id, updated_comment)

      case dict.get(state.users, comment.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma - 1)
          let updated_users =
            dict.insert(state.users, comment.author_id, updated_author)
          Ok(
            EngineState(
              ..state,
              comments: updated_comments,
              users: updated_users,
            ),
          )
        }
        Error(_) -> Ok(EngineState(..state, comments: updated_comments))
      }
    }
  }
}

fn get_user_feed(
  state: EngineState,
  user_id: UserId,
) -> Result(List(Post), Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(user) -> {
      let posts =
        list.flat_map(user.joined_subreddits, fn(subreddit_id) {
          case dict.get(state.subreddits, subreddit_id) {
            Ok(subreddit) ->
              list.filter_map(subreddit.posts, fn(post_id) {
                dict.get(state.posts, post_id)
              })
            Error(_) -> []
          }
        })

      let sorted_posts =
        list.sort(posts, fn(a, b) { int.compare(b.timestamp, a.timestamp) })

      Ok(sorted_posts)
    }
  }
}

fn send_message(
  state: EngineState,
  from_user_id: UserId,
  to_user_id: UserId,
  content: String,
  timestamp: Int,
) -> Result(#(MessageId, EngineState), Error) {
  case get_user(state, from_user_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case get_user(state, to_user_id) {
        Error(e) -> Error(e)
        Ok(_) ->
          case string.is_empty(content) {
            True -> Error(InvalidInput)
            False -> {
              let #(message_id, new_state) = generate_id(state, "msg_")
              let message =
                DirectMessage(
                  id: message_id,
                  from_user_id: from_user_id,
                  to_user_id: to_user_id,
                  content: content,
                  timestamp: timestamp,
                  is_read: False,
                )
              let updated_messages =
                dict.insert(new_state.messages, message_id, message)
              Ok(#(
                message_id,
                EngineState(..new_state, messages: updated_messages),
              ))
            }
          }
      }
  }
}

fn get_user_messages(
  state: EngineState,
  user_id: UserId,
) -> Result(List(DirectMessage), Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(_) -> {
      let messages =
        dict.values(state.messages)
        |> list.filter(fn(msg) { msg.to_user_id == user_id })
        |> list.sort(fn(a, b) { int.compare(b.timestamp, a.timestamp) })

      Ok(messages)
    }
  }
}

fn reply_to_message(
  state: EngineState,
  original_message_id: MessageId,
  content: String,
  timestamp: Int,
) -> Result(#(MessageId, EngineState), Error) {
  case dict.get(state.messages, original_message_id) {
    Error(_) -> Error(MessageNotFound)
    Ok(original_message) ->
      send_message(
        state,
        original_message.to_user_id,
        original_message.from_user_id,
        content,
        timestamp,
      )
  }
}
