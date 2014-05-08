use base "basetest";
use bmwqemu;

# Cleaning for testing pidgin

my @packages = qw/pidgin pidgin-otr/;

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub install_pkg() {
    my $self = shift;

    x11_start_program("xterm");
    type_string "rpm -qa @packages\n";
    waitidle;
    sleep 5;

    # Remove packages
    type_string "xdg-su -c 'rpm -e @packages'\n";
    waitidle;
    sleep 3;
    if ($password) {
        sendpassword;
        send_key "ret", 1;
    }
    waitidle;
    sleep 10;
    type_string "clear\n";
    sleep 2;
    type_string "rpm -qa @packages\n";
    waitidle;
    sleep 2;
    waitforneedle( "pidgin-pkg-removed", 10 );    #make sure pkgs removed.
    waitidle;
    sleep 2;
    send_key "alt-f4";
    sleep 2;                                      #close xterm
}

sub run() {
    my $self = shift;
    install_pkg;
}

1;
# vim: set sw=4 et:
