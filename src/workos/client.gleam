//// Typed client for the WorkOS REST API.
////
//// Requests authenticate with a bearer API key. HTTP is provided by
//// `gleam_httpc`; the base URL is configurable for tests.

import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri
import workos/error

pub const default_base_url = "https://api.workos.com"

pub opaque type Client {
  Client(api_key: String, base_url: String)
}

/// Create a client for the WorkOS REST API with an API key from the
/// WorkOS Dashboard.
pub fn new(api_key: String) -> Client {
  Client(api_key: api_key, base_url: default_base_url)
}

/// Point the client at a different API base URL (e.g. a test server).
pub fn with_base_url(client: Client, base_url: String) -> Client {
  Client(client.api_key, base_url)
}

/// Paginated list envelope returned by WorkOS list endpoints.
pub type Paged(a) {
  Paged(data: List(a), after: String, before: String)
}

/// List request parameters; `None` omits the query parameter.
pub type ListOptions {
  ListOptions(limit: Option(Int), after: Option(String))
}

/// No pagination parameters.
pub fn default_list_options() -> ListOptions {
  ListOptions(limit: None, after: None)
}

/// Encode optional query parameters; `None` values are skipped.
pub fn encode_query(params: List(#(String, Option(String)))) -> String {
  params
  |> list.filter_map(fn(pair) {
    case pair.1 {
      Some(value) -> Ok(pair.0 <> "=" <> uri.percent_encode(value))
      None -> Error(Nil)
    }
  })
  |> string.join("&")
}

/// Build `"path?limit=<limit>&after=<after>"`, skipping `None` parameters.
pub fn path_with_query(
  path: String,
  limit: Option(String),
  after: Option(String),
) -> String {
  case encode_query([#("limit", limit), #("after", after)]) {
    "" -> path
    query -> path <> "?" <> query
  }
}

/// Decode a WorkOS paginated list envelope wrapping `elem` items.
pub fn paged_decoder(elem: decode.Decoder(a)) -> decode.Decoder(Paged(a)) {
  use data <- decode.field("data", decode.list(elem))
  use metadata <- decode.optional_field(
    "list_metadata",
    #("", ""),
    metadata_decoder(),
  )
  decode.success(Paged(data: data, after: metadata.0, before: metadata.1))
}

fn metadata_decoder() -> decode.Decoder(#(String, String)) {
  use after <- decode.optional_field("after", "", decode.string)
  use before <- decode.optional_field("before", "", decode.string)
  decode.success(#(after, before))
}

/// Send a request and decode the (2xx) response body with `decoder`.
pub fn perform(
  client: Client,
  method: http.Method,
  path: String,
  body: Option(String),
  decoder: decode.Decoder(a),
) -> Result(a, error.Error) {
  let req = request_from_base(client, method, path)
  let req = case body {
    Some(body) ->
      request.set_body(req, body)
      |> request.set_header("Content-Type", "application/json")
    None -> req
  }

  case httpc.send(req) {
    Ok(resp) -> handle_response(resp.status, resp.body, decoder)
    Error(_) -> Error(error.NetworkError("HTTP request failed"))
  }
}

fn request_from_base(
  client: Client,
  method: http.Method,
  path: String,
) -> request.Request(String) {
  let assert Ok(base) = uri.parse(client.base_url)
  let assert Ok(req) = request.from_uri(base)
  let with_path = request.set_path(req, path)

  with_path
  |> request.set_method(method)
  |> request.set_header("Authorization", "Bearer " <> client.api_key)
}

fn handle_response(
  status: Int,
  body: String,
  decoder: decode.Decoder(a),
) -> Result(a, error.Error) {
  case status >= 200 && status <= 299 {
    True ->
      case json.parse(from: body, using: decoder) {
        Ok(value) -> Ok(value)
        Error(_) -> Error(error.DecodeError("Could not decode WorkOS response"))
      }
    False -> Error(error.ApiError(status, error.decode_message(body)))
  }
}
