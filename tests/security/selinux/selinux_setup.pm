# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environment for selinux tests,
#          check SELinux status by default via 'sestatus/selinuxenabled'
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#40358, poo#105202, tc#1769801

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use Utils::Architectures;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Program 'sestatus' can be found in policycoreutils pkgs
    zypper_call("in policycoreutils");
    # Program 'semanage' is in policycoreutils-python-utils pkgs on TW and SLES 15-SP4
    if (is_tumbleweed || is_sle('>=15-SP4')) {
        zypper_call('in policycoreutils-python-utils');
    }
    if (!is_sle('>=15')) {
        assert_script_run('zypper -n in policycoreutils-python');
    }

    # Install as many as SELinux related packages
    my @pkgs = (
        'selinux-tools', 'libselinux-devel', 'libselinux1', 'python3-selinux', 'libsepol1', 'libsepol-devel',
        'libsemanage1', 'libsemanage-devel', 'checkpolicy', 'mcstrans', 'restorecond', 'setools-console',
        'setools-devel', 'setools-java', 'setools-libs', 'setools-tcl', 'policycoreutils-python-utils'
    );
    foreach my $pkg (@pkgs) {
        my $results = script_run("zypper --non-interactive se $pkg");
        if ($results) {
            record_info('WARNING', "Package $pkg is missing, zypper search returns: $results");
        }
        else {
            zypper_call("in $pkg");
        }
    }
    if (is_x86_64) {
        zypper_call('in libselinux1-32bit');
    }

    # For opensuse, e.g, Tumbleweed install selinux_policy pkgs as needed
    # For sle15 and sle15+ "selinux-policy-*" pkgs will not be released
    # NOTE: have to install "selinux-policy-minimum-*" pkg due to this bug: bsc#1108949
    # Install policy packages separately due to this bug: bsc#1177675
    if (is_sle('>=15')) {
        my @files
          = ('selinux-policy-20200219-3.6.noarch.rpm', 'selinux-policy-minimum-20200219-3.6.noarch.rpm', 'selinux-policy-devel-20200219-3.20.noarch.rpm');
        foreach my $file (@files) {
            assert_script_run 'wget --quiet ' . data_url("selinux/$file");
            assert_script_run("rpm -ivh --nosignature --nodeps --noplugins $file");
        }
    }
    elsif (!is_sle && !is_leap) {
        my @files = ('selinux-policy', 'selinux-policy-minimum', 'selinux-policy-devel');
        foreach my $file (@files) {
            zypper_call("in $file");
        }
    } else {
        zypper_call('in selinux-policy-minimum');
    }

    # Record the pkgs' version for reference
    my $results = script_output('zypper se -s selinux policy');
    record_info('Pkg_ver', "SELinux packages' version is: $results");

    # Check SELinux status by default, it should be disabled
    # 'selinuxenabled' exits with status 0 if SELinux is enabled and 1 if it is not enabled
    validate_script_output('sestatus', sub { m/SELinux status: .*disabled/ });
    if (script_run('selinuxenabled') == 0) {
        $self->result('fail');
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
