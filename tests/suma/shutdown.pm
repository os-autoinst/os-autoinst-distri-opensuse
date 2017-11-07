# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Shutdown of SUSE Manager, needs longer time then default 60s
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use parent "basetest";
use 5.018;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run('spacewalk-service stop', 120);
    my $action = 'poweroff';
    type_string "systemctl $action\n";
    sleep 30;
    send_key('esc');
    send_key('ctrl-alt-f10');
    send_key('esc');
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        assert_shutdown_and_restore_system($action);
    }
    else {
        assert_shutdown(480) if $action eq 'poweroff';
        reset_consoles;
    }
}

1;
