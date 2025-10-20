// src/db_demo.gleam
import gleam/erlang/process.{new_name}
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
      run_test_query(conn)
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
fn run_test_query(conn: pog.Connection) {
  let sql = "SELECT now()::text"

  // Decoder for first column as a string
  let decoder = {
    use t <- decode.field(0, decode.string)
    decode.success(t)
  }

  case
    pog.query(sql)
    |> pog.returning(decoder)
    |> pog.execute(conn)
  {
    Ok(result) -> {
      case result.rows {
        [] -> {
          io.println("Query returned no rows.")
        }
        [r, ..] -> {
          io.println("Query result (first row): " <> r)
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
