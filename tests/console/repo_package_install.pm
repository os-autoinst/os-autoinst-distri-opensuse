# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check SLE repositories, packages and installation status
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils qw(is_sle is_jeos);

my %packages = (
    salt => {
        repo      => 'Basesystem',
        installed => is_jeos() ? 1 : 0,       # On JeOS Salt is present in the default image
        condition => sub { is_sle('15+') },
    },
    'update-test-feature' => {                # See poo#36451
        repo      => is_sle('15+') ? 'Basesystem' : 'SLES',
        installed => 0,
        available => sub { get_var('BETA') },
    },
);
# Define more packages with the same set of expectations
$packages{'update-test-interactive'} = $packages{'update-test-feature'};
$packages{'update-test-security'}    = $packages{'update-test-feature'};
$packages{'update-test-trival'}      = $packages{'update-test-feature'};

sub run {
    select_console 'root-console';
    my $errors = '';    # Variable to accumulate errors
    for my $package (keys %packages) {
        # Skip package if condition is defined and is false
        next if defined($packages{$package}->{condition}) && !$packages{$package}->{condition}->();
        my $args = $packages{$package}->{installed} ? '--installed-only' : '--not-installed-only';
        # Set flag if availability condition is defined and is true or not defined
        my $available = !!(!defined($packages{$package}->{available}) || $packages{$package}->{available}->());
        # Negate condition if package should not be available
        my $cmd = $available ? '' : '! ';
        $cmd .= "zypper se -n $args --match-exact --details $package";
        # Verify repo only if package expected to be available
        $cmd .= ' | grep ' . $packages{$package}->{repo} if $available;
        # Record error in case non-zero return code
        if (script_run($cmd)) {
            if ($available) {
                $errors .= "Package '$package' not found in @{ [ $packages{$package}->{repo} ] } or not preinstalled."
                  . " Expected to be installed: @{ [ $packages{$package}->{installed} ? 'true' : 'false' ] }\n";
            }
            else {
                $errors .= "Package '$package' found in @{ [ $packages{$package}->{repo} ] } repo, expected to be not available\n";
            }
        }
    }
    # Fail in case of any unexpected results
    die "$errors" if $errors;
}

1;
