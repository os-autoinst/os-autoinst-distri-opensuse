# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Verify that the signed kernel is using the expected key length
#
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    zypper_call('in go');
    # download and compile the go program to check the key length
    # upstream project: https://github.com/ilmanzo/autograph-pls
    # to update: $ curl -O --output-dir data/security/secureboot https://raw.githubusercontent.com/ilmanzo/autograph-pls/main/parsesign.go
    assert_script_run 'curl -O ' . data_url('security/secureboot/parsesign.go');
    assert_script_run('go build parsesign.go');
    my $expected_keylength = get_required_var('ARCH') =~ /s390x|ppc64le/ ? 4096 : 2048;
    validate_script_output('./parsesign ' . get_boot_image_name(), sub { /Key size calculation: $expected_keylength bits/ });
    assert_script_run 'rm parsesign parsesign.go';    # cleanup
}

sub get_boot_image_name {
    my $arch = get_required_var('ARCH');
    my %kernel_paths = (
        s390x => 'image',
        aarch64 => 'Image',
        x86_64 => 'vmlinuz',
        ppc64le => 'vmlinux',
    );
    return '/boot/' . $kernel_paths{$arch} if exists $kernel_paths{$arch};
    die "Unsupported architecture: $arch";
}

1;
