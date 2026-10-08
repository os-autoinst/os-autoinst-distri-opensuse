#!/bin/sh

my_name=${0##*/}
dump_dir=/tmp/dump
dump_tar=
white_list=/tmp/dump/white.list
use_white_list=
timeout=1
proc_exclude="/proc/\(self\|thread-self\|[0-9]+\)/.*"
page_sz=$(getconf PAGESIZE)
nproc=$(nproc)

echo "Dump /proc and /sys script, written by rpalethorpe@suse.com"

while getopts d:c:w:u:t:b:h arg; do
    case $arg in
       d) dump_dir="$OPTARG" ;;
       c) dump_tar="$OPTARG" ;;
       w) white_list="$OPTARG" ;;
       u) use_white_list="$OPTARG" ;;
       t) timeout="$OPTARG" ;;
       b) batch_size="$OPTARG" ;;
       h) cat <<-EOF >&1

This script partially dumps the contents of /proc and /sys to a folder. It can
attempt to dump all the contents and then write out which files were
successful to a white list. Or use a previously generated white list.

usage:
$my_name	[ -d dump_dir ]
 	 		[ -w white_list ] [ -u use_white_list ]
 			[ -t timeout ]
 			[ -b batch_size ]
$my_name	-h

-d dump_dir	  The output directory, note that this will be recreated.
   		  Set to $dump_dir

-c dump_tar	  Tar and compress the output directory contents into the file dump_tar.
   		  Compression is performed using bzip2.

-w white_list	  The white list to output after dumping the files.
   		  Set to $white_list

-u white_list	  The list of files to dump, if this is unset then 'find' is
   		  used to create a list.

-t timeout	  How long, in seconds, we should wait for operations to finish.
   		  Set to $timeout.

-h		  Print this help message and exit.

Files are added to the white list if they are small, but not empty and can be
copied quickly. The idea is that when running the script with -w white_list
the majority of useful information can be quickly saved during automated
testing.

It is best to run this script as root otherwise sensitive information will be
filtered out by the kernel e.g. memory layout. Which happens to be the most
useful information in most situations.

EOF
	  exit 0 ;;
   esac
done

files=
if [ ! $use_white_list ]; then
    echo "Finding files in /proc and /sys"
    proc_files=$(find -L /proc -maxdepth 4 -perm /u=r,g=r -not -regex "$proc_exclude" -not -type d 2> /dev/null)
    sys_files=$(find -L /sys -maxdepth 4 -perm /u=r,g=r -not -type d 2> /dev/null)
    files="$proc_files $sys_files"
else
    echo "Using file list $use_white_list"
    files=$(cat $use_white_list)
fi

dump_dir=${dump_dir%/}
echo "Dumping to $dump_dir"
rm -rf $dump_dir
mkdir $dump_dir

# This is run inside background subshells with stdin redirected to a named pipe.
spawn_dd () {
    local f=

    read -r f
    until [ "$f" = "EXIT" ]; do
	mkdir -p $dump_dir$(dirname $f)
	timeout $timeout dd if=$f of=$dump_dir$f bs=$page_sz count=63 status=none
	if [ $? -eq 137 ]; then
	    echo "dd $f was KILLED"
	elif [ $? -eq 139 ]; then
	    echo "dd $f had a SEGMENTATION FAULT"
	elif [ $? -eq 124 ]; then
	    echo "dd $f took too long"
	    rm $dump_dir$f
	fi
	read -r f
    done
}

for i in $(seq $nproc); do
    mkfifo "$dump_dir/fifo$i"
    ( spawn_dd ) < "$dump_dir/fifo$i" &
done

count=$nproc
for f in $files; do
    count=$((count - 1))
    if [ $count -lt 1 ]; then
	count=$nproc
    fi
    echo "$f" > "$dump_dir/fifo$count"
done

for i in $(seq $nproc); do
    echo "EXIT" > "$dump_dir/fifo$i"
done

wait

for i in $(seq $nproc); do
    rm "$dump_dir/fifo$i"
done

if [ $white_list ]; then
    echo "Finished copying files, now generating $white_list"
    for f in $(find $dump_dir -not -type d); do
	size=$(stat -c '%s' $f)

	if [ ${size:=0} -gt 0 -a $size -lt 256000 ]; then
	    echo "${f#$dump_dir}" >> $white_list
	else
	    echo "$f has invalid file size: ${size:=0}"
	fi
    done
else
    echo "Finished copying files."
fi

if [ $dump_tar ]; then
    echo "Compressing dumped files into $dump_tar"
    oldpwd=${pwd}
    cd $dump_dir
    tar -cjf $dump_tar *
    cd $oldpwd
fi
