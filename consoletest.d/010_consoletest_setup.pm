use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;

    # init
    # log into text console
    send_key "ctrl-alt-f4";
    waitforneedle( "text-login", 10 );
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;
    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    #type_string 'PS1=\$\ '."\n"; # qemu-0.12.4 can not do backslash yet. http://permalink.gmane.org/gmane.comp.emulators.qemu/71856

    script_sudo("chown $username /dev/$serialdev");
    script_run("echo 010_consoletest_setup OK > /dev/$serialdev");

    # it is only a waste of time, if this does not work
    alarm 3 unless waitserial( "010_consoletest_setup OK", 10 );
    $self->take_screenshot;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
