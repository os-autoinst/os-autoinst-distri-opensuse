# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare system for reboot after zdup upgrade
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    clear_console;

    # Print zypper repos
    script_run("zypper lr -d");
    # Remove the --force when this is fixed:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
    script_run("systemctl set-default --force graphical.target");
    sleep 5;

    save_screenshot;

    # TODO: why not just script_run 'root' ?
    # switch to tty3 (in case we are in X)
    send_key "ctrl-alt-f3";
    assert_screen "text-login";
    # Reboot after dup
    send_key "ctrl-alt-delete";
}

1;
# vim: set sw=4 et:
