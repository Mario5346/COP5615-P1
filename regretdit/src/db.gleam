// import pog
// //import std/result.{Result, Ok, Error}
// import gleam/io

// pub fn connect() -> Result(pog.Conn, String) {
//   case pog.url_config("postgresql://gleam_user:mysecret@localhost:5432/reddit_gleam") {
//     Ok(config) ->
//       Ok(pog.connect(config))
//     Error(e) ->
//       Error("Invalid connection URL: " <> e)
//   }
// }

// pub fn main() {
//   case connect() {
//     Ok(conn) ->{
//       io.println("✅ Connected to PostgreSQL!")
//       // You can now query the DB:
//       let sql = "SELECT now();"
//       case pog.query(conn, sql, []) {
//         Ok(result) -> io.println("Server time: " <> result.rows |> list.first |> string.inspect)
//         Error(e) -> io.println("Query failed: " <> e)
//       }
//     }
//     Error(e) ->
//       io.println("❌ Connection failed: " <> e)
//   }
// }
