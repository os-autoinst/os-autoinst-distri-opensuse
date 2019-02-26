# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot from XFCE environment
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    send_key "alt-f4";    # open logout dialog
    assert_screen 'logoutdialog', 15;
    send_key "tab";       # reboot
    save_screenshot;
    send_key "ret";       # confirm
    $self->wait_boot;
}

sub test_flags {
    return {milestone => 1};
}

1;

