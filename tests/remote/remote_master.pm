# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use mm_network;
use lockapi;

# poo#9576
sub run() {
    my $slave_ip;

    select_console 'root-console';
    # Setup static NETWORK
    configure_default_gateway;
    configure_static_ip('10.0.2.12/15');

    # Wait until slave becomes ready
    mutex_lock "installation_ready";

    if (check_var("REMOTE_MASTER", "vnc")) {
        # Get slave ip using slptool
        script_run "systemctl stop SuSEfirewall2";
        $slave_ip = script_output "slptool findsrvs service:YaST.installation.suse:vnc | cut -d: -f4 | tr -d /";
        script_run "systemctl start SuSEfirewall2";

        select_console 'x11';
        x11_start_program("xterm");
        type_string "vncviewer -fullscreen $slave_ip:1\n";
        assert_screen "remote_master_password";    # wait for password prompt
        type_string "$password\n";
    }
    elsif (check_var("REMOTE_MASTER", "ssh")) {
        $slave_ip = "10.0.2.11";
        select_console 'user-console';
        clear_console;

        type_string "ssh root\@$slave_ip\n";
        assert_screen "remote-ssh-login";
        type_string "yes\n";
        assert_screen 'password-prompt';
        type_string "$password\n";
        assert_screen "remote-ssh-login-ok";
        type_string "yast.ssh\n";
    }
    else {
        die("REMOTE_MASTER has wrong value");
    }
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
