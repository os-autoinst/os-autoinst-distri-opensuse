use base "basetest";
use bmwqemu;

# Preparation for testing pidgin

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

    # Remove screensaver
    type_string "xdg-su -c 'rpm -e gnome-screensaver'\n";
    waitidle;
    sleep 3;
    if ($password) {
        sendpassword;
        send_key "ret", 1;
    }

    # Install packages
    type_string "xdg-su -c 'zypper -n in @packages'\n";
    waitidle;
    sleep 3;
    if ($password) {
        sendpassword;
        send_key "ret", 1;
    }
    sleep 60;
    type_string "\n";    # prevent the screensaver...
    waitforneedle( "pidgin-pkg", 500 );    #make sure pkgs installed
    waitidle;
    sleep 2;
    type_string "rpm -qa @packages\n";
    waitidle;
    sleep 2;
    waitforneedle( "pidgin-pkg-installed", 10 );    #make sure pkgs installed
    waitidle;
    sleep 2;

    #send_key "alt-f4";sleep 2; #close xterm

    # Enable the showoffline
    type_string "pidgin\n";    # enable the pidgin
    waitidle;
    sleep 2;

    send_key "alt-c";
    waitidle;
    sleep 5;
    send_key "alt-b";
    sleep 2;
    send_key "o";
    waitidle;
    sleep 2;
    waitforneedle( "pidgin-showoff", 10 );    #enable show offline
    send_key "o";

    send_key "ctrl-q";
    sleep 2;
    send_key "alt-f4";
    sleep 2;                                  #close xterm
}

sub run() {
    my $self = shift;
    install_pkg;
}

1;
# vim: set sw=4 et:
