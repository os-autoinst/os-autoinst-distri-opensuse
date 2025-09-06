# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the minimal installed system packages.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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

    my @packages_with_recommends;
    for my $pkg (@installed_packages) {
        my $recommends = script_output("rpm -q --queryformat '%{RECOMMENDS}' $pkg", proceed_on_failure => 1);
        if ($recommends && $recommends ne '(none)') {
            push @packages_with_recommends, "$pkg: $recommends";
        }
    }

    record_info('Packages with recommendations:', join("\n", @packages_with_recommends));
    record_info('Count of packages with recommendations:', scalar @packages_with_recommends);

    record_info('onlyRequired validation:',
        scalar(@packages_with_recommends) == 0 ?
          'PASS: No packages have recommendations installed.' :
          'INFO: Some packages still have recommendations.');
}

1;
