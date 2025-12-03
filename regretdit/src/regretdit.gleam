import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string

// ========== Types ==========

pub type UserId =
  String

pub type SubregretditId =
  String

pub type PostId =
  String

pub type CommentId =
  String

pub type MessageId =
  String

pub type PublicKey =
  String

pub type Signature =
  String

pub type Stats {
  Stats(
    posts: Int,
    comments: Int,
    upvotes: Int,
    downvotes: Int,
    dms: Int,
    subs_joined: Int,
  )
}

pub type User {
  User(
    id: UserId,
    username: String,
    karma: Int,
    joined_subregretdits: List(SubregretditId),
    public_key: PublicKey,
  )
}

pub type Subregretdit {
  Subregretdit(
    id: SubregretditId,
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
    subregretdit_id: SubregretditId,
    title: String,
    content: String,
    upvotes: Int,
    downvotes: Int,
    comments: List(CommentId),
    timestamp: Int,
    signature: Signature,
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
    subregretdits: Dict(SubregretditId, Subregretdit),
    posts: Dict(PostId, Post),
    comments: Dict(CommentId, Comment),
    messages: Dict(MessageId, DirectMessage),
    next_id: Int,
    stats: Stats,
  )
}

pub type Error {
  UserNotFound
  SubregretditNotFound
  PostNotFound
  CommentNotFound
  MessageNotFound
  AlreadyJoined
  NotAMember
  Unauthorized
  InvalidInput
  InvalidSignature
  CryptoError
}

// ========== Actor Messages ==========

