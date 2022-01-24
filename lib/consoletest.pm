# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;
use version_utils 'is_public_cloud';
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
    select_console('log-console');
    $self->remount_tmp_if_ro;
    $self->export_logs_basic;
    # Export extra log after failure for further check gdm issue 1127317, also poo#45236 used for tracking action on Openqa
    $self->export_logs_desktop;

    if (is_public_cloud()) {
        select_host_console(force => 1);

        # Destroy the public cloud instance in case of fatal test failure
        # Currently there is theoretical chance to call cleanup two times. See details in poo#95780
        my $flags = $self->test_flags();
        $self->{run_args}->{my_provider}->cleanup() if ($flags->{fatal});

        # When tunnel-console is used we upload the log
        my $ssh_sut = '/var/tmp/ssh_sut.log';
        upload_logs($ssh_sut) unless (script_run("test -f $ssh_sut") != 0);
    }
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
