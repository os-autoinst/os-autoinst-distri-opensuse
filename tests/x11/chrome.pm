use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    my $arch;
    if (check_var('ARCH', 'i586')) {
      $arch="i386";
    } else {
      $arch="x86_64";
    }
    my $chrome_url = "https://dl.google.com/linux/direct/google-chrome-stable_current_$arch.rpm";

    mouse_hide;

    x11_start_program("xterm");
    assert_screen('xterm-started');

    script_sudo "zypper -n install $chrome_url; echo \"zypper-chrome-\$?- > /dev/$serialdev\"";
    wait_serial "zypper-chrome-0-";
    save_screenshot;
    send_key "alt-f4";

    x11_start_program("google-chrome");

    assert_screen 'google-chrome-main-window', 10;
    send_key "esc"; # get rid of popup
    sleep 1;
    send_key "ctrl-l";
    sleep 1;
    type_string "about:\n";
    assert_screen 'google-chrome-about', 15;

    send_key "ctrl-l";
    sleep 1;
    type_string "https://html5test.com/index.html\n";
    assert_screen 'google-chrome-html5test', 30;

    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
