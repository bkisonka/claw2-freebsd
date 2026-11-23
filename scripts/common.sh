# Shared settings and helpers of the claw2 FreeBSD packaging. Sourced by
# the scripts in this directory, never executed on its own.
#
# Every setting can be overridden from the environment:
#   CLAW2_SOURCE     a local tarball or directory with the application's
#                    source, instead of its GitHub release
#   CLAW2_MIRROR     a mirror of the FreeBSD release files (base.txz)
#   CLAW2_PKG_REPO   a pkg(8) repository definition for the roots built
#                    here — for networks where pkg's own server pool
#                    misbehaves (the file is copied to
#                    /usr/local/etc/pkg/repos/FreeBSD.conf inside; without
#                    it a tree gets this host's repositories)
#   CLAW2_RELEASE    FreeBSD release to build for   (default: this system)
#   CLAW2_ARCH       architecture                     (default: this system)
#   CLAW2_CACHE      where downloads are kept (default /var/cache/claw2-freebsd)

PKGDIR=$(cd "$(dirname "$0")/.." && pwd)
PORTDIR=$PKGDIR/port/www/claw2
PORTFILES=$PORTDIR/files

CLAW2_SOURCE_URL=${CLAW2_SOURCE_URL:-https://github.com/bkisonka/claw2/archive/refs/tags}
CLAW2_RELEASE=${CLAW2_RELEASE:-$(uname -r | sed 's/-p[0-9]*$//')}
CLAW2_ARCH=${CLAW2_ARCH:-$(uname -m)}
CLAW2_MIRROR=${CLAW2_MIRROR:-https://download.freebsd.org/ftp}
# Checksums always come from the official site, whatever mirror the files
# themselves come from.
CLAW2_OFFICIAL=${CLAW2_OFFICIAL:-https://download.freebsd.org/ftp}
CLAW2_CACHE=${CLAW2_CACHE:-/var/cache/claw2-freebsd}

# To stderr: the functions below are called in $(...), where a message on
# stdout would end up being used as a path.
die() { echo "$(basename "$0"): $*" >&2; exit 1; }
log() { echo "== $*" >&2; }
need_root() { [ "$(id -u)" = 0 ] || die "must run as root"; }

# The version lives in one place: the port.
claw2_version() {
	CLAW2_VERSION=${CLAW2_VERSION:-$(sed -n 's/^DISTVERSION=[[:space:]]*//p' "$PORTDIR/Makefile")}
	[ -n "$CLAW2_VERSION" ] || die "cannot read DISTVERSION from $PORTDIR/Makefile"
	export CLAW2_VERSION
}

# download <url> <file>: keeps what is already there.
download() {
	[ -s "$2" ] && return 0
	mkdir -p "$(dirname "$2")"
	fetch -q -o "$2.tmp" "$1" || die "cannot fetch $1"
	mv "$2.tmp" "$2"
}

# release_file <name>: prints the cached path of a file of the FreeBSD
# release (base.txz, ...), downloading it once and checking its SHA256
# against the release's MANIFEST. Called as  x=$(release_file f) || exit 1.
release_file() {
	rf_dir=$CLAW2_CACHE/$CLAW2_RELEASE-$CLAW2_ARCH
	rf_name=$1
	if [ ! -s "$rf_dir/$rf_name" ]; then
		log "downloading $rf_name — FreeBSD $CLAW2_RELEASE $CLAW2_ARCH"
		rel=$CLAW2_ARCH/$CLAW2_ARCH/$CLAW2_RELEASE
		rm -f "$rf_dir/$rf_name"
		download "$CLAW2_MIRROR/releases/$rel/$rf_name" "$rf_dir/$rf_name"
		download "$CLAW2_OFFICIAL/releases/$rel/MANIFEST" "$rf_dir/MANIFEST"
		want=$(awk -F'\t' -v n="$rf_name" '$1 == n {print $2}' "$rf_dir/MANIFEST")
		[ -n "$want" ] || die "no checksum for $rf_name in the release's MANIFEST"
		got=$(sha256 -q "$rf_dir/$rf_name")
		if [ "$got" != "$want" ]; then
			rm -f "$rf_dir/$rf_name"
			die "checksum mismatch for $rf_name: got $got, want $want"
		fi
	fi
	echo "$rf_dir/$rf_name"
}

# extract_base <root>: a bare FreeBSD userland at <root>.
extract_base() {
	eb_base=$(release_file base.txz) || exit 1
	mkdir -p "$1"
	tar -xf "$eb_base" -C "$1"
}

# pkg_repos <root>: where the pkg(8) that installs into the tree takes its
# package repositories from — CLAW2_PKG_REPO if there is one, otherwise what
# this host installs from, keys included. Left alone, a bare tree knows only
# FreeBSD's own server pool.
pkg_repos() {
	pr_etc=$1/usr/local/etc
	mkdir -p "$pr_etc/pkg/repos"
	if [ -n "${CLAW2_PKG_REPO:-}" ]; then
		cp "$CLAW2_PKG_REPO" "$pr_etc/pkg/repos/FreeBSD.conf" ||
			die "cannot take the repository definition from $CLAW2_PKG_REPO"
	else
		cp /usr/local/etc/pkg/repos/*.conf "$pr_etc/pkg/repos/" 2>/dev/null || true
		if [ -d /usr/local/etc/pkg/keys ]; then
			cp -R /usr/local/etc/pkg/keys "$pr_etc/pkg/"
		fi
	fi
}

# unmount_tree <root>: whatever is mounted under the tree, deepest first —
# a devfs or a procfs of a kept root, stacked mounts included.
unmount_tree() {
	ut_root=$1
	mount -p | awk -v r="$ut_root/" '$2 ~ "^" r {print $2}' | while read -r m; do
		umount -f "$m" 2>/dev/null || true
	done
}

# sha256_file <dir> <file>: the checksum of <file> next to it, in the form
# both sha256(1) -c and sha256sum(1) -c read.
sha256_file() {
	(cd "$1" && echo "$(sha256 -q "$2")  $2" > "$2.sha256")
}

# source_tarball <dir>: prints the path of the application's source as
# port/www/claw2 expects its distfile (GitHub archive of the release tag,
# top directory claw2-<version>). CLAW2_SOURCE substitutes a local tree.
# Called as  x=$(source_tarball dir) || exit 1.
source_tarball() {
	claw2_version
	tarball=$1/claw2-v$CLAW2_VERSION.tar.gz
	if [ -s "$tarball" ]; then
		echo "$tarball"
		return 0
	fi
	mkdir -p "$1"
	if [ -n "${CLAW2_SOURCE:-}" ]; then
		log "using the local source $CLAW2_SOURCE"
		if [ -d "$CLAW2_SOURCE" ]; then
			# The top directory must be named like GitHub's archive.
			base=$(basename "$CLAW2_SOURCE")
			tar -czf "$tarball.tmp" -C "$(dirname "$CLAW2_SOURCE")" \
				--exclude '*/node_modules' --exclude '*/dist' --exclude '*/.git' \
				-s "/^${base}\$/claw2-${CLAW2_VERSION}/" "$base"
		else
			cp "$CLAW2_SOURCE" "$tarball.tmp"
		fi
		mv "$tarball.tmp" "$tarball"
	else
		log "downloading bkisonka/claw2 v$CLAW2_VERSION"
		download "$CLAW2_SOURCE_URL/v$CLAW2_VERSION.tar.gz" "$tarball"
	fi
	got=$(sha256 -q "$tarball")
	want=$(sed -n "s/^SHA256 (claw2\/v$CLAW2_VERSION.tar.gz) = //p" "$PORTDIR/distinfo" 2>/dev/null)
	if [ -z "$want" ]; then
		echo "WARNING: no checksum recorded for v$CLAW2_VERSION in port/www/claw2/distinfo." >&2
		echo "         sha256 of what was fetched: $got" >&2
	elif [ "$got" != "$want" ]; then
		rm -f "$tarball"
		die "checksum mismatch for the source: got $got, want $want"
	fi
	echo "$tarball"
}

# The options the installers share:
#   --iface <interface> --ip <address>   the jail's address while it runs —
#                                        an alias of the interface: a free
#                                        one on that network
#   --name <jail>                        default claw2
#   --path <dir>                         default /usr/local/jails/<name>
# The address is not optional: a jail without one has no IP at all on
# FreeBSD, and the gateway needs the network in both directions.
jail_options() {
	JAIL_NAME=claw2
	JAIL_PATH=
	JAIL_IFACE=
	JAIL_IP=
	while [ $# -gt 0 ]; do
		[ $# -ge 2 ] || return 1
		case "$1" in
		--name) JAIL_NAME=$2 ;;
		--path) JAIL_PATH=$2 ;;
		--iface) JAIL_IFACE=$2 ;;
		--ip) JAIL_IP=$2 ;;
		*) return 1 ;;
		esac
		shift 2
	done
	case "$JAIL_NAME" in
	"" | *[!a-zA-Z0-9_-]*) return 1 ;;
	esac
	[ -n "$JAIL_PATH" ] || JAIL_PATH=/usr/local/jails/$JAIL_NAME
	if [ -z "$JAIL_IFACE" ] || [ -z "$JAIL_IP" ]; then
		echo "$0: a jail has no network without an address of its own" >&2
		return 1
	fi
	# The interface goes into jail.conf(5) as it is: nothing that could end
	# a line. The address lands in ip4.addr: it has to be an IPv4 one.
	case "$JAIL_IFACE" in
	*[!a-zA-Z0-9_.:-]*) return 1 ;;
	esac
	case "$JAIL_IP" in
	*[!0-9.]*) return 1 ;;
	esac
	JAIL_ARGS="$JAIL_IFACE $JAIL_IP"
}

