# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Network Settings Dialog
# (yast2 lan module) version 4.3, minor differences to v4.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::v4_3::NetworkSettingsController;
use parent 'YaST::NetworkSettings::v4::NetworkSettingsController';
use strict;
use warnings;
use YaST::NetworkSettings::TopNavigationBar;
use YaST::NetworkSettings::HostnameDNSTab;
use YaST::NetworkSettings::ActionButtons;
use YaST::Warning::Notification;
use YaST::NetworkSettings::v4_3::OverviewTab;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{TopNavigationBar} = YaST::NetworkSettings::TopNavigationBar->new({app => YuiRestClient::get_app()});
    $self->{OverviewTab} = YaST::NetworkSettings::v4_3::OverviewTab->new({app => YuiRestClient::get_app()});
    $self->{HostnameDNSTab} = YaST::NetworkSettings::HostnameDNSTab->new({app => YuiRestClient::get_app()});
    $self->{ActionButtons} = YaST::NetworkSettings::ActionButtons->new({app => YuiRestClient::get_app()});
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

sub get_overview_tab {
    my ($self) = @_;
    return $self->{OverviewTab};
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

sub cancel_changes {
    my ($self) = @_;
    $self->get_action_buttons()->press_cancel();
}

sub accept_all_changes_will_be_lost {
    my ($self) = @_;
    $self->get_action_buttons()->press_yes();
}

sub proceed_with_current_configuration {
    my ($self) = @_;
    $self->get_overview_tab()->is_shown();
    $self->get_action_buttons()->press_ok();
}

1;
