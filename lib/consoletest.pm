# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;
use version_utils qw(is_public_cloud is_openstack);
use utils;

my %avc_record = (
    start => 0,
    end => undef
);

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
    record_avc_selinux_alerts();
    $self->SUPER::post_fail_hook;
    # at this point the instance is shutdown
    return if (is_public_cloud() || is_openstack());
    select_console('log-console');
    $self->remount_tmp_if_ro;
    $self->export_logs_basic;
    # Export extra log after failure for further check gdm issue 1127317, also poo#45236 used for tracking action on Openqa
    $self->export_logs_desktop;
}

=head2 record_avc_selinux_alerts

List AVCs that have been recorded during a runtime of a test module that executes this function

=cut

sub record_avc_selinux_alerts {
    if ((current_console() !~ /root|log/) || (script_run('test -f /var/log/audit/audit.log') != 0)) {
        return;
    }

    my @logged = split(/\n/, script_output('ausearch -m avc -r', proceed_on_failure => 1));

    # no new messages are registered
    if (scalar @logged <= $avc_record{start}) {
        return;
    }

    $avc_record{end} = scalar @logged - 1;
    my @avc = @logged[$avc_record{start} .. $avc_record{end}];
    $avc_record{start} = $avc_record{end} + 1;

    record_info('AVC', join("\n", @avc));
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
