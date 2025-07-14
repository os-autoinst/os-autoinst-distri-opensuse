# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate only mandatory dependencies are installed
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal();

    assert_script_run('rpm -qa');
    my @installed_pkgs = split /\n/, script_output('rpm -qa');
    my %is_installed   = map { $_ => 1 } @installed_pkgs;

    record_info("Installed package number:", scalar @installed_pkgs);

    my @detected_packages;
    my @pattern_list = split(/\n/, script_output('rpm -qa patterns-*'));
    foreach my $pattern (@pattern_list) {
        my @recommend_pkgs = map {
            # Match (pkg if (product(...))) or just pkg
            /(?:\(([\w\-\+\.]+)\s+if\s+\(product\()/ ? $1 : /^([\w\-\+\.]+)$/ ? $1 : ()
        } split /\n/, script_output("rpm -q --recommends $pattern");
        for my $pkg (
            record_info("Check package:" . $pkg);
            grep {
                $_ && !$is_installed{$_} && script_run("rpm -q $_ > /dev/null 2>&1") == 0
            } @recommend_pkgs
        ) {
            next if script_output("rpm -q --whatrequires $pkg", proceed_on_failure => 1) !~ /no package requires/;
            push @detected_packages, $pkg;
        }
    }

    record_info('Detected packages', join(',', @detected_packages));
}

1;
