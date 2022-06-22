# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;
use version_utils qw(is_public_cloud is_openstack);
use publiccloud::utils 'select_host_console';

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

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

=head2 post_fail_hook

Method executed when run() finishes and the module has result => 'fail'

=cut

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    # at this point the instance is shutdown
    return if (is_public_cloud() || is_openstack());
    select_console('log-console');
    $self->remount_tmp_if_ro;
    $self->export_logs_basic;
    # Export extra log after failure for further check gdm issue 1127317, also poo#45236 used for tracking action on Openqa
    $self->export_logs_desktop;
}

=head2 use_wicked_network_manager

 use_wicked_network_manager();

switch network manager to wicked.

=cut

sub use_wicked_network_manager {
    assert_script_run "systemctl disable NetworkManager --now";
    assert_script_run "systemctl enable --force wicked --now";
    assert_script_run "systemctl start wickedd.service";
    assert_script_run "systemctl start wicked.service";
    assert_script_run qq{systemctl status wickedd.service | grep \"active \(running\)\"};
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {no_rollback => 1} : {};
}

1;
