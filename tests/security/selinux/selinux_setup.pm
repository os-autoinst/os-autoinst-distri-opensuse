# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environment for selinux tests.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#40358, poo#105202, tc#1769801

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use version_utils qw(is_sle is_leap is_tumbleweed is_alp is_sle_micro);
use transactional qw(process_reboot trup_call);
use Utils::Architectures;

sub get_policy_date {
    if (is_sle('>=15') && is_sle('<15-sp4')) {
        return '20200219';
    } elsif (is_sle('>=15-sp4')) {
        return '20220124';
    } else {
        return undef;
    }
}

sub install_pkgs {
    my @pkgs = (
        'wget', 'policycoreutils', 'selinux-tools', 'libselinux-devel', 'libselinux1', 'python3-selinux',
        'libsepol1', 'libsepol-devel', 'libsemanage1', 'libsemanage-devel',
        'checkpolicy', 'mcstrans', 'restorecond', 'setools-console',
        'setools-devel', 'setools-java', 'setools-libs', 'setools-tcl',
        'policycoreutils-python-utils', 'policycoreutils-python', 'libselinux1-32bit', 'selinux-policy-minimum',
        'selinux-policy', 'selinux-policy-minimum', 'selinux-policy-devel'
    );
    zypper_install_available "@pkgs";

    # For sle15 and sle15+ "selinux-policy-*" pkgs will not be released
    # NOTE 1: we have to install "selinux-policy-minimum-*" pkg due to this bug: bsc#1108949
    # NOTE 2: we have to install policy packages separately due to this bug: bsc#1177675
    if (is_sle('>=15')) {
        my $policy_date = get_policy_date();
        my $policy_archive = $policy_date ? "selinux-$policy_date.tgz" : 'none';
        assert_script_run("wget --quiet --no-check-certificate https://gitlab.suse.de/qe-security/testing/-/raw/main/data/selinux/$policy_archive");
        assert_script_run("tar -xzf $policy_archive");
        assert_script_run("rpm -ivhU --nosignature --nodeps --noplugins ./selinux*$policy_date*.rpm", timeout => 120);
    }
}

sub run {
    my ($self) = @_;

    # on ALP selinux is enabled and set to enforcing by default
    if (is_alp || is_sle_micro('>=6.0')) {
        validate_script_output('sestatus', sub { m/SELinux status: .*enabled/ && m/Current mode: .*enforcing/ }, fail_message => 'SELinux is NOT enabled and set to enforcing');
        trup_call('pkg install policycoreutils-python-utils');
        process_reboot(trigger => 1);
    } else {
        # In CC testing, the root login will be disabled, so we need to use select_console
        is_s390x() ? select_console 'root-console' : select_serial_terminal;

        install_pkgs;

        # Record the pkgs' version for reference
        my $results = script_output('zypper se -s selinux policycore', timeout => 300);
        record_info('Pkg_ver', "SELinux packages' version is: $results");

        # Check that SELinux is disabled by default.
        validate_script_output('sestatus', sub { m/SELinux status: .*disabled/ }, fail_message => 'SELinux is enabled when it should not be');
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
