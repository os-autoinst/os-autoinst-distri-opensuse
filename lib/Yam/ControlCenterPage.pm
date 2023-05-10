# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Control Center
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::ControlCenterPage;
use parent 'Yam::PageBase';
use strict;
use warnings;
use testapi;    # needed because of bsc1206966

sub init {
    my $self = shift;
    $self->{lbl_yast_cc} = $self->{app}->label({label => 'YaST Control Center'});
    $self->{slb_groups} = $self->{app}->selectionbox({id => 'groups'});
    $self->{slb_progs} = $self->{app}->selectionbox({id => 'progs'});
    $self->{btn_help} = $self->{app}->button({id => 'help'});
    $self->{btn_run} = $self->{app}->button({id => 'run'});
    $self->{btn_quit} = $self->{app}->button({id => 'quit'});
    return $self;
}

sub get_control_center_page {
    my ($self) = @_;
    die 'YaST Control Center is not displayed' unless $self->{btn_run}->exist();
    return $self;
}


# private methods collection

sub _apply_workaround_bsc1206966 {
    my ($self) = @_;
    record_soft_failure('bsc#1206966 - Item selection with REST API does not update contents');
    my $currentgroup = $self->{slb_groups}->selected_items();
    for (1 .. 4) { send_key 'tab'; }
    if ($currentgroup eq 'Software') {
        send_key 'down';
        send_key 'up';
    }
    else {
        send_key 'up';
        send_key 'down';
    }
}

