# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
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
    # Workaround: Try to fix a race condition between akonadi and kmail
    # to create the Local mail resources (boo#1105207)
    x11_start_program('echo -e "[SpecialCollections]\nDefaultResourceId=akonadi_maildir_resource_0" >> ~/.config/specialmailcollectionsrc', valid => 0);

    # start akonadi server to avoid the self-test running when we launch kontact
    x11_start_program('akonadictl start', valid => 0);

    # Workaround: sometimes the account assistant behind of mainwindow or tips window
    # To disable it run at first time start
    if (is_pre_15) {
        x11_start_program('echo -e "[General]\nfirst-start=false" >> ~/.kde4/share/config/kmail2rc', valid => 0);
    }
    x11_start_program('echo -e "[General]\nfirst-start=false" >> ~/.config/kmail2rc', valid => 0);
    my $match_timeout = 90;
    $match_timeout = $match_timeout * 3 if get_var('LIVETEST');
    my @tags = qw(test-kontact-1 kontact-import-data-dialog kontact-window);
    x11_start_program('kontact', target_match => \@tags, match_timeout => $match_timeout);
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
    # matching 'generic-desktop' needs more time for LIVETEST
    select_console('root-console');
    script_run 'killall -w kontact';
    select_console('x11');
}

1;
