# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the 2 newest go versions by compiling and running man_or_boy.go
# Maintainer: Dominik Heidler <dominik@heidler.eu>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use registration;

sub mob_test {
    assert_script_run "go build /home/$username/data/man_or_boy.go";
    assert_script_run('test $(./man_or_boy) == "-67"');
    assert_script_run 'rm man_or_boy';
    assert_script_run("test \$(go run /home/$username/data/man_or_boy.go) == \"-67\"");
}

sub run {
    select_serial_terminal;

    if (is_sle() && !main_common::is_updates_tests()) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product(get_addon_fullname('sdk'));
    }

    script_run "zypper se go | grep ' go[0-9][0-9.]* '";
    my $older_go = script_output "zypper se go | grep ' go[0-9][0-9.]* ' | awk -F '|' '{print \$2}' | tr -d ' ' | sort --version-sort | tail -2 | head -1";
    my $latest_go = script_output "zypper se go | grep ' go[0-9][0-9.]* ' | awk -F '|' '{print \$2}' | tr -d ' ' | sort --version-sort | tail -1 | head -1";
    record_info "Go Versions", "Detected Go versions:\nOlder: $older_go\nLatest: $latest_go";
    record_info "$older_go";
    zypper_call "in $older_go";
    mob_test();
    zypper_call "rm $older_go";
    record_info "$latest_go";
    zypper_call "in $latest_go";
    mob_test();
    zypper_call "rm $latest_go";
}

1;
