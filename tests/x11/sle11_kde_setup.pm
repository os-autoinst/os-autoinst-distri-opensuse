# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;

    # SLE11 KDE has enabled "find applications" feature which if doesn't recognize entered command
    # executes some of last known executed application/command.
    # e.g. xterm https://openqa.suse.de/tests/49520/modules/yast2_users/steps/2
    send_key "alt-f2";    # run command window
    assert_screen 'desktop-runner';
    send_key_until_needlematch 'run-command-settings', 'tab', 5;
    sleep 2;
    send_key ' ';         # enter KDE run command (KRunner) settings
    send_key_until_needlematch 'run-command-filter', 'tab', 5;
    type_string('app');    # filter applications feature
    send_key_until_needlematch 'run-command-app-checkbox', 'tab', 5;
    send_key ' ';          # uncheck find applications feature
    send_key "alt-o";      # OK
    sleep 2;
    send_key "esc";        # close run command window
}

sub test_flags() {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
