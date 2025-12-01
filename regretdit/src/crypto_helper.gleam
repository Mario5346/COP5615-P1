// File: src/crypto_helper.gleam
// Helper module for RSA key generation and signing using Erlang FFI

import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/string

// Generate RSA-2048 key pair
// Returns #(public_key_pem_base64, private_key_pem_base64)
@external(erlang, "crypto_helper_ffi", "generate_rsa_keypair")
pub fn generate_rsa_keypair() -> #(String, String)

// Sign a message with RSA private key
// Returns base64-encoded signature
@external(erlang, "crypto_helper_ffi", "sign_message")
pub fn sign_message(message: String, private_key_pem: String) -> String

// For demo purposes - simplified key generation
pub fn generate_demo_keypair() -> #(String, String) {
  // In a real implementation, this would call the Erlang FFI
  // For demo, we'll create dummy keys (replace with actual RSA in production)
  let public_key =
    bit_array.base64_encode(<<"demo_public_key_2048":utf8>>, True)
  let private_key =
    bit_array.base64_encode(<<"demo_private_key_2048":utf8>>, True)
  #(public_key, private_key)
}

// For demo purposes - simplified signing
pub fn sign_demo_message(message: String, _private_key: String) -> String {
  // In production, use actual RSA signing
  let message_bytes = bit_array.from_string(message)
  let hash = crypto.hash(crypto.Sha256, message_bytes)
  bit_array.base64_encode(hash, True)
}
