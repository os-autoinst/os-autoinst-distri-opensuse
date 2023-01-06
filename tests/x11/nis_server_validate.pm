# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: make shadow
# Summary: Validate YaST configuration functionality for NIS
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use lockapi 'mutex_create';
use x11utils 'turn_off_gnome_screensaver';
use mmapi 'wait_for_children';

sub run {
    my ($self) = @_;
    my $test_data = get_test_suite_data();

    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;

    assert_script_run "grep \"$test_data->{nfs_domain}\" /etc/idmapd.conf",
      fail_message => "Nfs domain was not found in idmapd.conf";
    assert_script_run "grep \"$test_data->{nis_domain}\" /etc/defaultdomain",
      fail_message => "Nis domain was not found in defaultdomain";
    foreach my $map (@{$test_data->{map_names}}) {
        assert_script_run "find /var/yp/$test_data->{nis_domain}/ -name $map*",
          fail_message => "$map was not found in /var/yp/$test_data->{nis_domain}/";
    }
    assert_script_run "useradd $test_data->{username} -p $test_data->{password}",
      fail_message => "Failed to add user $test_data->{username}";
    assert_script_run "cd /var/yp/",
      fail_message => "Failed to switch to directory /var/yp/";
    assert_script_run "make",
      fail_message => "Failed to make Makefile in /var/yp/";
    assert_script_run "chown $test_data->{username}:users /home/$test_data->{username}/",
      fail_message => "Failed to change ownership of /home/$test_data->{username}/";
    mutex_create('nis_user_ready');
    wait_for_children;
    enter_cmd "killall xterm";
}

1;
