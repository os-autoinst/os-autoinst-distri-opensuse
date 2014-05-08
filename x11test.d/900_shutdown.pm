use base "basetest";
use bmwqemu;

sub is_applicable() {
    return 1;
}

sub run() {
    my $self = shift;

    if ( $ENV{DESKTOP} eq "kde" ) {
        send_key "ctrl-alt-delete";    # shutdown
        waitforneedle 'logoutdialog', 15;

        type_string "\t";
        waitforneedle( "kde-turn-off-selected", 2 );
        type_string "\n";
        waitinststage( "splashscreen", 40 );
    }

    if ( $ENV{DESKTOP} eq "gnome" ) {
        send_key "ctrl-alt-delete";    # shutdown
        waitforneedle 'logoutdialog', 15;

        send_key "ret";                # confirm shutdown
                                      #if(!$ENV{GNOME2}) {
                                      #    sleep 3;
                                      #    send_key "ctrl-alt-f1";
                                      #    sleep 3;
                                      #    qemusend "system_powerdown"; # shutdown
                                      #}
        waitinststage( "splashscreen", 40 );
    }

    if ( $ENV{DESKTOP} eq "xfce" ) {
        for ( 1 .. 5 ) {
            send_key "alt-f4";         # opens log out popup after all windows closed
        }
        waitidle;
        type_string "\t\t";          # select shutdown
        sleep 1;

        #$self->check_screen;
        type_string "\n";
        waitinststage("splashscreen");
    }

    if ( $ENV{DESKTOP} =~ m/lxde|minimalx|textmode/ ) {
        qemusend "system_powerdown";    # shutdown
        waitidle;

        #$self->check_screen;
        #send_key "ctrl-alt-f1"; # work-around for LXDE bug 619769 ; not needed in Factory anymore
        waitinststage("splashscreen");
    }
}

1;
# vim: set sw=4 et:
