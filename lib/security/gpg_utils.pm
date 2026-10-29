# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Helpers shared by the gpg test modules
#
# Maintainer: QE Security <none@suse.de>

package security::gpg_utils;

use strict;
use warnings;
use testapi;
use utils qw(zypper_call package_upgrade_check);
use package_utils 'install_package';
use version_utils qw(is_sle is_sle_micro is_public_cloud);

use base 'Exporter';

our @EXPORT = qw(check_libgcrypt);

=head1 SYNOPSIS

Helpers shared by tests/console/gpg.pm and
tests/console/oqa_agnostic/gpg_agnostic.pm.

=head2 check_libgcrypt

    return if check_libgcrypt();

Install libgcrypt20 (and libgcrypt20-hmac where it still exists) and
check that they are at least 1.9.0, see poo#107509. Returns 1 when a
Public Cloud BETA image is ahead of its repositories (bsc#1199312) and
the test should be aborted, otherwise 0.

=cut

sub check_libgcrypt {
    my $pkg_list = {
        libgcrypt20 => '1.9.0',
        'libgcrypt20-hmac' => '1.9.0'
    };
    delete $pkg_list->{'libgcrypt20-hmac'} if is_sle('15-SP6+') || is_sle_micro('6.2+');
    my $pc_beta = is_public_cloud() && check_var('BETA', '1');

    if ($pc_beta) {
        if (zypper_call('in ' . join(' ', keys %$pkg_list), exitcode => [0, 4]) == 4) {
            record_info('Aborting', 'The repositories are behind Public Cloud image. See bsc#1199312');
            return 1;
        }
    }
    else {
        install_package(join(' ', keys %$pkg_list), trup_reboot => 1);
    }

    if (is_sle('>=15-sp4') || is_sle_micro) {
        package_upgrade_check($pkg_list) unless $pc_beta;
    }
    else {
        foreach my $pkg_name (keys %$pkg_list) {
            my $pkg_ver = script_output("rpm -q --qf '%{version}\n' --whatprovides $pkg_name");
            record_info("$pkg_name version", "Version of Current package: $pkg_ver");
        }
    }
    return 0;
}

1;
