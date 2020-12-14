# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Network Settings Dialog
# (yast2 lan module) version 4.3, minor differences to v4.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::v4_3::NetworkSettingsController;
use parent 'YaST::NetworkSettings::v4::NetworkSettingsController';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    return $class->SUPER::new($args);
}

sub view_bond_slave_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bond');
    $self->get_overview_tab()->press_edit();
    $self->get_bond_slaves_tab_on_edit()->select_tab();
    $self->get_bond_slaves_tab_on_edit()->press_next();
}

1;
