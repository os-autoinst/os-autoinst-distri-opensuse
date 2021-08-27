# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for System Role Page
#          in the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::SystemRole::SystemRoleController;
use strict;
use warnings;
use Installation::SystemRole::SystemRolePage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SystemRolePage} = Installation::SystemRole::SystemRolePage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_system_role_page {
    my ($self) = @_;
    die "System Role Page is not displayed" unless $self->{SystemRolePage}->is_shown();
    return $self->{SystemRolePage};
}

sub get_selected_role {
    my ($self) = @_;
    my @items = $self->get_system_role_page()->get_selected_roles();
    die 'More than one System Role is selected' if scalar @items > 1;
    return $items[0];
}

sub select_system_role {
    my ($self, $role) = @_;
    $self->get_system_role_page()->select_system_role($role);
}

sub next {
    my ($self) = @_;
    return $self->get_system_role_page()->press_next();
}

1;
