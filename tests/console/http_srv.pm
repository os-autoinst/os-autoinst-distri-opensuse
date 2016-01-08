# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    # Install apache2
    script_sudo("zypper -n -q in apache2");
    wait_idle 10;
    assert_screen 'test-http_srv-1', 3;

    # After installation, apache2 is disabled
    script_sudo("systemctl status apache2.service | tee /dev/$serialdev -");
    wait_idle 5;
    wait_serial ".*disable.*", 2;

    # Now must be enabled
    script_sudo("systemctl start apache2.service");
    script_sudo("systemctl status apache2.service | tee /dev/$serialdev -");
    wait_idle 5;
    wait_serial(".*Syntax error.*", 2, 1) || die "have error while starting apache2";
    save_screenshot;
}

1;
# vim: set sw=4 et:
