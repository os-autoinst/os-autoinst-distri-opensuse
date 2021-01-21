# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Web browser UI test for rancher container
# Maintainer: George Gkioulis <ggkioulis@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'ensure_unlocked_desktop';

sub run {
    my ($self) = @_;

    select_console('x11', await_console => 0);
    ensure_unlocked_desktop();

    # start firefox
    $self->start_firefox_with_profile();
    $self->firefox_open_url('https://localhost');
    assert_and_click('security_risk_advanced');
    send_key('pgdn');
    assert_and_click('security_risk_continue');
    assert_screen('welcome_to_rancher');

    $self->exit_firefox();
}

1;

