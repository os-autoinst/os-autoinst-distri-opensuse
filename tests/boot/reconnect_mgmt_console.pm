# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reconnect management-consoles after reboot
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils qw(reconnect_mgmt_console handle_emergency);
use testapi;

sub run {
    reconnect_mgmt_console;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;

    handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
    $self->SUPER::post_fail_hook;
}

1;
