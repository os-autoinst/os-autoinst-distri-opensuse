use base "opensusebasetest";    # use opensusebasetest to avoid fatal flag
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_and_click 'release-notes-button';    # open release notes window
    assert_and_click 'release-notes-tab-sle';   # click on first SLES tab
    if (get_var("ADDONS")) {
        foreach $a (split(/,/, get_var('ADDONS'))) {
            send_key 'alt-s';   # jump to first tab
            $self->key_round("release-notes-tab-$a", 'right');
        }
    }
    send_key 'alt-o';   # exit release notes window
}

1;
