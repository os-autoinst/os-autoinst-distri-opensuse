# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
# - In case of failure, upload "systests.output" log
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    my $self = shift;
    select_serial_terminal;

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
    # workaround esp. on aarch64 some test fail occasinally due to low worker performance
    # if there are failed tests run them again up to 3 times
    eval {
        assert_script_run 'runuser -u bernhard -- sh runall.sh -n', 7000;
    };
    if ($@) {
        for (1 .. 3) {
            eval {
                record_soft_failure 'Retry: poo#71329';
                assert_script_run 'TFAIL=$(awk -F: -e \'/^R:.*:FAIL/ {print$2}\' systests.output)';
                assert_script_run 'for t in $TFAIL; do runuser -u bernhard -- sh run.sh $t; done', 2000;
            };
            last unless ($@);
            record_info 'Retry', "Failed bind test retry: $_ of 3";
        }
    }
    # remove loopback interfaces
    assert_script_run 'sh ifconfig.sh down';
    assert_script_run 'ip a';
}

sub post_fail_hook {
    # print out what tests failed
    assert_script_run 'grep -E "^A|^R" systests.output|grep -B1 FAIL';
    upload_logs 'systests.output';
}

1;
