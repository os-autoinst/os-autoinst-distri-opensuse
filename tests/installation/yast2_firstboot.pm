# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Utilize OS using YaST2 Firstboot module
# Doc: https://en.opensuse.org/YaST_Firstboot
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_module_guitest';
use y2_logs_helper qw(accept_license verify_license_has_to_be_accepted);
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console);
use installation_user_settings qw(await_password_check enter_userinfo enter_rootinfo);
use version_utils qw(is_sle is_opensuse);
use scheduler 'get_test_suite_data';

sub firstboot_language_keyboard {
    my $shortcuts = {
        l => 'lang',
        k => 'keyboard'
    };
    assert_screen('lang_and_keyboard', 60);
    mouse_hide(1);
    foreach (sort keys %${shortcuts}) {
        send_key 'alt-' . $_;
        wait_screen_change(sub { send_key 'ret' }) if check_var('DESKTOP', 'textmode');
        assert_screen $shortcuts->{$_} . '_selected';
    }
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub firstboot_licenses {
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

sub firstboot_welcome {
    assert_screen 'welcome';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub firstboot_timezone {
    assert_screen 'inst-timezone';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub firstboot_user {
    assert_screen 'local_user';
    enter_userinfo(username => get_var('YAST2_FIRSTBOOT_USERNAME'));
    # In opensuse, we expect autologin at first boot, not in SLE.
    wait_screen_change(sub { send_key 'alt-a'; },    7) if is_opensuse;
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
    await_password_check;
}

sub firstboot_root {
    assert_screen 'root_user', 60;
    enter_rootinfo;
}

sub firstboot_hostname {
    assert_screen 'hostname';
    wait_screen_change(sub { send_key $cmd{next}; }, 7);
}

sub run {
    my $self      = shift;
    my $test_data = get_test_suite_data();
    my %clients;
    foreach my $client (@{$test_data->{clients}}) {
        # Make sure the subroutine called from test data exists
        die "Client '$client' is not defined in the module, please check test_data" unless defined(&{"$client"});
        my $client_method = \&{"$client"};
        $client_method->($self);
    }
    assert_screen 'installation_completed';
    send_key $cmd{finish};
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    # upload YaST2 Firstboot configuration file
    upload_logs('/etc/YaST2/firstboot.xml', log_name => "firstboot.xml.conf");
}

sub test_flags {
    return {fatal => 1};
}

1;
