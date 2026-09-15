//// WorkOS SSO redirect helpers.
////
//// Pure string logic only (URL building and callback parsing), so redirect
//// flows can be built and verified fully offline; no network access.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// Parameters for the hosted SSO authorization redirect (`/sso/authorize`).
pub type AuthorizationConfig {
  AuthorizationConfig(
    /// WorkOS OAuth application client id.
    client_id: String,
    /// Redirect URI registered for the application.
    redirect_uri: String,
    /// Anti-CSRF token; verify it against the callback `state` parameter.
    state: String,
    /// e.g. "GoogleOAuth", "MicrosoftOAuth", or use connection_id.
    provider: Option(String),
    /// WorkOS connection id (mutually exclusive with provider).
    connection_id: Option(String),
    /// WorkOS organization id.
    organization_id: Option(String),
    /// Pre-filled email on the hosted login screen.
    login_hint: Option(String),
    /// "sign-up" or "sign-in" hint for the hosted login screen.
    screen_hint: Option(String),
  )
}

/// Result of parsing an SSO redirect callback URL.
pub type Callback {
  CallbackSuccess(code: String, state: String)
  CallbackFailure(code: String, message: String)
}

/// Build the hosted SSO authorization URL.
///
/// `domain` must be an HTTPS URL — the AuthKit domain
/// (`https://acme.authkit.app`) or the SSO connection domain
/// (`https://acme.okta.com`); the path `/sso/authorize` is appended.
pub fn authorize_url(
  domain: String,
  config: AuthorizationConfig,
) -> Result(String, String) {
  let invalid = "domain must be an HTTPS URL, e.g. https://acme.authkit.app"

  case uri.parse(string.trim(domain)) {
    Error(_) -> Error(invalid)
    Ok(parsed) ->
      case parsed.scheme, parsed.host {
        Some("https"), Some(_) -> Ok(build_url(normalize_base(domain), config))
        _, _ -> Error(invalid)
      }
  }
}

/// Strip a trailing slash so the authorize path joins cleanly.
fn normalize_base(domain: String) -> String {
  case string.ends_with(domain, "/") {
    True -> string.slice(domain, 0, string.length(domain) - 1)
    False -> domain
  }
}

fn build_url(base: String, config: AuthorizationConfig) -> String {
  let query =
    [
      #("client_id", config.client_id),
      #("redirect_uri", config.redirect_uri),
      #("state", config.state),
    ]
    |> list.map(param_string)
    |> list.append(optional_params(config))
    |> string.join("&")

  base <> "/sso/authorize?" <> query
}

fn param_string(pair: #(String, String)) -> String {
  pair.0 <> "=" <> uri.percent_encode(pair.1)
}

fn optional_params(config: AuthorizationConfig) -> List(String) {
  [
    option.map(config.provider, fn(v) { #("provider", v) }),
    option.map(config.connection_id, fn(v) { #("connection_id", v) }),
    option.map(config.organization_id, fn(v) { #("organization_id", v) }),
    option.map(config.login_hint, fn(v) { #("login_hint", v) }),
    option.map(config.screen_hint, fn(v) { #("screen_hint", v) }),
  ]
  |> list.filter_map(fn(param) {
    case param {
      Some(value) -> Ok(value)
      None -> Error(Nil)
    }
  })
  |> list.map(param_string)
}

/// Parse an SSO redirect callback URL.
///
/// Success shape: `?code=<code>&state=<state>`. Failure shape:
/// `?error=<code>&error_description|error_message=<message>`.
pub fn parse_callback(url: String) -> Result(Callback, String) {
  case uri.parse(url) {
    Error(_) -> Error("callback URL is invalid")
    Ok(parsed) ->
      case parsed.query {
        Some(query) ->
          case uri.parse_query(query) {
            Error(_) -> Error("callback URL has invalid query parameters")
            Ok(params) -> handle_params(params)
          }
        None -> Error("callback URL is missing query parameters")
      }
  }
}

fn handle_params(params: List(#(String, String))) -> Result(Callback, String) {
  let code = list.key_find(params, "code")
  let state = list.key_find(params, "state")
  let error_code = list.key_find(params, "error")
  let message =
    result.or(
      list.key_find(params, "error_description"),
      list.key_find(params, "error_message"),
    )

  case code, state {
    Ok(code), Ok(state) -> Ok(CallbackSuccess(code: code, state: state))
    Ok(_code), Error(_) -> Error("callback URL is missing the state parameter")
    Error(_), _ ->
      case error_code, message {
        Ok(code), Ok(message) ->
          Ok(CallbackFailure(code: code, message: message))
        Ok(code), Error(_) ->
          Ok(CallbackFailure(
            code: code,
            message: "SSO callback reported an error",
          ))
        Error(_), _ -> Error("callback URL is missing the code parameter")
      }
  }
}

/// Check a callback `state` against the expected anti-CSRF token.
pub fn state_matches(callback: Callback, expected: String) -> Bool {
  case callback {
    CallbackSuccess(state: state, ..) -> state == expected
    CallbackFailure(..) -> False
  }
}
