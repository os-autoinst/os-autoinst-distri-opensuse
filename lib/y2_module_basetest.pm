=head1 y2_module_basetest.pm

This module provides common subroutines for YaST2 modules in graphical and text mode.

=cut
# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: This module provides common subroutines for YaST2 modules in graphical and text mode
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

package y2_module_basetest;

use parent 'opensusebasetest';
use Exporter 'import';

use strict;
use warnings;
use testapi;
use utils 'show_tasks_in_blocked_state';
use y2_installbase;
use version_utils qw(is_opensuse is_leap is_tumbleweed);

our @EXPORT = qw(is_network_manager_default
  continue_info_network_manager_default
  accept_warning_network_manager_default
  workaround_suppress_lvm_warnings
  with_yast_env_variables
);

=head2 with_yast_env_variables

 with_yast_env_variables([extra_vars]);

Set environment variables for yast application.
C<extra_vars> extends the variables that can be used. C<extra_vars> expects a string.
ex: with_yast_env_variables("foo=bar");

=cut
sub with_yast_env_variables {
    my ($extra_vars) = shift // '';
    return "Y2DEBUG=1 ZYPP_MEDIA_CURL_DEBUG=1 Y2STRICTTEXTDOMAIN=1 $extra_vars";
}

=head2 is_network_manager_default

 is_network_manager_default();

openSUSE desktop roles have network manager as default except for older Leap versions.

=cut
sub is_network_manager_default {
    return 0 if !is_opensuse;
    return 0 if is_leap('<=15.0');
    return get_var('DESKTOP', '') =~ /gnome|kde|xfce/;
}

=head2 continue_info_network_manager_default

 continue_info_network_manager_default();

Click on Continue when appears info indicating that network interfaces are controlled by Network Manager

=cut
sub continue_info_network_manager_default {
    if (is_network_manager_default) {
        assert_screen 'yast2-lan-warning-network-manager';
        send_key $cmd{continue};
    }
}

=head2 accept_warning_network_manager_default

 accept_warning_network_manager_default();

Click on OK when appears a warning indicating that network interfaces are controlled by Network Manager.

=cut
sub accept_warning_network_manager_default {
    assert_screen 'yast2-lan-warning-network-manager';
    send_key $cmd{ok};
    assert_screen 'yast2_lan-global-tab';
}

=head2 workaround_suppress_lvm_warnings

 workaround_suppress_lvm_warnings();

LVM is polluting stdout with leaked invocation warnings because of file descriptor 3 is assigned to /root/.bash_history.

record_soft_failure if is 'is_tumbleweed' for issue 'bsc#1124481 - LVM is polluting stdout with leaked invocation warnings'.

The workaround suppresses the warnings by setting the environment variable LVM_SUPPRESS_FD_WARNINGS.

=cut
sub workaround_suppress_lvm_warnings {
    if (is_tumbleweed) {
        record_soft_failure('bsc#1124481 - LVM is polluting stdout with leaked invocation warnings');
        assert_script_run('export LVM_SUPPRESS_FD_WARNINGS=1');
    }
}

sub post_fail_hook {
    my $self = shift;

    my $defer_blocked_task_info = testapi::is_serial_terminal();
    show_tasks_in_blocked_state unless ($defer_blocked_task_info);

    select_console 'log-console';
    save_screenshot;

    show_tasks_in_blocked_state if ($defer_blocked_task_info);

    $self->remount_tmp_if_ro;
    y2_installbase::save_upload_y2logs($self);
    upload_logs('/var/log/zypper.log', failok => 1);
    y2_installbase::save_system_logs($self);
    y2_installbase::save_strace_gdb_output($self, 'yast');
}

1;
