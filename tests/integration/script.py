import json
from jwcrypto.jwk import JWK, JWKSet # type: ignore
from jwcrypto.jwt import JWT # type: ignore
from shlex import quote

machine.wait_for_unit("multi-user.target")

api_url = "https://localhost/reside/packit/api"

response = machine.succeed(f"curl -sSfk {api_url}/auth/config")
data = json.loads(response)
assert data == {
  "enableAuth": True,
  "enableBasicLogin": True,
  "enableGithubLogin": False,
}

with subtest("Can login with username and password"):
    machine.succeed(
      "create-basic-user reside admin@localhost.com password",
      "grant-role reside admin@localhost.com ADMIN")

    payload = quote(json.dumps({ "email": "admin@localhost.com", "password": "password"}))
    response = machine.succeed(f"curl -sSfk --json {payload} {api_url}/auth/login/basic")
    token = json.loads(response)["token"]

    response = machine.succeed(f"curl -sSfk --oauth2-bearer {quote(token)} {api_url}/outpack/")
    data = json.loads(response)
    assert data["status"] == "success"

with subtest("Can login with service token"):
    key = JWK.generate(kty = "RSA")
    keyset = JWKSet(keys = key)
    payload = quote(keyset.export(private_keys = False))
    machine.succeed(f"curl -sSfk http://127.0.0.1:81/jwks.json -X PUT --data-raw {payload}")

    audience = "https://localhost:8443/reside"
    jwt = JWT(
        header = { "alg": "RS256" },
        claims = { "iss": "https://token.actions.githubusercontent.com", "aud": audience }
    )
    jwt.make_signed_token(key)

    payload = quote(json.dumps({ 'token': jwt.serialize() }))
    response = machine.succeed(f"curl -sSfk --json {payload} {api_url}/auth/login/service")
    token = json.loads(response)["token"]

    response = machine.succeed(f"curl -sSfk --oauth2-bearer {quote(token)} {api_url}/outpack/")
    data = json.loads(response)
    assert data["status"] == "success"

