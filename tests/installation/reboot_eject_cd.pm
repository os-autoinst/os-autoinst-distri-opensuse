use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # Eject the DVD
    send_key "ctrl-alt-f3";
    sleep 4;
    send_key "ctrl-alt-delete";
		
    # Bug in 13.1?
    backend_send "system_reset";
		
    # backend_send "eject ide1-cd0";

    if (get_var("ENCRYPT")) {
        assert_screen("encrypted-disk-password-prompt");
        type_password();    # enter PW at boot
        send_key "ret";
    }
}

1;

# vim: set sw=4 et:
