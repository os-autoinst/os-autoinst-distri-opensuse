use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    type_string "PS1=\"# \"\n";
    #mutex_unlock "hacluster_support_server_ready";

    my $hostname = get_var("HOSTNAME", 'susetest');
    script_run "hostnamectl set-hostname $hostname && echo 'hostname_sets' > /dev/$serialdev";
    die "hostnamectl set failed" unless wait_serial "hostname_sets", 20;
    script_run "systemctl restart wicked.service && echo 'wicked_restarted' > /dev/$serialdev"; #update dynamic DNS
    die "wicked restart failed" unless wait_serial "wicked_restarted", 60;
    script_run "SuSEfirewall2 off;", 30;
    save_screenshot;
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
