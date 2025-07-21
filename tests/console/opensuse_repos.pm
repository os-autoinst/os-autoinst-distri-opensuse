# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
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
    select_serial_terminal;
    my $pkgname = 'openSUSE-repos-Tumbleweed';
    $pkgname = 'openSUSE-repos-Leap' if is_leap;
    $pkgname = 'openSUSE-repos-LeapMicro' if is_leap_micro;
    $pkgname = 'openSUSE-repos-MicroOS' if is_microos;
    $pkgname = 'openSUSE-repos-Slowroll' if is_slowroll;

    zypper_call "in $pkgname";
    assert_script_run("rpm -q $pkgname");

    # NVIDIA repo is available only for x86_64 and aarch64
    if (is_x86_64 || is_aarch64) {
        zypper_call('in openSUSE-repos-NVIDIA', exitcode => [0, 106]);
        assert_script_run("rpm -q $pkgname-NVIDIA");
    }

    zypper_call("refresh-services");
    assert_script_run "zypper lr --uri | grep cdn.opensuse.org";
    assert_script_run "zypper lr --uri | grep download.nvidia.com" if (is_x86_64 || is_aarch64);

    # removing the distro package, removes the NVIDIA service too if it was installed
    zypper_call("rm $pkgname");
    # restore old repos which were replaced by openSUSE service
    assert_script_run(q"pushd /etc/zypp/repos.d; for f in *; do mv $f $(echo $f|sed s'/.rpmsave//'); done; popd");

    if (script_run("zypper lr --uri | grep -E 'cdn\.opensuse|download\.nvidia'") == 0) {
        die "Unexpected leftover repositories";
    }

}

sub test_flags {
    return {milestone => 1};
}

1;