sub _select_software {
    my ($self) = @_;
    $self->{slb_groups}->select('Software');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_online_update {
    my ($self) = @_;
    $self->{slb_progs}->select('Online Update');
}

sub _select_software_management {
    my ($self) = @_;
    $self->{slb_progs}->select('Software Management');
}

sub _select_add_on_products {
    my ($self) = @_;
    $self->{slb_progs}->select('Add-On Products');
}

sub _select_media_check {
    my ($self) = @_;
    $self->{slb_progs}->select('Media Check');
}

sub _select_software_repositories {
    my ($self) = @_;
    $self->{slb_progs}->select('Software Repositories');
}

sub _select_system {
    my ($self) = @_;
    $self->{slb_groups}->select('System');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_boot_loader {
    my ($self) = @_;
    $self->{slb_progs}->select('Boot Loader');
}

sub _select_date_and_time {
    my ($self) = @_;
    return $self;
    $self->{slb_progs}->select('Date and Time');
}

sub _select_kernel_kdump {
    my ($self) = @_;
    $self->{slb_progs}->select('Kernel Kdump');
}

sub _select_language {
    my ($self) = @_;
    return $self;
    $self->{slb_progs}->select('Language');
}

sub _select_network_settings {
    my ($self) = @_;
    $self->{slb_progs}->select('Network Settings');
}

sub _select_services_manager {
    my ($self) = @_;
    $self->{slb_progs}->select('Services Manager');
}

sub _select_hardware {
    my ($self) = @_;
    $self->{slb_groups}->select('Hardware');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_printer {
    my ($self) = @_;
    $self->{slb_progs}->select('Printer');
}

sub _select_system_keyboard_layout {
    my ($self) = @_;
    $self->{slb_progs}->select('System Keyboard Layout');
}

sub _select_network_services {
    my ($self) = @_;
    $self->{slb_groups}->select('Network Services');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_hostnames {
    my ($self) = @_;
    $self->{slb_progs}->select('Hostnames');
}

sub _select_ntp_configuration {
    my ($self) = @_;
    $self->{slb_progs}->select('NTP Configuration');
}

sub _select_proxy {
    my ($self) = @_;
    $self->{slb_progs}->select('Proxy');
}

sub _select_remote_administration {
    my ($self) = @_;
    $self->{slb_progs}->select('Remote Administration (VNC)');
}

sub _select_iscsi_initiator {
    my ($self) = @_;
    $self->{slb_progs}->select('iSCSI Initiator');
}

sub _select_security_and_users {
    my ($self) = @_;
    $self->{slb_groups}->select('Security and Users');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_firewall {
    my ($self) = @_;
    $self->{slb_progs}->select('Firewall');
}

sub _select_user_and_group_management {
    my ($self) = @_;
    $self->{slb_progs}->select('User and Group Management');
}

sub _select_support {
    my ($self) = @_;
    $self->{slb_groups}->select('Support');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_release_notes {
    my ($self) = @_;
    $self->{slb_progs}->select('Release Notes');
}

sub _select_miscellaneous {
    my ($self) = @_;
    $self->{slb_groups}->select('Miscellaneous');
    $self->_apply_workaround_bsc1206966();
    return $self;
}

sub _select_display_system_log {
    my ($self) = @_;
    $self->{slb_progs}->select("Display the system's log (/var/log/messages)");
}

sub _select_systemd_journal {
    my ($self) = @_;
    $self->{slb_progs}->select('Systemd Journal');
}

sub _select_vendor_driver {
    my ($self) = @_;
    $self->{slb_progs}->select('Vendor Driver');
}

sub _run {
    my ($self) = @_;
    $self->{btn_run}->click();
}

# public methods

sub open_online_update {
    my ($self) = @_;
    _select_software();
    _select_online_update();
}

sub open_software_management {
    my ($self) = @_;
    _select_software();
    _select_software_management();
}

sub open_add_on_products {
    my ($self) = @_;
    _select_software();
    _select_add_on_products();
}

sub open_media_check {
    my ($self) = @_;
    _select_software();
    _select_media_check();
}

sub open_software_repositories {
    my ($self) = @_;
    _select_software();
    _select_software_repositories();
}

sub open_boot_loader {
    my ($self) = @_;
    _select_system();
    _select_boot_loader();
}

sub open_date_and_time {
    my ($self) = @_;
    _select_system();
    _select_date_and_time();
}

sub open_kernel_kdump {
    my ($self) = @_;
    _select_system();
    _select_kernel_kdump();
}

sub open_language {
    my ($self) = @_;
    _select_system();
    _select_language();
}

sub open_network_settings {
    my ($self) = @_;
    _select_system();
    _select_network_settings();
}

sub open_services_manager {
    my ($self) = @_;
    _select_system();
    _select_services_manager();
}

sub open_printer {
    my ($self) = @_;
    _select_hardware();
    _select_printer();
}

sub open_system_keyboard_layout {
    my ($self) = @_;
    _select_hardware();
    _select_system_keyboard_layout();
}

sub open_hostnames {
    my ($self) = @_;
    _select_network_services();
    _select_hostnames();
}

sub open_ntp_configuration {
    my ($self) = @_;
    _select_network_services();
    _select_ntp_configuration();
}

sub open_proxy {
    my ($self) = @_;
    _select_network_services();
    _select_proxy();
}

sub open_remote_administration {
    my ($self) = @_;
    _select_network_services();
    _select_remote_administration();
}

sub open_iscsi_initiator {
    my ($self) = @_;
    _select_network_services();
    _select_iscsi_initiator();
}

sub open_firewall {
    my ($self) = @_;
    _select_security_and_users();
    _select_firewall();
}

sub open_user_and_group_management {
    my ($self) = @_;
    _select_security_and_users();
    _select_user_and_group_management;
}

sub open_release_notes {
    my ($self) = @_;
    $self->get_control_center_page();
    $self->_select_support();
    $self->_select_release_notes();
}

sub open_display_system_log {
    my ($self) = @_;
    _select_miscellaneous();
    _select_display_system_log();
}

sub open_systemd_journal {
    my ($self) = @_;
    _select_miscellaneous();
    _select_systemd_journal();
}

sub open_vendor_driver {
    my ($self) = @_;
    _select_miscellaneous();
    _select_vendor_driver();
}

sub quit {
    my ($self) = @_;
    $self->get_control_center_page();
    $self->{btn_quit}->click();
}


1;
