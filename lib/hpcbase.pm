package hpcbase;
use base "opensusebasetest";
use strict;
use testapi;

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
