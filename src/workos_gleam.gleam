//// WorkOS SDK for Gleam.
////
//// A typed client for the WorkOS REST API plus offline-testable SSO
//// authorization URL and callback helpers.

import workos/client
import workos/error

/// Authenticated WorkOS API client.
pub type Client =
  client.Client

/// Errors returned by SDK calls.
pub type Error =
  error.Error

pub const api_base_url = client.default_base_url

/// Build a client for the WorkOS REST API, authenticated with an API key
/// from the WorkOS Dashboard.
pub fn new(api_key: String) -> client.Client {
  client.new(api_key)
}

/// Point a client at a different API base URL (e.g. a test server).
pub fn with_base_url(client: client.Client, base_url: String) -> client.Client {
  client.with_base_url(client, base_url)
}
