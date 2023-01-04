# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup environment for selinux tests,
#          check SELinux status by default via 'sestatus/selinuxenabled'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#40358, poo#105202, tc#1769801

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use version_utils qw(is_sle is_leap is_tumbleweed is_alp);
use Utils::Architectures;

sub run {
    my ($self) = @_;

    # In CC testing, the root login will be disabled, so we need to use select_console
    is_s390x() ? select_console 'root-console' : select_serial_terminal;

    # Using packages from gitlab
    my $repo_link = 'https://gitlab.suse.de/qe-security/testing/-/raw/main/data/selinux';
    my $policy_pkg_20220124 = 'selinux-20220124.tgz';
    my $policy_pkg_20200219 = 'selinux-20200219.tgz';

    # Program 'sestatus' can be found in policycoreutils
    if (is_alp) {
        assert_script_run('transactional-update --non-interactive pkg install policycoreutils');
    }
    else {
        zypper_call("in policycoreutils");
    }
    # Program 'semanage' is found in:
    #  - policycoreutils-python-utils pkgs on ALP, TW and SLES 15-SP4
    #  - policycoreutils for 15-SP{0,3}
    #  - policycoreutils-python for <= 12-SP5
    if (is_alp) {
        assert_script_run('transactional-update --non-interactive pkg install policycoreutils-python-utils');
    }
    else {
        if (is_tumbleweed || is_sle('>=15-SP4')) {
            zypper_call("in policycoreutils-python-utils");
        }
        if (!is_sle('>=15')) {
            assert_script_run('zypper -n in policycoreutils-python');
        }
    }
    # Reboot ALP after transactional updates finished
    if (is_alp) {
        my $prev_console = current_console();
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 300);
        select_console($prev_console);
    }
    # Install as many as SELinux related packages
    my @pkgs = (
        'selinux-tools', 'libselinux-devel', 'libselinux1', 'python3-selinux',
        'libsepol1', 'libsepol-devel', 'libsemanage1', 'libsemanage-devel',
        'checkpolicy', 'mcstrans', 'restorecond', 'setools-console',
        'setools-devel', 'setools-java', 'setools-libs', 'setools-tcl',
        'policycoreutils-python-utils'
    );
    if (!is_alp) {
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
    }
    # For opensuse, e.g, Tumbleweed install selinux_policy pkgs as needed
    # For sle15 and sle15+ "selinux-policy-*" pkgs will not be released
    # NOTE: have to install "selinux-policy-minimum-*" pkg due to this bug: bsc#1108949
    # Install policy packages separately due to this bug: bsc#1177675
    if (is_sle('>=15-sp4')) {
        # Download and install selinux policy packages
        assert_script_run("wget --quiet --no-check-certificate $repo_link/$policy_pkg_20220124");
        assert_script_run("tar -xzf $policy_pkg_20220124");
        assert_script_run("rpm -ivhU --nosignature --nodeps --noplugins ./selinux*20220124*.rpm", timeout => 120);
    }
    elsif (is_sle('>=15') && is_sle('<15-sp4')) {
        # Download and install selinux policy packages
        assert_script_run("wget --quiet --no-check-certificate $repo_link/$policy_pkg_20200219");
        assert_script_run("tar -xzf $policy_pkg_20200219");
        assert_script_run("rpm -ivhU --nosignature --nodeps --noplugins ./selinux*20200219*.rpm", timeout => 120);
    }
    elsif (!is_sle && !is_leap && !is_alp) {
        my @files = ('selinux-policy', 'selinux-policy-minimum', 'selinux-policy-devel');
        foreach my $file (@files) {
            zypper_call("in $file");
        }
    }
    elsif (!is_alp) {
        zypper_call('in selinux-policy-minimum');
    }

    # Record the pkgs' version for reference
    my $results = script_output('zypper se -s selinux policy');
    record_info('Pkg_ver', "SELinux packages' version is: $results");

    # Check SELinux status by default, it should be disabled otherwise but enabled on ALP
    # On ALP, it will be checked in the sestatus module
    # 'selinuxenabled' exits with status 0 if SELinux is enabled and 1 if it is not enabled
    if (!is_alp) {
        validate_script_output('sestatus', sub { m/SELinux status: .*disabled/ });
        if (script_run('selinuxenabled') == 0) {
            $self->result('fail');
        }
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
