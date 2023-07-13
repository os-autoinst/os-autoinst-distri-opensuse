# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Overview page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::InstallationSettings::InstallationSettingsPage;
use strict;
use warnings;
use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_install} = $self->{app}->button({id => 'next'});
    $self->{rct_overview} = $self->{app}->richtext({id => 'proposal'});

    return $self;
}

sub get_overview_content {
    my ($self) = @_;
    return $self->{rct_overview}->text();
}

sub is_ssh_service_enabled {
    my ($self) = @_;
    my $overview_content = $self->get_overview_content();
    return ($overview_content =~ m/SSH service will be enabled/);
}

sub open_ssh_port {
    my ($self) = @_;
    $self->{rct_overview}->activate_link('security--open_ssh');
}

sub is_ssh_port_open {
    my ($self) = @_;
    my $overview_content = $self->get_overview_content();
    return ($overview_content =~ m/SSH port will be open/);
}

sub is_shown {
    my ($self) = @_;
    return $self->{rct_overview}->exist();
}

sub is_loaded_completely {
    my ($self) = @_;
    my $result;
    eval {
        $result = YuiRestClient::Wait::wait_until(object => sub {
                my $overview_content = $self->get_overview_content();
                return ($overview_content =~ m/SSH port will be/);
        }, timeout => 60, message => "Overview content is not loaded.");
    };
    $result ? 1 : 0;
}

sub access_booting_options {
    my ($self) = @_;
    $self->{rct_overview}->activate_link('bootloader_stuff');
}

sub access_security_options {
    my ($self) = @_;
    $self->{rct_overview}->activate_link('security');
}

sub access_ssh_import_options {
    my ($self) = @_;
    $self->{rct_overview}->activate_link('ssh_import');
}

sub press_install {
    my ($self) = @_;
    return $self->{btn_install}->click();
}

1;
