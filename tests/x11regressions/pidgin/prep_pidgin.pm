use base "basetest";
use testapi;

# Preparation for testing pidgin

my @packages = qw/pidgin pidgin-otr/;

sub install_pkg() {
    my $self = shift;

    x11_start_program("xterm");
    type_string "rpm -qa @packages\n";
    wait_idle;
    sleep 5;

    # Remove screensaver
    type_string "xdg-su -c 'rpm -e gnome-screensaver'\n";
    wait_idle;
    sleep 3;
    if ($password) {
        sendpassword;
        send_key "ret", 1;
    }

    # Install packages
    type_string "xdg-su -c 'zypper -n in @packages'\n";
    wait_idle;
    sleep 3;
    if ($password) {
        sendpassword;
        send_key "ret", 1;
    }
    sleep 60;
    type_string "\n";    # prevent the screensaver...
    assert_screen "pidgin-pkg", 500;    #make sure pkgs installed
    wait_idle;
    sleep 2;
    type_string "rpm -qa @packages\n";
    wait_idle;
    sleep 2;
    assert_screen "pidgin-pkg-installed", 10;    #make sure pkgs installed
    wait_idle;
    sleep 2;

    #send_key "alt-f4";sleep 2; #close xterm

    # Enable the showoffline
    type_string "pidgin\n";    # enable the pidgin
    wait_idle;
    sleep 2;

    send_key "alt-c";
    wait_idle;
    sleep 5;
    send_key "alt-b";
    sleep 2;
    send_key "o";
    wait_idle;
    sleep 2;
    assert_screen "pidgin-showoff", 10;    #enable show offline
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
