# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kselftests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use testapi qw(get_var get_required_var set_var);
use utils;
use strict;
use testapi;
use warnings;
use serial_terminal 'select_serial_terminal';
use LTP::WhiteList;
use version_utils qw(is_transactional);
use transactional 'trup_install';
use LTP::kirk;

sub download_kernel_source
{
    my @kv = split /\./, script_output "uname -r";
    my ($kv0, $kv1, $kv2) = ($kv[0], $kv[1], (split /-/, $kv[2])[0]);
    my $url = "https://mirrors.kernel.org/pub/linux/kernel/v$kv0.x/linux-$kv0.$kv1";

    $url .= $kv2 eq '0' ? ".tar.gz" : ".$kv2.tar.gz";

    assert_script_run("mkdir /root/linux");
    assert_script_run("curl " . $url . "| tar xz --strip-components=1 -C /root/linux", timeout => 600);
}

sub run
{
    my ($self) = @_;

    select_serial_terminal;

    # install build tools
    zypper_call("ref");
    is_transactional ? trup_install("gcc make") : zypper_call("in -t pattern devel_basis");

    # download linux source code
    download_kernel_source;

    # compile tests
    my $suite = get_required_var('KSELFTESTS_SUITE');
    my $root = "/root/linux/tools/testing/selftests";

    assert_script_run("make -C /root/linux headers", timeout => 1800);
    assert_script_run("make -C $root/$suite", timeout => 1800);

    # set tests to skip
    my $environment = {
        product => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision => get_var('BUILD'),
        flavor => get_var('FLAVOR'),
        arch => get_var('ARCH'),
        backend => get_var('BACKEND'),
        kernel => script_output('uname -r'),
        libc => '',
        gcc => '',
        harness => 'SUSE OpenQA',
        ltp_version => ''
    };

    my $issues = get_var('KSELFTESTS_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($issues);
    my @skipped = $whitelist->list_skipped_tests($environment, 'kselftests');
    my $test_exclude;
    if (@skipped) {
        $test_exclude = join("|", @skipped);

        record_info(
            "Exclude",
            "Excluding tests: $test_exclude",
            result => 'softfail'
        );
    }

    my @volumes = (
        {src => $root, dst => $root},
        {src => "/tmp", dst => "/tmp"}
    );

    LTP::kirk->run(
        framework => "kselftests:root=$root",
        skip => $test_exclude,
        suite => $suite,
        # when KIRK_INSTALL == 'container' we want to share
        # kselftests folder and kirk logs folder
        container_volumes => \@volumes,
    );
}

1;
