use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;

    script_run "hostnamectl set-hostname susetest && echo 'hostname_sets' > /dev/$serialdev";
    die "hostnamectl set failed" unless wait_serial "hostname_sets", 20;

    script_run "hostnamectl status";
    assert_screen("hostnamectl_status");

    script_run "hostname";
    assert_screen("hostname");

    script_run "exit";
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
