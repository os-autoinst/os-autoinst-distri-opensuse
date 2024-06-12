# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openSUSE-repos
# Summary: Basic checks for openSUSE-repos.

# - Install openSUSE-repos
# - Innstall openSUSE-repos-NVIDIA on aarch64 and x86_64
# - Import gpg keys and refresh repositories
# - Flavors of openSUSE-repos packages correspond with flavor of openSUSE-release
# Maintainer: Lubos Kocmman <lubos.kocman@suse.com>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use version_utils qw(is_tumbleweed is_leap is_leap_micro is_microos is_slowroll);
use serial_terminal 'select_serial_terminal';

sub run {
    my $pkgname = 'openSUSE-repos-Tumbleweed';
    select_serial_terminal;

    zypper_call "in openSUSE-repos";

    $pkgname = 'openSUSE-repos-Leap' if is_leap;
    $pkgname = 'openSUSE-repos-LeapMicro' if is_leap_micro;
    $pkgname = 'openSUSE-repos-MicroOS' if is_microos;
    $pkgname = 'openSUSE-repos-Slowroll' if is_slowroll;

    assert_script_run("rpm -q $pkgname");

    # NVIDIA repo is available only for x86_64 and aarch64
    if (is_x86_64 || is_aarch64) {
        zypper_call('in openSUSE-repos-NVIDIA', exitcode => [0, 106]);
        assert_script_run("rpm -q $pkgname-NVIDIA");
    }

    # Ensure we can refresh repositories
    record_soft_failure('poo#161798,Refresh repos failed') if (zypper_call('--gpg-auto-import-keys ref -s', exitcode => [0, 4]) == 4);
}

sub test_flags {
    return {milestone => 1};
}

1;
