# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;


our $date_re = qr/[0-9]{4}-[0-9]{2}-[0-9]{2}/;

sub check_package_lifecycle {
    my ($package) = @_;
    my $output = script_output 'zypper lifecycle ' . $package;
    # https://github.com/nadvornik/zypper-lifecycle/blob/master/test-data/SLES.lifecycle
    # says it should be
    #  /$package\s*[0-9.*-]\+\s[0-9]{4}-[0-9]{2}-[0-9]{2}/;
    # but it's actually
    die "$package lifecycle entry incorrect" unless $output =~ /$package-\S+\s+$date_re/;
}

sub run() {
    diag('fate#320597: Introduce \'zypper lifecycle\' to provide information about life cycle of individual products and packages');
    select_console 'user-console';
    my $output = script_output 'zypper lifecycle';
    die "Missing header line"                                        unless $output =~ /Product end of support/;
    die "All packages within base distribution should have same EOL" unless $output =~ /No packages with end of support different from product./;
    die "Missing link to lifecycle page"                             unless $output =~ qr{\*\) See https://www.suse.com/lifecycle for latest information};
    # Compare to test data from
    # https://github.com/nadvornik/zypper-lifecycle/blob/master/test-data/SLES.lifecycle
    # from https://fate.suse.com/320597
    # 1. verify that "zypper lifecycle" shows correct eol dates for installed
    # products (this tests also fate#320699)
    #
    # 3. verify that "zypper lifecycle" shows correct package eol based on the
    # data from step 2
    map { check_package_lifecycle $_ } qw/aaa_base kernel-default/;
    #
    # 4. verify that "zypper lifecycle --days N" and "zypper lifecycle --date
    # D" shows correct results
    assert_script_run 'zypper lifecycle --help';
    assert_script_run('zypper lifecycle --days 1', timeout => 30, fail_message => 'All packages supported tomorrow');
    $output = script_output 'zypper lifecycle --days 0';
    my $today = qx{date --iso-8601};
    chomp($today);
    die "'end of support' line not found" unless $output =~ /No (products|packages).*before $today/;
    assert_script_run('zypper lifecycle --days 9999', timeout => 30, fail_message => 'No package should be supported for more than 20 years');
    $output = script_output 'zypper lifecycle --days 9999';
    die "Product 'end of support' line not found" unless $output =~ /^Product end of support before/;
    my $product_version = get_required_var('VERSION') =~ s/-/ /r;
    die "Current product should not be supported anymore" unless $output =~ /SUSE Linux Enterprise.*$product_version.*$date_re/;
    assert_script_run('zypper lifecycle --date $(date --iso-8601)', timeout => 30, fail_message => 'All packages should be supported as of today');
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
