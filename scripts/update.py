# This script is used to update the sources of external packages, such as
# outpack_server and Packit.
#
# The procedure to do this is usually quite manual: one has to update the
# revision in the package definition and set the hash to an empty string, run
# the build and wait for it to fail with a hash mismatch, copy paste the hash
# into the package definition, set the dependency hash to an empty string, run
# the build again, copy paste the hash again, ...
#
# This script does the same, but in an automated fashion.

import subprocess
import os.path
import sys
import re
import argparse
import os
import json
from urllib.request import urlopen

PRELUDE = """
let
  overrideHash = p: hash:
    p.overrideAttrs (_: { outputHash = hash; outputHashAlgo = "sha256"; });

  overrideGithub = src: owner: repo: rev: hash:
    overrideHash (src.override { inherit owner repo rev; }) hash;

  overrideSource = p: owner: repo: rev: hash:
    p.overrideAttrs (old: { src = overrideGithub old.src owner repo rev; });

  force = x: builtins.deepSeq x x;
in
"""

SUPPORTED_DEPS = {"gradle", "cargo", "npm"}


def fetch_latest_commit(owner, repo, branch):
    if branch is None:
        url = f"https://api.github.com/repos/{owner}/{repo}"
        branch = json.load(urlopen(url))["default_branch"]

    url = f"https://api.github.com/repos/{owner}/{repo}/git/ref/heads/{branch}"
    return json.load(urlopen(url))["object"]["sha"]


def nix_eval(expr, args):
    cmdargs = ["nix-instantiate", "--eval", "--json", "--expr", PRELUDE + expr]
    for k, v in args.items():
        cmdargs.extend(("--argstr", k, v))

    p = subprocess.run(cmdargs, text=True, stdout=subprocess.PIPE, check=True)
    return json.loads(p.stdout)


def nix_build(expr, args):
    cmdargs = ["nix-build", "--expr", PRELUDE + expr, "--no-out-link"]
    for k, v in args.items():
        cmdargs.extend(("--argstr", k, v))

    p = subprocess.run(cmdargs, text=True, capture_output=True)
    stderr = p.stderr.strip()
    for line in stderr.split("\n"):
        line = line.strip()
        if line.startswith("got:"):
            return line.split("got:")[1].strip()
    else:
        print(p.stderr)
        sys.exit(1)


def evaluate_metadata(name):
    expr = """
{ cwd, name }:
let
  flake = builtins.getFlake cwd;
  package = flake.packages.${builtins.currentSystem}."${name}";
in
  force {
    owner = package.src.owner;
    repo = package.src.repo;
    attributes = builtins.attrNames package;
  }
"""

    return nix_eval(expr, {"cwd": os.getcwd(), "name": name})


def prefetch_src(name, owner, repo, rev):
    print(f"Fetching {owner}/{repo}@{rev}...", file=sys.stderr)
    expr = """
{ cwd, name, owner, repo, rev }:
let
  flake = builtins.getFlake cwd;
  package = flake.packages.${builtins.currentSystem}."${name}";
in
  overrideGithub package.src owner repo rev ""
"""

    return nix_build(expr, {
        "cwd": os.getcwd(),
        "name": name,
        "owner": owner,
        "repo": repo,
        "rev": rev,
    })


def prefetch_dep(name, owner, repo, rev, source_hash, attribute):
    print(f"Fetching {attribute}", file=sys.stderr)
    expr = """
{ cwd, name, owner, repo, rev, sourceHash, attribute }:
let
  flake = builtins.getFlake cwd;
  package = flake.packages.${builtins.currentSystem}."${name}";
  newPackage = overrideSource package owner repo rev sourceHash;
in
  overrideHash newPackage."${attribute}" ""
"""

    return nix_build(expr, {
        "cwd": os.getcwd(),
        "name": name,
        "owner": owner,
        "repo": repo,
        "rev": rev,
        "sourceHash": source_hash,
        "attribute": attribute
    })


def extract_dep_name(attr):
    if (m := re.match("^(.*)Deps$", attr)) and m.group(1) in SUPPORTED_DEPS:
        return m.group(1)
    else:
        return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--owner')
    parser.add_argument('--repo')
    parser.add_argument('--branch')
    parser.add_argument('--output')
    parser.add_argument('name')
    g = parser.add_mutually_exclusive_group()
    g.add_argument('--deps', nargs="*")
    g.add_argument('--no-deps', dest='deps', action='store_const', const=())

    args = parser.parse_args()

    if args.owner is None or args.repo is None or args.deps is None:
        metadata = evaluate_metadata(args.name)
        if args.owner is None:
            args.owner = metadata["owner"]
        if args.repo is None:
            args.repo = metadata["repo"]
        if args.deps is None:
            args.deps = [
                name
                for attr in metadata["attributes"]
                if (name := extract_dep_name(attr))
            ]

    if args.output is None:
        args.output = os.path.join("packages", args.name, "sources.json")

    rev = fetch_latest_commit(args.owner, args.repo, args.branch)
    source_hash = prefetch_src(args.name, args.owner, args.repo, rev)
    deps_hash = {
        dep: prefetch_dep(args.name, args.owner, args.repo, rev,
                          source_hash, f"{dep}Deps")
        for dep in args.deps
    }

    result = {
        "src": {
            "owner": args.owner,
            "repo": args.repo,
            "rev": rev,
            "hash": source_hash,
        },
    }
    for k, v in deps_hash.items():
        result[f"{k}DepsHash"] = v

    with open(args.output, "w") as f:
        json.dump(result, f, indent=2)
