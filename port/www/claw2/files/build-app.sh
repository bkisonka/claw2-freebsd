#!/bin/sh
#
# Builds claw2 from a source tree on FreeBSD and installs the result into
# a prefix. One script for the port (www/claw2) and for the installer that
# builds from source, so the two cannot drift apart.
#
#   build-app.sh build   <source-dir>
#   build-app.sh install <source-dir> <prefix>
#
# build needs node >= 22.13, npm, python3 and gmake: no FreeBSD binaries are
# published for better-sqlite3 and bcrypt, node-gyp compiles them.
# install needs the sample config next to this script.
set -eu

usage() {
	echo "usage: $0 build <source-dir> | install <source-dir> <prefix>" >&2
	exit 2
}

[ $# -ge 2 ] || usage
cmd=$1
src=$2
case "$cmd" in
build) ;;
install) [ $# -eq 3 ] || usage; prefix=$3 ;;
*) usage ;;
esac

: "${NPM:=npm}"

# Everything the gateway serves or needs at start-up.
PAYLOAD="dist node_modules web/dist pwa/dist agents prompts wiki hss.cjs package.json"
LICENSES="LICENSE COPYING COPYING.LESSER LICENSE-HSS.md LICENSE.ru.md NOTICE"

build() {
	cd "$src"
	npm_major=$("$NPM" --version | cut -d. -f1)

	# npm 12 refuses dependencies given as tarball URLs; pwa's xlsx is one
	# (SheetJS publishes outside the registry). Older npm needs no flag.
	remote=""
	[ "$npm_major" -ge 12 ] && remote="--allow-remote=root"

	# node-gyp compiles better-sqlite3 and bcrypt against the headers of the
	# node it runs under. The node port installs them under the prefix:
	# pointed there, node-gyp does not go to nodejs.org for them. The
	# setting is node-gyp's, which reads it from the environment on its own;
	# npm warns that it does not know it, and passes.
	: "${npm_config_nodedir:=${LOCALBASE:-/usr/local}}"
	export npm_config_nodedir

	# --force: @huggingface/transformers depends on onnxruntime-node, which
	# declares os win32|darwin|linux — npm refuses to install it anywhere
	# else. It is installed without a binary; only local embeddings load
	# it, and they are not available on FreeBSD.
	"$NPM" ci --force
	"$NPM" run build

	# The web client in single-user mode, as the Docker image builds it.
	(cd web && "$NPM" ci && VITE_CLAW2_SINGLE_USER=1 "$NPM" run build)

	# The PWA needs no install-time binaries (sharp) — again as in the image.
	(cd pwa && "$NPM" ci $remote --ignore-scripts && "$NPM" rebuild esbuild && "$NPM" run build)

	# Keep what the gateway loads at run time: the first step installed the
	# toolchain (typescript, esbuild, vitest) to build with.
	"$NPM" ci --force --omit=dev

	# The bundled skills' libraries, next to the skills. In the soft sandbox —
	# the only one on FreeBSD — a skill may read agents/node_modules, not the
	# application's node_modules, where the Docker image puts them (its skills
	# run in a container and see the whole tree). agents/package-lock.json is
	# left aside: it does not match agents/package.json, so the versions come
	# from the registry, as the image's do. The optional chart.js is skipped
	# like in the image: the chart skill renders through QuickChart.
	(cd agents && "$NPM" install --no-save --no-package-lock --omit=optional \
		--no-audit --no-fund)
}

install_app() {
	for item in $PAYLOAD; do
		if [ ! -e "$src/$item" ]; then
			echo "$0: $src/$item is missing — build first" >&2
			exit 1
		fi
	done
	dest="$prefix/share/claw2"
	mkdir -p "$dest"
	(cd "$src" && tar -cf - $PAYLOAD) | (cd "$dest" && tar -xf -)
	for f in $LICENSES; do
		[ -f "$src/$f" ] && cp "$src/$f" "$dest/"
	done
	# The gateway writes what the skills produce; both live under agents/.
	mkdir -p "$dest/agents/output" "$dest/agents/uploads"
	mkdir -p "$prefix/etc/claw2"
	cp "$(dirname "$0")/claw2.yaml.sample" "$(dirname "$0")/claw2.env.sample" "$prefix/etc/claw2/"
	echo "installed into $dest"
}

case "$cmd" in
build) build ;;
install) install_app ;;
esac
