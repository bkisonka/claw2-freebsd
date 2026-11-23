#!/bin/sh
#
# Builds a jail template: a bare FreeBSD userland with the claw2 package
# installed, ready to be unpacked and started as a jail. On FreeBSD, as root:
#
#   scripts/build-jail.sh
#       -> dist/claw2-jail-<version>-<release>-<arch>.txz, its .sha256 and
#          dist/claw2.jail.conf, a matching jail.conf(5) stanza
#
# The package comes first (scripts/build-pkg.sh) and is installed into a
# fresh root, so no build tool ever touches the template. Settings:
# scripts/common.sh.

. "$(dirname "$0")/common.sh"
need_root
claw2_version

work=$PKGDIR/work
root=$work/jailroot
dist=$PKGDIR/dist
pkg=claw2-$CLAW2_VERSION.pkg
template=claw2-jail-$CLAW2_VERSION-$CLAW2_RELEASE-$CLAW2_ARCH

if [ ! -s "$dist/$pkg" ]; then
	log "no dist/$pkg yet — building it"
	"$PKGDIR/scripts/build-pkg.sh" || die "cannot build the package"
fi

log "fresh FreeBSD $CLAW2_RELEASE $CLAW2_ARCH"
"$PKGDIR/scripts/buildroot.sh" create "$root" || die "cannot create the root"

log "installing the package and what it depends on"
cp "$dist/$pkg" "$root/tmp/$pkg"
pkg -c "$root" install -y node22 sqlite-ext-vec || die "cannot install the dependencies"
pkg -c "$root" add "/tmp/$pkg" || die "cannot install $pkg"
rm -f "$root/tmp/$pkg"
jail_conf "$root" claw2

# Leave nothing of this machine in the template: the package cache, the
# logs, the package repositories it installed from — keys included, all of
# /usr/local/etc/pkg is theirs — and the way it resolves names. The host
# that runs the jail provides its own.
pkg -c "$root" clean -ay >/dev/null 2>&1 || true
rm -rf "$root/var/log/*" "$root/var/run/*" "$root/tmp/*" "$root/root/.npm" \
	"$root/root/.cache" "$root/usr/local/etc/pkg"
rm -f "$root/etc/resolv.conf"
mkdir -p "$root/var/run" "$root/var/log"

log "packing dist/$template.txz — a few minutes"
rm -f "$dist/$template.txz"
# Without the devfs and the procfs of the build root: the jail mounts its own.
unmount_tree "$root"
tar -C "$root" -cJf "$dist/$template.txz" .
sha256_file "$dist" "$template.txz"

cat > "$dist/claw2.jail.conf" <<EOF
# claw2 $CLAW2_VERSION — jail for FreeBSD $CLAW2_RELEASE $CLAW2_ARCH.
# Unpack the template first:
#     mkdir -p /usr/local/jails/claw2
#     tar -xf $template.txz -C /usr/local/jails/claw2
#     cp /etc/resolv.conf /usr/local/jails/claw2/etc/resolv.conf
# Put this stanza into /etc/jail.conf.d/claw2.conf and adjust the interface
# and the address — a free one on that network: without an address of its
# own a jail has no network at all. Then:  service jail start claw2
claw2 {
    path = "/usr/local/jails/claw2";
    host.hostname = "claw2";
    interface = "em0";
    ip4.addr = "192.168.1.70";
    exec.clean;
    exec.start = "/bin/sh /etc/rc";
    exec.stop = "/bin/sh /etc/rc.shutdown";
    exec.consolelog = "/var/log/jail_claw2_console.log";
    mount.devfs;
    mount.procfs;
    stop.timeout = 30;
}
EOF

log "dist/$template.txz — $(du -h "$dist/$template.txz" | cut -f1), $(du -sh "$root" | cut -f1) unpacked"
