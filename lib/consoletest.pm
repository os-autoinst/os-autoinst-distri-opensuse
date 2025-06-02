# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;
use version_utils qw(is_public_cloud is_openstack);
use Utils::Logging qw(export_logs_basic export_logs_desktop record_avc_selinux_alerts);
use utils;

=head1 consoletest

C<consoletest> - Base class for all console tests

=cut

=head2 post_run_hook

Method executed when run() finishes.

=cut

sub post_run_hook {
    my ($self) = @_;

    # start next test in home directory
    enter_cmd "cd";

    record_avc_selinux_alerts();
    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

=head2 post_fail_hook

Method executed when run() finishes and the module has result => 'fail'

=cut

sub post_fail_hook {
    my ($self) = @_;
    return if get_var('NOLOGS');
    record_avc_selinux_alerts();
    $self->SUPER::post_fail_hook;
    # at this point the instance is shutdown
    return if (is_public_cloud() || is_openstack());
    # Remaining log functions are executed in Utils::Logging::export_logs()
    # called in opensusebasetest::post_fail_hook()
    select_console('log-console');
    show_oom_info;
    show_tasks_in_blocked_state;
}

=head2 use_wicked_network_manager

 use_wicked_network_manager();

switch network manager to wicked.

=cut

sub use_wicked_network_manager {
    zypper_call("in wicked");
    assert_script_run "systemctl disable NetworkManager --now";
    assert_script_run "systemctl enable --force wicked --now";
    assert_script_run "systemctl start wickedd.service";
    assert_script_run "systemctl start wicked.service";
    assert_script_run qq{systemctl status wickedd.service | grep \"active \(running\)\"};
}

1;
