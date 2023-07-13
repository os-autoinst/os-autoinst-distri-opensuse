# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for System Role Page
#          in the installer.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
    $self->{roles} = {
        desktop_with_KDE_plasma => 'Desktop with KDE Plasma',
        desktop_with_GNOME => 'Desktop with GNOME',
        desktop_with_Xfce => 'Desktop with Xfce',
        generic_desktop => 'Generic Desktop',
        server => 'Server',
        transactional_server => 'Transactional Server'
    };
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
    $self->get_system_role_page()->select_system_role($self->get_available_role($role));
    $self->get_system_role_page()->press_next();
}

sub get_available_role {
    my ($self, $role) = @_;
    return $self->{roles}{$role};
}

sub accept_system_role {
    my ($self) = @_;
    $self->get_system_role_page()->press_next();
}

1;
