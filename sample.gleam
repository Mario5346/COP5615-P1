import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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

pub type RedditEngine {
  RedditEngine(
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

// ========== Engine Initialization ==========

pub fn new() -> RedditEngine {
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

// ========== User Management ==========

pub fn register_user(
  engine: RedditEngine,
  username: String,
) -> Result(#(UserId, RedditEngine), Error) {
  case string.is_empty(username) {
    True -> Error(InvalidInput)
    False -> {
      let #(user_id, new_engine) = generate_id(engine, "user_")
      let user =
        User(id: user_id, username: username, karma: 0, joined_subreddits: [])
      let updated_users = dict.insert(new_engine.users, user_id, user)
      Ok(#(user_id, RedditEngine(..new_engine, users: updated_users)))
    }
  }
}

pub fn get_user(engine: RedditEngine, user_id: UserId) -> Result(User, Error) {
  case dict.get(engine.users, user_id) {
    Ok(user) -> Ok(user)
    Error(_) -> Error(UserNotFound)
  }
}

// ========== Subreddit Management ==========

pub fn create_subreddit(
  engine: RedditEngine,
  creator_id: UserId,
  name: String,
  description: String,
) -> Result(#(SubredditId, RedditEngine), Error) {
  case get_user(engine, creator_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case string.is_empty(name) {
        True -> Error(InvalidInput)
        False -> {
          let #(subreddit_id, new_engine) = generate_id(engine, "sub_")
          let subreddit =
            Subreddit(
              id: subreddit_id,
              name: name,
              description: description,
              members: [creator_id],
              posts: [],
            )
          let updated_subreddits =
            dict.insert(new_engine.subreddits, subreddit_id, subreddit)

          // Add subreddit to user's joined list
          case dict.get(new_engine.users, creator_id) {
            Ok(user) -> {
              let updated_user =
                User(..user, joined_subreddits: [
                  subreddit_id,
                  ..user.joined_subreddits
                ])
              let updated_users =
                dict.insert(new_engine.users, creator_id, updated_user)
              Ok(#(
                subreddit_id,
                RedditEngine(
                  ..new_engine,
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

pub fn join_subreddit(
  engine: RedditEngine,
  user_id: UserId,
  subreddit_id: SubredditId,
) -> Result(RedditEngine, Error) {
  case get_user(engine, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(engine.subreddits, subreddit_id) {
        Error(_) -> Error(SubredditNotFound)
        Ok(subreddit) ->
          case list.contains(subreddit.members, user_id) {
            True -> Error(AlreadyJoined)
            False -> {
              let updated_subreddit =
                Subreddit(..subreddit, members: [user_id, ..subreddit.members])
              let updated_subreddits =
                dict.insert(engine.subreddits, subreddit_id, updated_subreddit)

              let updated_user =
                User(..user, joined_subreddits: [
                  subreddit_id,
                  ..user.joined_subreddits
                ])
              let updated_users =
                dict.insert(engine.users, user_id, updated_user)

              Ok(
                RedditEngine(
                  ..engine,
                  subreddits: updated_subreddits,
                  users: updated_users,
                ),
              )
            }
          }
      }
  }
}

pub fn leave_subreddit(
  engine: RedditEngine,
  user_id: UserId,
  subreddit_id: SubredditId,
) -> Result(RedditEngine, Error) {
  case get_user(engine, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(engine.subreddits, subreddit_id) {
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
                dict.insert(engine.subreddits, subreddit_id, updated_subreddit)

              let updated_user =
                User(
                  ..user,
                  joined_subreddits: list.filter(user.joined_subreddits, fn(id) {
                    id != subreddit_id
                  }),
                )
              let updated_users =
                dict.insert(engine.users, user_id, updated_user)

              Ok(
                RedditEngine(
                  ..engine,
                  subreddits: updated_subreddits,
                  users: updated_users,
                ),
              )
            }
          }
      }
  }
}

// ========== Post Management ==========

pub fn create_post(
  engine: RedditEngine,
  author_id: UserId,
  subreddit_id: SubredditId,
  title: String,
  content: String,
  timestamp: Int,
) -> Result(#(PostId, RedditEngine), Error) {
  case get_user(engine, author_id) {
    Error(e) -> Error(e)
    Ok(_user) ->
      case dict.get(engine.subreddits, subreddit_id) {
        Error(_) -> Error(SubredditNotFound)
        Ok(subreddit) ->
          case list.contains(subreddit.members, author_id) {
            False -> Error(NotAMember)
            True ->
              case string.is_empty(title) {
                True -> Error(InvalidInput)
                False -> {
                  let #(post_id, new_engine) = generate_id(engine, "post_")
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
                    dict.insert(new_engine.posts, post_id, post)

                  let updated_subreddit =
                    Subreddit(..subreddit, posts: [post_id, ..subreddit.posts])
                  let updated_subreddits =
                    dict.insert(
                      new_engine.subreddits,
                      subreddit_id,
                      updated_subreddit,
                    )

                  Ok(#(
                    post_id,
                    RedditEngine(
                      ..new_engine,
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

pub fn get_post(engine: RedditEngine, post_id: PostId) -> Result(Post, Error) {
  case dict.get(engine.posts, post_id) {
    Ok(post) -> Ok(post)
    Error(_) -> Error(PostNotFound)
  }
}

// ========== Comment Management ==========

pub fn create_comment(
  engine: RedditEngine,
  author_id: UserId,
  post_id: PostId,
  parent_comment_id: Option(CommentId),
  content: String,
  timestamp: Int,
) -> Result(#(CommentId, RedditEngine), Error) {
  case get_user(engine, author_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case dict.get(engine.posts, post_id) {
        Error(_) -> Error(PostNotFound)
        Ok(post) ->
          case string.is_empty(content) {
            True -> Error(InvalidInput)
            False -> {
              // Verify parent comment exists if provided
              case parent_comment_id {
                Some(parent_id) ->
                  case dict.get(engine.comments, parent_id) {
                    Error(_) -> Error(CommentNotFound)
                    Ok(_) ->
                      create_comment_internal(
                        engine,
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
                    engine,
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
  engine: RedditEngine,
  author_id: UserId,
  post_id: PostId,
  parent_comment_id: Option(CommentId),
  content: String,
  timestamp: Int,
  post: Post,
) -> Result(#(CommentId, RedditEngine), Error) {
  let #(comment_id, new_engine) = generate_id(engine, "comment_")
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
  let updated_comments = dict.insert(new_engine.comments, comment_id, comment)

  // Update post with new comment
  let updated_post = Post(..post, comments: [comment_id, ..post.comments])
  let updated_posts = dict.insert(new_engine.posts, post_id, updated_post)

  // If this is a reply, update parent comment
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
    RedditEngine(..new_engine, comments: final_comments, posts: updated_posts),
  ))
}

// ========== Voting & Karma ==========

pub fn upvote_post(
  engine: RedditEngine,
  post_id: PostId,
) -> Result(RedditEngine, Error) {
  case dict.get(engine.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, upvotes: post.upvotes + 1)
      let updated_posts = dict.insert(engine.posts, post_id, updated_post)

      // Update author karma
      case dict.get(engine.users, post.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma + 1)
          let updated_users =
            dict.insert(engine.users, post.author_id, updated_author)
          Ok(RedditEngine(..engine, posts: updated_posts, users: updated_users))
        }
        Error(_) -> Ok(RedditEngine(..engine, posts: updated_posts))
      }
    }
  }
}

pub fn downvote_post(
  engine: RedditEngine,
  post_id: PostId,
) -> Result(RedditEngine, Error) {
  case dict.get(engine.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, downvotes: post.downvotes + 1)
      let updated_posts = dict.insert(engine.posts, post_id, updated_post)

      // Update author karma
      case dict.get(engine.users, post.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma - 1)
          let updated_users =
            dict.insert(engine.users, post.author_id, updated_author)
          Ok(RedditEngine(..engine, posts: updated_posts, users: updated_users))
        }
        Error(_) -> Ok(RedditEngine(..engine, posts: updated_posts))
      }
    }
  }
}

pub fn upvote_comment(
  engine: RedditEngine,
  comment_id: CommentId,
) -> Result(RedditEngine, Error) {
  case dict.get(engine.comments, comment_id) {
    Error(_) -> Error(CommentNotFound)
    Ok(comment) -> {
      let updated_comment = Comment(..comment, upvotes: comment.upvotes + 1)
      let updated_comments =
        dict.insert(engine.comments, comment_id, updated_comment)

      // Update author karma
      case dict.get(engine.users, comment.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma + 1)
          let updated_users =
            dict.insert(engine.users, comment.author_id, updated_author)
          Ok(
            RedditEngine(
              ..engine,
              comments: updated_comments,
              users: updated_users,
            ),
          )
        }
        Error(_) -> Ok(RedditEngine(..engine, comments: updated_comments))
      }
    }
  }
}

pub fn downvote_comment(
  engine: RedditEngine,
  comment_id: CommentId,
) -> Result(RedditEngine, Error) {
  case dict.get(engine.comments, comment_id) {
    Error(_) -> Error(CommentNotFound)
    Ok(comment) -> {
      let updated_comment = Comment(..comment, downvotes: comment.downvotes + 1)
      let updated_comments =
        dict.insert(engine.comments, comment_id, updated_comment)

      // Update author karma
      case dict.get(engine.users, comment.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma - 1)
          let updated_users =
            dict.insert(engine.users, comment.author_id, updated_author)
          Ok(
            RedditEngine(
              ..engine,
              comments: updated_comments,
              users: updated_users,
            ),
          )
        }
        Error(_) -> Ok(RedditEngine(..engine, comments: updated_comments))
      }
    }
  }
}

// ========== Feed ==========

pub fn get_user_feed(
  engine: RedditEngine,
  user_id: UserId,
) -> Result(List(Post), Error) {
  case get_user(engine, user_id) {
    Error(e) -> Error(e)
    Ok(user) -> {
      // Get all posts from joined subreddits
      let posts =
        list.flat_map(user.joined_subreddits, fn(subreddit_id) {
          case dict.get(engine.subreddits, subreddit_id) {
            Ok(subreddit) ->
              list.filter_map(subreddit.posts, fn(post_id) {
                dict.get(engine.posts, post_id)
              })
            Error(_) -> []
          }
        })

      // Sort by timestamp (newest first)
      let sorted_posts =
        list.sort(posts, fn(a, b) { int.compare(b.timestamp, a.timestamp) })

      Ok(sorted_posts)
    }
  }
}

// ========== Direct Messages ==========

pub fn send_message(
  engine: RedditEngine,
  from_user_id: UserId,
  to_user_id: UserId,
  content: String,
  timestamp: Int,
) -> Result(#(MessageId, RedditEngine), Error) {
  case get_user(engine, from_user_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case get_user(engine, to_user_id) {
        Error(e) -> Error(e)
        Ok(_) ->
          case string.is_empty(content) {
            True -> Error(InvalidInput)
            False -> {
              let #(message_id, new_engine) = generate_id(engine, "msg_")
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
                dict.insert(new_engine.messages, message_id, message)
              Ok(#(
                message_id,
                RedditEngine(..new_engine, messages: updated_messages),
              ))
            }
          }
      }
  }
}

pub fn get_user_messages(
  engine: RedditEngine,
  user_id: UserId,
) -> Result(List(DirectMessage), Error) {
  case get_user(engine, user_id) {
    Error(e) -> Error(e)
    Ok(_) -> {
      let messages =
        dict.values(engine.messages)
        |> list.filter(fn(msg) { msg.to_user_id == user_id })
        |> list.sort(fn(a, b) { int.compare(b.timestamp, a.timestamp) })

      Ok(messages)
    }
  }
}

pub fn reply_to_message(
  engine: RedditEngine,
  original_message_id: MessageId,
  content: String,
  timestamp: Int,
) -> Result(#(MessageId, RedditEngine), Error) {
  case dict.get(engine.messages, original_message_id) {
    Error(_) -> Error(MessageNotFound)
    Ok(original_message) ->
      send_message(
        engine,
        original_message.to_user_id,
        original_message.from_user_id,
        content,
        timestamp,
      )
  }
}

pub fn mark_message_as_read(
  engine: RedditEngine,
  message_id: MessageId,
) -> Result(RedditEngine, Error) {
  case dict.get(engine.messages, message_id) {
    Error(_) -> Error(MessageNotFound)
    Ok(message) -> {
      let updated_message = DirectMessage(..message, is_read: True)
      let updated_messages =
        dict.insert(engine.messages, message_id, updated_message)
      Ok(RedditEngine(..engine, messages: updated_messages))
    }
  }
}
