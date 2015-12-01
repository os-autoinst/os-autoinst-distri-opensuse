use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;
    ensure_valid_root_prompt();

    my $hostname = get_var("HOSTNAME", 'susetest');
    script_run "hostnamectl set-hostname $hostname && echo 'hostname_sets' > /dev/$serialdev";
    die "hostnamectl set failed" unless wait_serial "hostname_sets", 20;

    script_run "hostnamectl status";
    assert_screen("hostnamectl_status_$hostname");

    script_run "hostname";
    assert_screen("hostname-$hostname");

    script_run "exit";
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
