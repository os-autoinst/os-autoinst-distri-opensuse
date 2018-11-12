package hpcbase;
use base "opensusebasetest";
use strict;
use testapi;
use utils 'systemctl';

sub enable_and_start {
    my ($self, $arg) = @_;
    systemctl "enable $arg";
    systemctl "start $arg";
}

sub upload_service_log {
    my ($self, $service_name) = @_;
    script_run("journalctl -u $service_name > /tmp/$service_name");
    script_run("cat /tmp/$service_name");
    upload_logs("/tmp/$service_name", failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    script_run("journalctl -o short-precise > /tmp/journal.log");
    script_run('cat /tmp/journal.log');
    upload_logs('/tmp/journal.log', failok => 1);
    upload_service_log('wickedd-dhcp4.service');
}

sub switch_user {
    my ($self, $username) = @_;
    type_string("su - $username\n");
    assert_screen 'user-nobody';
}

1;