INSTALL_USAGE="--iface <interface> --ip <address> [--name <jail>] [--path <dir>]"

# jail_up: the jail jail_options described, defined and started. A jail
# that does not start ends the installer: what is wrong is in its console log.
jail_up() {
	# shellcheck disable=SC2086
	"$PKGDIR/scripts/jail.sh" create "$JAIL_NAME" "$JAIL_PATH" $JAIL_ARGS || exit 1
	"$PKGDIR/scripts/jail.sh" start "$JAIL_NAME" || exit 1
}

# What to do once the files are in place. The same text as the package's
# pkg-message, with this jail's paths.
print_next_steps() {
	etc=$JAIL_PATH/usr/local/etc/claw2
	cat <<EOF

claw2 is installed in the jail $JAIL_NAME.

1. Configuration — copy the sample and edit it:
     cp $etc/claw2.yaml.sample $etc/claw2.yaml
   The service makes the file its own when it starts: the web interface
   saves its settings into it.

2. Keys — into $etc/claw2.env, as root, mode 0600 (the service reads it and
   hands the values to the gateway; nobody else needs access):
     OPENAI_API_KEY=sk-...
     CLAW2_GATEWAY_API_KEY=\$(openssl rand -hex 24)

3. Start it (from now on the gateway starts with the jail):
     jexec $JAIL_NAME service claw2 start

The interface is at http://$JAIL_IP:3000 and asks for the gateway key.
The log: $JAIL_PATH/var/log/claw2.log
EOF
}

