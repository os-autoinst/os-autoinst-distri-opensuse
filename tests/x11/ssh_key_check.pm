# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ssh key dialog test
#    https://progress.opensuse.org/issues/11454 https://github.com/yast/skelcd-control-SLES/blob/d2f9a79c0681806bf02eb38c4b7c287b9d9434eb/control/control.SLES.xml#L53-L71
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('xterm -geometry 150x45+5+5', target_match => 'xterm');
    become_root;
    script_run 'cd /etc/ssh';
    script_run 'touch ssh_host_key ssh_host_key.pub';    # this file must exist to trigger ssh key import
    script_run 'echo "SSHHOSTKEYFILE" | tee /etc/ssh/*key*';
    script_run 'echo "SSHHOSTPUBKEYFILE" | tee /etc/ssh/*key.pub*';
    script_run "cat /etc/ssh/*key* | tee /dev/$serialdev";
    script_run "md5sum * | tee /etc/ssh/ssh_config /dev/$serialdev";
    type_string "killall xterm\n";
}

1;
