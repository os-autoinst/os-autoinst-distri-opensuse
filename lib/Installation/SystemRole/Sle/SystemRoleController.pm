# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for System Role Page
#          in the installer for SLES.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SystemRole::Sle::SystemRoleController;
use parent 'Installation::SystemRole::SystemRoleController';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{roles} = {
        SLES_with_GNOME => 'SLES with GNOME',
        text_mode => 'Text Mode',
        minimal => 'Minimal',
        transactional_server => 'Transactional Server',
        HA_node => 'HA node'
    };
    return $self;
}

1;