# ports_framework <dir> <origin>...: unpacks what a port needs from the
# ports tree into <dir>/ports — Mk with its Uses, Templates, Keywords,
# Tools — and the ports named by origin (www/claw2's dependencies, for
# one: the framework checks that every origin a package refers to exists).
# Variables are prefixed: a function's variables are global in sh.
ports_framework() {
	pf_dir=$1
	shift
	pf_tarball=$CLAW2_CACHE/ports/ports.tar.xz
	if [ ! -s "$pf_tarball" ]; then
		log "downloading the ports framework"
		download "${CLAW2_PORTS_URL:-$CLAW2_MIRROR/ports/ports/ports.tar.xz}" "$pf_tarball"
	fi
	mkdir -p "$pf_dir"
	set -- ports/Mk ports/Templates ports/Keywords ports/Tools "$@"
	tar -xf "$pf_tarball" -C "$pf_dir" "$@"
}

# jail_conf <root> <hostname>: what a jail runs at start-up — and what it
# had better not: sendmail, a syslog listening on the network, sshd.
jail_conf() {
	jc_root=$1
	jc_host=$2
	cat > "$jc_root/etc/rc.conf" <<EOF
hostname="$jc_host"
sendmail_enable="NONE"
sendmail_submit_enable="NO"
sendmail_outbound_enable="NO"
sendmail_msp_queue_enable="NO"
syslogd_flags="-ss"
cron_flags="-J 60"
sshd_enable="NO"
claw2_enable="YES"
EOF
	# To resolve names in there, from this host.
	cp /etc/resolv.conf "$jc_root/etc/resolv.conf" 2>/dev/null || true
}

# guard_path <path>: refuses to remove anything that is not a full path
# given on the command line.
guard_path() {
	case "$1" in
	/*/*/*) ;;
	*) die "refusing to touch '$1': expected an explicit path" ;;
	esac
}
