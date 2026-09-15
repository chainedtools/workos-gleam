import gleam/io
import workos
import workos/organizations
import workos/users

// Replace with an API key from the WorkOS Dashboard.
pub fn main() {
  let client = workos.new("sk_test_...")

  let assert Ok(page) = organizations.list(client, workos.default_list_options())
  for organization in page.data {
    io.println(organization.name)
  }

  let assert Ok(organization) = organizations.get(client, "org_01H5")
  io.println("Got organization: " <> organization.name)
}
