# Debugging an existing machine

This page lists useful tools used to inspect and debug the state of a deployed
machine. All the commands listed on this page are intended to be run directly
on the machine, either over SSH or in the VM console.

## How do I manage services?

All the services on the machine are managed by systemd. The
[`systemctl` command][systemctl] can be used to interact with them.

Services that may be running include the Packit API, outpack_server, the runner
API and workers, nginx, redis, postgresql, etc.

```sh
# Check the status of all services
$ systemctl status

# Check the status of a particular service
$ systemctl status outpack-<instance>
$ systemctl status packit-api-<instance>
$ systemctl status orderly-runner-api
$ systemctl status orderly-runner-worker-0

# Restart a particular service
$ systemctl restart outpack-<instance>
$ systemctl restart packit-api-<instance>
$ systemctl restart orderly-runner-api
$ systemctl restart orderly-runner-worker-0

# See the list of services that have failed to start
$ systemctl list-units --failed
```

The `systemctl` command has pretty good completion support. You can start
typing the name of a unit[^unit] and press TAB to see suggestions.

[systemctl]: https://www.freedesktop.org/software/systemd/man/latest/systemctl.html
[^unit]: A systemd "unit" is a generalization of a service. Units include
    services but also timers, sockets, mount points, etc.

## How do I check a service's logs?

All of the logs from systemd units are stored by journald. You can view those
logs using the [`journalctl` command][journalctl]:

```sh
# View the logs for the entire machine
$ journalctl

# View the logs for a particular service
$ journalctl -u outpack-<instance>
$ journalctl -u packit-api-<instance>

# View the logs for multiple services, interleaved
$ journalctl -u outpack-<instance> -u packit-api-<instance>
```

By default `journalctl` shows all logs on disk, starting with the oldest.
Usually you'll instead be interested in recent logs:
- `--since today` shows only today's logs, starting at midnight.
- `--since "4 hours ago"` shows only the last 4 hours of logs.
- `--pager-end` / `-e` skips to the bottom of the logs.
- `--reverse` / `-r` shows the logs in reverse order, ie. most recent first.
- `--boot` / `-b` shows logs since the last reboot of the machine.
- `--follow` / `-f` waits and prints new log lines as they get produced.
- `--grep=PATTERN` only show lines where the message matches the given regular
    expression.

[journalctl]: https://www.freedesktop.org/software/systemd/man/latest/journalctl.html

## How do I inspect / edit the database?

> [!WARNING]
> If doing this on the production instance, start by thinking very carefully
> about what you are about to do.

The `psql` command can be used to get an SQL session to the database of your
choice. Each Packit instance uses its own database. The root Linux user has
permissions to access any of them.

```sh
$ psql <instance>
=# SELECT * FROM "user";
```

The database is initially populated by the packit-api service. During the first
start of a new instance, it can take a minute for the service to start and for
the database's tables to exist.

## How do I inspect the state of the runner queue?

The `runner-cli` command can be used to interact with the runner queue using
the [`rrq` package](https://mrc-ide.github.io/rrq/). The command starts an R
interactive session with the package attached and a default controller
configured already.

```sh
$ runner-cli
> rrq_worker_list()
> [1] "dermatoplastic_coral"

# The command accepts standard R flags
$ runner-cli -s -e 'rrq_worker_list()'
[1] "dermatoplastic_coral"
```

Note that behind the scenes, the R session runs inside an ephemeral container,
therefore it will have its own view of the file system. While you can install
new packages, these will be installed inside of the container and will go away
when the session is closed.

The standard `redis-cli` command is also available:
```sh
$ redis-cli
127.0.0.1:6379> SMEMBERS "orderly.runner.queue:worker:id"
1) "dermatoplastic_coral"
```

A particularly useful command is `monitor`, which may be used to monitor all
commands issued by other processes, including the the runner API and the
workers:
```sh
$ redis-cli monitor
OK
1739897967.173346 [0 127.0.0.1:50730] "EXPIRE" "orderly.runner.queue:worker:dermatoplastic_coral:heartbeat" "30"
1739897967.179299 [0 127.0.0.1:50730] "BLPOP" "orderly.runner.queue:worker:dermatoplastic_coral:heartbeat:kill" "10"
```

