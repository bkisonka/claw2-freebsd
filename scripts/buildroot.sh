#!/bin/sh
#
# A build root for the packaging: a bare FreeBSD userland in a directory,
# with the packages a build needs. Commands run in it through chroot(8), so
# nothing leaks into the system that builds. Needs root.
#
#   buildroot.sh create <root> [<package>...]   new root from the FreeBSD
#                                               release, with the packages
#   buildroot.sh mount <root>                   (re)mount what a kept root needs
#   buildroot.sh exec <root> <command>          run a shell command inside
#   buildroot.sh destroy <root>                 unmount and delete
#
# Settings come from common.sh (CLAW2_MIRROR, CLAW2_PKG_REPO, ...).

. "$(dirname "$0")/common.sh"
need_root

usage() {
	echo "usage: $0 create|mount|destroy <root> [<package>...] | exec <root> <command>" >&2
	exit 2
}

cmd=${1:-}
root=${2:-}
case "$cmd" in
create | mount) ;;
exec) [ $# -eq 3 ] || usage ;;
destroy) ;;
*) usage ;;
esac
[ -n "$root" ] || usage
guard_path "$root"

mounted() {
	mount -p | awk -v m="$1" '$2 == m {f = 1} END {exit !f}'
}

mount_root() {
	# node needs /dev/null and /dev/urandom; procfs is for the tooling. A
	# kept root may have them already: mounting again would stack them.
	mkdir -p "$root/proc"
	mounted "$root/dev" || mount -t devfs devfs "$root/dev" 2>/dev/null || true
	mounted "$root/proc" || mount -t procfs proc "$root/proc" 2>/dev/null || true
}

# The FreeBSD base comes with its system files flagged schg (immutable):
# rm alone cannot delete them.
delete_root() {
	unmount_tree "$root"
	chflags -R 0 "$root" 2>/dev/null || true
	rm -rf "$root"
}

case "$cmd" in
create)
	shift 2
	log "build root $root — FreeBSD $CLAW2_RELEASE $CLAW2_ARCH"
	# A leftover root of an interrupted run still has its mounts.
	delete_root
	extract_base "$root"
	cp /etc/resolv.conf "$root/etc/resolv.conf" 2>/dev/null || true
	chmod 1777 "$root/tmp"
	mount_root
	pkg_repos "$root"
	pkg -c "$root" update || die "cannot reach the package repositories from the build root"
	if [ $# -gt 0 ]; then
		pkg -c "$root" install -y "$@" || die "cannot install: $*"
	fi
	;;
mount)
	mount_root
	;;
exec)
	chroot "$root" /usr/bin/env -i \
		PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin \
		HOME=/root TERM=${TERM:-dumb} \
		/bin/sh -c "$3"
	;;
destroy)
	delete_root
	;;
esac
