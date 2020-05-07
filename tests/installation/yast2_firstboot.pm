# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Utilize OS using YaST2 Firstboot module
# Doc: https://en.opensuse.org/YaST_Firstboot
# Maintainer: Martin Loviska <mloviska@suse.com>

use base 'y2_installbase';
use y2_logs_helper qw(accept_license verify_license_has_to_be_accepted);
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use installation_user_settings qw(await_password_check enter_userinfo enter_rootinfo);
use version_utils qw(is_sle is_opensuse);

sub language_and_keyboard {
    my $shortcuts = {
        l => 'lang',
        k => 'keyboard'
    };
    assert_screen('lang_and_keyboard', 60);
    mouse_hide(1);
    foreach (sort keys %${shortcuts}) {
        send_key 'alt-' . $_;
        assert_screen $shortcuts->{$_} . '_selected';
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub license {
    my $self = shift;
    # default TO value was not sufficient
    assert_screen('license-agreement', 60);
    # Nothing to be accepted in opensuse
    unless (is_opensuse) {
        $self->verify_license_has_to_be_accepted;
        $self->accept_license;
    }
    send_key $cmd{next};
}

sub welcome {
    assert_screen 'welcome';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub clock_and_timezone {
    assert_screen 'inst-timezone';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub user_setup {
    my $is_not_shared_passwd = shift;
    assert_screen 'local_user';
    enter_userinfo(username => get_var('YAST2_FIRSTBOOT_USERNAME'));
    if (defined($is_not_shared_passwd)) {
        send_key 'alt-t' if (is_opensuse);
    }
    else {
        send_key 'alt-t' if (is_sle('>=12-sp4'));
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
    await_password_check;
    wait_screen_change(sub { send_key $cmd{next}; }, 7) unless defined($is_not_shared_passwd);
}

sub root_setup {
    assert_screen 'root_user';
    enter_rootinfo;
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub run {
    my $self = shift;
    language_and_keyboard;
    welcome;
    $self->license;
    clock_and_timezone;
    user_setup(1);
    root_setup;
    assert_screen 'installation_completed';
    send_key $cmd{finish};
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    # upload YaST2 Firstboot configuration file
    upload_logs('/etc/YaST2/firstboot.xml', log_name => "firstboot.xml.conf");
}

1;
