# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'verify_software';
use version_utils qw(is_sle is_jeos);

my %software = ();

# Define test data

$software{'salt-minion'} = {
    repo => 'Basesystem',
    installed => is_jeos() ? 1 : 0,    # On JeOS Salt is present in the default image
    condition => sub { is_sle('15+') },
};
$software{'sles-ltss-release'} = {
    repo => 'LTSS',
    installed => 1,
    condition => sub { is_sle('15+') },
    available => sub { get_var('SCC_REGCODE_LTSS') }
};
$software{'update-test-feature'} = {    # See poo#36451
    repo => is_sle('15+') ? 'Basesystem' : 'SLES',
    installed => 0,
    available => sub { get_var('BETA') },
};
# Define more packages with the same set of expectations
$software{'update-test-interactive'} = $software{'update-test-feature'};
$software{'update-test-security'} = $software{'update-test-feature'};
if (is_sle('15+')) {
    $software{'update-test-trivial'} = $software{'update-test-feature'};
} else {
    $software{'update-test-trivial'} = $software{'update-test-feature'};
}

sub verify_pattern {
    my ($name) = shift;
    my $errors = '';
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
    select_serial_terminal;

    my $errors = '';    # Variable to accumulate errors
    for my $name (keys %software) {
        # Skip package if condition is defined and is false
        next if defined($software{$name}->{condition}) && !$software{$name}->{condition}->();
        # Validate common part for packages and patterns
        my $available = !!(!defined($software{$name}->{available}) || $software{$name}->{available}->());
        $errors .= verify_software(name => $name,
            installed => $software{$name}->{installed},
            pattern => $software{$name}->{pattern},
            available => $available,
            repo => $software{$name}->{repo});
        # Validate pattern
        $errors .= verify_pattern($name) if $software{$name}->{pattern};
    }
    # Fail in case of any unexpected results
    die "$errors" if $errors;
}

1;
