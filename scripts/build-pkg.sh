#!/bin/sh
#
# Builds the claw2 package with the port (port/www/claw2) in a build root.
# On FreeBSD, as root:
#
#   scripts/build-pkg.sh        ->  dist/claw2-<version>.pkg and its .sha256
#
# The build root is a bare FreeBSD userland with the build dependencies,
# the ports framework and the port itself. The application's source is the
# release of bkisonka/claw2 — or CLAW2_SOURCE. Settings: scripts/common.sh.

. "$(dirname "$0")/common.sh"
need_root
claw2_version

work=$PKGDIR/work
root=$work/buildroot
dist=$PKGDIR/dist
name=claw2-$CLAW2_VERSION
distfile=v$CLAW2_VERSION.tar.gz
# The build root's packages, and the ports the package and its build refer
# to: the framework insists the latter exist. python3 is the python3 link
# node-gyp looks for (python312, which npm-node22 brings, installs only
# python3.12).
deps="pkg npm-node22 node22 python3 sqlite-ext-vec"
origins="ports/ports-mgmt/pkg ports/www/node22 ports/www/npm-node22 ports/lang/python3 ports/databases/sqlite-ext-vec"

mkdir -p "$work" "$dist"

log "source of $name"
# Taken down at once: helper functions share this shell's variables.
src_tarball=$(source_tarball "$work/download") || exit 1
src_sha256=$(sha256 -q "$src_tarball")
src_size=$(stat -f %z "$src_tarball")

# CLAW2_REUSE_BUILDROOT=1 keeps the root of the previous run — the build
# dependencies are already in it. "pkg" is among them: pkg -c runs the
# host's pkg against the root and puts nothing into it, and the ports
# framework builds any dependency it misses from source.
# shellcheck disable=SC2086
if [ "${CLAW2_REUSE_BUILDROOT:-}" = 1 ] && [ -x "$root/usr/local/bin/npm" ]; then
	log "reusing the build root $root"
	"$PKGDIR/scripts/buildroot.sh" mount "$root"
	# A package added to the list since that root was made.
	pkg -c "$root" install -y $deps || die "cannot install into the build root: $deps"
else
	log "build root with the build dependencies"
	"$PKGDIR/scripts/buildroot.sh" create "$root" $deps || die "cannot create the build root"
fi
# shellcheck disable=SC2086
ports_framework "$root/usr" $origins

# The port, its distfile and the checksum record of this very source.
mkdir -p "$root/usr/ports/www" "$root/usr/ports/distfiles/claw2"
rm -rf "$root/usr/ports/www/claw2"
cp -R "$PORTDIR" "$root/usr/ports/www/claw2"
cp "$src_tarball" "$root/usr/ports/distfiles/claw2/$distfile"
{
	echo "TIMESTAMP = $(date +%s)"
	echo "SHA256 (claw2/$distfile) = $src_sha256"
	echo "SIZE (claw2/$distfile) = $src_size"
} > "$root/usr/ports/www/claw2/distinfo"

log "building the package: npm ci, tsc, web, pwa — several minutes"
"$PKGDIR/scripts/buildroot.sh" exec "$root" \
	"cd /usr/ports/www/claw2 && BATCH=yes make package" || die "the port did not build"

built=$(ls "$root"/usr/ports/www/claw2/work/pkg/*.pkg 2>/dev/null | head -1)
[ -n "$built" ] || die "the port produced no package"
cp "$built" "$dist/$name.pkg"
sha256_file "$dist" "$name.pkg"
log "dist/$name.pkg — $(du -h "$dist/$name.pkg" | cut -f1)"
