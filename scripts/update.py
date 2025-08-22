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

import argparse
import github
import json
import os
import os.path
import re
import subprocess
import sys

from concurrent.futures import ThreadPoolExecutor
from contextlib import nullcontext
from github import Github
from urllib.parse import urljoin

PRELUDE = """
let
  overrideHash = p: hash:
    p.overrideAttrs { outputHash = hash; outputHashAlgo = "sha256"; };

  overrideGithub = src: owner: repo: rev: hash:
    overrideHash (src.override { inherit owner repo rev; }) hash;

  overrideSource = p: owner: repo: rev: hash:
    p.overrideAttrs (old: {
        src = overrideGithub old.src owner repo rev hash;
    });
in
"""

SUPPORTED_DEPS = {"gradle", "cargo", "npm"}


def resolve_prs_concurrently(repo, commits):
    """
    Map a list of commits to their corresponding pull request.

    Returns a dictionary from commit ID to Pull Request object. If no PRs match
    a commit (eg. the commit was directly pushed to a branch), the dictionary
    entry maps to None. If multiple PRs match a commit, an arbitrary pull
    request is returned.
    """
    def f(c):
        pulls = c.get_pulls()
        return (c.sha, next(iter(pulls), None))

    # This needs one API call to GitHub per commit, which can be very slow.
    # Doing it concurrently helps a lot.
    with ThreadPoolExecutor(max_workers=16) as executor:
        return dict(executor.map(f, commits))


def format_link(text, url):
    """Format a link as Markdown."""
    return f"[{text}]({url})"


def commit_log(client, owner, repo, base, head, *, resolve_prs):
    # We use the redirect subdomain to avoid creating backlinks on all the
    # pull-requests.
    # https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls#avoiding-backlinks-to-linked-references
    base_url = f"https://redirect.github.com/{owner}/{repo}/"

    messages = []
    seen = set()

    r = client.get_repo(f"{owner}/{repo}")
    commits = list(r.compare(base, head).commits)

    if resolve_prs:
        prs = resolve_prs_concurrently(r, commits)
    else:
        prs = {}

    for c in commits:
        pr = prs.get(c.sha)
        if pr is None:
            title = c.commit.message.splitlines()[0]
            url = urljoin(base_url, f"commit/{c.sha}")
            link = format_link(c.sha[:7], url)
            messages.append(f"{title} ({link})")
        elif pr.number not in seen:
            seen.add(pr.number)
            url = urljoin(base_url, f"pull/{pr.number}")
            link = format_link(f"#{pr.number}", url)
            messages.append(f"{pr.title} ({link})")

    return messages


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
  (x: builtins.deepSeq x x) {
    owner = package.src.owner;
    repo = package.src.repo;
    rev = package.src.rev;
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


def prefetch_dep(name, owner, repo, rev, source_hash, dep):
    print(f"Fetching {dep} dependencies for {name}...", file=sys.stderr)
    expr = """
{ cwd, name, owner, repo, rev, sourceHash, attribute }:
let
  flake = builtins.getFlake cwd;
  package = flake.packages.${builtins.currentSystem}."${name}";
  deps = overrideSource package."${attribute}" owner repo rev sourceHash;
in
  overrideHash deps ""
"""

    return nix_build(expr, {
        "cwd": os.getcwd(),
        "name": name,
        "owner": owner,
        "repo": repo,
        "rev": rev,
        "sourceHash": source_hash,
        "attribute": f"{dep}Deps",
    })


def extract_dep_name(attr):
    if (m := re.match("^(.*)Deps$", attr)) and m.group(1) in SUPPORTED_DEPS:
        return m.group(1)
    else:
        return None


def open_output(path):
    if path is not None:
        return open(path, "w")
    else:
        return nullcontext(sys.stdout)


def create_client(args):
    if token := os.environ.get("GH_TOKEN"):
        auth = github.Auth.Token(token)
    else:
        auth = None

    return Github(auth=auth)


def update(args):
    client = create_client(args)

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

    rev = client.get_repo(f"{args.owner}/{args.repo}").get_commit(args.ref).sha

    if metadata["rev"] == rev:
        print(f"{args.name} is already up-to-date at {rev}")
        if not args.force:
            return
    else:
        print(f"Updating {args.name} from {metadata['rev']} to {rev}")
        messages = commit_log(
            client, args.owner, args.repo, metadata["rev"], rev,
            resolve_prs=args.resolve_prs)
        with open_output(args.write_commit_log) as f:
            f.writelines(f"- {m}\n" for m in messages)

    source_hash = prefetch_src(args.name, args.owner, args.repo, rev)
    deps_hash = {
        dep: prefetch_dep(
            args.name, args.owner, args.repo, rev, source_hash, dep
        )
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", help="Owner of source repository.")
    parser.add_argument("--repo", help="Name of source repository.")
    parser.add_argument(
        "--ref",
        help="Git reference (branch name, tag or commit hash)",
        default="HEAD")
    parser.add_argument("--output", help="File in which to write the result.")
    parser.add_argument(
        "--write-commit-log",
        help="File in which to write the commit log."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Fetch the sources even if the commit sha is identical.",
    )
    parser.add_argument(
        "--resolve-prs",
        action="store_true",
        help="""
            Use pull request titles and links intead of commits when
            generating the changelog. This requires a lot of requests to
            the GitHub API, which is slow and likely to exceed the rate
            limit if the GH_TOKEN environment variable is not configured.
        """
    )
    parser.add_argument("name")

    g = parser.add_mutually_exclusive_group()
    g.add_argument("--deps", nargs="*", help="Dependency type to fetch")
    g.add_argument("--no-deps", dest="deps", action="store_const", const=())

    args = parser.parse_args()
    update(args)
