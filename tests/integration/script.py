import json as jsonpkg
import shlex
from urllib.parse import urlencode

from jwcrypto.jwk import JWK, JWKSet  # type: ignore
from jwcrypto.jwt import JWT  # type: ignore


def curl(machine, url, json=None, token=None, method=None, data=None, expect_json=True, wait=False):
    args = ["curl", "-sSfk"]
    if method is not None:
        args.extend(["-X", method])
    if json is not None:
        args.extend(["--json", jsonpkg.dumps(json)])
    if data is not None:
        args.extend(["--data-raw", data])
    if token is not None:
        args.extend(["--oauth2-bearer", token])
    args.append(url)

    cmd = shlex.join(args)
    if wait:
        response = machine.wait_until_succeeds(cmd)
    else:
        response = machine.succeed(cmd)

    if expect_json:
        return jsonpkg.loads(response)
    else:
        return response


machine.wait_for_unit("multi-user.target")

api_url = "https://reside.localhost/packit/api"

response = curl(machine, f"{api_url}/auth/config")
assert response == {
    "enableAuth": True,
    "enableBasicLogin": True,
    "enableGithubLogin": False,
    "enablePreAuthLogin": False,
}

with subtest("Can login with username and password"):
    machine.succeed(
        "create-basic-user reside admin@localhost.com password",
        "grant-role reside admin@localhost.com ADMIN",
    )

    response = curl(
        machine,
        f"{api_url}/auth/login/basic",
        json={"email": "admin@localhost.com", "password": "password"},
    )
    token = response["token"]

    response = curl(machine, f"{api_url}/outpack", token=token)
    assert response["status"] == "success"

with subtest("Can login with device flow"):
    response = curl(machine, f"{api_url}/deviceAuth", method="POST")

    # This is normally done by the user, in the browser.
    # The token here is inherited from the previous test.
    curl(
        machine,
        f"{api_url}/deviceAuth/validate",
        token=token,
        json={"user_code": response["user_code"]},
        expect_json=False,
    )

    data = urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        "device_code": response["device_code"],
    })
    # Usually this would be in a loop, waiting for the user to complete the browser form.
    # However we do it programatically so it is guaranteed to be ready immediately.
    response = curl(machine, f"{api_url}/deviceAuth/token", data=data)
    token = response["access_token"]

    response = curl(machine, f"{api_url}/outpack", token=token)
    assert response["status"] == "success"

with subtest("Can login with service token"):
    key = JWK.generate(kty="RSA")
    keyset = JWKSet(keys=key)
    curl(
        machine,
        "http://127.0.0.1:81/jwks.json",
        method="PUT",
        data=keyset.export(private_keys=False),
        expect_json=False,
    )

    audience = "https://reside.localhost:8443"
    jwt = JWT(
        header={"alg": "RS256"},
        claims={"iss": "https://token.actions.githubusercontent.com", "aud": audience},
    )
    jwt.make_signed_token(key)

    response = curl(
        machine, f"{api_url}/auth/login/service", json={"token": jwt.serialize()}
    )
    token = response["token"]
    response = curl(machine, f"{api_url}/outpack", token=token)
    assert response["status"] == "success"

# This is a very minimal test, just making sure the orderly.runner API can start.
with subtest("orderly.runner"):
    response = curl(machine, "http://localhost:8240", wait=True)
    assert response["status"] == "success"
    assert "orderly2" in response["data"]
    assert "orderly.runner" in response["data"]
