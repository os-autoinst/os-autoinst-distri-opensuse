# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for installer welcome screen. Covers loading linuxrc
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils 'ensure_fullscreen';

sub run() {
    my @welcome_tags = [qw(inst-welcome inst-welcome-confirm-self-update-server)];
    ensure_fullscreen;
    my $bootup_timeout = 500;
    if (get_var("BETA")) {
        assert_screen "inst-betawarning", $bootup_timeout;
        send_key "ret";
        assert_screen @welcome_tags, 10;
    }
    else {
        assert_screen @welcome_tags, $bootup_timeout;
    }
    if (match_has_tag('inst-welcome-confirm-self-update-server')) {
        wait_screen_change { send_key $cmd{ok} };
        assert_screen 'inst-welcome';
    }

    wait_idle;
    mouse_hide;

    # license+lang
    if (get_var("HASLICENSE")) {
        send_key $cmd{next};
        assert_screen "license-not-accepted";
        send_key $cmd{ok};
        send_key $cmd{accept};    # accept license
    }
    assert_screen "languagepicked";
    send_key $cmd{next};
    if (!check_var('INSTLANG', 'en_US') && check_screen "langincomplete", 1) {
        send_key "alt-f";
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # system might be stuck on bootup showing only splash screen so we press
    # esc to show console logs
    send_key 'esc';
    $self->SUPER::post_fail_hook;
    # in case we could not even reach the installer welcome screen and logs
    # could not be collected on the serial output:
    upload_logs '/var/log/linuxrc.log';
}

1;
# vim: set sw=4 et:
