# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_jeos);

our $date_re = qr/[0-9]{4}-[0-9]{2}-[0-9]{2}/;

sub run {
    diag('fate#320597: Introduce \'zypper lifecycle\' to provide information about life cycle of individual products and packages');
    select_console 'user-console';
    my $overview = script_output 'zypper lifecycle', 300;
    die "Missing header line:\nOutput: '$overview'" unless $overview =~ /Product end of support/;
    die "Missing link to lifecycle page:\nOutput: '$overview'"
      if $overview =~ /n\/a/ && $overview !~ qr{\*\) See https://www.suse.com/lifecycle for latest information};
    # Compare to test data from
    # https://github.com/nadvornik/zypper-lifecycle/blob/master/test-data/SLES.lifecycle
    # from https://fate.suse.com/320597
    # 1. verify that "zypper lifecycle" shows correct eol dates for installed
    # products (this tests also fate#320699)
    #
    # 3. verify that "zypper lifecycle" shows correct package eol based on the
    # data from step 2
    my ($base_repos, $package, $prod);
    my $prod = script_output 'basename `readlink /etc/products.d/baseproduct ` .prod';
    # select a package suitable for the following test
    # the package must be installed from base product repo
    my $output = script_output 'echo $(zypper -n -x se -i -t product -s ' . $prod . ')', 300;
    # Parse base repositories
    if (my @repos = $output =~ /repository="([^"]+)"/g) {
        $base_repos = join(" ", @repos);
    }

    die "Got malformed repo list:\nOutput: '$output'" unless $base_repos;

    $output = script_output 'echo $(for repo in ' . $base_repos . ' ; do zypper -n -x se -t package -i -s -r $repo ; done | grep name= | head -n 1 )', 300;
    # Parse package name
    if ($output =~ /name="(?<package>[^"]+)"/) {
        $package = $+{package};
    }
    # For JeOS build testing we are always using the latest repositories, because
    # JeOS images are build with a *different* build number to SLES/Leap. It seems
    # that SLES repositories are not populated with packages for several hours
    # (I have seen the test pass after 14 hours from the image creation), and actually
    # no package in the image comes from any repository - it's from the image. So we
    # hard-code 'sles-release' package, and it... works. Somehow.
    if (!$package && is_jeos) {
        record_info 'Workaround', "Hardcoding 'sles-release' package for lifecycle check", result => 'softfail';
        $package = 'sles-release';
    }
    die "No suitable package found. Script output:\nOutput: '$output'" unless $package;

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
    $output = script_output "zypper lifecycle $package", 300;
    die "$package lifecycle entry incorrect:\nOutput: '$output'" unless $output =~ /$package(-\S+)?\s+$testdate/;

    # test that the package is reported if we query the date after
    $output = script_output "zypper lifecycle --date $testdate_after", 300;
    die "$package not reported for date $testdate_after:\nOutput: '$output'" unless $output =~ /$package(-\S+)?\s+$testdate/;

    # test that the package is not reported if we query the date before
    # report can be empty - exit code 1 is allowed
    $output = script_output "zypper lifecycle --date $testdate_before || test \$? -le 1", 300;
    die "$package reported for date $testdate_before:\nOutput: '$output'" if $output =~ /$package(-\S+)?\s+$testdate/;

    # delete lifecycle data - package eol should default to product eol
    select_console 'root-console';
    assert_script_run "rm -f /var/lib/lifecycle/data/$prod.lifecycle";

    # get product eol
    my $product_file = "/etc/products.d/$prod.prod";
    my $product_name = script_output "grep '<summary>' $product_file";
    $product_name =~ s/.*<summary>([^<]*)<\/summary>.*/$1/s || die "no product name found in $product_file";
    record_info('Product found', "Product found in overview: '$product_name'");

    my $product_eol;
    for my $l (split /\n/, $overview) {
        if ($l =~ /^(?<!Codestream:)\s+$product_name\s*(\S*)/) {
            $product_eol = $1;
            last;
        }
    }
    die "baseproduct eol not found in overview\nOutput: '$product_name'" unless $product_eol;

    select_console 'user-console';
    # verify that package eol defaults to product eol
    $output = script_output "zypper lifecycle $package", 300;
    unless ($output =~ /$package(-\S+)?\s+$product_eol/) {
        die "$package lifecycle entry incorrect:\nOutput: '$output', expected: '/$package-\\S+\\s+$product_eol'";
    }

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

    # report should be empty - exit code 1 is expected
    # but it can show maintenance updates released during last few minutes
    $output = script_output 'zypper lifecycle --days 0 || test $? -le 1', 300;
    die "All products should be supported as of today\nOutput: '$output'" unless $output =~ /No products.*before/;

    $output = script_output 'zypper lifecycle --days 9999', 300;
    die "Product 'end of support' line not found\nOutput: '$output'"         unless $output =~ /Product end of support before/;
    die "Current product should not be supported anymore\nOutput: '$output'" unless $output =~ /$product_name\s+$product_eol/;

    # report should be empty - exit code 1 is expected
    # but it can show maintenance updates released during last few minutes
    $output = script_output 'zypper lifecycle --date $(date --iso-8601) || test $? -le 1', 300;
    die "All products should be supported as of today\nOutput: '$output'" unless $output =~ /No products.*before/;
}

sub test_flags {
    return {milestone => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    # Additionally collect executed scripts
    assert_script_run 'tar -cf /tmp/script_output.tgz /tmp/*.sh';
    upload_logs '/tmp/script_output.tgz';
}

1;
