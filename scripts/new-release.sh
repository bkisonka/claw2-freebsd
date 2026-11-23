#!/bin/sh
#
# Points the packaging at a release of bkisonka/claw2. On FreeBSD:
#
#   scripts/new-release.sh <version>
#
# Sets the version in the port and records the checksum of the release's
# source archive in port/www/claw2/distinfo. What is left is yours:
# commit, then  make pkg jail  and attach dist/ to the GitHub release.
# No root needed.

. "$(dirname "$0")/common.sh"
version=${1:-}
case "$version" in
"" | *[!a-zA-Z0-9._-]*) die "usage: $0 <version>, e.g. 0.2.17" ;;
esac

url=$CLAW2_SOURCE_URL/v$version.tar.gz
tmp=${TMPDIR:-/tmp}/claw2-v$version.tar.gz.$$
echo "fetching $url"
fetch -q -o "$tmp" "$url" || die "cannot fetch it — is the tag v$version published?"

sed -i '' -e "s/^DISTVERSION=[[:space:]]*.*/DISTVERSION=\t$version/" "$PORTDIR/Makefile"
{
	echo "TIMESTAMP = $(date +%s)"
	echo "SHA256 (claw2/v$version.tar.gz) = $(sha256 -q "$tmp")"
	echo "SIZE (claw2/v$version.tar.gz) = $(stat -f %z "$tmp")"
} > "$PORTDIR/distinfo"
rm -f "$tmp"

echo "port/www/claw2/Makefile: DISTVERSION=$version"
echo "port/www/claw2/distinfo:"
cat "$PORTDIR/distinfo"
echo
echo "next: make pkg jail   — then attach dist/ to the release v$version"
