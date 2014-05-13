use base "basetest";
use bmwqemu;

sub is_applicable() {
    return 1;
}

sub run() {
    my $self = shift;

    if ( $ENV{DESKTOP} eq "kde" ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

        return; # we don't want qemu "to crash" 

        type_string "\t";
        assert_screen  "kde-turn-off-selected", 2 ;
        type_string "\n";
	waitforneedle( "splashscreen", 40 );
    }

    if ( $ENV{DESKTOP} eq "gnome" ) {
        send_key "ctrl-alt-delete";    # shutdown
        assert_screen 'logoutdialog', 15;

        return; # we don't want qemu "to crash" 

        send_key "ret";                # confirm shutdown
                                      #if(!$ENV{GNOME2}) {
                                      #    sleep 3;
                                      #    send_key "ctrl-alt-f1";
                                      #    sleep 3;
                                      #    qemusend "system_powerdown"; # shutdown
                                      #}
        waitforneedle( "splashscreen", 40 );
    }

    if ( $ENV{DESKTOP} eq "xfce" ) {
        for ( 1 .. 5 ) {
            send_key "alt-f4";         # opens log out popup after all windows closed
        }
        wait_idle;
        type_string "\t\t";          # select shutdown
        sleep 1;

        return; # we don't want qemu "to crash" 

        # assert_screen 'test-shutdown-1', 3;
        type_string "\n";
        waitforneedle("splashscreen");
    }

    return; # we don't want qemu "to crash" - we need to make os-autoinst catch this properly first

    if ( $ENV{DESKTOP} =~ m/lxde|minimalx|textmode/ ) {
        qemusend "system_powerdown";    # shutdown
        wait_idle;

        # assert_screen 'test-shutdown-2', 3;
        # send_key "ctrl-alt-f1"; # work-around for LXDE bug 619769 ; not needed in Factory anymore
        assert_screen "splashscreen";
    }
}

1;
# vim: set sw=4 et:
