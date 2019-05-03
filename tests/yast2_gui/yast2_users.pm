# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test initial startup of users configuration YaST2 module
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "y2x11test";
use strict;
use warnings;
use testapi;

use utils 'type_string_slow_extended';
use version_utils qw(is_tumbleweed is_leap);

sub write_change_now {
    send_key 'alt-x';
    send_key 'down';
    send_key 'down';
    send_key 'down';
    assert_screen 'write_change_now_reached';
    send_key 'ret';
}

sub check_with_xterm {
    my (%args) = @_;
    x11_start_program('xterm');
    become_root;
    validate_script_output($args{command}, sub { m/$args{expected}/ });
    wait_screen_change { send_key 'alt-f4'; };
}


sub add_user {
    my (%args) = @_;
    send_key 'alt-a';    # add user tab
    type_string_slow_extended($args{username});
    send_key 'tab';
    type_string_slow_extended($args{username});
    send_key 'tab';
    type_string_slow_extended($args{password});
    send_key 'tab';
    type_string_slow_extended($args{password});
    assert_screen 'user_data_fields_filled_up';
    send_key "alt-o";    # OK => Exit
    if (is_leap || is_tumbleweed) {
        assert_screen 'do_not_disable_auto_login';
        send_key 'alt-n';
    }
    assert_screen 'new_user_has_been_created';
}

sub edit_user {
    send_key 'alt-i';    # edit user tab
    send_key 'tab';      # change user full name
    send_key 'tab';      # we need 2 tabs
    type_string_slow_extended('edited');
    send_key 'tab';      # change username
    type_string_slow_extended('edited');
    send_key "alt-o";
    assert_screen 'home_dir_popup__checking';
    send_key 'ret';
    assert_screen 'edited_user_checking';
}

sub show_user_info {
    send_key 'alt-i';
    send_key 'alt-d';
    assert_screen 'show_user__checking';
    send_key 'alt-o';
}

sub delete_user {
    send_key 'alt-t';
    assert_screen 'delete_user_popup__checking';
    send_key 'alt-y';
}

sub show_help {
    send_key 'alt-h';
    assert_screen 'help_popup__checking';
    send_key 'alt-c';
}

sub show_system_users {
    send_key 'alt-s';
    send_key 'down';
    send_key 'down';
    assert_screen 'system_user__checking';
    send_key 'ret';
    assert_screen 'list_users__checking';
}

sub run {
    my $self = shift;
    select_console 'x11';
    my $username = 'joshua';
    my $password = 'Sup3rS3cr3t!';

    $self->launch_yast2_module_x11('users', match_timeout => 60);
    assert_screen 'yast2_users_main_screen';
    add_user(username => $username, password => $password);
    write_change_now;
    check_with_xterm(command => "cat /etc/passwd|grep $username", expected => $username);
    edit_user;
    write_change_now;
    check_with_xterm("cat /etc/passwd|grep edited", expected => "edited");
    show_user_info;
    delete_user;
    write_change_now;
    check_with_xterm("cat /etc/passwd | grep edited | test `wc -l` -eq 0", expected => "");
    show_help;
    show_system_users;
    send_key "alt-o";
    wait_serial("yast2-users-status-0") || die 'Fail! YaST2 - Users dialog is not closed or non-zero code returned.';

}

1;
