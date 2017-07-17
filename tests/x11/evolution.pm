# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
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
use utils;

sub run {
    x11_start_program("evolution");
    my @tags = qw(test-evolution-1 evolution-default-client-ask);
    push(@tags, 'evolution-preview-release') if is_gnome_next;
    do {
        assert_screen \@tags;
        send_key 'alt-o'                                  if match_has_tag('evolution-preview-release');
        assert_and_click 'evolution-default-client-agree' if match_has_tag('evolution-default-client-ask');
    } until (match_has_tag('test-evolution-1'));
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
