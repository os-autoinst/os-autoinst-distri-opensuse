# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the base product from /etc/products.d/baseproduct.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal();

    my @installed_packages = split /\n/, script_output('rpm -qa');
    my %is_installed = map { $_ => 1 } @installed_pkgs;

    record_info("Package number:", scalar @installed_pkgs);
    record_info('Installed packages:', join("\n", @installed_packages));

    my @all_recommends;
    for my $pattern (split /\n/, script_output('rpm -qa patterns-*')) {
        my @recommends = split /\n/, script_output("rpm -q --recommends $pattern");
        push @all_recommends, @recommends;
    }

    my @problematic_packages;
    for my $pkg (@all_recommends) {
        next unless $pkg && $is_installed{$pkg};
        my $whatrequires = script_output("rpm -q --whatrequires $pkg", proceed_on_failure => 1);
        next unless $whatrequires =~ /no package requires/;
        push @problematic_packages, $pkg;
    }

    record_info('Problematic packages', join(',', @problematic_packages));
    record_info('Found recommended packages that shouldn\'t be installed with onlyRequired',
        join(',', @problematic_packages)) if @problematic_packages;
}

1;
