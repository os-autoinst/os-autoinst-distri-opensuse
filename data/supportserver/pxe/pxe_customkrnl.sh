#!/bin/sh

myname="$(basename "$0")"

# Default locations (part 1)
#
# Suppose a standard openQA installation took place remotely on disk /dev/sdb
# exported by the support server
#
disk_dflt="/dev/sdb"
bdev_dflt="/dev/sdb2"
src_grandpa="/mnt"

src_parentd_dflt="/boot"
src_kernel_dflt="vmlinuz"
src_initrd_dflt="initrd"


function abort() {
	local message="$1"
	echo "$myname: ERROR: $message. Aborting..." >&2
	# Tidy up
	[ -b "$bdev" ] && umount "$src_grandpa"
	exit 1
}

function usage() {
	echo "
Usage:  $myname [-B _bdev_] [-D _disk_] [-k kernel] [-K kernel_dest] [-i initrd] [-I initrd_dest]
	$myname -h

	to retrieve a kernel and initrd from a block device and save them
	in an appropriate location below $dest_grandpa.
	Locations are supposed to fit a custom PXE boot entry previously
	created by a \"setup_pxe.sh -C ...\" invocation.
	Defaults as detected from the \"LABEL custom\" entry in the
	config file: $pxe_configfile

Options:
	-h   Print this help and exit successfully

	-B   block device which provides the kernel (default: $bdev_dflt).
	     May also be a mountpoint where such a device is mounted.
	-D   disk hosting _bdev_ (potentially needed to make _bdev_ appear
	     if this host's idea of its partitioning is outdated and needs refreshing).
	     Default: $disk_dflt.
	-k   location of the kernel relative to _bdev_ (default: $src_parentd_dflt/$src_kernel_dflt)
	-i   location of the initrd relative to _bdev_ (default: $src_parentd_dflt/$src_initrd_dflt)
	-K   location of requested kernel copy below $dest_grandpa (default: $dest_kernel_dflt)
	-I   location of requested initrd copy below $dest_grandpa (default: $dest_initrd_dflt)
"
}

# Default locations (part 2)
#
# a unique existing PXE configuration is assumed
pxe_configfile="$(find /srv/tftpboot -type f -path "*/pxelinux.cfg/default")"
[ -f "$pxe_configfile" ] || abort "\$pxe_configfile==\"$pxe_configfile\": no unique PXE config found."

# __Locations according to the supportserver's setup.pm and setup_pxe.sh__
#
#  atftpd (SLE-12):		$dest_grandpa   == "/srv/tftpboot/boot"
#  tftp (SLE-15 and newer):	$dest_grandpa   == "/srv/tftpboot"
#  In any case:			$pxe_configfile == "$dest_grandpa/pxelinux.cfg/default"
#
dest_grandpa="$(dirname "$(dirname "$pxe_configfile")")"

# Auto-detect default destinations from the assumed "LABEL custom" section
# in the existing PXE config file (see setup_pxe.sh)
#
pxe_custom_entry="$(sed -n \
	-e '/^[[:blank:]]*LABEL[[:blank:]]*custom[[:blank:]]*$/,/^[[:blank:]]*LABEL\>/p' \
       "$pxe_configfile")"
dest_kernel_dflt="$(echo "$pxe_custom_entry" | sed -n -e \
	'/^[[:blank:]]*\<kernel\>[[:blank:]]*/ {
		s///
		s/[[:blank:]]*$//
		p
	}')"
dest_initrd_dflt="$(echo "$pxe_custom_entry" | sed -n -e \
	'/^[[:blank:]]*\<append\>.*initrd=/ {
		s///
		/[[:blank:]].*$/s///
		p
	}')"

if [ -z "$dest_kernel_dflt" -o -z "$dest_initrd_dflt" ]; then
	abort "\
Unable to detect configured kernel or initrd locations:

PXE config file:	$pxe_configfile

-----8<-----   START  custom kernel boot entry  -----8<-----
$pxe_custom_entry
-----8<-----    END   custom kernel boot entry  -----8<-----

\$dest_kernel_default:	$dest_kernel_default
\$dest_initrd_default:	$dest_initrd_default
"
fi	# if [ -z "$dest_kernel_dflt" -o ...


# Cmdline evaluation: Defaults and options
#
bdev="$bdev_dflt"
disk="$disk_dflt"
src_kernel="$src_parentd_dflt/$src_kernel_dflt"
src_initrd="$src_parentd_dflt/$src_initrd_dflt"
dest_kernel="$dest_kernel_dflt"
dest_initrd="$dest_initrd_dflt"

while getopts hB:D:k:i:K:I: optchar ; do
    case "$optchar" in
        h)      usage ; exit 0            ;;
        B)      bdev="$OPTARG"            ;;
        D)      disk="$OPTARG"            ;;
        k)      src_kernel="$OPTARG"      ;;
        i)      src_initrd="$OPTARG"      ;;
        K)      dest_kernel="$OPTARG"     ;;
        I)      dest_initrd="$OPTARG"     ;;
        *)      usage ; exit 1            ;;
    esac
done

# Sanity checks
#
if [ -f "$bdev/$src_kernel" -a -f "$bdev/$src_initrd" ] 2>/dev/null ; then
	src_grandpa="$bdev"
elif [ -b "$bdev" ] || \
	{ [ -b "$disk" ] && { partx -a "$disk"; [ -b "$bdev" ] ; } ; }
	# If a *client* just partitioned that disk, the server may be
	# unaware of partition $bdev until after a rescan via partx
then
	mount -oro "$bdev" "$src_grandpa" || abort "Unable to mount $bdev to $src_grandpa"
else
	abort "\
option -B: $bdev: neither a block device nor an existing directory:
$(ls -l $bdev 2>&1)
/proc/partitions:
$(cat /proc/partitions)
"
fi
pushd "$src_grandpa" >/dev/null 2>&1
[ -f "$src_kernel" ] || abort "option -k: $src_kernel: not a regular file (or symlink to one)"
[ -f "$src_initrd" ] || abort "option -i: $src_initrd: not a regular file (or symlink to one)"
popd	# pushd "$src_grandpa"
#
# END: Cmdline evaluation and sanity checks

# ACTION: OK, get them
#
if \
	mkdir -p -m755 "$(dirname "$dest_grandpa/$dest_kernel")" "$(dirname "$dest_grandpa/$dest_initrd")" && \
	cd "$dest_grandpa" && \
	cp -pv "$src_grandpa/$src_kernel" "$dest_kernel" && \
	cp -pv "$src_grandpa/$src_initrd" "$dest_initrd" && \
	chmod 644 "$dest_kernel" "$dest_initrd"
	# Needed for tftp: world-readable (e.g. original initrds are root.root 600)
then
	# Tidy up
	# WARNING: the existing SLES-12 SP3 openQA supportserver would just HANG
	#          here (or sometimes already during the mount attempt above)
	#          in case $src_grandpa hosts a >= SLES-15 btrfs!
	#          A new SLES-15 SP1 supportserver was verified to not be affected.
	#
	[ -b "$bdev" ] && umount "$src_grandpa"
	echo "PXE: custom kernel and initrd installed."
else
	abort "Unable to copy kernel or initrd to desired destination"
fi
