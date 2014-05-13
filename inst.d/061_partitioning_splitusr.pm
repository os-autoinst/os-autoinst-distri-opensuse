use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $vars{SPLITUSR};
}

sub run() {
    my $self = shift;
    send_key "alt-e", 1;    # Edit
                         # select vda2
    send_key "right";
    send_key "down";      # only works with multiple HDDs
    send_key "right";
    send_key "down";
    send_key "tab";
    send_key "tab";
    send_key "down";

    #send_key "right"; send_key "down"; send_key "down";
    send_key "alt-i", 1;    # Resize
    send_key "alt-u";     # Custom
    type_string "1.5G";
    sleep 2;
    send_key "ret", 1;

    # add /usr
    send_key $cmd{addpart};
    wait_idle 4;
    send_key $cmd{"next"};
    wait_idle 3;
    for ( 1 .. 10 ) {
        send_key "backspace";
    }
    type_string "4.5G";
    send_key $cmd{"next"}, 1;
    send_key "alt-m";           # Mount Point
    type_string "/usr\b";    # Backspace to break bad completion to /usr/local
    assert_screen  "partition-splitusr-submitted-usr", 3 ;
    send_key $cmd{"finish"};
    assert_screen  "partition-splitusr-finished", 3 ;
    send_key $cmd{"accept"}, 1;
    send_key "alt-y";           # Quit the warning window
}

1;
# vim: set sw=4 et:
