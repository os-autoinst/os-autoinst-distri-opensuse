use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my %desktopkeys = (kde => "k", gnome => "g", xfce => "x", lxde => "l", minimalx => "m", textmode => "i");
    assert_screen "desktop-selection", 30;
    my $d   = get_var("DESKTOP");
    my $key = "alt-$desktopkeys{$d}";
    if ($d eq "kde") {

        # KDE is default
    }
    elsif ($d eq "gnome") {
        send_key $key;
        assert_screen "gnome-selected", 3;
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
