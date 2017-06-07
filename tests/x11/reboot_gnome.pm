# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot GNOME with or without authentication and ensure proper boot
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    power_action('reboot');
    workaround_type_encrypted_passphrase;
    $self->wait_boot;
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

sub test_flags() {
    return {milestone => 1};
}

1;

# vim: set sw=4 et:
