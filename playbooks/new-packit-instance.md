# Adding a new Packit instance

These instructions will deploy a new Packit instance to an existing machine.
The instructions assume you already have a machine setup and an associated
GitHub application. Assuming the machine already has one instance deployed, its
GitHub application can be reused for the new instance. See
[the new machine playbook](new-machine-provisioning.md) for details on creating
a GitHub application.

## Configuration and deployment

These instructions use `<hostname>` as a placeholder for the name of the
machine that will be hosting the instance and `<instance>` as a placeholder for
the name of the instance. The instance name should only use alphanumerical
characters and `-`. It should be unique within its machine, and preferably
globally unique among all machines to avoid confusion.

Edit the relevant `machines/<hostname>.nix` file and add a new entry to the
`services.multi-packit.instances` list.

You will need to customize the instance by configuring some of the
`services.packit-api.<instance>` options. At the minimum, you will want to
set `authentication.method` to `"github"` and set `authentication.github.org`.
All members of this organisation will be allowed to access the instance using
their GitHub account.

Additionally, you may set a `authentication.github.team` value to restrict
access to just one team within that organisation.

Deploy the modified configuration to the server as usual.

## Authorizing the Github application

The OAuth application on Github manually needs to be granted permission, by one
of the organisation's admins, to access the organisation. See
[the GitHub documentation][github-oauth-org]. Because we use a single OAuth app
for all instances hosted on the same machine, this only needs to be done once
per org and domain, even if it is used by multiple instances.

[github-oauth-org]: https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-your-membership-in-organizations/requesting-organization-approval-for-oauth-apps

## Creating an initial admin

When the server is first deployed, no user has administrator priviledges. You
must manually grant add you GitHub account to the ADMIN role:

1. Log in to the instance with your GitHub account.
1. SSH onto the server.
1. Run `grant-role <instance> <username> ADMIN` where `<username>` is your
   GitHub username.
1. Log out and back in for the changes to take effect.

Afterwards permissions may be managed through the web UI.
