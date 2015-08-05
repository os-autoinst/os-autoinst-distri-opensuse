use base "x11test";
use strict;
use testapi;

#testcase 4158-1249067 move a file with nautilus

sub run() {

    my $self = shift;

    x11_start_program("nautilus");
    assert_screen 'nautilus-launched',3;
    x11_start_program("touch newfile");
    
    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    sleep 2;
    send_key "ctrl-x";
    send_key_until_needlematch 'nautilus-Downloads-matched', 'left', 5;
    send_key "ret";
    sleep 2;
    send_key "ctrl-v";      #paste to dir ~/Downloads
    assert_screen "nautilus-newfile-moved",5;
    sleep 2;
    send_key "alt-up";      #back to home dir from ~/Downloads
    assert_screen 'nautilus-no-newfile',5;      #assure newfile moved
    send_key "ctrl-w";      #close nautilus

    #remove the newfile, rm via cmd to avoid file moving to trash
    x11_start_program("rm Downloads/newfile");
}

1;
# vim: set sw=4 et:
