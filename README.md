# Experimental WorkOS for Gleam

[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Gleam](https://img.shields.io/badge/gleam-1.18.1+-blue)](https://gleam.run)

Welcome to the experimental **Gleam SDK** for [**WorkOS**](https://workos.com).

> **⚠️ Experimental SDK**: This SDK is currently experimental and not
> production-ready. It covers a pragmatic base of the WorkOS REST API and is
> intended for testing and feedback purposes.

## 📦 Getting Started

### Prerequisites

You need:
- A [WorkOS account](https://dashboard.workos.com/signup) and an [API key](https://dashboard.workos.com/api-keys)
- Gleam 1.18.1 or later (Erlang target)

### Installation

#### Using Gleam's package manager (Recommended)

```bash
gleam add workos_gleam
```

The only runtime dependencies are `gleam_stdlib`, `gleam_http`, `gleam_json`,
and `gleam_httpc` (Erlang's built-in HTTP client).

### Basic Configuration

Here's a quick example to get a WorkOS client up and running:

```gleam
import workos

// Replace with an API key from the WorkOS Dashboard
let client = workos.new("sk_test_...")
```

With your client configured, every call authenticates with a
`Authorization: Bearer <api-key>` header against `https://api.workos.com`.

### Quick Usage Examples

#### List and get users

```gleam
import workos/users
import workos/client

let client = workos.new("sk_test_...")

let assert Ok(page) = users.list(client, workos.default_list_options())
for user in page.data {
  // ...
}

let assert Ok(user) = users.get(client, "user_01H5Z")
```

#### Create an organization

```gleam
import workos/organizations

let assert Ok(organization) =
  organizations.create(client, "Acme Corp", ["acme.com"])
```

#### List organizations

```gleam
import workos/organizations
import workos/client

let assert Ok(page) =
  organizations.list(client, client.ListOptions(limit: Some(10), after: None))
```

#### SSO redirects (fully offline)

Authorization URLs and callback parsing are pure string logic — build them
without touching the network:

```gleam
import workos/sso

let config =
  sso.AuthorizationConfig(
    client_id: "client_...",
    redirect_uri: "https://app.example.com/callback",
    state: "st_anti_csrf_token",
    provider: sso.Some("GoogleOAuth"),
    connection_id: sso.None,
    organization_id: sso.None,
    login_hint: sso.None,
    screen_hint: sso.None,
  )
let assert Ok(url) = sso.authorize_url("https://acme.authkit.app", config)

// Then, on the callback endpoint:
let assert Ok(parsed) =
  sso.parse_callback("https://app.example.com/callback?code=...&state=st_...")
// Failure redirects parse as sso.CallbackFailure via ?error=... instead
```

Always verify the callback `state` matches what you sent before using the
authorization `code`.

## 🔧 Configuration Options

- **Base URL**: `workos.with_base_url(client, "https://api.workos.com")` — override for test servers.
- **List options**: `client.ListOptions(limit: Some(10), after: Some("cursor"))` — `None` omits the parameter.

## 🧩 Features

### Current Features
- ✅ **Typed client**: Bearer-token authentication against `https://api.workos.com`
- ✅ **Users**: list and get
- ✅ **Organizations**: list, get, and create
- ✅ **SSO redirect helpers**: authorization URL builders and callback param parsing (pure string logic)
- ✅ **Typed errors**: API errors, decode errors, and network failures
- ✅ **Offline tests**: URL building and JSON decoding tested with no network access

### Upcoming Features
- 🔄 Directory Sync
- 🔄 Audit Logs
- 🔄 Webhook signature verification
- 🔄 AuthKit session/token handling

## 📁 Examples

The repository includes a runnable example in `examples/`:

- **`basic.gleam`** - Relevant version of a full end-to-end client flow

## 🏗️ Building from Source

```bash
# Clone the repository
git clone https://github.com/solvedggorg/workos-gleam.git
cd workos-gleam

# Build the library
gleam build

# Type-check
gleam check

# Run tests
gleam test
```

All tests are offline — no network access is required.

## 📃 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🔗 Resources

- [WorkOS Documentation](https://workos.com/docs) - Complete WorkOS documentation
- [WorkOS API Reference](https://workos.com/docs/reference) - REST API reference
- [Gleam Language](https://gleam.run) - Learn about the Gleam programming language

## ⚠️ Disclaimer

This is an experimental SDK. It is not officially supported by WorkOS and
should not be used in production environments without thorough testing and
evaluation.

---

*Built with ❤️ for the Gleam ecosystem*
