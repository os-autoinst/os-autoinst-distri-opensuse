use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{LIVECD} && $vars{UPGRADE};
}

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1; # waiting for mounting partitions
    assert_screen "remove-repository", 10;
    send_key $cmd{"next"}, 1; # waiting for downloading online repos
    if (check_screen('network-not-configured', 5)) {
        send_key 'alt-n';
        if (check_screen('ERROR-cannot-download-repositories')) {
            send_key 'alt-o';
            ++$self->{dents};
        }
    }
    assert_screen "list-of-online-repositories", 10;
    send_key $cmd{"next"}, 1; # waiting for writing list of online repos
    assert_screen "update-license-argt", 10;
    send_key $cmd{"next"}, 1; # waiting for analyzing system
    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
