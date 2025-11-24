# SUSE's openQA tests
#
# Copyright 2018-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libopenssl-devel libmysqlclient-devel bind rpm-build perl-IO-Socket-INET6
# bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6
# perl-Net-DNS python3-dnspython git-core python3-pytest python3-hypothesis
# jemalloc-devel libcmocka-devel
# Summary: bind upstream testsuite
#          prepare, build, fix broken tests and execute testsuite
# - Add PHUB module for pytyhon3-* packages like python3-pytest"
# - Install required packages for the test, depending on SLES version
# - Enable source repositories and install bind src.rpm
# - Build bind package from spec "rpmbuild -bc SPECS/bind.spec"
# - Replace bind from build with system binaries on "conf.sh"
# - Upload "conf.sh" as reference
# - Setup loopback interfaces
# - Run "runall.sh" testsuite
# - Upload test-suite.txt
# Documentation:
# Official docu below, look for version specific README in /usr/src/packages/BUILD/bind-*/bin/tests/system
# https://gitlab.isc.org/isc-projects/bind9/-/blob/main/bin/tests/system/README.md
#
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);
use version_utils qw(package_version_cmp);

sub run {
    select_serial_terminal;
    add_suseconnect_product(get_addon_fullname('phub')) if is_sle('15-SP2+');
    if (is_sle('<=12-SP5')) {
        # preinstall libopenssl-devel & libmysqlclient-devel because on 12* are multiple versions and zypper can't decide,
        # perl-IO-Socket-INET6 for reclimit test
        zypper_call 'in libopenssl-devel libmysqlclient-devel bind rpm-build perl-IO-Socket-INET6 python3-pytest';
    }
    elsif (is_sle('>=15')) {
        # bind-utils for dig, net-tools-deprecated for ifconfig, perl-IO-Socket-INET6 for reclimit,
        # perl-Net-DNS for xfer, dnspython for chain test
        zypper_call 'in bind rpm-build bind-utils net-tools-deprecated perl-IO-Socket-INET6 perl-Socket6 perl-Net-DNS python3-dnspython git-core python3-pytest python3-hypothesis jemalloc-devel libcmocka-devel';
        # xdist for parallel test execution and other test dependencies
        zypper_call('in python3*-Jinja2 python3*-pytest-xdist python3*-dnspython python3*-hypothesis gnutls', exitcode => [0, 107]) if is_sle('=15-SP7');
    }
    # enable source repositories to get latest source packages
    assert_script_run 'for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`;do zypper mr -e --refresh $r;done';
    # install bind sources to build and run testsuite
    zypper_call 'si bind';
    my $bind_version = script_output("rpm -q --qf '%{version}' bind");
    record_info('Bind version', "$bind_version");
    # disable previously enabled source repositories
    assert_script_run 'for r in `zypper lr|awk \'/Source-Pool/ {print $5}\'`;do zypper mr -d --no-refresh $r;done';
    # reconnect to regenerate PATH
    enter_cmd 'exit';
    reset_consoles;
    select_serial_terminal;
    assert_script_run 'export CI_ENABLE_ALL_TESTS=1';
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
    # temporary disable logfileconf poo#159465
    assert_script_run 'sed -i \'/\\s*logfileconfig\\s*\\\/d\' Makefile' if is_sle('=15-SP6');
    # disable failing tests on 15-SP7 poo#181709
    assert_script_run 'rm -rf upforwd forward logfileconfig qmin' if is_sle('=15-SP7');
    assert_script_run 'cat Makefile';
    # fix permissions and executables to run the testsuite
    assert_script_run 'chown bernhard:root -R .';
    assert_script_run 'chmod +x *.sh *.pl';
    # setup loopback interfaces for testsuite
    assert_script_run 'sh ifconfig.sh up';
    assert_script_run 'ip a';
    my $bind_cmd;
    my $worker_count = is_sle('<15-SP2') ? 2 : 8;
    if (package_version_cmp($bind_version, '9.18.33') <= 0) {
        $bind_cmd = "runuser -u bernhard -- sh runall.sh -n $worker_count";
    }
    else {
        $bind_cmd = 'pytest -n 10';
    }
    # workaround esp. on aarch64 some test fail occasinally due to low worker performance
    # if there are failed tests run them again up to 3 times
    eval {
        assert_script_run('set -o pipefail; ' . $bind_cmd . " |& tee -a /tmp/test-suite.txt", 7000);
    };
    if ($@) {
        record_info 'Retry:', 'poo#71329';
        for (1 .. 3) {
            eval {
                if (package_version_cmp($bind_version, '9.18.33') <= 0) {
                    assert_script_run 'TFAIL=$(awk -F: -e \'/^R:.*:FAIL/ {print$2}\' /tmp/test-suite.txt); echo $TFAIL';
                    assert_script_run "for t in \$TFAIL; do runuser -u bernhard -- sh run.sh \$t; done", 2000;
                }
                elsif (package_version_cmp($bind_version, '9.20.9') < 0) {
                    assert_script_run 'TFAIL=$(awk \'/^FAIL:/ {print$2}\' /tmp/test-suite.txt); echo $TFAIL';
                    assert_script_run "for t in \$TFAIL; do runuser -u bernhard -- sh run.sh \$t; done", 2000;
                }
                else {
                    assert_script_run 'TFAIL=$(awk \'/^FAILED/ {print$2}\' /tmp/test-suite.txt); echo $TFAIL';
                    assert_script_run "for t in \$TFAIL; do $bind_cmd \$t; done", 2000;
                }
            };
            last unless ($@);
            record_info "Retry $_", "Failed bind test retry: $_ of 3";
            die 'bind testsuite failed, see test-suite.txt' if $@ && $_ == 3;
        }
    }
    # remove loopback interfaces
    assert_script_run 'sh ifconfig.sh down';
    assert_script_run 'ip a';
}

sub post_fail_hook {
    upload_logs "/tmp/test-suite.txt";
}

sub post_run_hook {
    upload_logs "/tmp/test-suite.txt";
}

1;
