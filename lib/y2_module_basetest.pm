=head1 y2_module_basetest.pm

This module provides common subroutines for YaST2 modules in graphical and text mode.

=cut
# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module provides common subroutines for YaST2 modules in graphical and text mode
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package y2_module_basetest;

use parent 'y2_base';
use Exporter 'import';

use strict;
use warnings;
use testapi;
use utils 'show_tasks_in_blocked_state';
use version_utils qw(is_opensuse is_leap is_tumbleweed);

our @EXPORT = qw(is_network_manager_default
  continue_info_network_manager_default
  accept_warning_network_manager_default
  with_yast_env_variables
  wait_for_exit
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


=head2 wait_for_exit

 wait_for_exit(module => $module, timeout => $timeout);

Wait for string yast2-$module-status-0 (which has been
previously used to open the module) to appear in the serial output
using a timeout in order to ensure that the module exited.

C<module> module to wait for exit.
C<timeout> timeout to wait on the serial.

=cut

sub wait_for_exit {
    my %args = @_;
    $args{timeout} //= 60;
    wait_serial("yast2-$args{module}-status-0", timeout => $args{timeout}) ||
      die "Fail! yast2 $args{module} is not closed or non-zero code returned.";
}

sub post_fail_hook {
    my $self = shift;
    $self->upload_widgets_json();
    my $defer_blocked_task_info = testapi::is_serial_terminal();
    show_tasks_in_blocked_state unless ($defer_blocked_task_info);

    select_console 'log-console';
    save_screenshot;

    show_tasks_in_blocked_state if ($defer_blocked_task_info);

    $self->remount_tmp_if_ro;
    $self->save_upload_y2logs();
    upload_logs('/var/log/zypper.log', failok => 1);
    $self->save_system_logs();
    $self->save_strace_gdb_output('yast');
}

1;
