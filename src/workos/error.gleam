//// Error type shared by all WorkOS API calls.

import gleam/dynamic/decode
import gleam/json

/// Errors surfaced by the SDK.
pub type Error {
  /// Non-2xx API response; `message` comes from the API body when present.
  ApiError(status: Int, message: String)
  /// Response body did not match the expected schema.
  DecodeError(message: String)
  /// Request never completed (transport failure, non-UTF-8 body, ...).
  NetworkError(message: String)
}

/// Extract the human-readable message from an API error body.
pub fn decode_message(body: String) -> String {
  let decoder = {
    use message <- decode.optional_field("message", "", decode.string)
    decode.success(message)
  }
  case json.parse(from: body, using: decoder) {
    Ok("") -> body
    Ok(message) -> message
    Error(_) -> body
  }
}
