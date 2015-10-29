use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    my $arch;
    if (check_var('ARCH', 'i586')) {
        $arch = "i386";
    }
    else {
        $arch = "x86_64";
    }
    my $chrome_url = "https://dl.google.com/linux/direct/google-chrome-stable_current_$arch.rpm";

    mouse_hide;

    x11_start_program("xterm");
    assert_screen('xterm-started');

    # install the google key first
    become_root;
    assert_script_run "rpm --import https://dl.google.com/linux/linux_signing_key.pub";

    # validate it's properly installed
    script_run "rpm -qi gpg-pubkey-7fac5991-*";
    assert_screen 'google-key-installed';

    assert_script_run "zypper -n install $chrome_url";
    save_screenshot;
    # closing xterm
    send_key "alt-f4";

    x11_start_program("google-chrome");

    assert_and_click 'chrome-default-browser-query';

    assert_screen 'google-chrome-main-window', 50;
    send_key "ctrl-l";
    sleep 1;
    type_string "about:\n";
    assert_screen 'google-chrome-about', 15;

    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
