# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Kernel command line length validation function.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Utils::Bootloader;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils;
use Utils::Architectures;
use utils qw(
  ensure_serialdev_permissions
);

our @EXPORT = qw(
  check_kernel_arg_len
);

# Architecture-specific COMMAND_LINE_SIZE, as defined in the Linux kernel
# sources (see arch/*/include/{asm,uapi/asm}/setup.h). Kept here instead of
# being read from the installed 'linux-kernel-headers' package so that this
# check does not depend on that package being available on the SUT.
use constant COMMAND_LINE_SIZE_BY_ARCH => {
    s390x => 4096,
    aarch64 => 2048,
    ppc64le => 2048,
    riscv64 => 2048,
    x86_64 => 2048,
    i586 => 2048,
};

=head1 _get_command_line_size

    _get_command_line_size()

Returns the C<COMMAND_LINE_SIZE> value for the current worker architecture 
from C<COMMAND_LINE_SIZE_BY_ARCH>. Dies if the architecture is not supported.

=cut

sub _get_command_line_size {
    # get_var is exported by testapi in openQA
    my $arch = get_var('ARCH') // 'undef';

    return COMMAND_LINE_SIZE_BY_ARCH->{$arch} if exists COMMAND_LINE_SIZE_BY_ARCH->{$arch};

    # openQA jobs should always have an ARCH, but we use // 'undef' just in case
    # it is missing from the job settings, making debugging easier in the web UI.
    die 'check_kernel_arg_len: unsupported architecture ' . ($arch // 'undef');
}

=head1 check_kernel_arg_len

    check_kernel_arg_len()

Validates whether the length of the longest kernel command line found in F</boot/grub2/grub.cfg>
exceeds the architecture-specific C<COMMAND_LINE_SIZE> limit defined in C<COMMAND_LINE_SIZE_BY_ARCH>.

=cut

sub check_kernel_arg_len {
    require bootloader_setup;
    ensure_serialdev_permissions;

    my $grub_cfg_file = bootloader_setup::GRUB_CFG_FILE();

    if (is_transactional) {
        my $def_snapshot = -1;
        my @snapper_lines = split(/\n/, script_output('snapper --csv list'));
        foreach my $line (@snapper_lines) {
            my @fields = split(/,/, $line);
            # column indices (0-based): 2=Number, 3=Default, 4=Active
            if (($fields[3] // '') eq 'yes' && ($fields[4] // '') eq 'no') {
                $def_snapshot = $fields[2];
                last;
            }
        }
        $grub_cfg_file = "/.snapshots/$def_snapshot/snapshot/boot/grub2/grub.cfg" unless ($def_snapshot == -1);
    }

    my $extract_kernel_args = sprintf('grep -oP "(linux\s)\K.*" %s', $grub_cfg_file);
    my @kernel_arg_lines = split(/\n/, script_output($extract_kernel_args));
    my $longest_arg = '';
    foreach my $line (@kernel_arg_lines) {
        $longest_arg = $line if (length($line) > length($longest_arg));
    }
    my $kernel_args = "BOOT_IMAGE=" . $longest_arg;
    my $defined_cmd_line_size = _get_command_line_size;

    my $length = length($kernel_args);
    my $cli_len = ($defined_cmd_line_size >= $length) ? 'OK' : 'Kernel Cmd Line args len is more than COMMAND_LINE_SIZE';
    my $cli_len_result = ($length > $defined_cmd_line_size) ? 'fail' : 'ok';
    my $output_str = "COMMAND_LINE_SIZE: $defined_cmd_line_size\nGRUB_FILE: $grub_cfg_file\nLongest Arg: $kernel_args\nLen: $length\nArg Len: $cli_len";

    record_info('KERNEL', $output_str, result => $cli_len_result);
    die "$cli_len_result: $cli_len" unless ($cli_len_result eq 'ok');

}
