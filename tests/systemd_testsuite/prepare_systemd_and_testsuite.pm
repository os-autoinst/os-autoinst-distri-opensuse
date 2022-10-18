# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare systemd and testsuite.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use Mojo::Base qw(systemd_testsuite_test);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);

sub run {
    my ($self) = @_;
    my $test_opts = {
        NO_BUILD => get_var('SYSTEMD_NO_BUILD', 1),
        TEST_PREFER_NSPAWN => get_var('SYSTEMD_NSPAWN', 1),
        UNIFIED_CGROUP_HIERARCHY => get_var('SYSTEMD_UNIFIED_CGROUP', 'yes')
    };
    my $testdir = '/usr/lib/systemd/tests/test/';
    my @pkgs = qw(
      lz4
      busybox
      qemu
      dhcp-client
      python3
      plymouth
      binutils
      netcat-openbsd
      cryptsetup
      less
      device-mapper
      strace
      e2fsprogs
      hostname
      net-tools-deprecated
      systemd-testsuite
    );

    select_serial_terminal();

    if (is_sle) {
        add_suseconnect_product('sle-module-legacy');
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
        my $repo = sprintf('http://download.suse.de/download/ibs/SUSE:/SLE-%s:/GA/standard/',
            get_var('VERSION'));
        zypper_call("ar $repo systemd-tests");
    }

    #install testsuite and dependecies
    zypper_call('ref');
    zypper_call("in @pkgs");

    # navigate to test case directory
    # extract all available test cases
    assert_script_run("cd $testdir");
    my @schedule = ();
    my $exclude = get_var('SYSTEMD_EXCLUDE');

    if (my $include = get_var('SYSTEMD_INCLUDE')) {
        @schedule = split(',', $include);
    } else {
        my @tests = split(/\n/, script_output(qq(find . -maxdepth 1 -type d -name "TEST-*")));
        foreach my $test (@tests) {
            # trim folder prefix
            $test =~ s/\.\///;
            if (defined($exclude) && $test =~ m/$exclude/) {
                next;
            }
            push @schedule, $test;
        }
    }

    # execute generic openQA's systemd runner for each test case directory found within the *systemd-tests* package
    # test case options are passed to each scheduled module separately
    foreach my $test (@schedule) {
        my $args = OpenQA::Test::RunArgs->new(test => $test, dir => $testdir, make_opts => $test_opts);
        autotest::loadtest('tests/systemd_testsuite/runner.pm', name => $test, run_args => $args);
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
