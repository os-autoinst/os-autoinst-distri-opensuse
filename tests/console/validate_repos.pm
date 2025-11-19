# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate repos in the system using expectations from the test data.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use repo_tools 'validate_repo_properties';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();

    select_console 'root-console';

    my %expected_repos = map { $_->{alias} => 1 } @{$test_data->{repos}};
    my @actual_aliases = split(/\n/, script_output("zypper -n lr --uri | awk \'NR>4 && \$1 ~ /[0-9]/ {print \$3}\'"));
    my $unexpected_aliases = '';
    my @skip_aliases = (
        qr/home_images/,
        qr/home_sles16/,
        qr/^SLES$/,    # This is on SLE 16 Full install of QE Security
        qr/SLES15-SP7-15\.7-0/,
        qr/SLE-15-SP7-SAP-15\.7-0/,
    );

    script_output 'zypper -n lr --uri';

    foreach my $repo (@{$test_data->{repos}}) {
        my $filter = $repo->{filter} ? $repo->{$repo->{filter}} : undef;
        validate_repo_properties({
                Filter => $filter,
                Alias => $repo->{alias},
                Name => $repo->{name},
                URI => join('', /$repo->{uri}/),
                Enabled => $repo->{enabled},
                Autorefresh => $repo->{autorefresh}
        });
    }
    foreach my $alias (@actual_aliases) {
        next if grep { $alias =~ $_ } @skip_aliases;
        if (!$expected_repos{$alias}) {
            $unexpected_aliases .= $alias . '\n';
        }
    }
    die("Unexpected repository found: $unexpected_aliases") if $unexpected_aliases;
}

1;
