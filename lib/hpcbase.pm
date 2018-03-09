package hpcbase;
use base "opensusebasetest";
use strict;
use testapi;
use utils 'systemctl';

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
    systemctl "enable $arg";
    systemctl "start $arg";
}

sub upload_service_log {
    my ($self, $service_name) = @_;
    testapi::script_run("journalctl -u $service_name > /tmp/$service_name");
    testapi::script_run("cat /tmp/$service_name");
    testapi::upload_logs("/tmp/$service_name");
}

sub post_fail_hook {
    my ($self) = @_;
    testapi::script_run("journalctl -o short-precise > /tmp/journal.log");
    testapi::script_run('cat /tmp/journal.log');
    testapi::upload_logs('/tmp/journal.log');
    hpcbase::upload_service_log('wickedd-dhcp4.service');
}

1;
