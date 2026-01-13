# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the product installed by agama via /etc/os-release
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use Config::Tiny;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';

    my $test_data = get_test_suite_data()->{os_release};
    my $os_release = Config::Tiny->read_string(script_output('cat /etc/os-release'))->{_};

    foreach my $key (keys %$test_data) {
        my $expected = $test_data->{$key};
        my $actual = $os_release->{$key};
        $actual =~ s/^"|"$//g;
        assert_equals($expected, $actual, "Mismatch for $key, expect $expected but got $actual");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
