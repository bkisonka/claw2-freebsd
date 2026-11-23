#!/bin/sh
#
# Installs a claw2 jail from the package: a thin jail from the FreeBSD
# release of this host, the package put into it. On the FreeBSD host, as
# root, with access to the package repositories:
#
#   scripts/install-pkg.sh --pkg <claw2-<version>.pkg> \
#       --iface <interface> --ip <address> [--name <jail>] [--path <dir>]
#
# The package is scripts/build-pkg.sh's output, or a release's. FreeBSD and
# the package's dependencies come from this host's package repositories.

. "$(dirname "$0")/common.sh"
need_root

usage="usage: $0 --pkg <claw2-<version>.pkg> $INSTALL_USAGE"
case "${1:-}" in
--pkg) pkg=$2 ;;
*)
	echo "$usage" >&2
	exit 2
	;;
esac
shift 2
jail_options "$@" || { echo "$usage" >&2; exit 2; }
[ -s "$pkg" ] || die "package not found: $pkg"

guard_path "$JAIL_PATH"
if [ -e "$JAIL_PATH" ]; then
	die "$JAIL_PATH exists — remove the old jail first (scripts/jail.sh remove $JAIL_NAME)"
fi

log "FreeBSD $CLAW2_RELEASE $CLAW2_ARCH into $JAIL_PATH"
extract_base "$JAIL_PATH"
jail_conf "$JAIL_PATH" "$JAIL_NAME"
pkg_repos "$JAIL_PATH"

jail_up

log "the package's dependencies (node22, sqlite-ext-vec)"
pkg -j "$JAIL_NAME" install -y node22 sqlite-ext-vec || die "cannot install the dependencies"

log "claw2"
cp "$pkg" "$JAIL_PATH/tmp/claw2.pkg"
pkg -j "$JAIL_NAME" add /tmp/claw2.pkg || die "cannot install $pkg"
rm -f "$JAIL_PATH/tmp/claw2.pkg"

print_next_steps
