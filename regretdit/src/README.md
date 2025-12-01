# Project 4.2: Regretdit REST API Implementation

### Step 1: Start the Server

Open a terminal and run:
```bash
gleam run -m api_server
```

You should see:
```
 Regretdit API Server started on http://[Server IP]:8080
 API Documentation:
   POST   /api/users                    - Register user
   GET    /api/users/:id                - Get user
   ...
```
In our case, our server IP is 192.168.0.169

### Step 3: Test with Multiple Clients

**Run the Gleam demo client** (another machine):
```bash
gleam run -m client
```

**Manual testing with curl** (see examples below)

## - Complete API Reference

### User Endpoints

#### Register User
```bash
curl -X POST http://[Server IP]:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"Srikar"}'

# Response:
# {"success":true,"user_id":"user_1","username":"Srikar"}
```

#### Get User
```bash
curl http://[Server IP]:8080/api/users/user_1

# Response:
# {"id":"user_1","username":"alice","karma":0,"joined_subregretdits":[]}
```

#### Get User Feed
```bash
curl http://[Server IP]:8080/api/users/user_1/feed

# Response: Array of posts from joined subregretdits
```

#### Get User Messages
```bash
curl http://[Server IP]:8080/api/users/user_1/messages

# Response: Array of direct messages
```

### Subregretdit Endpoints

#### Create Subregretdit
```bash
curl -X POST http://[Server IP]:8080/api/subregretdits \
  -H "Content-Type: application/json" \
  -d '{"creator_id":"user_1","name":"r/gleam","description":"Gleam programming"}'

# Response:
# {"success":true,"subregretdit_id":"sub_1"}
```

#### List All Subregretdits
```bash
curl http://[Server IP]:8080/api/subregretdits

# Response: Array of all subregretdits with member/post counts
```

#### Get Subregretdit Details
```bash
curl http://[Server IP]:8080/api/subregretdits/sub_1

# Response: Full subregretdit details including members and posts
```

#### Join Subregretdit
```bash
curl -X POST http://[Server IP]:8080/api/subregretdits/sub_1/join \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user_2"}'

# Response:
# {"success":true}
```

### Post Endpoints

#### Create Post
```bash
curl -X POST http://[Server IP]:8080/api/posts \
  -H "Content-Type: application/json" \
  -d '{"author_id":"user_1","subregretdit_id":"sub_1","title":"Hello!","content":"First post"}'

# Response:
# {"success":true,"post_id":"post_1"}
```

#### Get Post
```bash
curl http://[Server IP]:8080/api/posts/post_1

# Response: Full post details with votes and comments
```

#### Upvote Post
```bash
curl -X POST http://[Server IP]:8080/api/posts/post_1/upvote

# Response:
# {"success":true}
```

#### Downvote Post
```bash
curl -X POST http://[Server IP]:8080/api/posts/post_1/downvote

# Response:
# {"success":true}
```

### Comment Endpoints

#### Create Comment
```bash
curl -X POST http://[Server IP]:8080/api/comments \
  -H "Content-Type: application/json" \
  -d '{"author_id":"user_2","post_id":"post_1","content":"Great post!"}'

# Response:
# {"success":true,"comment_id":"comment_1"}
```

#### Upvote Comment
```bash
curl -X POST http://[Server IP]:8080/api/comments/comment_1/upvote

# Response:
# {"success":true}
```

#### Downvote Comment
```bash
curl -X POST http://[Server IP]:8080/api/comments/comment_1/downvote

# Response:
# {"success":true}
```

### Message Endpoints

#### Send Direct Message
```bash
curl -X POST http://[Server IP]:8080/api/messages \
  -H "Content-Type: application/json" \
  -d '{"from_user_id":"user_1","to_user_id":"user_2","content":"Hello!"}'

# Response:
# {"success":true,"message_id":"msg_1"}
```

### System Endpoints

#### Get Platform Statistics
```bash
curl http://[Server IP]:8080/api/stats

# Response:
# {"posts":10,"comments":25,"upvotes":50,"downvotes":5,"dms":8,"subs_joined":15}
```

#### Health Check
```bash
curl http://[Server IP]:8080/health

# Response:
# {"status":"healthy"}
```
### Error Handling
- **400 Bad Request**: Invalid input, already joined, etc.
- **404 Not Found**: User/post/subregretdit not found
- **500 Internal Server Error**: Timeout or system error
