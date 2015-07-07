use base "console_yasttest";
use testapi;

sub add_user() {
    send_key "alt-a";
    assert_screen "yast2_users-add_user";
    type_string "Test user";
    assert_screen "yast2_users-username";
    send_key "alt-p";
    type_password "nots3cr3t.";
    send_key "tab";
    type_password "nots3cr3t.";
    send_key "alt-o";
    assert_screen "yast2_users-disable_autologin";
    send_key "alt-n";
    assert_screen "yast2_users-testuser";
}

sub edit_user() {
    send_key "alt-i";
    assert_screen "yast2_users-edit_testuser";
    send_key "alt-f";
    sleep 1;
    type_string " #1";
    send_key "alt-o";
    assert_screen "yast2_users-edited_testuser";
}

sub remove_user() {
    send_key "alt-t";
    assert_screen "yast2_users-confirm_delete";
    send_key "alt-y";
    assert_screen "yast2_users-users";
}

sub add_passwordless_user() {
    assert_script_run "pam-config -a --unix-nullok";
    assert_script_run "useradd test -c 'Test user'";
    assert_script_run "passwd -d test";
}

sub edit_passwordless_user() {
    send_key "down";
    sleep 1;
    edit_user;
}

sub remove_passwordless_user() {
    assert_script_run "pam-config -d --unix-nullok";
    assert_script_run "userdel test";
}

sub start_yast2_users() {
    assert_script_run "yast2 users";
    assert_screen "yast2_users-users";
}

sub run() {
    become_root;

    # Start yast2 users
    start_yast2_users;

    # Basic tests
    add_user;
    edit_user;
    remove_user;
    send_key "alt-o"; # Exit yast2 users

    # Password-less users
    send_key "ctrl-l"; # Clear screen
    add_passwordless_user;
    start_yast2_users;
    edit_passwordless_user;
    send_key "alt-o"; # Exit yast2 users
    remove_passwordless_user;

    # Exit
    send_key "ctrl-l"; # Clear screen
    script_run "exit"
}

1;
# vim: set sw=4 et:
