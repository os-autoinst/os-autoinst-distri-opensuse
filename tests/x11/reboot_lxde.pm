# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot from LXDE environment
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    #send_key "ctrl-alt-delete"; # does open task manager instead of reboot
    x11_start_program('lxsession-logout', target_match => 'logoutdialog');
    send_key "tab";    # reboot
    save_screenshot;
    send_key "ret";    # confirm
    $self->wait_boot;
}

sub test_flags {
    return {milestone => 1};
}

1;

