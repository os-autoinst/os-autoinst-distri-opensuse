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
use utils qw/ensure_fullscreen/;

sub run() {
    my $self = shift;

    my @welcome_tags = [qw(inst-welcome inst-welcome-confirm-self-update-server)];
    ensure_fullscreen;
    if (get_var("BETA")) {
        assert_screen "inst-betawarning", 500;
        send_key "ret";
        assert_screen @welcome_tags, 10;
    }
    else {
        assert_screen @welcome_tags, 500;
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

1;
# vim: set sw=4 et:
