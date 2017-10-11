# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot of the branchserver salt minion machine
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base 'opensusebasetest';
use 5.018;
use testapi;


sub run {   
    my ($self) = @_;
    if (check_var('SUMA_SALT_MINION', 'branch')) {
        type_string("shutdown -r now\n");
        reset_consoles;
        $self->wait_boot(bootloader_time => 80, ready_time => 1500);
        select_console 'root-console';
        
        script_run('systemctl status salt-minion');
        assert_script_run('systemctl is-active salt-minion');

    }
}


sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