pub type EngineMessage {
  RegisterUser(
    username: String,
    public_key: PublicKey,
    reply: Subject(Result(UserId, Error)),
  )
  GetUserPublicKey(user_id: UserId, reply: Subject(Result(PublicKey, Error)))
  CreateSubregretdit(
    creator_id: UserId,
    name: String,
    description: String,
    reply: Subject(Result(SubregretditId, Error)),
  )
  JoinSubregretdit(
    user_id: UserId,
    subregretdit_id: SubregretditId,
    reply: Subject(Result(Nil, Error)),
  )
  LeaveSubregretdit(
    user_id: UserId,
    subregretdit_id: SubregretditId,
    reply: Subject(Result(Nil, Error)),
  )
  CreatePost(
    author_id: UserId,
    subregretdit_id: SubregretditId,
    title: String,
    content: String,
    timestamp: Int,
    signature: Signature,
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
  GetSubregretdit(
    subregretdit_id: SubregretditId,
    reply: Subject(Result(Subregretdit, Error)),
  )
  GetAllSubregretdits(reply: Subject(List(Subregretdit)))
  GetStats(reply: Subject(Stats))
  Shutdown
}

// ========== Actor Implementation ==========
fn create_post_message(
  author_id: UserId,
  subregretdit_id: SubregretditId,
  title: String,
  content: String,
  timestamp: Int,
) -> String {
  author_id
  <> "|"
  <> subregretdit_id
  <> "|"
  <> title
  <> "|"
  <> content
  <> "|"
  <> int.to_string(timestamp)
}

fn verify_signature(
  message: String,
  signature_b64: Signature,
  _public_key_pem: PublicKey,
) -> Bool {
  case bit_array.base64_decode(signature_b64) {
    Ok(_signature_bytes) -> {
      let message_bytes = bit_array.from_string(message)
      let _message_hash = crypto.hash(crypto.Sha256, message_bytes)
      True
    }
    Error(_) -> False
  }
}

fn handle_message(
  state: EngineState,
  message: EngineMessage,
) -> actor.Next(EngineState, EngineMessage) {
  case message {
    RegisterUser(username, public_key, reply) -> {
      let result = register_user(state, username, public_key)
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
    GetUserPublicKey(user_id, reply) -> {
      let result = get_user_public_key(state, user_id)
      process.send(reply, result)
      actor.continue(state)
    }

    CreateSubregretdit(creator_id, name, description, reply) -> {
      let result = create_subregretdit(state, creator_id, name, description)
      case result {
        Ok(#(subregretdit_id, new_state)) -> {
          // io.println("Created subregretdit: " <> name)
          // print_subregretdits(new_state)
          process.send(reply, Ok(subregretdit_id))
          actor.continue(new_state)
        }
        Error(e) -> {
          process.send(reply, Error(e))
          actor.continue(state)
        }
      }
    }

    JoinSubregretdit(user_id, subregretdit_id, reply) -> {
      let result = join_subregretdit(state, user_id, subregretdit_id)
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

    LeaveSubregretdit(user_id, subregretdit_id, reply) -> {
      let result = leave_subregretdit(state, user_id, subregretdit_id)
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

    CreatePost(
      author_id,
      subregretdit_id,
      title,
      content,
      timestamp,
      signature,
      reply,
    ) -> {
      let result =
        create_post(
          state,
          author_id,
          subregretdit_id,
          title,
          content,
          timestamp,
          signature,
        )
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
      // io.println("downvote comment called")
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

    GetSubregretdit(subregretdit_id, reply) -> {
      let result = get_subregretdit(state, subregretdit_id)
      process.send(reply, result)
      actor.continue(state)
    }

    GetAllSubregretdits(reply) -> {
      let subregretdits = dict.values(state.subregretdits)
      process.send(reply, subregretdits)
      actor.continue(state)
    }

    GetStats(reply) -> {
      process.send(reply, state.stats)
      actor.continue(state)
    }

    Shutdown -> actor.stop()
  }
}

pub fn start() {
  let initial_state =
    EngineState(
      users: dict.new(),
      subregretdits: dict.new(),
      posts: dict.new(),
      comments: dict.new(),
      messages: dict.new(),
      next_id: 1,
      stats: Stats(
        posts: 0,
        comments: 0,
        upvotes: 0,
        downvotes: 0,
        dms: 0,
        subs_joined: 0,
      ),
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
  public_key: PublicKey,
) -> Result(#(UserId, EngineState), Error) {
  case string.is_empty(username) {
    True -> Error(InvalidInput)
    False -> {
      case string.is_empty(public_key) {
        True -> Error(InvalidInput)
        False -> {
          let #(user_id, new_state) = generate_id(state, "user_")
          let user =
            User(
              id: user_id,
              username: username,
              karma: 0,
              joined_subregretdits: [],
              public_key: public_key,
            )
          let updated_users = dict.insert(new_state.users, user_id, user)
          Ok(#(user_id, EngineState(..new_state, users: updated_users)))
        }
      }
    }
  }
}

fn get_user_public_key(
  state: EngineState,
  user_id: UserId,
) -> Result(PublicKey, Error) {
  case dict.get(state.users, user_id) {
    Ok(user) -> Ok(user.public_key)
    Error(_) -> Error(UserNotFound)
  }
}

fn get_user(state: EngineState, user_id: UserId) -> Result(User, Error) {
  case dict.get(state.users, user_id) {
    Ok(user) -> Ok(user)
    Error(_) -> Error(UserNotFound)
  }
}

fn get_subregretdit(
  state: EngineState,
  subregretdit_id: SubregretditId,
) -> Result(Subregretdit, Error) {
  case dict.get(state.subregretdits, subregretdit_id) {
    Ok(subregretdit) -> Ok(subregretdit)
    Error(_) -> Error(SubregretditNotFound)
  }
}

fn create_subregretdit(
  state: EngineState,
  creator_id: UserId,
  name: String,
  description: String,
) -> Result(#(SubregretditId, EngineState), Error) {
  case get_user(state, creator_id) {
    Error(e) -> Error(e)
    Ok(_) ->
      case string.is_empty(name) {
        True -> Error(InvalidInput)
        False -> {
          let #(subregretdit_id, new_state) = generate_id(state, "sub_")
          let subregretdit =
            Subregretdit(
              id: subregretdit_id,
              name: name,
              description: description,
              members: [creator_id],
              posts: [],
            )
          let updated_subregretdits =
            dict.insert(new_state.subregretdits, subregretdit_id, subregretdit)

          case dict.get(new_state.users, creator_id) {
            Ok(user) -> {
              let updated_user =
                User(..user, joined_subregretdits: [
                  subregretdit_id,
                  ..user.joined_subregretdits
                ])
              let updated_users =
                dict.insert(new_state.users, creator_id, updated_user)
              Ok(#(
                subregretdit_id,
                EngineState(
                  ..new_state,
                  subregretdits: updated_subregretdits,
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

fn join_subregretdit(
  state: EngineState,
  user_id: UserId,
  subregretdit_id: SubregretditId,
) -> Result(EngineState, Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(state.subregretdits, subregretdit_id) {
        Error(_) -> Error(SubregretditNotFound)
        Ok(subregretdit) ->
          case list.contains(subregretdit.members, user_id) {
            True -> Error(AlreadyJoined)
            False -> {
              let updated_subregretdit =
                Subregretdit(..subregretdit, members: [
                  user_id,
                  ..subregretdit.members
                ])
              let updated_subregretdits =
                dict.insert(
                  state.subregretdits,
                  subregretdit_id,
                  updated_subregretdit,
                )

              let updated_user =
                User(..user, joined_subregretdits: [
                  subregretdit_id,
                  ..user.joined_subregretdits
                ])
              let updated_users =
                dict.insert(state.users, user_id, updated_user)
              Ok(
                EngineState(
                  ..state,
                  subregretdits: updated_subregretdits,
                  users: updated_users,
                  stats: Stats(
                    posts: state.stats.posts,
                    comments: state.stats.comments,
                    upvotes: state.stats.upvotes,
                    downvotes: state.stats.downvotes,
                    dms: state.stats.dms,
                    subs_joined: state.stats.subs_joined + 1,
                  ),
                ),
              )
            }
          }
      }
  }
}

fn leave_subregretdit(
  state: EngineState,
  user_id: UserId,
  subregretdit_id: SubregretditId,
) -> Result(EngineState, Error) {
  case get_user(state, user_id) {
    Error(e) -> Error(e)
    Ok(user) ->
      case dict.get(state.subregretdits, subregretdit_id) {
        Error(_) -> Error(SubregretditNotFound)
        Ok(subregretdit) ->
          case list.contains(subregretdit.members, user_id) {
            False -> Error(NotAMember)
            True -> {
              let updated_subregretdit =
                Subregretdit(
                  ..subregretdit,
                  members: list.filter(subregretdit.members, fn(id) {
                    id != user_id
                  }),
                )
              let updated_subregretdits =
                dict.insert(
                  state.subregretdits,
                  subregretdit_id,
                  updated_subregretdit,
                )

              let updated_user =
                User(
                  ..user,
                  joined_subregretdits: list.filter(
                    user.joined_subregretdits,
                    fn(id) { id != subregretdit_id },
                  ),
                )
              let updated_users =
                dict.insert(state.users, user_id, updated_user)

              Ok(
                EngineState(
                  ..state,
                  subregretdits: updated_subregretdits,
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
  subregretdit_id: SubregretditId,
  title: String,
  content: String,
  timestamp: Int,
  signature: Signature,
) -> Result(#(PostId, EngineState), Error) {
  case get_user(state, author_id) {
    Error(e) -> Error(e)
    Ok(user) -> {
      // Verify the signature
      let message =
        create_post_message(
          author_id,
          subregretdit_id,
          title,
          content,
          timestamp,
        )
      case verify_signature(message, signature, user.public_key) {
        False -> Error(InvalidSignature)
        True -> {
          case dict.get(state.subregretdits, subregretdit_id) {
            Error(_) -> Error(SubregretditNotFound)
            Ok(subregretdit) ->
              case list.contains(subregretdit.members, author_id) {
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
                          subregretdit_id: subregretdit_id,
                          title: title,
                          content: content,
                          upvotes: 0,
                          downvotes: 0,
                          comments: [],
                          timestamp: timestamp,
                          signature: signature,
                        )
                      let updated_posts =
                        dict.insert(new_state.posts, post_id, post)

                      let updated_subregretdit =
                        Subregretdit(..subregretdit, posts: [
                          post_id,
                          ..subregretdit.posts
                        ])
                      let updated_subregretdits =
                        dict.insert(
                          new_state.subregretdits,
                          subregretdit_id,
                          updated_subregretdit,
                        )

                      Ok(#(
                        post_id,
                        EngineState(
                          ..new_state,
                          posts: updated_posts,
                          subregretdits: updated_subregretdits,
                          stats: Stats(
                            ..state.stats,
                            posts: state.stats.posts + 1,
                          ),
                        ),
                      ))
                    }
                  }
              }
          }
        }
      }
    }
  }
}

fn get_post(state: EngineState, post_id: PostId) -> Result(Post, Error) {
  case dict.get(state.posts, post_id) {
    Ok(post) -> {
      // Verify signature when post is retrieved
      case get_user(state, post.author_id) {
        Ok(user) -> {
          let message =
            create_post_message(
              post.author_id,
              post.subregretdit_id,
              post.title,
              post.content,
              post.timestamp,
            )
          case verify_signature(message, post.signature, user.public_key) {
            True -> Ok(post)
            False -> Error(InvalidSignature)
          }
        }
        Error(_) -> Error(UserNotFound)
      }
    }
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
    EngineState(
      ..new_state,
      comments: final_comments,
      posts: updated_posts,
      stats: Stats(..state.stats, comments: state.stats.comments + 1),
    ),
  ))
}

fn upvote_post(
  state: EngineState,
  post_id: PostId,
) -> Result(EngineState, Error) {
  // io.println("upvote post")
  case dict.get(state.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, upvotes: post.upvotes + 1)
      let updated_posts = dict.insert(state.posts, post_id, updated_post)

      case dict.get(state.users, post.author_id) {
        Ok(author) -> {
          // io.println("karma+1")
          let updated_author = User(..author, karma: author.karma + 1)
          let updated_users =
            dict.insert(state.users, post.author_id, updated_author)
          Ok(
            EngineState(
              ..state,
              posts: updated_posts,
              users: updated_users,
              stats: Stats(..state.stats, upvotes: state.stats.upvotes + 1),
            ),
          )
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
  // io.println("downvote post")
  case dict.get(state.posts, post_id) {
    Error(_) -> Error(PostNotFound)
    Ok(post) -> {
      let updated_post = Post(..post, downvotes: post.downvotes + 1)
      let updated_posts = dict.insert(state.posts, post_id, updated_post)

      case dict.get(state.users, post.author_id) {
        Ok(author) -> {
          // io.println(
          //   "Author ID: "
          //   <> author.id
          //   <> "-- karma: "
          //   <> int.to_string(author.karma),
          // )
          let updated_author = User(..author, karma: author.karma - 1)
          let updated_users =
            dict.insert(state.users, post.author_id, updated_author)
          Ok(
            EngineState(
              ..state,
              posts: updated_posts,
              users: updated_users,
              stats: Stats(..state.stats, downvotes: state.stats.downvotes + 1),
            ),
          )
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
  // io.println("upvote comment")
  case dict.get(state.comments, comment_id) {
    Error(_) -> Error(CommentNotFound)
    Ok(comment) -> {
      let updated_comment = Comment(..comment, upvotes: comment.upvotes + 1)
      let updated_comments =
        dict.insert(state.comments, comment_id, updated_comment)

      case dict.get(state.users, comment.author_id) {
        Ok(author) -> {
          let updated_author = User(..author, karma: author.karma + 1)
          // io.println("Author Karma: " <> int.to_string(author.karma))
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
        Error(_) ->
          Ok(
            EngineState(
              ..state,
              comments: updated_comments,
              stats: Stats(..state.stats, upvotes: state.stats.upvotes + 1),
            ),
          )
      }
    }
  }
}

fn downvote_comment(
  state: EngineState,
  comment_id: CommentId,
) -> Result(EngineState, Error) {
  // io.println("downvote comment")
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
          // io.println("Author Karma: " <> int.to_string(author.karma))
          Ok(
            EngineState(
              ..state,
              comments: updated_comments,
              users: updated_users,
            ),
          )
        }
        Error(_) ->
          Ok(
            EngineState(
              ..state,
              comments: updated_comments,
              stats: Stats(..state.stats, downvotes: state.stats.downvotes + 1),
            ),
          )
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
        list.flat_map(user.joined_subregretdits, fn(subregretdit_id) {
          case dict.get(state.subregretdits, subregretdit_id) {
            Ok(subregretdit) ->
              list.filter_map(subregretdit.posts, fn(post_id) {
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
                EngineState(
                  ..new_state,
                  messages: updated_messages,
                  stats: Stats(..state.stats, dms: state.stats.dms + 1),
                ),
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
