# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the 2 newest go versions by compiling and running man_or_boy.go
# Maintainer: Dominik Heidler <dominik@heidler.eu>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use registration;
use package_utils qw(install_package uninstall_package);

sub mob_test {
    assert_script_run "go build /home/$username/data/man_or_boy.go";
    assert_script_run('test $(./man_or_boy) == "-67"');
    assert_script_run 'rm man_or_boy';
    assert_script_run("test \$(go run /home/$username/data/man_or_boy.go) == \"-67\"");
}

sub run {
    select_serial_terminal;

    if (is_sle('<16') && !main_common::is_updates_tests()) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product(get_addon_fullname('sdk'));
    }

    script_run "zypper se '/^go[0-9][0-9.]*\$/'", timeout => 300;
    my $older_go = script_output "zypper se '/^go[0-9][0-9.]*\$/' | awk -F '|' '{print \$2}' | tr -d ' ' | sort --version-sort | tail -2 | head -1";
    my $latest_go = script_output "zypper se '/^go[0-9][0-9.]*\$/' | awk -F '|' '{print \$2}' | tr -d ' ' | sort --version-sort | tail -1 | head -1";
    record_info "Go Versions", "Detected Go versions:\nOlder: $older_go\nLatest: $latest_go";
    record_info "$older_go";
    install_package("$older_go", trup_continue => 1, trup_reboot => 1);
    mob_test();
    uninstall_package("$older_go", trup_continue => 1, trup_reboot => 1);
    record_info "$latest_go";
    install_package("$latest_go", trup_continue => 1, trup_reboot => 1);
    mob_test();
    uninstall_package("$latest_go", trup_continue => 1, trup_reboot => 1);
}

1;
