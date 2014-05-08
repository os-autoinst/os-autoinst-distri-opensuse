use base "installstep";
use bmwqemu;

sub is_applicable() {
    return $ENV{DUALBOOT};
}

sub run() {
    my $self = shift;

    # Eject the DVD
    send_key "ctrl-alt-f3";
    sleep 4;
    send_key "ctrl-alt-delete";

    # Bug in 13.1?
    qemusend "system_reset";

    # qemusend "eject ide1-cd0";

    wait_encrypt_prompt;
    waitforneedle( "grub-reboot-windows", 25 );

    send_key "down";
    send_key "down";
    send_key "ret";
    waitforneedle( "windows8", 80 );
}

1;
# vim: set sw=4 et:
