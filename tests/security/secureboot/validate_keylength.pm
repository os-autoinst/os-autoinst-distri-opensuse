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
    my ($self) = shift;
    select_serial_terminal;
    zypper_call('in go');
    # download and compile the go program to check the key length
    # upstream project: https://github.com/ilmanzo/autograph-pls
    # to update: $ curl -O --output-dir data/security/secureboot https://raw.githubusercontent.com/ilmanzo/autograph-pls/main/parsesign.go
    assert_script_run 'curl -O ' . data_url('security/secureboot/parsesign.go');
    assert_script_run('go build parsesign.go');
    record_info '/boot/ directory:', script_output('ls -l /boot/');
    $self->{$image_name} = get_boot_image_name();
    record_info 'Current kernel image and cmdline:', $self->{$image_name} . ' ' . script_output 'cat /proc/cmdline';
    my $expected_keylength = get_expected_keylength();
    validate_script_output('./parsesign ' . $self->{$image_name}, sub { /Key size calculation: $expected_keylength bits/ });
    assert_script_run 'rm parsesign parsesign.go';    # cleanup
}

sub get_boot_image_name {
    # First, try to find the kernel image based on the running kernel's release version.
    # This is more reliable than just guessing based on architecture.
    my $running_kernel_release = script_output('uname -r');
    my $kernel_image = script_output("find /boot -name 'vmlinuz-$running_kernel_release' -o -name 'Image-$running_kernel_release' -o -name 'image-$running_kernel_release' -o -name 'vmlinux-$running_kernel_release' | head -n 1");

    return $kernel_image if ($kernel_image && -e $kernel_image);

    # If the dynamic lookup fails, fall back to the architecture-based map.
    my $arch = get_required_var('ARCH');
    my %kernel_paths = (
        s390x => '/boot/image',
        aarch64 => '/boot/Image',
        x86_64 => '/boot/vmlinuz',
        ppc64le => '/boot/vmlinux',
    );
    return $kernel_paths{$arch} if exists $kernel_paths{$arch};
    die "Unsupported architecture: $arch";
}

# on x86_64 and aarch64 we expect 2048 bits keys
# for s390x and ppc64le we expect 4096 bits keys (except for kernel staging builds)
sub get_expected_keylength {
    return '2048' unless get_required_var('ARCH') =~ /s390x|ppc64le/;
    return '(2048|4096)' if get_var('STAGING');
    return '4096';
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs $self->{$image_name} if defined $self->{$image_name};
    $self->SUPER::post_fail_hook;
}


1;
