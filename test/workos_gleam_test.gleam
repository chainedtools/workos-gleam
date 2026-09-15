import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import workos/organizations
import workos/sso
import workos/users

pub fn main() {
  gleeunit.main()
}

// SSO helpers are pure string logic and run offline.

pub fn build_authorize_url_test() {
  let config =
    sso.AuthorizationConfig(
      client_id: "client_123",
      redirect_uri: "https://app.example.com/callback",
      state: "st_abc",
      provider: option.Some("GoogleOAuth"),
      connection_id: option.None,
      organization_id: option.None,
      login_hint: option.None,
      screen_hint: option.None,
    )

  sso.authorize_url("https://acme.authkit.app", config)
  |> should.equal(
    Ok(
      "https://acme.authkit.app/sso/authorize?client_id=client_123&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback&state=st_abc&provider=GoogleOAuth",
    ),
  )
}

pub fn authorize_url_rejects_http_domain_test() {
  let config =
    sso.AuthorizationConfig(
      client_id: "client_123",
      redirect_uri: "https://app.example.com/callback",
      state: "st_abc",
      provider: option.None,
      connection_id: option.None,
      organization_id: option.None,
      login_hint: option.None,
      screen_hint: option.None,
    )

  sso.authorize_url("http://acme.authkit.app", config)
  |> should.be_error()
}

pub fn authorize_url_trims_trailing_slash_test() {
  let config =
    sso.AuthorizationConfig(
      client_id: "client_123",
      redirect_uri: "https://app.example.com/callback",
      state: "st_abc",
      provider: option.None,
      connection_id: option.None,
      organization_id: option.None,
      login_hint: option.None,
      screen_hint: option.None,
    )

  sso.authorize_url("https://acme.authkit.app/", config)
  |> should.equal(
    Ok(
      "https://acme.authkit.app/sso/authorize?client_id=client_123&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback&state=st_abc",
    ),
  )
}

pub fn parse_callback_success_test() {
  sso.parse_callback(
    "https://app.example.com/callback?code=code_4&state=st_abc",
  )
  |> should.equal(Ok(sso.CallbackSuccess(code: "code_4", state: "st_abc")))
}

pub fn parse_callback_failure_test() {
  sso.parse_callback(
    "https://app.example.com/callback?error=connection_not_found&error_description=Connection%20not%20found",
  )
  |> should.equal(
    Ok(sso.CallbackFailure(
      code: "connection_not_found",
      message: "Connection not found",
    )),
  )
}

pub fn parse_callback_invalid_url_test() {
  sso.parse_callback("https://app.example.com/callback?no===")
  |> should.be_error()
}

pub fn state_matches_test() {
  let callback =
    sso.parse_callback(
      "https://app.example.com/callback?code=code_4&state=st_abc",
    )
  let assert Ok(parsed) = callback

  sso.state_matches(parsed, "st_abc") |> should.be_true()
  sso.state_matches(parsed, "st_other") |> should.be_false()
}

// JSON decoding runs offline against recorded API shapes.

pub fn decode_user_test() {
  let body =
    "{"
    <> "\"id\":\"user_01H5\","
    <> "\"email\":\"ada@example.com\","
    <> "\"first_name\":null,"
    <> "\"last_name\":\"Lovelace\","
    <> "\"email_verified\":true,"
    <> "\"created_at\":\"2024-01-01T00:00:00.000Z\","
    <> "\"updated_at\":\"2024-06-01T00:00:00.000Z\""
    <> "}"

  let assert Ok(user) = users.decode(body)

  user.id |> should.equal("user_01H5")
  user.email |> should.equal("ada@example.com")
  user.first_name |> should.equal("")
  user.last_name |> should.equal("Lovelace")
  user.email_verified |> should.equal(True)
}

pub fn decode_users_paged_test() {
  let body =
    "{"
    <> "\"data\":[{\"id\":\"user_01H5\",\"email\":\"ada@example.com\","
    <> "\"created_at\":\"2024-01-01T00:00:00.000Z\","
    <> "\"updated_at\":\"2024-06-01T00:00:00.000Z\"}],"
    <> "\"list_metadata\":{\"after\":\"user_next\",\"before\":\"\"}"
    <> "}"

  let assert Ok(page) = users.decode_paged(body)

  page.after |> should.equal("user_next")
  list.length(page.data) |> should.equal(1)
}

pub fn decode_organization_test() {
  let body =
    "{"
    <> "\"id\":\"org_01H5\","
    <> "\"name\":\"Acme Corp\","
    <> "\"created_at\":\"2024-01-01T00:00:00.000Z\","
    <> "\"domains\":[{\"id\":\"dom_01H5\",\"domain\":\"acme.com\","
    <> "\"state\":\"verified\"}]"
    <> "}"

  let assert Ok(organization) = organizations.decode(body)

  organization.name |> should.equal("Acme Corp")
  list.length(organization.domains) |> should.equal(1)
}

pub fn decode_organizations_paged_test() {
  let body =
    "{"
    <> "\"data\":[{\"id\":\"org_01H5\",\"name\":\"Acme Corp\","
    <> "\"created_at\":\"2024-01-01T00:00:00.000Z\"}],"
    <> "\"list_metadata\":{\"after\":\"\",\"before\":\"\"}"
    <> "}"

  let assert Ok(page) = organizations.decode_paged(body)

  page.after |> should.equal("")
  list.length(page.data) |> should.equal(1)
}
