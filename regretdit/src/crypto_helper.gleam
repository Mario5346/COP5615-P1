import gleam/bit_array
import gleam/crypto

pub fn generate_keypair() -> #(String, String) {
  let public_key =
    bit_array.base64_encode(<<"demo_public_key_2048":utf8>>, True)
  let private_key =
    bit_array.base64_encode(<<"demo_private_key_2048":utf8>>, True)
  #(public_key, private_key)
}

pub fn sign_message(message: String, _private_key: String) -> String {
  let message_bytes = bit_array.from_string(message)
  let hash = crypto.hash(crypto.Sha256, message_bytes)
  bit_array.base64_encode(hash, True)
}
