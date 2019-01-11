# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: This module provides helper functions for handling YaST widgets in text and graphical mode
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

package yast2_widget_utils;

use base Exporter;
use Exporter;

use strict;
use testapi;

our @EXPORT = qw(change_service_configuration verify_service_configuration);

=head2 verify_service_configuration
Verify service configuration: status
=cut
sub verify_service_configuration {
    my (%args) = @_;
    my $status = $args{status};
    assert_screen "yast2_ncurses_service_$status";
}

=head2 change_service_configuration
Modify service configuration: "after writing" and/or "after reboot" steps
=cut
sub change_service_configuration {
    my (%args)            = @_;
    my $after_writing_ref = $args{after_writing};
    my $after_reboot_ref  = $args{after_reboot};

    assert_screen 'yast2_ncurses_service_start_widget';
    change_service_configuration_step('after_writing_conf', $after_writing_ref) if $after_writing_ref;
    change_service_configuration_step('after_reboot',       $after_reboot_ref)  if $after_reboot_ref;
}

=head2 change_service_configuration_step
Modify one service configuration step
=cut
sub change_service_configuration_step {
    my ($step_name, $step_conf_ref) = @_;
    my ($action)         = keys %$step_conf_ref;
    my ($shortcut)       = values %$step_conf_ref;
    my $needle_selection = 'yast2_ncurses_service_' . $action . '_' . $step_name;
    my $needle_check     = 'yast2_ncurses_service_check_' . $action . '_' . $step_name;

    send_key $shortcut;
    send_key 'end';
    send_key_until_needlematch $needle_selection, 'up', 5, 1;
    if (check_var_array('EXTRATEST', 'y2uitest_ncurses')) {
        send_key 'ret';
        assert_screen $needle_check;
    }
}

1;
