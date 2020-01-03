#!/bin/bash
#
#  Thu Oct 31 11:14:59 CET 2019:
#  The current official supportserver is SLES-12 SP3. This is too old
#  for purposes like mounting/umounting disk partitions hosting a SLE15 btrfs.
#
#  This script creates a new SLES-15 SP1 supportserver disk image.
#
#  Excerpt from reference:
#  https://github.com/os-autoinst/openQA/blob/master/docs/WritingTests.asciidoc
#
#	=== Support Server based tests
#	
#	The idea is to have a dedicated "helper server" to allow advanced network
#	based testing.
#
#       ....
#	
#	==== Preparing the supportserver
#	
#	
#	The support server image is created by calling a special test, based on the autoyast test:
#	
#	[source,sh]
#	--------------------------------------------------------------------------------



# Settings changes and problems: DISTRI VERSION ISO adapted in the obvious way.
# Substantial updates are needed for the autoyast file:
#
#    /var/lib/openqa/share/tests/os-autoinst-distri-opensuse/data/supportserver/autoyast_supportserver_x86.xml
#
# This autoyast file is hardly dependent on the product to install.
# All the same it is not usable for a SLES-15 SP1 installation.
#
# The tentative autoyast_supportserver_x86_sle15.xml specifies
# all repositories explicitly. Also, the package list needed
# adaptations:
#
#    -  mc      is no longer official, alas. Need to add an appropriate
#               inofficial PackageHub repo.
#    -  atftp   is no longer available on SLE-15. Need to switch to tftp.
#
#    -  tftp    Latest version 5.2-3.22 is fatally affected by bsc#1153625!
#               An error in its systemd service description file keeps the
#               service from starting.
#
#               Workaround: bug is fixed in tftp-5.2-5.3.1 from update candidate
#               S:M:12899. 
#               The usual method of setting OS_TEST_ISSUES and OS_TEST_TEMPLATE
#               does not work: the supportserver_generator test ignores this silently.
#
#               Therefore: added the corresponding internal repo explicitly
#               to the autoyast file.
#
#               FIXME: this is no longer necessary once S:M:12899 (or an equivalent)
#               is released as an official update.
#
#
#    In the command below, BUILD is set according to file media.1/media
#    on the ISO medium. Expected job result: a new image file
#
#    /var/lib/openqa/share/factory/hdd/openqa_support_server_sles15sp1.x86_64.qcow2
#
/usr/share/openqa/script/client \
	--host $URL_of_your_openQA_host \
	--verbose \
	jobs post \
	DISTRI=sle \
	VERSION="15-SP1" \
        BUILD="228.2" \
        BUILD_SLE="228.2" \
	ISO=SLE-15-SP1-Installer-DVD-x86_64-GM-DVD1.iso \
	ARCH=x86_64 \
	FLAVOR=Server-DVD \
	TEST=supportserver_generator \
	MACHINE=64bit \
	DESKTOP=textmode \
	INSTALLONLY=1 \
	AUTOYAST=supportserver/autoyast_supportserver_x86_sle15.xml \
	SUPPORT_SERVER_GENERATOR=1 \
	PUBLISH_HDD_1=openqa_support_server_sles15sp1.x86_64.qcow2



#  Excerpt (continued) from reference:
#  /usr/local/src/openQA-gitrepo/openQA/docs/WritingTests.asciidoc
#
#	This produces QEMU image 'supportserver.qcow2' that contains the
#	supportserver. The 'autoyast_supportserver.xml' should define correct user
#	and password, as well as packages and the common configuration.
#	
#	More specific role the supportserver should take is then selected when the
#	server is run in the actual test scenario.
#	
#	==== Using the supportserver
#	....
