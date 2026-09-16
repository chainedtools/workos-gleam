//// WorkOS Organizations API (list, get, create).

import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/uri
import workos/client
import workos/error

/// A WorkOS organization.
pub type Organization {
  Organization(
    id: String,
    name: String,
    created_at: String,
    user_count: Int,
    domains: List(Domain),
  )
}

/// A verified/pending domain on an organization.
pub type Domain {
  Domain(id: String, domain: String, state: String)
}

pub fn domain_decoder() -> decode.Decoder(Domain) {
  use id <- decode.field("id", decode.string)
  use domain <- decode.field("domain", decode.string)
  use state <- decode.optional_field("state", "unknown", decode.string)

  decode.success(Domain(id: id, domain: domain, state: state))
}

pub fn organization_decoder() -> decode.Decoder(Organization) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use user_count <- decode.optional_field("user_count", 0, decode.int)
  use domains <- decode.optional_field(
    "domains",
    [],
    decode.list(domain_decoder()),
  )

  decode.success(Organization(
    id: id,
    name: name,
    created_at: created_at,
    user_count: user_count,
    domains: domains,
  ))
}

/// Decode a single organization JSON body (offline testable).
pub fn decode(body: String) -> Result(Organization, json.DecodeError) {
  json.parse(from: body, using: organization_decoder())
}

/// Decode a paginated organizations list body (offline testable).
pub fn decode_paged(
  body: String,
) -> Result(client.Paged(Organization), json.DecodeError) {
  json.parse(from: body, using: client.paged_decoder(organization_decoder()))
}

/// List organizations, optionally paginated.
pub fn list(
  client: client.Client,
  options: client.ListOptions,
) -> Result(client.Paged(Organization), error.Error) {
  let after = option.map(options.after, uri.percent_encode)
  let limit = option.map(options.limit, int.to_string)

  client.perform(
    client,
    http.Get,
    client.path_with_query("/organizations", limit, after),
    option.None,
    client.paged_decoder(organization_decoder()),
  )
}

/// Fetch an organization by id.
pub fn get(
  client: client.Client,
  id: String,
) -> Result(Organization, error.Error) {
  client.perform(
    client,
    http.Get,
    "/organizations/" <> uri.percent_encode(id),
    option.None,
    organization_decoder(),
  )
}

/// Create an organization. `domains` holds bare domains, e.g.
/// `["example.com"]`, sent as `domain_data` entries.
pub fn create(
  client: client.Client,
  name: String,
  domains: List(String),
) -> Result(Organization, error.Error) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("domain_data", json.array(domains, json.string)),
    ])
    |> json.to_string

  client.perform(
    client,
    http.Post,
    "/organizations",
    option.Some(body),
    organization_decoder(),
  )
}
