# Updating Packit

These instructions focus on the case where a new version of Packit,
outpack_server and/or orderly.runner need to be deployed. These instructions
are most appropriate when deploying changes that do not require any
configuration changes.

## 1. Run the update workflow

The [`packages` directory](../packages) contains JSON files that specify the
Git revision used to build and deploy the various components, as well as their
dependencies. A [GitHub actions workflow](../.github/workflows/update.yaml)
runs nightly and creates (or updates) a pull request to update outpack_server
and Packit to their latest revision.

You can either wait for the workflow to run automatically, or you can manually
trigger it from [the GitHub UI][github-trigger]. When running automatically, it
will use the HEAD of each project. When triggering manually, you can specify a
particular branch or revision, though most of the time you'll want to leave
that field empty to deploy the HEAD.

We don't generally maintain compatibility across versions of the different
components. If updating one component to the lastest HEAD, you should update
all of the other ones too unless you explicitly know the interfaces haven't
changed.

[github-trigger]: https://github.com/reside-ic/packit-infra/actions/workflows/update.yaml

The automatic's pull request description includes the list of commits that were
added compared to the `main` branch of `packit-infra`. The list of commits
should help you identify whether the update is particularly risky.

> [!IMPORTANT]
> Updating orderly.runner is currently a manual process. This will be automated
> as well soon.

## 2. Run VM integration tests

This repository contains an integration test that largely mimicks the staging
and production environments within a virtual machine. The test suite doesn't
yet cover a lot of behaviour, altough this will hopefully be expanded in the
future.

A separate GitHub actions workflow should run on the pull request that was
automatically opened by the update workflow. Unfortunately GitHub doesn't run
workflows on pull requests opened by other workflows[^workflow-loop]. You can
make the tests run by closing and re-opening the pull request.

The tests can also be run locally by checking out the pull request and running
the following command:

```sh
nix flake check -L
```

[^workflow-loop]: Presumably, this is to avoid an infinite cycle of a workflow
    triggering itself.

## 3. Deploy the pull request to wpia-packit-dev

The `wpia-packit-dev` machine can be used as a staging environment to deploy
new versions of Packit. Run the following command, replacing `<pr number>` with
the appropriate value[^refresh].

[^refresh]: The `--refresh` argument is there to make sure Nix doesn't use a
    locally cached version of the repository.

```sh
nix run --refresh "github:reside-ic/packit-infra?ref=refs/pull/<pr number>/merge#deploy" wpia-packit-dev
```

The above command is also automatically added as a comment in the pull request.

Alternatively, if you've checked out the pull request locally, you can replace
the URL with the path to your local worktree (or `.` for the current working
directory), eg:

```sh
nix run ".#deploy" wpia-packit-dev
```

## 4. Verify that wpia-packit-dev works as expected

The things to look out for will depend on what changes the update carried. If
the update includes a particular new features, you should focus on checking
that particular feature.

The steps below are only suggestions, and may be slightly out of date if and
when changes are made to the interface.

- Visit <https://packit-dev.dide.ic.ac.uk>
    - You should see a list of instances, with just `packit-dev` listed.
- Follow the link to the `reside-dev` instance and log in using GitHub.
- The home page should have a list of available packet groups, with at least a handful of entries.
- Click on one of the packet groups to view the list of packets.
- Click on one of the packets to view the packet's metadata and list of files.
- Try to download some of the files.
- In the top-left corner, click the "Runner" button.
- Select the `main` branch and any of the packet group names (eg. `artefact-types`).
- Click the "Run" button.
- Wait for the packet to run and complete successfully.
- Click "View Packet"

In the future we will work to include automated end-to-end tests that can be
run against the `packit-dev` machine.

## 5. Merge the pull request

## 6. Deploy the main branch to all machines

```sh
nix run --refresh "github:reside-ic/packit-infra#deploy" wpia-packit-dev
nix run --refresh "github:reside-ic/packit-infra#deploy" wpia-packit-private
nix run --refresh "github:reside-ic/packit-infra#deploy" wpia-packit
```

Even though you would have deployed the pull request to `wpia-packit-dev`
already, you should also re-deploy the resulting main branch to it. This is
necessary as the deployment includes the Git hash of the repository, which will
be different after merging.

If you've lost track of what commit you've deployed to which machine, the
[Grafana dashboard][grafana] includes a table with each machine's commit, as
well as the main branch. When done, all rows of the table should show the same
commit hash.

[grafana]: https://bots.dide.ic.ac.uk/grafana/d/ec3e9e02-b051-4bf6-a995-3d4274e702fe/outpack
