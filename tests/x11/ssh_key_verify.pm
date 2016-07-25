# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    x11_start_program("xterm -geometry 150x45+5+5");
    become_root;
    script_run 'cd /etc/ssh';
    if (get_var('SSH_KEY_IMPORT')) {
        type_string "cat /etc/ssh/ssh_host_key | tee /dev/$serialdev\n";
        wait_serial "SSHHOSTKEYFILE", 5 || die "/etc/ssh/ssh_host_key content doesn't match";
        type_string "cat /etc/ssh/ssh_host_key.pub | tee /dev/$serialdev\n";
        wait_serial "SSHHOSTPUBKEYFILE", 5 || die "/etc/ssh/ssh_host_key.pub content doesn't match";
    }
    elsif (get_var('SSH_KEY_DO_NOT_IMPORT')) {
        type_string "cat /etc/ssh/ssh_host_key | tee /dev/$serialdev\n";
        wait_serial "SSHHOSTKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key content does match";
        type_string "cat /etc/ssh/ssh_host_key.pub | tee /dev/$serialdev\n";
        wait_serial "SSHHOSTPUBKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key.pub content does match";
    }
    # md5sum of files in /etc/ssh can be compared manually from serial0.txt or needle
    script_run "md5sum * | tee /dev/$serialdev";
    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
