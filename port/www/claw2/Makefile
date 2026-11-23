# FreeBSD port of claw2. Part of bkisonka/claw2-freebsd; outside the
# official ports tree on purpose — see pkg-descr.
#
# The application's source is the release tarball of bkisonka/claw2
# (GitHub archive of the tag); its npm dependencies are fetched at build
# time, and better-sqlite3 and bcrypt are compiled from source.

PORTNAME=	claw2
DISTVERSION=	0.2.17
CATEGORIES=	www
MASTER_SITES=	https://github.com/bkisonka/claw2/archive/refs/tags/
DISTNAME=	v${PORTVERSION}
DIST_SUBDIR=	${PORTNAME}
# GitHub names the archive's top directory after the project, not the tag.
WRKSRC=		${WRKDIR}/${PORTNAME}-${DISTVERSION}

MAINTAINER=	bkisonka@users.noreply.github.com
COMMENT=	Personal AI agent you host yourself
WWW=		https://github.com/bkisonka/claw2-freebsd

LICENSE=	AGPLv3
LICENSE_FILE=	${WRKSRC}/LICENSE

# node-gyp wants "python3": npm-node22 brings python3.12, but not the
# python3 link — that is the python3 package.
BUILD_DEPENDS=	${LOCALBASE}/bin/npm:www/npm-node22 \
		${LOCALBASE}/bin/python3:lang/python3
RUN_DEPENDS=	node22>=22.13:www/node22 \
		sqlite-ext-vec>=0.1.6:databases/sqlite-ext-vec

USE_RC_SUBR=	${PORTNAME}
SUB_FILES=	pkg-message

# Deliberately no USERS/GROUPS: the ports framework would want the
# account's number from the tree's registries, and a port outside the tree
# has none (every number of the service range is taken). The account is
# created without a fixed number — see post-build and files/pkg-install.
post-build:
	# The staged files carry the service account's ownership into the
	# package, so the account has to exist where the package is built (the
	# build root of scripts/build-pkg.sh). files/pkg-install creates it
	# again, with a free id, wherever the package is installed.
	@pw groupshow ${PORTNAME} >/dev/null 2>&1 || pw groupadd ${PORTNAME}
	@pw usershow ${PORTNAME} >/dev/null 2>&1 || \
		pw useradd ${PORTNAME} -g ${PORTNAME} -d /var/db/${PORTNAME} -s /usr/sbin/nologin

# The scripts under files/ are run through the shell, not executed: the
# executable bit does not survive every way of fetching the tree.
do-build:
	@${ECHO_MSG} "===>  Building ${PORTNAME}: npm ci, tsc, web, pwa"
	@cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} PATH="${PREFIX}/bin:${PATH}" \
		NPM=${PREFIX}/bin/npm ${SH} ${FILESDIR}/build-app.sh build ${WRKSRC}

do-install:
	@${SETENV} ${MAKE_ENV} ${SH} ${FILESDIR}/build-app.sh install ${WRKSRC} ${STAGEDIR}${PREFIX}

post-stage:
	# The service runs as the service account and writes under its tree —
	# the same finish the installer building from source applies.
	@${SETENV} ${MAKE_ENV} ${SH} ${FILESDIR}/finish-install.sh ${STAGEDIR}${PREFIX} ${STAGEDIR}

# No pkg-plist: the application's tree is whatever the build produced,
# thousands of files of npm dependencies. files/plist.sh writes its packing
# list once the tree is staged and finished — POST_PLIST is where the
# framework lets a port add to its temporary list.
POST_PLIST=	add-plist-tree
add-plist-tree:
	@${SETENV} ${MAKE_ENV} ${SH} ${FILESDIR}/plist.sh ${STAGEDIR} ${PREFIX} >> ${TMPPLIST}

# The framework's own check: nothing staged outside the lists, nothing in
# the lists that is not staged.
pre-package:	check-plist

.include <bsd.port.mk>
