=head1 yast2_widget_utils.pm

This module provides helper functions for handling YaST widgets in text and graphical mode.

=cut
# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module provides helper functions for handling YaST widgets in text and graphical mode
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

package yast2_widget_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use YaST::workarounds;
use version_utils qw(is_sle);

our @EXPORT = qw(change_service_configuration verify_service_configuration);

=head2 verify_service_configuration

 verify_service_configuration([status => $status]);

Verify service configuration: status. This will just verify C<assert_screen> for C<yast2_ncurses_service_$status>.

=cut

sub verify_service_configuration {
    my (%args) = @_;
    my $status = $args{status};
    assert_screen "yast2_ncurses_service_$status";
}

=head2 change_service_configuration

 change_service_configuration([after_writing => $after_writing], [after_reboot => $after_reboot]);

Modify service configuration: "after writing" and/or "after reboot" steps

=cut

sub change_service_configuration {
    my (%args) = @_;
    my $after_writing_ref = $args{after_writing};
    my $after_reboot_ref = $args{after_reboot};

    apply_workaround_poo124652('yast2_ncurses_service_start_widget') if (is_sle('=15-SP5'));
    change_service_configuration_step('after_writing_conf', $after_writing_ref) if $after_writing_ref;
    change_service_configuration_step('after_reboot', $after_reboot_ref) if $after_reboot_ref;
}

=head2 change_service_configuration_step

 change_service_configuration_step($step_name, $step_conf_ref);

Modify one service configuration step.

C<$step_name> is the name for change service configuration. It is a part of C<needle_selection> which is used for needle match.
C<$step_conf_ref> is used together with 'keys' as a reference for C<$action>. It is used also with 'values' as a reference for C<$shortcut>. 
C<$action> is a part of C<needle_selection> which is used for needle match.

=cut

sub change_service_configuration_step {
    my ($step_name, $step_conf_ref) = @_;
    my ($action) = keys %$step_conf_ref;
    my ($shortcut) = values %$step_conf_ref;
    my $needle_selection = 'yast2_ncurses_service_' . $action . '_' . $step_name;
    my $needle_check = 'yast2_ncurses_service_check_' . $action . '_' . $step_name;

    send_key $shortcut;
    send_key 'end';
    send_key_until_needlematch $needle_selection, 'up', 6, 1;
    if (check_var_array('EXTRATEST', 'y2uitest_ncurses')) {
        send_key 'ret';
        assert_screen $needle_check;
    }
}

1;
