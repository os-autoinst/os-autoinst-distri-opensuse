# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "console_yasttest";
use testapi;

sub run() {
    my $self = shift;

    become_root();

    type_string("rm -f /root/autoinst.xml ; zypper -n in autoyast2 ; yast2 clone_system ; echo FINISHED >/dev/$serialdev\n");
    my $n_error = 0;
    while ($n_error < 5 && !wait_serial("FINISHED", 200)) {
        # try to confirm error dialogs and continue
        $self->result('fail');
        save_screenshot;
        send_key "ret";
        $n_error++;
    }

    type_string("test -f /root/autoinst.xml && echo CLONED >/dev/$serialdev\n");
    die "autoinst.xml was not created" if !wait_serial("CLONED", 20);

    upload_asset "/root/autoinst.xml";

    type_string "exit\n";
}

1;
# vim: set sw=4 et:
