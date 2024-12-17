# Wiping a Packit instance

These steps remove all packets and associated data from a Packit instance.
This is a destructive operation with no way of rolling it back. It removes all
data from the instance indiscriminately. There currently isn't any way to
remove a single packet. Make sure you understand the consequences.

These steps will preserve auxiliary data held in Packit, including users,
roles and permissions.

There are two places where data needs to be deleted: we need to remove the data
from outpack_server and then clear the cache from Packit's database.

In the following instructions, `<fqdn>` refers to the hostname of the machine
hosting the instance (eg. `packit.dide.ic.ac.uk`) and `<instance>` refers to
the name of the instance (eg. `training`).

Start by connecting to the machine hosting the server using SSH. All subsequent
commands are to be run on the remote host.
```sh
ssh root@<fqdn>
```

The outpack and packit-api services need to be shutdown before proceeding:
```sh
systemctl stop outpack-<instance> packit-api-<instance>
```

Make sure the services are stopped as expected. The command should print
`Active: inactive (dead)` for both services.
```sh
systemctl status outpack-<instance> packit-api-<instance>
```

Delete the outpack root folder:
```sh
rm -r /var/lib/outpack/<instance>
```

Open an SQL session and delete all entries from the `packet` and `packet_group`
tables. Make sure you exit the session afterwards to return to the bash shell.
```sh
psql <instance>
=# DELETE FROM "packet";
=# DELETE FROM "packet_group";
=# exit
```

Start outpack server and Packit again. The outpack service unit will re-create
its root folder on start, and the Packit API server will populate the database
as new packets get pushed to the instance.
```sh
systemctl start outpack-<instance> packit-api-<instance>
```

Check the service logs to make sure everything is up and running again. The
`-r` flag shows logs in reverse order, ie. most recent entries first.
```sh
journalctl -u outpack-<instance> -u packit-api-<instance> -r
```
