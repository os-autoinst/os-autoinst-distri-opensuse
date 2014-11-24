use base "installbasetest";
use testapi;

sub run() {
    my $self = shift;
    send_key "ctrl-alt-f3";
    sleep 4;
    send_key "ctrl-alt-delete";

    wait_encrypt_prompt;
    assert_screen "reboot_after_install", 200;
}

1;
# vim: set sw=4 et:
