# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: validate package and patterns in the SUT
# - Create an structure containing some software names and patterns
# - Using zypper, check if packages are installed, following rules defined in
#   the structure
# - Using zypper, check if patterns are installed, following rules defined in
#   the structure
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_jeos);

my %software = ();

# Define test data

$software{salt} = {
    repo      => 'Basesystem',
    installed => is_jeos() ? 1 : 0,       # On JeOS Salt is present in the default image
    condition => sub { is_sle('15+') },
};
$software{'update-test-feature'} = {      # See poo#36451
    repo      => is_sle('15+') ? 'Basesystem' : 'SLES',
    installed => 0,
    available => sub { get_var('BETA') },
};
# Define more packages with the same set of expectations
$software{'update-test-interactive'} = $software{'update-test-feature'};
$software{'update-test-security'}    = $software{'update-test-feature'};
if (is_sle('15+')) {
    $software{'update-test-trivial'} = $software{'update-test-feature'};
} else {
    $software{'update-test-trival'} = $software{'update-test-feature'};
}

sub verify_installation_and_repo {
    my ($name) = shift;

    my $args = $software{$name}->{installed} ? '--installed-only' : '--not-installed-only';
    # define search type
    $args .= $software{$name}->{pattern} ? ' -t pattern' : ' -t package';
    # Set flag if availability condition is defined and is true or not defined
    my $available = !!(!defined($software{$name}->{available}) || $software{$name}->{available}->());
    # Negate condition if package should not be available
    my $cmd = $available ? '' : '! ';
    $cmd .= "zypper --non-interactive se -n $args --match-exact --details $name";
    # Verify repo only if package expected to be available
    $cmd .= ' | grep ' . $software{$name}->{repo} if $available;
    # Record error in case non-zero return code
    if (script_run($cmd)) {
        my $error = $software{$name}->{pattern} ? 'Pattern' : 'Package';
        if ($available) {
            $error .= " '$name' not found in @{ [ $software{$name}->{repo} ] } or not preinstalled."
              . " Expected to be installed: @{ [ $software{$name}->{installed} ? 'true' : 'false' ] }\n";
        }
        else {
            $error .= " '$name' found in @{ [ $software{$name}->{repo} ] } repo, expected to be not available\n";
        }
        return $error;
    }
    return '';
}

sub verify_pattern {
    my ($name)       = shift;
    my $errors       = '';
    my $pattern_info = script_output("zypper info -t pattern $name");

    for my $package (@{$software{$name}->{packages}}) {
        if ($pattern_info !~ /$package/) {
            if ($package eq 'cloud-regionsrv-client-plugin-ec2') {
                record_soft_failure 'bsc#1108267 -- Differences in the content of pattern Amazon Web Service between SLE12SP4 and SLE15.1';
                next;
            }
            $errors .= "Package '$package' is not listed in the pattern '$name'\n";
        }
    }
    return $errors;
}

sub run {
    select_console 'root-console';
    my $errors = '';    # Variable to accumulate errors
    for my $name (keys %software) {
        # Skip package if condition is defined and is false
        next if defined($software{$name}->{condition}) && !$software{$name}->{condition}->();
        # Validate common part for packages and patterns
        $errors .= verify_installation_and_repo($name);
        # Validate pattern
        $errors .= verify_pattern($name) if $software{$name}->{pattern};
    }
    # Fail in case of any unexpected results
    die "$errors" if $errors;
}

1;
