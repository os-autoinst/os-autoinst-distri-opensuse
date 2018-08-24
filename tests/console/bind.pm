# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: bind upstream testsuite
#          prepare, build, fix broken tests and execute testsuite
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use strict;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    if (is_sle('=12-SP3')) {
        # SLE 12-SP3 neeed gpg-offline to build
        assert_script_run 'wget http://download.suse.de/ibs/SUSE:/SLE-12:/GA/standard/noarch/gpg-offline-0.1-10.4.noarch.rpm';
        assert_script_run 'rpm -iv gpg-offline*';
        # perl-IO-Socket-INET6 for reclimit
        zypper_call 'in bind rpm-build perl-IO-Socket-INET6';
    }
    elsif (is_sle('>=15')) {
        # dnspython for chain test
        assert_script_run 'curl -L http://download.suse.de/install/SLP/SLE-15-Module-Public-Cloud-GM/x86_64/DVD1/noarch/python3-dnspython-1.15.0-1.25.noarch.rpm -o python3-dnspython.rpm';
        assert_script_run 'rpm -iv python3-dnspython.rpm';
        # bind-utils for dig, net-tools-deprecated for ifconfig, perl-IO-Socket-INET6 for reclimit, perl-Net-DNS for xfer
        zypper_call 'in bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6 perl-Net-DNS';
    }
    # install bind sources to build and run testsuite
    zypper_call 'si bind';
    assert_script_run 'rpm -q bind';
    assert_script_run 'cd /usr/src/packages';
    # build the bind package with tests
    assert_script_run 'rpmbuild -bc SPECS/bind.spec |& tee /tmp/build.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 500;
    upload_logs '/tmp/build.log';
    assert_script_run 'cd /usr/src/packages/BUILD/bind-*/bin/tests/system && pwd';
    # replace build bind binaries with system bind binaries
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkconf/\/usr\/sbin\/named-checkconf/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkzone/\/usr\/sbin\/named-checkzone/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/named\/named/\/usr\/sbin\/named/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/dig\/dig/\/usr\/bin\/dig/\' conf.sh';
    upload_logs 'conf.sh';
    # add missing $ and replace $dig with exported $DIG
    assert_script_run 'sed -i \'s/^DIG/$DIG/\' nsupdate/tests.sh' if is_sle('=12-SP3');
    assert_script_run 'sed -i \'s/$dig/$DIG/\' nsupdate/tests.sh' if is_sle('=12-SP3');
    # no idea what is with rpz on SLE 12 SP3, remove it for now
    assert_script_run 'rm -rf rpz' if is_sle('=12-SP3');
    # fix permissions and executables to run the testsuite
    assert_script_run 'chown root:root -R .';
    assert_script_run 'chmod +x *.sh *.pl';
    # setup loopback interfaces for testsuite
    assert_script_run 'sh ifconfig.sh up';
    assert_script_run 'ip a';
    my $timeout = is_sle('=12-SP3') ? 1500 : 2000;
    assert_script_run 'sh runall.sh', $timeout;
    upload_logs 'systests.output';
    # remove loopback interfaces
    assert_script_run 'sh ifconfig.sh down';
    assert_script_run 'ip a';
}

sub post_fail_hook {
    # print out what tests failed
    assert_script_run 'egrep "^A|^R" systests.output|grep -B1 FAIL';
    upload_logs 'systests.output';
}

1;
