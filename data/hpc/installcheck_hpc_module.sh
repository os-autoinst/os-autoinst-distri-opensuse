#! /bin/sh

arch=$1
version=$2

check="ftp://dist.suse.de/ibs/SUSE/Products/SLE-Module-HPC/12/${arch}/product/repodata/*-primary.xml.gz
ftp://dist.suse.de/ibs/SUSE/Updates/SLE-Module-HPC/12/${arch}/update/repodata/*-primary.xml.gz"

nocheck="ftp://dist.suse.de/ibs/SUSE/Products/SLE-Module-Toolchain/12/${arch}/product/repodata/*-primary.xml.gz
ftp://dist.suse.de/ibs/SUSE/Updates/SLE-Module-Toolchain/12/${arch}/update/repodata/*-primary.xml.gz
ftp://dist.suse.de/ibs/SUSE/Updates/SLE-Module-Web-Scripting/12/${arch}/update/repodata/*-primary.xml.gz
ftp://dist.suse.de/ibs/SUSE/Products/SLE-Module-Web-Scripting/12/${arch}/product/repodata/*-primary.xml.gz"

base="ftp://openqa.suse.de/SLE-${version}-SERVER-POOL-${arch}-Media1-CURRENT/repodata/*-primary.xml.gz"
sdk="ftp://openqa.suse.de/SLE-${version}-SDK-POOL-${arch}-Media1-CURRENT/repodata/*-primary.xml.gz"

checkd=$(mktemp check-XXXXX)
nocheckd=$(mktemp nocheck-XXXXX)

for i in $base $sdk $nocheck
do
   wget -P $nocheckd $i
done
for i in $check
do
   wget -P $checkd $i
done
installcheck ${arch} $checkd/* --nocheck $nocheckd/*

exit $?
