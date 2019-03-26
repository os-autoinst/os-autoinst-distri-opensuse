# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Plasma kontact startup test
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils 'is_pre_15';

sub run {
    select_console 'user-console';
    # start akonadi server to avoid the self-test running when we launch kontact
    assert_script_run 'DISPLAY=:0 akonadictl start';

    # Workaround: sometimes the account assistant behind of mainwindow or tips window
    # To disable it run at first time start
    if (is_pre_15) {
        assert_script_run 'echo -e "[General]\nfirst-start=false" >> ~/.kde4/share/config/kmail2rc';
    }
    assert_script_run 'echo -e "[General]\nfirst-start=false" >> ~/.config/kmail2rc';
    select_console 'x11';
    my @tags = qw(test-kontact-1 kontact-import-data-dialog kontact-window);
    x11_start_program('kontact', target_match => \@tags);
    do {
        assert_screen \@tags;
        # kontact might ask to import data from another mailer, don't
        wait_screen_change { send_key 'alt-n' } if match_has_tag('kontact-import-data-dialog');
        # KF5-based account assistant ignores alt-f4
        wait_screen_change { send_key 'alt-c' } if match_has_tag('test-kontact-1');
    } until (match_has_tag('kontact-window'));
    assert_screen [qw(kontact-error close_kontact)];
    if (match_has_tag('kontact-error')) {
        return record_soft_failure('Encountered fatal error, boo#1105207');
    }
    else {
        assert_and_click 'close_kontact';
    }
    # Since gcc7 used for packages within openSUSE Factory kontact seems to
    # persist consistently as a process in the background causing kontact to
    # be "restored" after a re-login/reboot causing later tests to fail. To
    # prevent this we explicitly stop the kontact background process.
    x11_start_program('killall kontact', valid => 0);
}

1;
