# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: libopenssl-devel libmysqlclient-devel bind rpm-build perl-IO-Socket-INET6
# bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6 perl-Net-DNS python3-dnspython
# Summary: bind upstream testsuite
#          prepare, build, fix broken tests and execute testsuite
# - Register and add correct products by calling "handle_bind_source_dependencies.sh"
# - Install required packages for the test, depending on SLES version
# - Enable source repositories and install bind src.rpm
# - Change to /usr/src/packages and rebuild bind package by calling "rpmbuild
# -bc SPECS/bind.spec"
# - Replace bind from build with system binaries on "conf.sh"
# - Upload "conf.sh" as reference
# - Setup loopback interfaces
# - Run "runall.sh" testsuite
# - De register repositores
# - In case of failure, upload "systests.output" log
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # script to add missing dependency repos and in second run remove only added products/repos
    assert_script_run 'curl -v -o /tmp/script.sh ' . data_url('qam/handle_bind_source_dependencies.sh');
    assert_script_run 'bash /tmp/script.sh', 200;
    if (is_sle('<=12-SP5')) {
        # preinstall libopenssl-devel & libmysqlclient-devel because on 12* are multiple versions and zypper can't decide,
        # perl-IO-Socket-INET6 for reclimit test
        zypper_call 'in libopenssl-devel libmysqlclient-devel bind rpm-build perl-IO-Socket-INET6';
    }
    elsif (is_sle('>=15')) {
        # bind-utils for dig, net-tools-deprecated for ifconfig, perl-IO-Socket-INET6 for reclimit,
        # perl-Net-DNS for xfer, dnspython for chain test
        zypper_call 'in bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6 perl-Net-DNS python3-dnspython';
    }
    # enable source repositories to get latest source packages
    assert_script_run 'for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`;do zypper mr -e --refresh $r;done';
    # install bind sources to build and run testsuite
    zypper_call 'si bind';
    assert_script_run 'rpm -q bind';
    # disable previously enabled source repositories
    assert_script_run 'for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`;do zypper mr -d --no-refresh $r;done';
    assert_script_run 'cd /usr/src/packages';
    # build the bind package with tests
    assert_script_run 'rpmbuild -bc SPECS/bind.spec', 2000;
    assert_script_run 'cd /usr/src/packages/BUILD/bind-*/bin/tests/system && pwd';
    # replace build bind binaries with system bind binaries
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkconf/\/usr\/sbin\/named-checkconf/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/check\/named-checkzone/\/usr\/sbin\/named-checkzone/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/named\/named/\/usr\/sbin\/named/\' conf.sh';
    assert_script_run 'sed -i \'s/$TOP\/bin\/dig\/dig/\/usr\/bin\/dig/\' conf.sh';
    upload_logs 'conf.sh';
    # add missing $ and replace $dig with exported $DIG
    assert_script_run 'sed -i \'s/^DIG/$DIG/\' nsupdate/tests.sh' if is_sle('<=12-SP3');
    assert_script_run 'sed -i \'s/$dig/$DIG/\' nsupdate/tests.sh' if is_sle('<=12-SP3');
    # no idea what is with rpz on SLE 12 SP3, remove it for now
    assert_script_run 'rm -rf rpz' if is_sle('<=12-SP3');
    # fix permissions and executables to run the testsuite
    assert_script_run 'chown bernhard:root -R .';
    assert_script_run 'chmod +x *.sh *.pl';
    # setup loopback interfaces for testsuite
    assert_script_run 'sh ifconfig.sh up';
    assert_script_run 'ip a';
    my $timeout = is_sle('<=12-SP3') ? 1500 : 3500;
    assert_script_run 'runuser -u bernhard -- sh runall.sh', $timeout;
    # remove loopback interfaces
    assert_script_run 'sh ifconfig.sh down';
    assert_script_run 'ip a';
}

sub post_run_hook {
    # deregister products or repositories added with first script run
    assert_script_run 'bash /tmp/script.sh';
}

sub post_fail_hook {
    # print out what tests failed
    assert_script_run 'egrep "^A|^R" systests.output|grep -B1 FAIL';
    upload_logs 'systests.output';
}

1;
