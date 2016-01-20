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
use base "y2logsstep";
use testapi;

sub run() {
    my %desktopkeys = (kde => "k", gnome => "g", xfce => "x", lxde => "l", minimalx => "m", textmode => "i");
    assert_screen "desktop-selection";
    my $d   = get_var("DESKTOP");
    my $key = "alt-$desktopkeys{$d}";
    if ($d eq "kde") {

        # KDE is default
    }
    elsif ($d eq "gnome") {
        send_key $key;
        assert_screen "gnome-selected";
    }
    else {    # lower selection level
        send_key "alt-o";    #TODO translate
                             # The keyboard shortcuts changed with libyu-qt >= 2.46.16; let's see which ones we need
        my $ret = check_screen([qw/other-desktop other-desktop-remapped/], 3);
        if ($ret->{needle}->has_tag("other-desktop-remapped")) {
            my %desktopkeys = (xfce => "f", lxde => "x", minimalx => "m", textmode => "i");
            $key = "alt-$desktopkeys{$d}";
        }
        send_key $key;
        sleep 3;             # needles for else cases missing
    }
    send_key $cmd{"next"};

    # ending at partition layout screen
}

1;
# vim: set sw=4 et:
