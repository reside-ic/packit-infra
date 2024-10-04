import argparse
import json
from getpass import getpass
from pathlib import Path

import hvac

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--token-file",
        help="File containing the Vault token",
        type=argparse.FileType("r"),
    )
    parser.add_argument("--url", help="URL to Vault")
    parser.add_argument("--root", type=Path, default=Path("/"))
    parser.add_argument(
        "--spec",
        help="Secret specification",
        type=argparse.FileType("r"),
        required=True,
    )

    args = parser.parse_args()

    client = hvac.Client(url=args.url)
    if args.token_file is not None:
        client.token = args.token_file.read().strip()
    else:
        ghtoken = getpass("GitHub Personal Access Token (will be hidden): ")
        login_response = client.auth.github.login(token=ghtoken)
        client.token = login_response["auth"]["client_token"]

    spec = json.load(args.spec)
    for entry in spec:
        path = args.root.joinpath(Path(entry["path"]).relative_to("/"))
        print(f"Reading {entry['mount']}/{entry['key']} to {path}")
        path.parent.mkdir(parents=True, exist_ok=True)

        secret = client.secrets.kv.v1.read_secret(
            mount_point=entry["mount"], path=entry["key"]
        )
        if entry["format"] == "plain":
            for v in entry["fields"].values():
                path.write_text(secret["data"][v])
        elif entry["format"] == "env":
            lines = [
                f"{k}={secret['data'][v]}"
                for k, v in entry["fields"].items()
            ]
            path.write_text("\n".join(lines))
