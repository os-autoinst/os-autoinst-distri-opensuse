# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436111: Firefox: Preferences Change Saving
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {

    my ($self) = @_;
    my $changesaving_checktimestamp = "ll --time-style=full-iso .mozilla/firefox/*.default/prefs.js | cut -d' ' -f7";

    $self->start_firefox;

    assert_screen_change {
        send_key "alt-tab";    #Switch to xterm
    };
    type_string "$changesaving_checktimestamp > dfa\n";

    assert_screen_change {
        send_key "alt-tab";    #Switch to firefox
    };

    assert_screen_change {
        send_key "alt-e";
    };
    send_key "n";
    assert_screen('firefox-changesaving-preferences', 30);

    send_key "alt-shift-s";
    send_key "down";           #Show a blank page
    assert_screen('firefox-changesaving-showblankpage', 30);

    assert_screen_change {
        send_key "ctrl-w";
    };
    assert_screen_change {
        send_key "alt-tab";    #Switch to xterm
    };
    type_string "$changesaving_checktimestamp > dfb\n";
    send_key "ctrl-l";
    type_string "diff dfa dfb\n";

    assert_screen('firefox-changesaving-diffresult', 30);
    type_string "rm df*\n", 1;    #Clear

    assert_screen_change {
        send_key "alt-tab";       #Switch to xterm
    };

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
