# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for Utils:Bootloader
# Maintainer: QE Kernel team <kernel-qa@suse.de>

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;

use Utils::Bootloader;

my $mocked_arch = 'x86_64';
my $mocked_script_output = '';

my $mock_bootloader = Test::MockModule->new('Utils::Bootloader');
$mock_bootloader->redefine(
    get_var => sub {
        my ($var) = @_;
        return $mocked_arch if $var eq 'ARCH';
        return undef;
    },
    record_info => sub { 1 },
    script_output => sub { return $mocked_script_output },
    ensure_serialdev_permissions => sub { 1 },
);

$INC{'bootloader_setup.pm'} = 1;
*bootloader_setup::GRUB_CFG_FILE = sub { 't/data/mock_grub.cfg' };

subtest 'Test _get_command_line_size for all architectures' => sub {
    my %expected_sizes = (
        s390x => 4096,
        aarch64 => 2048,
        ppc64le => 2048,
        riscv64 => 2048,
        x86_64 => 2048,
        i586 => 2048,
    );

    for my $arch (sort keys %expected_sizes) {
        $mocked_arch = $arch;
        is(Utils::Bootloader::_get_command_line_size(), $expected_sizes{$arch},
            "Architecture $arch returns correct size $expected_sizes{$arch}");
    }

    $mocked_arch = 'sparc64';
    throws_ok { Utils::Bootloader::_get_command_line_size() }
    qr/unsupported.*$mocked_arch/,
      'Dies correctly when an unsupported architecture is provided';

    $mocked_arch = undef;
    throws_ok { Utils::Bootloader::_get_command_line_size() }
    qr/unsupported.*undef/,
      'Dies correctly when ARCH is undefined';
};


subtest 'Test check_kernel_arg_len limits' => sub {
    $mocked_arch = 'x86_64';

    $mocked_script_output = "/boot/vmlinuz-6.5 root=/dev/sda1 ro quiet\n";

    lives_ok { check_kernel_arg_len() }
    'check_kernel_arg_len lives when string length is well below the limit';

    $mocked_script_output = ("A" x 2048) . "\n";

    throws_ok { check_kernel_arg_len() }
    qr/fail: Kernel.*COMMAND_LINE_SIZE/,
      'check_kernel_arg_len dies when the string length exceeds the limit';
};

done_testing();
