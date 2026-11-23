#!/bin/sh
#
# Finishes an installation: ownership and the service's directories. Called
#   - by the port, on the staged tree:   finish-install.sh <staged prefix> <stageroot>
#   - by the installer that builds from source, on the real system:
#                                        finish-install.sh /usr/local ""
#
# The service runs as CLAW2_USER (default claw2) and writes under its own
# tree: what the skills produce, its state (./data, ./.claw2) and the
# environment file with the keys.
set -eu

prefix=$1
stageroot=${2:-}
user=${CLAW2_USER:-claw2}
group=${CLAW2_GROUP:-$user}

chown -R "$user:$group" "$prefix/share/claw2"
for dir in var/db/claw2 var/run/claw2; do
	mkdir -p "$stageroot/$dir"
	chown "$user:$group" "$stageroot/$dir"
done
