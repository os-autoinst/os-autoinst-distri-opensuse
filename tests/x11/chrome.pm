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

    # fetch the google key first
    assert_script_run "wget https://dl.google.com/linux/linux_signing_key.pub";
    script_sudo "sudo rpm --import linux_signing_key.pub";

    # validate it's properly installed
    script_run "rpm -qi gpg-pubkey-7fac5991-*";
    assert_screen 'google-key-installed';

    script_sudo "zypper -n install $chrome_url; echo zypper-chrome-\$?- > /dev/$serialdev";
    wait_serial "zypper-chrome-0-" || die "didn't install chrome";
    save_screenshot;
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
