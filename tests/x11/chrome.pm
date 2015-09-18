use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    if (check_var('ARCH', 'i586')) {
      my $ARCH="i386";
    } else {
      my $ARCH="x86_64";
    }
    my $CHROME_URL = "https://dl.google.com/linux/direct/google-chrome-stable_current_${ARCH}.rpm";

    mouse_hide;

    x11_start_program("xterm");
    assert_screen('xterm-started');

    script_sudo "zypper -n install $CHROME_URL; echo \"zypper-chrome-\$?- > /dev/$serialdev\"";
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
