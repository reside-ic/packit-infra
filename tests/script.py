import json
from shlex import quote

machine.wait_for_unit("multi-user.target")

api_url = "https://localhost/reside/packit/api"
response = machine.wait_until_succeeds(f"curl -sfk {api_url}/auth/config")
data = json.loads(response)
assert data == {
  "enableAuth": True,
  "enableBasicLogin": True,
  "enableGithubLogin": False,
}

machine.succeed(
  "create-basic-user reside admin@localhost.com password",
  "grant-role reside admin@localhost.com ADMIN")

payload = json.dumps({ "email": "admin@localhost.com", "password": "password"})
response = machine.succeed(f"curl -sfk --json {quote(payload)} {api_url}/auth/login/basic")
token = json.loads(response)["token"]

response = machine.succeed(f"curl -sfk --oauth2-bearer {quote(token)} {api_url}/outpack/")
data = json.loads(response)
assert data["status"] == "success"
