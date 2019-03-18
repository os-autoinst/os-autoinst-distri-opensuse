# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure system can reboot from plasma5 session
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    send_key "ctrl-alt-delete";    # reboot
    assert_and_click 'sddm_reboot_option_btn';
    $self->wait_boot(bootloader_time => 300);
    # Ensure the desktop runner is reactive again before going into other test
    # modules
    # https://progress.opensuse.org/issues/30805
    $self->check_desktop_runner;
}

sub test_flags {
    return {milestone => 1};
}

1;

