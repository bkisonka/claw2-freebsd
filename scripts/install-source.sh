#!/bin/sh
#
# Installs a claw2 jail and builds the application inside it, from the
# source. On the FreeBSD host, as root, with access to the package
# repositories, the npm registry and GitHub:
#
#   scripts/install-source.sh \
#       --iface <interface> --ip <address> [--name <jail>] [--path <dir>]
#
# The source is the release of bkisonka/claw2 — or CLAW2_SOURCE; the build
# is the port's own build script, and what the port does at install time is
# repeated here step by step. Takes ten minutes or so: no FreeBSD binaries
# are published for better-sqlite3 and bcrypt, they compile.

. "$(dirname "$0")/common.sh"
need_root
claw2_version

jail_options "$@" || { echo "usage: $0 $INSTALL_USAGE" >&2; exit 2; }

guard_path "$JAIL_PATH"
if [ -e "$JAIL_PATH" ]; then
	die "$JAIL_PATH exists — remove the old jail first (scripts/jail.sh remove $JAIL_NAME)"
fi

work=$PKGDIR/work
mkdir -p "$work"
tarball=$(source_tarball "$work/download") || exit 1

log "FreeBSD $CLAW2_RELEASE $CLAW2_ARCH into $JAIL_PATH"
extract_base "$JAIL_PATH"
jail_conf "$JAIL_PATH" "$JAIL_NAME"
pkg_repos "$JAIL_PATH"

jail_up

log "build dependencies (npm-node22 brings node22, python3.12 and gmake; python3 is the link node-gyp looks for)"
pkg -j "$JAIL_NAME" install -y npm-node22 python3 sqlite-ext-vec || die "cannot install the build dependencies"

log "the source and the port's files go into the jail"
mkdir -p "$JAIL_PATH/tmp/claw2"
cp "$tarball" "$JAIL_PATH/tmp/claw2/source.tar.gz"
cp -R "$PORTFILES" "$JAIL_PATH/tmp/claw2/files"

# build-app.sh installs the application; the rest is what the port does at
# install time: the service user, the service script, ownership.
"$PKGDIR/scripts/jail.sh" exec "$JAIL_NAME" "
	set -e
	mkdir -p /tmp/claw2/src && tar -xf /tmp/claw2/source.tar.gz -C /tmp/claw2/src
	sh /tmp/claw2/files/build-app.sh build /tmp/claw2/src/claw2-$CLAW2_VERSION
	sh /tmp/claw2/files/build-app.sh install /tmp/claw2/src/claw2-$CLAW2_VERSION /usr/local
	pw groupshow claw2 >/dev/null 2>&1 || pw groupadd claw2
	pw usershow claw2 >/dev/null 2>&1 ||
		pw useradd claw2 -g claw2 -M 0755 -d /var/db/claw2 -s /usr/sbin/nologin
	# What USE_RC_SUBR does for the package: %%PREFIX%% of the service script.
	# A bare FreeBSD has no /usr/local/etc/rc.d yet — the ports tree's mtree
	# makes it where the package is built.
	mkdir -p /usr/local/etc/rc.d
	sed -e 's|%%PREFIX%%|/usr/local|g' /tmp/claw2/files/claw2.in > /usr/local/etc/rc.d/claw2
	chmod 755 /usr/local/etc/rc.d/claw2
	sh /tmp/claw2/files/finish-install.sh /usr/local ''
	rm -rf /tmp/claw2
	# A third of a gigabyte of downloads that only the build needed.
	rm -rf /root/.npm
" || die "the build inside the jail failed — its output is above"

print_next_steps
