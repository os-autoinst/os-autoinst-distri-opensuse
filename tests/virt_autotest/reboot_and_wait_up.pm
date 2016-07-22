# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use login_console;

sub reboot_and_wait_up() {
    my $self           = shift;
    my $reboot_timeout = shift;

    select_console('root-console');
    type_string("/sbin/reboot\n");
    reset_consoles;
    sleep 2;
    &login_console::login_to_console($reboot_timeout);

}

1;

