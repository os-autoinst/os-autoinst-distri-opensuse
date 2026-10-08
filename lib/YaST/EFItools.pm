# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package YaST::EFItools;

use strict;
use warnings;
use Exporter 'import';
use testapi;

our @EXPORT = qw(
  read_secure_boot_status
);

use constant MIN_OCTALS => 5;

=head1 tools for EFI related operations on /sys/firmware/efi/

=head2 check_secure_boot_status

The function reads out the octal values of the variable in efivars/SecureBoot-*.
Secure Boot status is stored in the 5th byte of that variable (0=disabled, 1=enabled)
See https://www.codelinsoft.it/sito/index.php/support/wiki/secure-boot for details

We check if the 5th byte is set to 0 or 1 and act accordingly. 

=cut

sub read_secure_boot_status {
    assert_script_run("ls /sys/firmware/efi/efivars/SecureBoot-*");
    my $octal_str = script_output("od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-*");
    my @octal_array = split(/\s+/, $octal_str);
    die 'Unexpected values in Secure Boot file' unless 0 + @octal_array >= MIN_OCTALS && $octal_array[MIN_OCTALS - 1] =~ /0|1/;
    my $secure_boot = $octal_array[MIN_OCTALS - 1] ? 'enabled' : 'disabled';
}

1;
