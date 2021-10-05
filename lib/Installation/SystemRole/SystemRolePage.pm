# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act on System Role page in
#          the installer.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

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
    $self->{sel_role} = $self->{app}->itemselector({id => 'role_selector'});
    return $self;
}

sub get_selected_roles {
    my ($self) = @_;
    return $self->{sel_role}->selected_items();
}

sub is_shown {
    my ($self) = @_;
    return $self->{sel_role}->exist();
}

sub select_system_role {
    my ($self, $role) = @_;
    return $self->{sel_role}->select($role);
}

1;
