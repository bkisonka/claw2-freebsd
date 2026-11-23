#!/bin/sh
#
# Installs a claw2 jail from a template — the jail root filesystem that
# scripts/build-jail.sh builds and a release ships. On the FreeBSD host, as
# root:
#
#   scripts/install-template.sh --template <claw2-jail-...txz> \
#       --iface <interface> --ip <address> [--name <jail>] [--path <dir>]
#
# The template is unpacked as it is: FreeBSD, the claw2 package and nothing
# else to download. Name resolution and the package repositories come from
# this host. The gateway starts with the jail as soon as its configuration
# is in place (the script prints what is left to do).

. "$(dirname "$0")/common.sh"
need_root

usage="usage: $0 --template <claw2-jail-<version>-<release>-<arch>.txz> $INSTALL_USAGE"
case "${1:-}" in
--template) template=$2 ;;
*)
	echo "$usage" >&2
	exit 2
	;;
esac
shift 2
jail_options "$@" || { echo "$usage" >&2; exit 2; }
[ -s "$template" ] || die "template not found: $template"

# The template is a FreeBSD userland: it has to be the release of this host.
case $(basename "$template") in
claw2-jail-*-"$CLAW2_RELEASE"-"$CLAW2_ARCH".txz) ;;
claw2-jail-*-*.txz)
	die "$template is not for FreeBSD $CLAW2_RELEASE $CLAW2_ARCH — this host"
	;;
esac

# The build leaves a checksum next to the template.
if [ -s "$template.sha256" ]; then
	want=$(awk 'NR == 1 {print $1}' "$template.sha256")
	got=$(sha256 -q "$template")
	[ "$got" = "$want" ] || die "checksum mismatch for $template: got $got, want $want"
fi

guard_path "$JAIL_PATH"
if [ -e "$JAIL_PATH" ] && [ -n "$(ls -A "$JAIL_PATH" 2>/dev/null)" ]; then
	die "$JAIL_PATH exists and is not empty"
fi
mkdir -p "$JAIL_PATH"

log "unpacking $template into $JAIL_PATH"
tar -xf "$template" -C "$JAIL_PATH"
# Name resolution and package repositories come from this host.
cp /etc/resolv.conf "$JAIL_PATH/etc/resolv.conf" 2>/dev/null || true
pkg_repos "$JAIL_PATH"

jail_up
print_next_steps
