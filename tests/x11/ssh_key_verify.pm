# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: coreutils
# Summary: ssh key dialog test
#    https://progress.opensuse.org/issues/11454 https://github.com/yast/skelcd-control-SLES/blob/d2f9a79c0681806bf02eb38c4b7c287b9d9434eb/control/control.SLES.xml#L53-L71
# Maintainer: QE Core <qe-core@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('xterm -geometry 150x45+5+5', target_match => 'xterm');
    become_root;
    script_run 'cd /etc/ssh';
    if (get_var('SSH_KEY_IMPORT')) {
        enter_cmd "cat /etc/ssh/ssh_host_key | tee /dev/$serialdev";
        wait_serial "SSHHOSTKEYFILE", 5 || die "/etc/ssh/ssh_host_key content doesn't match";
        enter_cmd "cat /etc/ssh/ssh_host_key.pub | tee /dev/$serialdev";
        wait_serial "SSHHOSTPUBKEYFILE", 5 || die "/etc/ssh/ssh_host_key.pub content doesn't match";
    }
    elsif (get_var('SSH_KEY_DO_NOT_IMPORT')) {
        enter_cmd "cat /etc/ssh/ssh_host_key | tee /dev/$serialdev";
        wait_serial "SSHHOSTKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key content does match";
        enter_cmd "cat /etc/ssh/ssh_host_key.pub | tee /dev/$serialdev";
        wait_serial "SSHHOSTPUBKEYFILE", 5, 1 || die "/etc/ssh/ssh_host_key.pub content does match";
    }
    # md5sum of files in /etc/ssh can be compared manually from serial0.txt or needle
    script_run "md5sum * | tee /dev/$serialdev";
    enter_cmd "killall xterm";
}

sub test_flags {
    return {fatal => 1};
}

1;
