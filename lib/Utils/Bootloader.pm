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
use utils qw(
  ensure_serialdev_permissions
);
use Utils::Architectures qw(
  is_x86_64
  is_aarch64
  is_ppc64le
  is_ppc64
  is_s390x
  is_riscv
);

our @EXPORT = qw(
  check_kernel_arg_len
);

use constant GRUB_CFG_FILE => "/boot/grub2/grub.cfg";

# Architecture-specific COMMAND_LINE_SIZE, as defined in the Linux kernel
# sources (see arch/*/include/{asm,uapi/asm}/setup.h). Kept here instead of
# being read from the installed 'linux-kernel-headers' package so that this
# check does not depend on that package being available on the SUT.
#
# x86_64, aarch64, ppc64(le) and riscv64 all share the same value, so it is
# kept as a single default instead of being repeated per architecture below.
use constant DEFAULT_COMMAND_LINE_SIZE => 2048;

# Only architectures whose COMMAND_LINE_SIZE differs from the default need
# an entry here. s390x uses a configurable CONFIG_COMMAND_LINE_SIZE
# (arch/s390/Kconfig, range 896-1048576); 4096 is the upstream default.
use constant COMMAND_LINE_SIZE_BY_ARCH => {
    s390x => 4096,
};

=head1 _get_command_line_size

    _get_command_line_size()

Returns the C<COMMAND_LINE_SIZE> value for the current worker architecture: the
architecture-specific override from C<COMMAND_LINE_SIZE_BY_ARCH> if one exists, otherwise
C<DEFAULT_COMMAND_LINE_SIZE>. Dies if the architecture is not supported at all.

=cut

sub _get_command_line_size {
    return COMMAND_LINE_SIZE_BY_ARCH->{s390x} if is_s390x;
    return DEFAULT_COMMAND_LINE_SIZE if is_x86_64 || is_aarch64 || is_ppc64le || is_ppc64 || is_riscv;
    die 'check_kernel_arg_len: unsupported architecture ' . get_var('ARCH');
}

=head1 check_kernel_arg_len

    check_kernel_arg_len()

Validates whether the length of the longest kernel command line found in F</boot/grub2/grub.cfg>
exceeds the architecture-specific C<COMMAND_LINE_SIZE> limit defined in C<COMMAND_LINE_SIZE_BY_ARCH>.

=cut

sub check_kernel_arg_len {
    ensure_serialdev_permissions;

    my $extract_kernel_args = sprintf('grep -oP "(linux\s.*/boot/\S+\s)\K.*" %s', GRUB_CFG_FILE);
    my $get_long_arg = $extract_kernel_args . ' | awk \'{ if (length > max) { max = length; long = $0 } } END { print long }\'';

    my $kernel_args = script_output($get_long_arg);
    my $defined_cmd_line_size = _get_command_line_size;

    my $length = length($kernel_args);
    my $cli_len = ($defined_cmd_line_size >= $length) ? 'OK' : 'Kernel Command Line args length is more than COMMAND_LINE_SIZE';
    my $cli_len_result = ($length >= $defined_cmd_line_size) ? 'fail' : 'ok';

    record_info('KERNEL', "COMMAND_LINE_SIZE: $defined_cmd_line_size\nLength: $length\nCLI: $kernel_args\nCLI Len: $cli_len",
        result => $cli_len_result);

}
