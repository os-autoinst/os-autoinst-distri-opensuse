#!/bin/bash

zypper -q -n in -y $(echo "
# compiler, tools and dependencies
make
automake
gcc
gcc-c++
glibc
glibc-devel
fuse
fuse-devel
glib2-devel
zlib-devel
kernel-default
kernel-default-devel
pkg-config
findutils-locate
curl
automake
autoconf
vim
wget
git-core
pciutils
cifs-utils
socat
sysstat
java-1_8_0-openjdk
mlocate

python-setuptools
python3-setuptools
python3-devel

# libraries
libnuma1
libnuma-devel
libpixman-1-0
libpixman-1-0-devel
libtool
libpcap-devel
libnet9
libncurses6
libcurl4
libcurl-devel
libxml2
libfuse2
libopenssl1_0_0
libopenssl-devel
libpython3_4m1_0
libzmq3

" | grep -v ^#)

wget -q http://download.opensuse.org/repositories/openSUSE:/Backports:/SLE-12/standard/x86_64/sshpass-1.06-2.1.x86_64.rpm
rpm -i sshpass-1.06-2.1.x86_64.rpm
zypper ar -f -G https://download.opensuse.org/repositories/devel:/languages:/python:/backports/SLE_12_SP4/devel:languages:python:backports.repo
zypper -q in -y -r devel_languages_python_backports python-pip python3-pip python3-tk
pip install -q --upgrade pip
pip3 install -q --upgrade pip
zypper rr devel_languages_python_backports

updatedb
ln -sf $(locate libc.so.6) /lib/libc.so.6
pip3 install -q virtualenv
mkdir -p /dev/hugepages

VSPERFENV_DIR="/root/vsperfenv"
if [ -d "$VSPERFENV_DIR" ] ; then
    echo "Directory $VSPERFENV_DIR already exists. Skipping python virtualenv creation."
    exit
fi

cd /root/vswitchperf/systems/
virtualenv "$VSPERFENV_DIR" --python /usr/bin/python
source "$VSPERFENV_DIR"/bin/activate
pip3 install -q -r ../requirements.txt
