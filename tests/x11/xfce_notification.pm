# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libnotify-tools
# Summary: Test xfce4-notifyd with a notification
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use testapi;

sub run {
    x11_start_program('notify-send --expire-time=30 Test', target_match => 'test-xfce_notification-1');
}

1;
