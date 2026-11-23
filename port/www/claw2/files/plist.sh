# Files and directories of the stage that the port staged itself — the
# framework's part it lists already — with the ownership the staged tree
# carries. The port has no pkg-plist: its tree is whatever the build
# produced, and the framework's own generator (make makeplist) lists neither
# ownership nor the directories that have files in them. Both matter here: a
# directory pkg(8) creates on its own is root's, and the service writes into
# its tree (see finish-install.sh).
#
# Appended to the framework's temporary list (POST_PLIST in the port's
# Makefile):
#
#   plist.sh <stagedir> <prefix>
set -eu

stagedir=$1
prefix=$2
user=${CLAW2_USER:-claw2}
group=${CLAW2_GROUP:-$user}

# A staged directory: its files and symbolic links — pkg(8) takes a link's
# target from the stage — and every directory below it, itself included.
tree() {
	[ -d "$stagedir/$1" ] || {
		echo "$0: $1 is not staged" >&2
		exit 1
	}
	cd "$stagedir/$1"
	{
		find . \( -type f -o -type l \) | sed "s|^\.|$1|"
		find . -type d | sed "s|^\.|$1|; s|^|@dir |"
	} | LC_ALL=C sort
}

# The configuration's samples: root's, like everything under etc.
tree "$prefix/etc/claw2"

echo "@owner $user"
echo "@group $group"
tree "$prefix/share/claw2"
# The service's directories outside the tree, as finish-install.sh
# makes them.
echo "@dir /var/db/claw2"
echo "@dir /var/run/claw2"
# Back to the defaults for whatever the framework adds after this.
echo "@owner"
echo "@group"
