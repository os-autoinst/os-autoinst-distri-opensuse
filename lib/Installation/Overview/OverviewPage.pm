# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act on the Overview page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Overview::OverviewPage;
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
    $self->{btn_install}  = $self->{app}->button({id => 'next'});
    $self->{txt_overview} = $self->{app}->richtext({id => 'proposal'});

    return $self;
}

sub get_overview_content {
    my ($self) = @_;
    return $self->{txt_overview}->text();
}

sub enable_ssh_service {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{txt_overview}->activate_link('security--enable_sshd');
            return $self->is_ssh_enabled;
    });
}

sub is_shown {
    my ($self) = @_;
    return $self->{txt_overview}->exist();
}

sub is_ssh_enabled {
    my ($self) = @_;
    my $overview_content = $self->get_overview_content();
    return ($overview_content =~ m/SSH service will be enabled/);
}

sub is_ssh_port_open {
    my ($self) = @_;
    my $overview_content = $self->get_overview_content();
    return ($overview_content =~ m/SSH port will be open/);
}

sub open_ssh_port {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->{txt_overview}->activate_link('security--open_ssh');
            return $self->is_ssh_port_open;
    });
}

sub press_install {
    my ($self) = @_;
    return $self->{btn_install}->click();
}

1;
