# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yp-tools
# Summary: Validate YaST configuration functionality for NIS
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use lockapi 'mutex_wait';
use x11utils 'turn_off_gnome_screensaver';
use utils 'systemctl';

sub run {
    my ($self) = @_;
    my $test_data = get_test_suite_data();

    x11_start_program('xterm -geometry 155x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    become_root;

    assert_script_run "ls /etc/yp.conf", fail_message => "File /etc/yp.conf doesn't exist";
    assert_script_run "grep \"ypserv\" /etc/yp.conf", fail_message => "\"ypserv\" was not found in /etc/yp.conf";
    assert_script_run "grep \"$test_data->{nis_domain}\" /etc/defaultdomain",
      fail_message => "\"$test_data->{nis_domain}\" was not found in /etc/defaultdomain";
    mutex_wait('nis_user_ready');
    assert_script_run "ypmatch $test_data->{username} passwd",
      fail_message => "New nis user is not visible from NIS client";
    # In order for the client to use nis users, nscd needs to be restarted.
    systemctl "restart nscd";
    assert_script_run "grep -r netgroup /etc/nsswitch.conf | grep nis",
      fail_message => "nsswitch.conf was not modified properly by NIS configuration";
    assert_script_run "su - $test_data->{username} -c 'pwd | grep $test_data->{username}'",
      fail_message => "Home directory of new NIS user is not the expected one";
    assert_script_run "su - $test_data->{username} -c 'echo \"nis works\" > some_random_file'",
      fail_message => "Cannot write in home directory of new NIS user from NIS client";
    assert_script_run "su - $test_data->{username} -c 'grep \"nis works\" some_random_file'",
      fail_message => "Failed to verify writability to home directory of new NIS user from NIS client";
    enter_cmd "killall xterm";
}

1;
