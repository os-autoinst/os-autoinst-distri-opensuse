# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test for 'zypper lifecycle'
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: fate#320597

use base "consoletest";
use strict;
use testapi;


our $date_re = qr/[0-9]{4}-[0-9]{2}-[0-9]{2}/;

sub run() {
    diag(
'fate#320597: Introduce \'zypper lifecycle\' to provide information about life cycle of individual products and packages'
    );
    select_console 'user-console';
    my $overview = script_output 'zypper lifecycle', 300;
    die "Missing header line" unless $overview =~ /Product end of support/;
    die "Missing link to lifecycle page"
      unless $overview =~ qr{\*\) See https://www.suse.com/lifecycle for latest information};
    # Compare to test data from
    # https://github.com/nadvornik/zypper-lifecycle/blob/master/test-data/SLES.lifecycle
    # from https://fate.suse.com/320597
    # 1. verify that "zypper lifecycle" shows correct eol dates for installed
    # products (this tests also fate#320699)
    #
    # 3. verify that "zypper lifecycle" shows correct package eol based on the
    # data from step 2
    my $prod            = script_output "basename `readlink /etc/products.d/baseproduct ` .prod";
    my $package         = 'aaa_base';
    my $testdate        = '2020-02-03';
    my $testdate_after  = '2020-02-04';
    my $testdate_before = '2020-02-02';
    # backup and create our lifecycle data with known content
    select_console 'root-console';
    assert_script_run "
    if [ -f /var/lib/lifecycle/data/$prod.lifecycle ] ; then
        mv /var/lib/lifecycle/data/$prod.lifecycle /var/lib/lifecycle/data/$prod.lifecycle.orig
    fi
    mkdir -p /var/lib/lifecycle/data
    echo '$package, *, $testdate' > /var/lib/lifecycle/data/$prod.lifecycle";
    # verify eol from lifecycle data
    select_console 'user-console';
    my $output = script_output "zypper lifecycle $package", 300;
    die "$package lifecycle entry incorrect:$output" unless $output =~ /$package-\S+\s+$testdate/;

    # test that the package is reported if we query the date after
    $output = script_output "zypper lifecycle --date $testdate_after", 300;
    die "$package not reported for date $testdate_after:$output" unless $output =~ /$package-\S+\s+$testdate/;

    # test that the package is not reported if we query the date before
    $output = script_output "zypper lifecycle --date $testdate_before", 300;
    die "$package reported for date $testdate_before:$output" if $output =~ /$package-\S+\s+$testdate/;

    # delete lifecycle data - package eol should default to product eol
    select_console 'root-console';
    assert_script_run "rm -f /var/lib/lifecycle/data/$prod.lifecycle";

    # get product eol
    my $product_name = script_output "grep '<summary>' /etc/products.d/$prod.prod";
    $product_name =~ s/.*<summary>([^<]*)<\/summary>.*/$1/;

    my $product_eol;
    for my $l (split /\n/, $overview) {
        if ($l =~ /$product_name\s*(\S*)/) {
            $product_eol = $1;
            last;
        }
    }
    die "baseproduct eol not found in overview" unless $product_eol;

    select_console 'user-console';
    # verify that package eol defaults to product eol
    $output = script_output "zypper lifecycle $package", 300;
    die "$package lifecycle entry incorrect:'$output', expected: '/$package-\\S+\\s+$product_eol'"
      unless $output =~ /$package-\S+\s+$product_eol/;

    # restore original data, if any
    select_console 'root-console';
    assert_script_run "
    if [ -f /var/lib/lifecycle/data/$prod.lifecycle.orig ] ; then
        mv /var/lib/lifecycle/data/$prod.lifecycle.orig /var/lib/lifecycle/data/$prod.lifecycle
    fi";
    #
    select_console 'user-console';
    # 4. verify that "zypper lifecycle --days N" and "zypper lifecycle --date
    # D" shows correct results
    assert_script_run 'zypper lifecycle --help';
    assert_script_run('zypper lifecycle --days 1', timeout => 300, fail_message => 'All packages supported tomorrow');
    $output = script_output 'zypper lifecycle --days 0', 300;
    die "'end of support' line not found" unless $output =~ /No (products|packages).*before/;
    assert_script_run(
        'zypper lifecycle --days 9999',
        timeout      => 300,
        fail_message => 'No package should be supported for more than 20 years'
    );
    $output = script_output 'zypper lifecycle --days 9999', 300;
    die "Product 'end of support' line not found"         unless $output =~ /^Product end of support before/;
    die "Current product should not be supported anymore" unless $output =~ /$product_name\s+$product_eol/;
    assert_script_run(
        'zypper lifecycle --date $(date --iso-8601)',
        timeout      => 300,
        fail_message => 'All packages should be supported as of today'
    );
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
