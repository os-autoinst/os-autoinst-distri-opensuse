# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on System Role page in
#          the installer.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::SystemRole::SystemRolePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{its_role} = $self->{app}->itemselector({id => 'role_selector'});
    return $self;
}

sub get_selected_roles {
    my ($self) = @_;
    return $self->{its_role}->selected_items();
}

sub is_shown {
    my ($self) = @_;
    return $self->{its_role}->exist();
}

sub select_system_role {
    my ($self, $role) = @_;
    return $self->{its_role}->select($role);
}

1;
