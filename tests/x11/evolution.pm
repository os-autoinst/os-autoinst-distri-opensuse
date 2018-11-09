# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startup of evolution with check of first-startup dialogs
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;
use version_utils "is_gnome_next";

sub run {
    my @tags = qw(test-evolution-1 evolution-default-client-ask);
    push(@tags, 'evolution-preview-release') if is_gnome_next;
    x11_start_program('evolution', target_match => \@tags);
    my $times = scalar(@tags) - 1;

    unless (match_has_tag('test-evolution-1')) {
        for (0 .. $times) {
            if (match_has_tag('evolution-default-client-ask')) {
                assert_and_click 'evolution-default-client-agree';
            }
            elsif (match_has_tag('evolution-preview-release')) {
                send_key 'alt-o';
            }
            wait_still_screen;    # avoid race condition caused by asserting multitags
            assert_screen \@tags;
        }
        assert_screen 'test-evolution-1';
    }

    #close assistant
    send_key 'alt-f4';

    assert_screen(['generic-desktop', 'evolution-main-window'], timeout => 30);
    if (match_has_tag 'evolution-main-window') {
        assert_and_click "close_evolution";
    }
}

1;
