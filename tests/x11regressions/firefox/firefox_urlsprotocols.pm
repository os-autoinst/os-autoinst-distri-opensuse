# Case#1436118 Firefox: URLs with various protocols

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    sleep 1;
    send_key "ctrl-d";
    assert_screen('firefox-launch',20);

    # sites_url
    my %sites_url = (
        http => "http://jekyllrb.com/",
        https => "https://www.google.com/",
        ftp => "ftp://mirror.bej.suse.com/",
        smb => "smb://mirror.bej.suse.com/dist",
        local => "file:///usr/share/w3m/w3mhelp.html"
    );

    for my $proto (keys %sites_url) {
        send_key "esc";
        send_key "alt-d";
        sleep 1;
        type_string $sites_url{$proto}. "\n";
        assert_screen('firefox-urls_protocols-' . $proto, 30);
    }

    # Exit
    send_key "alt-f4";
    
    # Umount smb directory from desktop
    assert_and_click('firefox-urls_protocols-umnt_smb'); sleep 1;
    send_key "shift-f10"; sleep 1;
    send_key "u";

    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
