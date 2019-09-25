#!/bin/sh

myname="$(basename "$0")"

# default locations

# suppose a standard openQA installation took place remotely on disk /dev/sdb
# exported by the support server

disk_dflt="/dev/sdb"
bdev_dflt="/dev/sdb2"
src_grandpa="/mnt"

src_parentd_dflt="/boot"
src_kernel_dflt="vmlinuz"
src_initrd_dflt="initrd"
dest_grandpa="/srv/tftpboot/boot/"
dest_parentd_dflt="client"
dest_kernel_dflt="vmlinuz"
dest_initrd_dflt="initrd"

function usage() {
	echo "
Usage:  $myname [-B _bdev_] [-D _disk_] [-k kernel] [-K kernel_dest] [-i initrd] [-I initrd_dest]
        $myname -h

        to retrieve a kernel and initrd from a block device and save them
        in an appropriate location below $dest_grandpa.
        Locations are supposed to fit a custom PXE boot entry previously
	created by a \"setup_pxe.sh -C ...\" invocation.
	Defaults as from a plain \"setup_pxe.sh -C\" invocation.

Options:
        -h   Print this help and exit successfully

	-B   block device which provides the kernel (default: $bdev_dflt).
	     May also be a mountpoint where such a device is mounted.
	-D   disk hosting _bdev_ (potentially needed to make _bdev_ appear
	     if this host's idea of its partitioning is outdated and needs refreshing).
	     Default: $disk_dflt.
	-k   location of the kernel relative to _bdev_ (default: $src_parentd_dflt/$src_kernel_dflt)
	-i   location of the initrd relative to _bdev_ (default: $src_parentd_dflt/$src_initrd_dflt)
        -K   location of wanted kernel copy below $dest_grandpa (default: $dest_parentd_dflt/$dest_kernel_dflt)
        -I   location of wanted initrd copy below $dest_grandpa (default: $dest_parentd_dflt/$dest_initrd_dflt)
"
}

function abort() {
	local message="$1"
	echo "$myname: ERROR: $message. Aborting..." >&2
	# Tidy up
	[ -b "$bdev" ] && umount "$src_grandpa"
	exit 1
}

# Cmdline evaluation: Defaults and options
#
bdev="$bdev_dflt"
disk="$disk_dflt"
src_parentd="$src_parentd_dflt"
src_kernel="$src_parentd/$src_kernel_dflt"
src_initrd="$src_parentd/$src_initrd_dflt"
dest_parentd="$dest_parentd_dflt"
dest_kernel="$dest_parentd/$dest_kernel_dflt"
dest_initrd="$dest_parentd/$dest_initrd_dflt"

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
if [ -d "$bdev" ] ; then
	src_grandpa="$bdev"
elif [ -b "$bdev" ] || \
	[ -b "$disk" ] && { partx -a "$disk"; [ -b "$bdev" ] ; }
	# If a client partitions that disk, the server may not know yet...
then
	# mount it. FIXME: already mounted??
	if ! mount -oro "$bdev" "$src_grandpa"; then
		abort "Unable to mount $bdev to $src_grandpa"
	fi
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
	cp -p "$src_grandpa/$src_kernel" "$dest_kernel" && \
	cp -p "$src_grandpa/$src_initrd" "$dest_initrd" && \
	chmod 644 "$dest_kernel" "$dest_initrd"
	# Needed for tftp: world-readable (e.g. initrds like to be root.root 600)
then
	# Tidy up
	[ -b "$bdev" ] && umount "$src_grandpa"
	echo "PXE: custom kernel and initrd installed."
else
	abort "Unable to copy kernel or initrd to desired destination"
fi
