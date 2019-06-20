# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check if an unregistered system can be registered and if
#          enabling and disabling extensions correctly work.
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use registration;
use utils 'zypper_call';

sub register_system_and_add_extension {
    wait_screen_change { type_string get_var "SCC_EMAIL" };
    send_key "tab";
    wait_screen_change { type_string get_var "SCC_REGCODE" };
    send_key "alt-n";
    assert_screen("yast2_registration-ext-mod-selection", timeout => 120);
    # enable Web and Scripting Module
    for my $i (0 .. 25) {
        send_key "down";
    }
    wait_screen_change { send_key "spc" };
    send_key "alt-n";
    wait_still_screen(stilltime => 7, timeout => 60);
    if (check_screen "yast2_registration-license-agreement") {
        wait_screen_change { send_key "alt-a" };
        send_key "alt-n";
        wait_still_screen 2;
    }
    assert_screen 'yast2-software-installation-summary', 90;
    send_key "alt-a";
    wait_still_screen 2;
    assert_screen 'yast2-sw_automatic-changes';
    send_key "alt-o";
    wait_still_screen 2;
    assert_screen 'installation-report';
    wait_screen_change { send_key "alt-f" };
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    zypper_call "in yast2-registration";

    cleanup_registration;
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'registration');
    assert_screen([qw(yast2_registration-overview yast2_registration-registration-page)]);

    send_key "alt-e" if (match_has_tag "yast2_registration-overview");
    register_system_and_add_extension;
    wait_serial("$module_name-0", 200) || die "'yast2 $module_name' didn't finish";

    assert_script_run "SUSEConnect --status-text |grep -A3 -E 'SUSE Linux Enterprise Server|Web and Scripting Module' | grep -qE '^\\s+Registered'";
}

1;

