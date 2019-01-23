# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_hostnames check hostnames and add/delete hostsnames
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;
use utils 'type_string_slow';


sub run {
    my $self   = shift;
    my $module = "host";

    select_console 'root-console';
    #	add 1 entry to /etc/hosts and edit it later
    script_run "echo '80.92.65.53    n-tv.de ntv' >> /etc/hosts";
    select_console 'x11', await_console => 0;
    $self->launch_yast2_module_x11('host', match_timeout => 90);
    assert_and_click "yast2_hostnames_added";
    wait_still_screen 1;
    wait_screen_change { send_key 'alt-i'; };
    send_key 'alt-t';
    type_string 'download-srv';
    wait_still_screen 1;
    send_key 'alt-h';
    type_string 'download.opensuse.org';
    wait_still_screen 1;
    send_key 'alt-i';
    type_string_slow '195.135.221.134';
    assert_and_click 'yast2_hostnames_changed_ok';
    assert_screen "yast2-$module-ui", 30;
    #	OK => Exit
    wait_screen_change { send_key "alt-o"; };
    # Check that entry was correctly edited in /etc/hosts
    select_console "root-console";
    assert_script_run q#grep '195\.135\.221\.134\s*download\.opensuse\.org\s*download-srv' /etc/hosts#;
}

# Test ends in root-console, default post_run_hook does not work here
sub post_run_hook {
    set_var('YAST2_GUI_TERMINATE_PREVIOUS_INSTANCES', 1);
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs('/etc/hosts');
    $self->SUPER::post_fail_hook;
}

1;
