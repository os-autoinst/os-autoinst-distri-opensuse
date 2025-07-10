# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the product installed by agama via /etc/os-release
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Config::Tiny;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';
    my $test_suite_data = get_test_suite_data();
    my $os_release_output = script_output('cat /etc/os-release');
    my $os_release = Config::Tiny->read_string($os_release_output)->{_};

    my %fields = (
        NAME                 => $test_suite_data->{NAME},
        PRETTY_NAME          => $test_suite_data->{PRETTY_NAME},
        VARIANT              => $test_suite_data->{VARIANT},
        VARIANT_ID           => $test_suite_data->{VARIANT_ID},
        VERSION_ID           => $test_suite_data->{VERSION_ID},
        ID                   => $test_suite_data->{ID},
        ID_LIKE              => $test_suite_data->{ID_LIKE},
        SUSE_SUPPORT_PRODUCT => $test_suite_data->{SUSE_SUPPORT_PRODUCT},
    );

    foreach my $key (keys %fields) {
        next unless defined $fields{$key};
        record_info $key, "Checking $key in /etc/os-release";
        my $expected = $fields{$key};
        my $actual = $os_release->{$key};
        assert_defined($actual, "$key is defined in /etc/os-release");
        assert_equals($expected, $actual, "Wrong product $key in /etc/os-release (expected='$expected', got='$actual')");
    }
}

1;
