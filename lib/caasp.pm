# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package caasp;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(handle_simple_pw process_reboot trup_call);

# Weak password warning should be displayed only once - bsc#1025835
sub handle_simple_pw {
    return if get_var 'SIMPLE_PW_CONFIRMED';

    assert_screen 'inst-userpasswdtoosimple';
    send_key 'alt-y';
    set_var 'SIMPLE_PW_CONFIRMED', 1;
}

# Process reboot with an option to trigger it
sub process_reboot {
    my $trigger = shift;
    script_run("reboot", 0) if $trigger;

    reset_consoles;
    assert_screen 'linux-login', 200;
    select_console 'root-console';
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my $cmd = shift;
    my $check = shift // 1;
    $cmd .= "; echo trup-\$?- > /dev/$serialdev" if $check;

    save_screenshot;
    send_key "ctrl-l";

    script_run "transactional-update $cmd", 0;
    if ($cmd =~ /ptf /) {
        assert_screen "dialog_yes_no";
        type_string "y\n";
    }
    wait_serial 'trup-0-' if $check;
}

1;
