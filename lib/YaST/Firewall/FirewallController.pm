# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions Firewall Settings Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firewall::FirewallController;
use strict;
use warnings;
use testapi;
use YaST::Firewall::MainPage;
use YaST::Firewall::StartUpPage;
use YaST::Firewall::InterfacesPage;
use YaST::Firewall::ZonesPage;
use YaST::Firewall::ZonePage;
use YaST::Firewall::ServicesPage;
use YaST::Firewall::PortsPage;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{MainPage} = YaST::Firewall::MainPage->new({app => YuiRestClient::get_app()});
    $self->{StartUpPage} = YaST::Firewall::StartUpPage->new({app => YuiRestClient::get_app()});
    $self->{InterfacesPage} = YaST::Firewall::InterfacesPage->new({app => YuiRestClient::get_app()});
    $self->{ZonesPage} = YaST::Firewall::ZonesPage->new({app => YuiRestClient::get_app()});
    $self->{ZonePage} = YaST::Firewall::ZonePage->new({app => YuiRestClient::get_app()});
    $self->{ServicesPage} = YaST::Firewall::ServicesPage->new({app => YuiRestClient::get_app()});
    $self->{PortsPage} = YaST::Firewall::PortsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_main_page {
    my ($self) = @_;
    die 'Main Firewall Page is not displayed' unless $self->{MainPage}->is_shown();
    return $self->{MainPage};
}

sub get_start_up_page {
    my ($self) = @_;
    die 'StartUp Pane is not displayed' unless $self->{StartUpPage}->is_shown();
    return $self->{StartUpPage};
}

sub get_interfaces_page {
    my ($self) = @_;
    die 'Interfaces Pane is not displayed' unless $self->{InterfacesPage}->is_shown();
    return $self->{InterfacesPage};
}

sub get_zones_page {
    my ($self) = @_;
    die 'Zones Pane is not displayed' unless $self->{ZonesPage}->is_shown();
    return $self->{ZonesPage};
}

sub get_zone_page {
    my ($self) = @_;
    die 'Zone Pane is not displayed' unless $self->{ZonePage}->is_shown();
    return $self->{ZonePage};
}

sub get_services_page {
    my ($self) = @_;
    die 'Services Pane is not displayed' unless $self->{ServicesPage}->is_shown();
    return $self->{ServicesPage};
}

sub get_ports_page {
    my ($self) = @_;
    die 'Ports Pane is not displayed' unless $self->{PortsPage}->is_shown();
    return $self->{PortsPage};
}

sub select_start_up_page {
    my ($self, $zone) = @_;
    $self->get_main_page()->select_start_up_page();
}

sub select_interfaces_page {
    my ($self, $zone) = @_;
    $self->get_main_page()->select_interfaces_page();
}

sub select_zones_page {
    my ($self, $zone) = @_;
    $self->get_main_page()->select_zones_page();
}

sub select_zone_page {
    my ($self, $zone) = @_;
    $self->get_main_page()->select_zone_page($zone);
}

sub start_firewall {
    my ($self) = @_;
    $self->get_start_up_page()->start_firewall();
}

sub stop_firewall {
    my ($self) = @_;
    $self->get_start_up_page()->stop_firewall();
}

sub accept_change {
    my ($self) = @_;
    $self->get_main_page()->press_accept();
}

sub set_default_zone {
    my ($self, $zone) = @_;
    $self->get_zones_page()->select_zone($zone);
    save_screenshot;
    $self->get_zones_page()->set_default_zone();
}

sub set_interface_zone {
    my ($self, $device, $zone) = @_;
    $self->get_interfaces_page()->set_interface_zone($device, $zone);
}

sub switch_ports_tab {
    my ($self) = @_;
    $self->get_zone_page()->switch_ports_tab();
}

sub switch_services_tab {
    my ($self) = @_;
    $self->get_zone_page()->switch_services_tab();
}

sub add_service {
    my ($self, $zone, $service) = @_;
    $self->switch_services_tab();
    save_screenshot;
    $self->get_services_page()->select_service($zone, $service);
    save_screenshot;
    $self->get_services_page()->add_service();
}

sub add_tcp_port {
    my ($self, $port) = @_;
    $self->switch_ports_tab();
    save_screenshot;
    $self->get_ports_page()->set_tcp_port($port);
}

1;
