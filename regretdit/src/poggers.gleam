// src/db_demo.gleam
import gleam/erlang/process.{new_name}
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/static_supervisor

//import gleam/result.{Ok, Error}
import gleam/dynamic/decode
import pog

pub fn main() {
  // Create a unique process name for the PostgreSQL connection pool
  // We don't annotate the type of pool_name; let Gleam infer it.
  let pool_name = new_name("db_connection")

  // Hardcoded connection settings — change these to match your setup
  let db_host = "localhost"
  let db_name = "regretdit"
  let db_user = "admin"
  let db_pass = "12345"
  let db_port = 5432

  start_with_config(
    pool_name,
    db_host,
    db_name,
    db_user,
    option.Some(db_pass),
    db_port,
  )
}

fn start_with_config(
  pool_name,
  host: String,
  database: String,
  user: String,
  password: option.Option(String),
  port: Int,
) {
  // Build a pog pool config from constants
  let child =
    pog.default_config(pool_name)
    |> pog.host(host)
    |> pog.database(database)
    |> pog.user(user)
    |> pog.password(password)
    |> pog.port(port)
    |> pog.pool_size(10)
    |> pog.supervised

  // Start supervisor for the DB pool
  case
    static_supervisor.new(static_supervisor.RestForOne)
    |> static_supervisor.add(child)
    |> static_supervisor.start
  {
    Ok(_) -> {
      io.println("✅ Started PostgreSQL pool successfully.")
      let conn = pog.named_connection(pool_name)
      io.println("Connected to PostgreSQL — running test query...")
      // let query = "SELECT now()::text"
      let query =
        "CREATE TABLE IF NOT EXISTS Users (
        id NUMERIC NOT NULL UNIQUE,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      );"

      let i = "4"
      let u = "MARIO4"
      let p = "password"

      // let new_user =
      //   "INSERT INTO Users VALUES(
      //   3,
      //   'MARIO3',
      //   'password'
      // );"
      let new_user =
        "INSERT INTO Users VALUES("
        <> i
        <> ", '"
        <> u
        <> "', '"
        <> p
        <> "'"
        <> ");"

      let get_users = "SELECT * FROM Users WHERE id = 4"

      //run_test_query(conn, query)
      //run_test_query(conn, new_user)
      //run_test_query(conn, get_users)

      setup_db_query(conn)
      //   case pog.named_connection(pool_name) {
      //     Ok(conn) -> {
      //       io.println("Connected to PostgreSQL — running test query...")
      //       run_test_query(conn)
      //     }
      //     Error(e) -> {
      //       io.println("ERROR: pog.named_connection failed: " <> e)
      //     }
      //   }
    }
    Error(e) -> {
      io.println("ERROR: Failed to start supervisor: ")
      echo e
      Nil
    }
  }
}

// Run a simple SQL query and print the result
fn run_test_query(conn: pog.Connection, query: String) {
  //let query = "SELECT now()::text"

  //Decoder for first column as a string
  // let decoder = {
  //   use t <- decode.field(0, decode.string)
  //   decode.success(t)
  // }

  let decoder = {
    use id <- decode.field(0, decode.int)
    // use user <- decode.field(1, decode.string)
    // use password <- decode.field(2, decode.string)
    decode.success(id)
  }

  case
    pog.query(query)
    |> pog.returning(decoder)
    |> pog.execute(conn)
  {
    Ok(result) -> {
      case result.rows {
        [] -> {
          io.println("Query returned no rows.")
        }
        [r, ..] -> {
          io.println("Query result (first row): " <> int.to_string(r))
        }
      }
    }
    Error(e) -> {
      io.println("Query failed: ")
      echo e
      Nil
    }
  }
}

fn setup_db_query(conn: pog.Connection) {
  //let query = "SELECT now()::text"

  //Decoder for first column as a string
  // let decoder = {
  //   use t <- decode.field(0, decode.string)
  //   decode.success(t)
  // }

  let user_table =
    "CREATE TABLE IF NOT EXISTS Users (
        id NUMERIC NOT NULL UNIQUE,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      );"

  let posts_table =
    "CREATE TABLE IF NOT EXISTS Posts (
    postid NUMERIC NOT NULL UNIQUE,
    username TEXT NOT NULL,
    sub TEXT NOT NULL,
    post TEXT NOT NULL,
    upvotes NUMERIC DEFAULT 0,
    downvotes NUMERIC DEFAULT 0,
    created TIMESTAMP WITH TIME ZONE DEFAULT now()
    );"

  let comments_table =
    "CREATE TABLE IF NOT EXISTS Comments (
        commentid NUMERIC NOT NULL UNIQUE,
        username TEXT NOT NULL,
        parent TEXT NOT NULL,
        firstchild BOOLEAN NOT NULL, 
        post TEXT NOT NULL,
        upvotes NUMERIC DEFAULT 0,
        downvotes NUMERIC DEFAULT 0,
        created TIMESTAMP WITH TIME ZONE DEFAULT now()
      );"
  let subregret_table =
    "CREATE TABLE IF NOT EXISTS Sub (
        subid NUMERIC NOT NULL UNIQUE,
        subname TEXT NOT NULL UNIQUE, 
        membernum NUMERIC DEFAULT 0,
        created TIMESTAMP WITH TIME ZONE DEFAULT now()
      );"

  run_test_query(conn, user_table)
  run_test_query(conn, posts_table)
  run_test_query(conn, comments_table)
  run_test_query(conn, subregret_table)
  // let decoder = {
  //   use id <- decode.field(0, decode.string)
  //   decode.success(id)
  // }

  // case
  //   pog.query(posts_table)
  //   |> pog.returning(decoder)
  //   |> pog.execute(conn)
  // {
  //   Ok(result) -> {
  //     case result.rows {
  //       [] -> {
  //         io.println("Query returned no rows.")
  //       }
  //       [r, ..] -> {
  //         io.println("Query result (first row): " <> r)
  //       }
  //     }
  //   }
  //   Error(e) -> {
  //     io.println("Query failed: ")
  //     echo e
  //     Nil
  //   }
  // }
}
