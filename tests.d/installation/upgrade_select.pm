use strict;
use base "y2logsstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return y2logsstep_is_applicable && !$vars{LIVECD} && $vars{UPGRADE};
}

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;
    assert_screen "remove-repository", 10;
    send_key $cmd{"next"}, 1;
    if (check_screen('network-not-configured', 5)) {
        send_key 'alt-n';
        if (check_screen('ERROR-cannot-download-repositories')) {
            send_key 'alt-o';
            ++$self->{dents};
        }
    }
    if (check_screen('list-of-online-repositories', 10)) {
        send_key 'alt-n';
        ++$self->{dents};
    }
    # Bug 881107 - there is 2nd license agreement screen in openSUSE upgrade
    # http://bugzilla.opensuse.org/show_bug.cgi?id=881107
    # (remove after the bug is closed)
    if (check_screen('upgrade-li-cense-agreement', 10)) {
        send_key 'alt-n';
        ++$self->{dents};
    }
    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
