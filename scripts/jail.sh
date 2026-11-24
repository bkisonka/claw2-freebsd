#!/bin/sh
#
# A claw2 jail on this host: defined from a directory tree, started, used
# and removed. Shared by the three installers. Needs root.
#
#   jail.sh create <name> <path> <interface> <ip>
#   jail.sh exec <name> <command>        a shell command inside the jail
#   jail.sh start <name>
#   jail.sh stop <name>
#   jail.sh remove <name>                stop, drop the definition, delete the tree
#
# The jail's address is an alias of the interface while the jail runs. It is
# not optional: a jail without an address of its own has no IP network at
# all on FreeBSD — nothing to listen on, nothing to reach the model with.

. "$(dirname "$0")/common.sh"
need_root

usage() {
	echo "usage: $0 create <name> <path> <interface> <ip> | exec <name> <command> | start|stop|remove <name>" >&2
	exit 2
}

cmd=${1:-}
name=${2:-}
case "$cmd" in
create) [ $# -eq 5 ] || usage ;;
exec) [ $# -eq 3 ] || usage ;;
start | stop | remove) [ $# -eq 2 ] || usage ;;
*) usage ;;
esac

conf=/etc/jail.conf.d/$name.conf

case "$cmd" in
create)
	path=$3
	iface=$4
	ip=$5
	mkdir -p /etc/jail.conf.d
	cat > "$conf" <<EOF
# Written by claw2-freebsd; edit freely.
$name {
    path = "$path";
    host.hostname = "$name";
    interface = "$iface";
    ip4.addr = "$ip";
    exec.clean;
    exec.start = "/bin/sh /etc/rc";
    exec.stop = "/bin/sh /etc/rc.shutdown";
    exec.consolelog = "/var/log/jail_${name}_console.log";
    mount.devfs;
    mount.procfs;
    stop.timeout = 30;
}
EOF
	# So the jail comes back after a reboot.
	sysrc jail_enable=YES >/dev/null
	echo "jail $name defined in $conf (jail_enable=YES added to /etc/rc.conf)"
	;;
exec)
	jexec "$name" /bin/sh -c "$3"
	;;
start)
	# onestart: starting the jail now does not depend on jail_enable, on
	# whether this host starts its jails at boot at all.
	service jail onestart "$name" || die "cannot start the jail $name"
	# The rc script reports a jail that failed to start — and exits 0.
	jls -j "$name" >/dev/null 2>&1 ||
		die "the jail $name is not running — see /var/log/jail_${name}_console.log"
	;;
stop)
	service jail stop "$name"
	;;
remove)
	service jail stop "$name" 2>/dev/null || true
	jls -j "$name" >/dev/null 2>&1 && die "the jail $name is still running"
	path=$(sed -n 's/^    path = "\(.*\)";$/\1/p' "$conf" 2>/dev/null)
	rm -f "$conf"
	if [ -n "$path" ]; then
		unmount_tree "$path"
		guard_path "$path"
		# The FreeBSD base comes with its system files flagged schg
		# (immutable): rm alone cannot delete them.
		chflags -R 0 "$path" 2>/dev/null || true
		rm -rf "$path"
		echo "removed $path"
	fi
	;;
esac
