# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: verify that SSH host key dit not got imported.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('xterm -geometry 150x45+5+5', target_match => 'xterm');
    become_root;
    script_run 'cd /etc/ssh';
    enter_cmd "cat /etc/ssh/ssh_host_key | tee /dev/$serialdev";
    wait_serial "SSHHOSTKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key content does match";
    enter_cmd "cat /etc/ssh/ssh_host_key.pub | tee /dev/$serialdev";
    wait_serial "SSHHOSTPUBKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key.pub content does match";
    script_run "md5sum * | tee /dev/$serialdev";
    enter_cmd "killall xterm";
}

sub test_flags {
    return {fatal => 1};
}

1;
