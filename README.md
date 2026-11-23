# claw2 for FreeBSD

[English](README.md) · [Русский](README.ru.md)

[claw2](https://github.com/bkisonka/claw2) — a personal AI agent you host
yourself — as native FreeBSD software: a `pkg(8)` package, a jail template
and an installer that builds from source. No Docker and nothing of the
Linux delivery: the gateway is an ordinary `rc.d` service inside a jail.

This repository is the packaging only. It holds no code of the application:
the source is taken from a release of bkisonka/claw2, and the package is
the build of one release tag, nothing more.

All three ways end the same: the jail `claw2` with FreeBSD, the package and
its service, to be configured and started.

## The three ways

| | Jail template | Package | From source |
|---|---|---|---|
| What you take | the template, about 330 MB | the package, about 140 MB | this repository |
| What your host downloads | nothing | `base.txz` of its FreeBSD release (165 MB); `node22` and `sqlite-ext-vec` from the package repositories | the same, the build dependencies (npm, python, gmake) and from the npm registry everything the application is built from |
| What happens on your host | the template is unpacked and started as a jail | a thin jail from the release of the host, the package installed into it | the same jail, and the application built inside it — about ten minutes |
| FreeBSD release of the jail | the template's | the host's | the host's |
| With | `scripts/install-template.sh` | `scripts/install-pkg.sh` | `scripts/install-source.sh` |

The package and the template of a release are built on FreeBSD 15.1-RELEASE
amd64, the release all of this was tested on. A package is built against
one FreeBSD release, and a template is a release's userland: on another
release or architecture, build your own with the scripts below — they
follow the host they run on. (That has not been tested.)

## Requirements

- FreeBSD, and root on the host.
- A free IP address for the jail, on one of the host's interfaces. The
  scripts add it as an alias while the jail runs and remove it with the
  jail. It has to be an address of a real network: a FreeBSD jail without
  an address of its own has no IP network at all, and with an address on
  `lo0` it is reachable from the host only — and cannot reach a model
  provider.
- An API key of an OpenAI-compatible model provider.

## Quick start

The examples use the interface `em0` and the address `192.168.1.70`. The
scripts are taken from a checkout:

```sh
git clone https://github.com/bkisonka/claw2-freebsd
cd claw2-freebsd
```

### 1. The jail template

From the [releases](https://github.com/bkisonka/claw2-freebsd/releases)
(0.2.17 here):

```sh
fetch https://github.com/bkisonka/claw2-freebsd/releases/download/v0.2.17/claw2-jail-0.2.17-15.1-RELEASE-amd64.txz
fetch https://github.com/bkisonka/claw2-freebsd/releases/download/v0.2.17/claw2-jail-0.2.17-15.1-RELEASE-amd64.txz.sha256
sha256 -c claw2-jail-0.2.17-15.1-RELEASE-amd64.txz.sha256

scripts/install-template.sh --template claw2-jail-0.2.17-15.1-RELEASE-amd64.txz \
    --iface em0 --ip 192.168.1.70
```

The template is a complete root filesystem — FreeBSD, `node22`, the
package, the service account — so nothing is downloaded and the jail is up
in seconds. The installer checks the checksum (when the `.sha256` file is
next to the template), and that the template is for the release and the
architecture of your host.

### 2. The package

```sh
fetch https://github.com/bkisonka/claw2-freebsd/releases/download/v0.2.17/claw2-0.2.17.pkg
fetch https://github.com/bkisonka/claw2-freebsd/releases/download/v0.2.17/claw2-0.2.17.pkg.sha256
sha256 -c claw2-0.2.17.pkg.sha256

scripts/install-pkg.sh --pkg claw2-0.2.17.pkg --iface em0 --ip 192.168.1.70
```

A thin jail: the base of your host's release (`base.txz`, its checksum
checked against the release's `MANIFEST`) and the package with its
dependencies, `node22` and `sqlite-ext-vec`, from the package repositories
of your host. Needs the network; a few minutes.

### 3. From source

```sh
scripts/install-source.sh --iface em0 --ip 192.168.1.70
```

The same jail, and the application is built inside it by the port's own
build script — the same build the package gets. Needs the package
repositories, the npm registry and GitHub, and takes about ten minutes:
no FreeBSD binaries are published for `better-sqlite3` and `bcrypt`, they
are compiled. The build dependencies stay in the jail.
`CLAW2_SOURCE=/path/to/source` builds a tarball or a directory of your own
instead of the release.

## After the installation

The same for all three. On the host, the jail's files are under
`/usr/local/jails/claw2/`.

```sh
J=/usr/local/jails/claw2

# 1. The configuration: copy the sample and edit it.
cp $J/usr/local/etc/claw2/claw2.yaml.sample $J/usr/local/etc/claw2/claw2.yaml

# 2. The keys — root only: the service reads the file and hands the values
#    to the gateway.
{ echo "OPENAI_API_KEY=sk-..."; echo "CLAW2_GATEWAY_API_KEY=$(openssl rand -hex 24)"; } \
    > $J/usr/local/etc/claw2/claw2.env
chmod 600 $J/usr/local/etc/claw2/claw2.env

# 3. Start.
jexec claw2 service claw2 start
fetch -qo- http://192.168.1.70:3000/health      # ok
```

The web interface is at `http://192.168.1.70:3000` and asks for the
gateway key; the mobile client is under `/pwa/`, the user guide under
`/wiki/`.

- **Configuration.** `etc/claw2/claw2.yaml` is the application's
  configuration, as in [the project](https://github.com/bkisonka/claw2),
  with FreeBSD defaults: skills in the soft sandbox, long-term memory off.
  The service makes the file its own when it starts — the web interface
  saves its settings into it. The keys never go into it: `apiKey:
  env:OPENAI_API_KEY` takes them from the environment the service provides.
- **Service.** `jexec claw2 service claw2 start|stop|status`. The service
  starts with the jail, after a reboot too (`claw2_enable="YES"` in the
  jail's `rc.conf`, `jail_enable="YES"` in the host's). The gateway runs as
  `claw2`, an account the package creates.
- **Logs.** The gateway's: `/usr/local/jails/claw2/var/log/claw2.log`. The
  jail's console: `/var/log/jail_claw2_console.log` on the host.
- **Files.** `/usr/local/jails/claw2/usr/local/share/claw2/` is the
  application and its data: `data/` with the chats; `agents/` with the
  skills, their output in `agents/output` and `agents/uploads`, and their
  libraries in `agents/node_modules`.
- **Update.** A new package goes over the old one; what the service wrote
  is not the package's and stays:

  ```sh
  cp claw2-0.2.18.pkg /usr/local/jails/claw2/tmp/
  pkg -j claw2 add /tmp/claw2-0.2.18.pkg
  ```

  A new template, or a new build from source: install it as another jail
  (`--name claw2-new --path /usr/local/jails/claw2-new`), carry over `data/`
  and `etc/claw2/`, remove the old one.
- **Remove.** `scripts/jail.sh remove claw2` stops the jail, drops its
  definition and deletes its directory — the chats included.

## Without a jail: the package on the host

The package is an ordinary one and can go right onto the host:

```sh
pkg add claw2-0.2.17.pkg
sysrc claw2_enable=YES
cp /usr/local/etc/claw2/claw2.yaml.sample /usr/local/etc/claw2/claw2.yaml
# The keys: /usr/local/etc/claw2/claw2.env, mode 0600 — as above.
service claw2 start
```

The application is in `/usr/local/share/claw2`, the log in
`/var/log/claw2.log`. `service claw2 stop` and `pkg delete claw2` remove
it; the configuration, the data and the account stay, and the message pkg
prints lists what is left.

## Building

For a release, on FreeBSD, as root, in a checkout:

```sh
make pkg      # dist/claw2-<version>.pkg and its .sha256
make jail     # dist/claw2-jail-<version>-<release>-<arch>.txz, its .sha256
              # and claw2.jail.conf, a matching jail.conf(5) stanza
make clean    # the build roots under work/
```

How it is built:

- **The port builds the application.** `port/www/claw2` is a FreeBSD port
  outside the official tree. Its `files/build-app.sh` is the build: `npm
  ci`, `tsc`, the web client, the PWA, the libraries of the skills, and
  `better-sqlite3` with `bcrypt` compiled by node-gyp. The installer that
  builds from source calls the same script, so the two cannot drift apart.
- **The package is built in a chroot** (`scripts/build-pkg.sh`): the base
  of the host's release with `pkg`, `npm-node22`, `node22`, `python3` and
  `sqlite-ext-vec`, the ports framework and the port. Nothing of it touches
  the system that builds.
- **The template is a clean base with the package installed into it**
  (`scripts/build-jail.sh`): no build tool ever gets near it.

Settings, all optional and all in `scripts/common.sh`: `CLAW2_SOURCE` (a
local tarball or directory instead of the release), `CLAW2_MIRROR` (a
mirror of the FreeBSD release files — the checksums always come from the
official site), `CLAW2_PKG_REPO` (a `pkg(8)` repository definition for the
roots built here, for networks where pkg's own server pool misbehaves),
`CLAW2_RELEASE`, `CLAW2_ARCH`, `CLAW2_CACHE` (where the downloads are
kept), `CLAW2_REUSE_BUILDROOT=1` (keep the build root of the previous run).

A new release of the application: `scripts/new-release.sh <version>` points
the port at it and records the checksum of its source. Commit, then
`make pkg jail` and attach `dist/` to the GitHub release.

## What is not there on FreeBSD

- **The hard sandbox.** Without Docker there are no one-off skill
  containers. Skills run in the soft sandbox: the Node.js permission model
  (`--permission --no-addons`) and the egress guard for the standard HTTP
  stacks. Raw sockets are not isolated, as they are in the hard sandbox.
- **Local embeddings.** The ONNX runtime has no FreeBSD binary, so
  long-term memory is off in the sample configuration. The application has
  an `http` embedding provider as well; it has not been tried here.
- **The sidecars.** Privacy OCR and SIP telephony rely on companion
  binaries (`privacy-ocr-sidecar`, `sip-media-sidecar`) that the gateway
  looks for next to itself. There are none for FreeBSD.

## License

claw2 is free software under the **GNU Affero General Public License v3.0**
([AGPL-3.0-only](https://github.com/bkisonka/claw2/blob/main/LICENSE)).
What the package installs is the unmodified source of one release of
[bkisonka/claw2](https://github.com/bkisonka/claw2) — the tag `v<version>`
of the same version as the package. The license texts ship inside the
package, in `/usr/local/share/claw2/`. This packaging is under the same
license: [LICENSE](LICENSE).
