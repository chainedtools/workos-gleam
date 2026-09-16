//// WorkOS Users API (list, get).

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/uri
import workos/client
import workos/error

/// A WorkOS user directory user.
pub type User {
  User(
    id: String,
    email: String,
    /// Empty string when the API returns `null`.
    first_name: String,
    /// Empty string when the API returns `null`.
    last_name: String,
    email_verified: Bool,
    created_at: String,
    updated_at: String,
  )
}

/// Field decoder accepting a `null` value as the fallback.
fn decode_one_of_or_null(
  decoder: decode.Decoder(a),
  fallback: a,
) -> decode.Decoder(a) {
  decode.one_of(decoder, or: [decode.success(fallback)])
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use first_name <- decode.optional_field(
    "first_name",
    "",
    decode_one_of_or_null(decode.string, ""),
  )
  use last_name <- decode.optional_field(
    "last_name",
    "",
    decode_one_of_or_null(decode.string, ""),
  )
  use email_verified <- decode.optional_field(
    "email_verified",
    False,
    decode.bool,
  )
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)

  decode.success(User(
    id: id,
    email: email,
    first_name: first_name,
    last_name: last_name,
    email_verified: email_verified,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

/// Decode a single user JSON body (offline testable).
pub fn decode(body: String) -> Result(User, json.DecodeError) {
  json.parse(from: body, using: user_decoder())
}

/// Decode a paginated users list body (offline testable).
pub fn decode_paged(
  body: String,
) -> Result(client.Paged(User), json.DecodeError) {
  json.parse(from: body, using: client.paged_decoder(user_decoder()))
}

/// List users, optionally paginated.
pub fn list(
  client: client.Client,
  options: client.ListOptions,
) -> Result(client.Paged(User), error.Error) {
  let after = option.map(options.after, fn(v) { uri.percent_encode(v) })
  let limit = option.map(options.limit, int.to_string)

  client.perform(
    client,
    http.Get,
    client.path_with_query("/user_management/users", limit, after),
    option.None,
    client.paged_decoder(user_decoder()),
  )
}

/// Fetch a user by id.
pub fn get(client: client.Client, id: String) -> Result(User, error.Error) {
  client.perform(
    client,
    http.Get,
    "/user_management/users/" <> uri.percent_encode(id),
    option.None,
    user_decoder(),
  )
}
