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

    select_console 'root-console';

    # Install apache2
    script_run "zypper -n -q in apache2";
    assert_screen 'test-http_srv-1';

    # After installation, apache2 is disabled
    script_run "systemctl status apache2.service | tee /dev/$serialdev -", 0;
    wait_serial(".*disable.*") || die "apache should be disabled by default";

    # Now must be enabled
    script_run "systemctl start apache2.service";
    script_run "systemctl status apache2.service | tee /dev/$serialdev -", 0;
    # do *not* expect syntax errors
    wait_serial(".*Syntax error.*", 12, 1) || die "have error while starting apache2";
    save_screenshot;
}

1;
# vim: set sw=4 et:
