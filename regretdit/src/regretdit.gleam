import gleam/io

// CREATE DATABASE
// DATABASE FUNCTIONS + GLEAM
// IMPLEMENT ACTORS AND FUNCTIONS
// IMPLEMENT SERVER AND CONNECTIONS
// SIMULATE

pub fn main() -> Nil {
  io.println("Hello from Regretdit!")
}
// register account:
// actor sends server message with user info
// check if username exists
// if new then server inserts account into USERS table with given data, return sucess and uid 
// if exists return error(exists)

// create subregretdit;
// user sends server request to create a sub
// server sends db requesst to create if does not already exist
// return success if no error
