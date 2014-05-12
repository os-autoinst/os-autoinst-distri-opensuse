use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD} && $ENV{UPGRADE};
}

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen  "select-for-update", 100 ;
    send_key $cmd{"next"}, 1;
    assert_screen  "remove-repository", 10 ;
    send_key $cmd{"next"}, 1;
    if (check_screen('network-not-configured', 5)) {
       send_key 'alt-n';
       if (check_screen('ERROR-cannot-download-repositories')) {
         send_key 'alt-o';
         ++$self->{dents};
       }
    }
    if (check_screen('ERROR-lilo-convert-failed', 10)) {
       send_key 'alt-n';
       ++$self->{dents};
    }
    assert_screen  "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
