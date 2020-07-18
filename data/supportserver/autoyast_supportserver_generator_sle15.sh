#!/bin/bash
#
#  Created_by: QA SLE YaST team <qa-sle-yast@suse.de>
#  Last Update: 2020
#
#  This script generates a supportserver disk image based on textmode.
#  Target arch are aarch64 and x86_64. Despite the build number the GMC is used.
#  
#  When the job is done you should find qcow2 image in https://openqa.suse.de/assets/hdd/
#  

echo "Usage: $0 [<BUILD>] [<ARCH>] [<Flavor>]" >&2 
build_number=${1:-209.2}
arch=${2:-aarch64}
flavor=${3:-Online}
if [ -z ${build_number+x} ]; then echo "Build is not given"; else echo "build is set to $build_number"; fi
if [ -z ${arch+x} ]; then echo "Arch is not given"; else echo "arch is set to $arch"; fi
if [ -z ${flavor+x} ]; then echo "Flavor is not given"; else echo "flavor is set to $flavor"; fi

case $arch in
    'aarch64')
	machine=aarch64
	;;
    'x86_64')
	machine=64bit
	;;
esac

if [ -z ${machine+x} ]; then echo "Machine is unset"; else echo "machine is set to $machine"; fi

/usr/share/openqa/script/openqa-cli api --osd -X POST jobs \
				    ARCH=$arch \
				    FLAVOR=$flavor \
				    DISTRI=sle \
				    MACHINE=$machine \
				    VERSION=15-SP2 \
				    BUILD=$build_number \
				    BUILD_SLE=$build_number \
				    ISO=SLE-15-SP2-$flavor-$arch-GMC-Media1.iso \
				    INSTALLONLY=1 \
				    DESKTOP=textmode \
				    AUTOYAST_PREPARE_PROFILE=1 \
				    TEST=supportserver_generator \
				    SUPPORT_SERVER_GENERATOR=1 \
				    AUTOYAST=supportserver/autoyast_supportserver_${arch}_sle15.xml \
				    PUBLISH_HDD_1=openqa_support_server_sles15sp2_${arch}_textmode_$(date +"%Y%m").qcow2 
