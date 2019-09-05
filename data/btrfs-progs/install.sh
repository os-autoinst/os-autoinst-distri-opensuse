#!/bin/bash -x

# The first parameter is the git url
# The second parameter is the install folder
git clone -q --depth 1 $1
cd btrfs-progs
./autogen.sh
./configure --disable-documentation --disable-zstd --disable-python
make
make testsuite
mkdir -p $2
tar zxf tests/btrfs-progs-tests.tar.gz -C $2
cp btrfs btrfs-convert btrfs-find-root btrfs-image btrfs-select-super btrfstune /sbin/
cp tests/clean-tests.sh $2
if [ "$3" == "misc" ];then
    sed -ie '/check_min_kernel_version/,+2 s/^/#/' $2/misc-tests/034*/test.sh
    umount /home
fi

