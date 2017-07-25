# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436067: Firefox: SSL Certificate
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;


    send_key "esc";
    send_key "alt-d";
    type_string "https://build.suse.de\n";

    check_screen('firefox-ssl-untrusted', 60);

    send_key "tab";
    send_key "ret";
    send_key "tab";
    send_key "ret";

    assert_screen('firefox-ssl-addexception', 60);
    send_key "alt-c";

    assert_screen('firefox-ssl-loadpage', 60);

    send_key "alt-e";
    send_key "n";

    assert_and_click('firefox-ssl-preference_advanced');
    assert_and_click('firefox-ssl-advanced_certificate');

    send_key "alt-shift-c";

    sleep 1;
    type_string "hong";
    send_key "down";

    sleep 1;
    send_key "alt-e";

    sleep 1;
    send_key "spc";
    assert_screen('firefox-ssl-edit_ca_trust', 30);
    send_key "ret";


    sleep 1;
    assert_and_click('firefox-ssl-certificate_servers');

    send_key "pgdn";
    send_key "pgdn";

    sleep 1;
    assert_screen('firefox-ssl-servers_cert', 30);

    wait_screen_change { send_key "alt-f4" };
    send_key "ctrl-w";

    send_key "alt-d";
    type_string "https://www.hongkongpost.gov.hk\n";
    assert_screen('firefox-ssl-connection_untrusted', 90);

    # Exit
    $self->exit_firefox;
}
1;
# vim: set sw=4 et:


