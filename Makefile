# claw2 for FreeBSD: packaging only — the application is bkisonka/claw2.
#
#   make pkg     dist/claw2-<version>.pkg                       the package
#   make jail    dist/claw2-jail-<version>-<release>-<arch>.txz  the jail
#                                                             template (builds
#                                                             the package first)
#   make clean   drop the build roots
#
# On FreeBSD, as root. Settings: scripts/common.sh. The installers for the
# user's machine are in scripts/ and take no make target.

VERSION!=	sed -n 's/^DISTVERSION=[[:space:]]*//p' port/www/claw2/Makefile
RELEASE!=	uname -r | sed 's/-p[0-9]*$$//'
ARCH!=		uname -m

PKG=	dist/claw2-$(VERSION).pkg
JAIL=	dist/claw2-jail-$(VERSION)-$(RELEASE)-$(ARCH).txz

all: pkg jail

pkg: $(PKG)

jail: $(JAIL)

$(PKG):
	scripts/build-pkg.sh

# Built by build-jail.sh when the package is not there yet.
$(JAIL):
	scripts/build-jail.sh

WORK=	${.CURDIR}/work

clean:
	-scripts/buildroot.sh destroy ${WORK}/buildroot
	-scripts/buildroot.sh destroy ${WORK}/jailroot
	# Whatever else is under work/ — the FreeBSD base comes with its system
	# files flagged schg (immutable): rm alone cannot delete them.
	-chflags -R 0 ${WORK} 2>/dev/null
	rm -rf ${WORK}

.PHONY: all pkg jail clean
