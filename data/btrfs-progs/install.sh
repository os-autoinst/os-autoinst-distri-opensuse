#!/bin/bash -x

# The first parameter is the git url
# The second parameter is the install folder
# The third parameter keep default btrfs binary
btrfs_bin='
btrfs
btrfs-convert
btrfs-find-root
btrfs-image
btrfs-select-super
btrfstune
mkfs.btrfs
Documentation
'

git clone -q --depth 1 $1
cd btrfs-progs
./autogen.sh
./configure --disable-documentation --disable-zstd --disable-python
make
make testsuite
mkdir -p $2
tar zxf tests/btrfs-progs-tests.tar.gz -C $2
if [ "$3" = 0 ]; then
    cp -r $btrfs_bin /sbin/
fi
