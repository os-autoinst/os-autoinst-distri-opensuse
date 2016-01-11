# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;
    script_run("zypper lr -d; echo zypper-lr-\$? > /dev/$serialdev");
    wait_serial("zypper-lr-0") || die "zypper lr failed";
    save_screenshot;

    type_string "exit\n";
}

1;
# vim: set sw=4 et:
