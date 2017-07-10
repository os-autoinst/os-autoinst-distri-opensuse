package hpcbase;
use base "opensusebasetest";
use strict;
use testapi;
use mm_network;

sub setup_static_mm_network {
    my ($self) = @_;
    my $host_ip = get_required_var('HPC_HOST_IP');
    configure_default_gateway;
    configure_static_ip($host_ip);
    configure_static_dns(get_host_resolv_conf());

    # check if gateway is reachable
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager > /dev/$serialdev";
}

sub exec_and_insert_password {
    my ($self, $cmd) = @_;
    type_string $cmd;
    send_key "ret";
    assert_screen('password-prompt', 60);
    type_password;
    send_key "ret";
}

sub enable_and_start {
    my ($self, $arg) = @_;
    assert_script_run("systemctl enable $arg");
    assert_script_run("systemctl start $arg");
}



1;
# vim: set sw=4 et:
