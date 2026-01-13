# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the minimal installed system packages.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $get_output_lines = sub {
        my ($command) = @_;
        return split /\n/, script_output($command);
    };

    select_serial_terminal();

    my @installed_packages = $get_output_lines->('rpm -qa');
    my %is_installed = map { $_ => 1 } @installed_packages;

    record_info("Package count:", scalar @installed_packages);
    record_info('Installed packages:', join("\n", @installed_packages));

    my @problematic_packages;
    for my $pkg (@installed_packages) {
        my $recommends = script_output("rpm -q --queryformat '%{RECOMMENDS}' $pkg", proceed_on_failure => 1);

        next unless $recommends && $recommends ne '(none)';
        my @recommended_pkgs = split /\s+/, $recommends;
        my @installed_recommends = grep { $is_installed{$_} } @recommended_pkgs;

        push @problematic_packages, {
            package => $pkg,
            installed_recommends => \@installed_recommends
        } if (@installed_recommends);
    }

    if (@problematic_packages) {
        my @report_lines = map {
            sprintf("%s has installed recommendations: %s",
                $_->{package},
                join(', ', @{$_->{installed_recommends}}))
        } @problematic_packages;

        record_info('Problematic packages:', join("\n", @report_lines));
    }

    record_info('onlyRequired validation:',
        @problematic_packages ?
          'FAIL: Found ' . scalar(@problematic_packages) . ' packages with installed recommendations.' :
          'PASS: No recommended packages are installed.'
    );
}

1;
