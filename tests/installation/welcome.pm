# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (get_var("BETA")) {
        assert_screen "inst-betawarning", 500;
        send_key "ret";
        assert_screen "inst-welcome", 10;
    }
    else {
        assert_screen "inst-welcome", 500;
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
