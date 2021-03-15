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
use YaST::NetworkSettings::TopNavigationBar;
use YaST::NetworkSettings::HostnameDNSTab;
use YaST::NetworkSettings::ActionButtons;
use YaST::Warning::Notification;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{TopNavigationBar}    = YaST::NetworkSettings::TopNavigationBar->new({app => YuiRestClient::get_app()});
    $self->{HostnameDNSTab}      = YaST::NetworkSettings::HostnameDNSTab->new({app => YuiRestClient::get_app()});
    $self->{ActionButtons}       = YaST::NetworkSettings::ActionButtons->new({app => YuiRestClient::get_app()});
    $self->{NotificationWarning} = YaST::Warning::Notification->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_top_navigation_bar {
    my ($self) = @_;
    return $self->{TopNavigationBar};
}

sub get_hostname_dns_tab {
    my ($self) = @_;
    return $self->{HostnameDNSTab};
}

sub get_action_buttons {
    my ($self) = @_;
    return $self->{ActionButtons};
}

sub get_notification_warning {
    my ($self) = @_;
    return $self->{NotificationWarning};
}

sub view_bond_slave_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bond');
    $self->get_overview_tab()->press_edit();
    $self->get_bond_slaves_tab_on_edit()->select_tab();
    $self->get_bond_slaves_tab_on_edit()->press_next();
}

sub confirm_warning {
    my ($self) = @_;
    $self->get_notification_warning()->confirm();
}

sub set_hostname_via_dhcp {
    my ($self, $args) = @_;
    my $dhcp_option = $args->{dhcp_option};
    $self->get_top_navigation_bar()->select_hostname_dns_tab();
    $self->get_hostname_dns_tab()->select_option_in_hostname_via_dhcp($dhcp_option);
}

sub save_changes {
    my ($self) = @_;
    $self->get_action_buttons()->press_ok();
}

1;
