# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the Overview Page
#          of the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Overview::OverviewController;
use strict;
use warnings;
use Installation::Overview::OverviewPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{OverviewPage} = Installation::Overview::OverviewPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_overview_page {
    my ($self) = @_;
    die "Installation Overview Page is not displayed" unless $self->{OverviewPage}->is_shown();
    return $self->{OverviewPage};
}

sub enable_ssh_service {
    my ($self) = @_;
    if (!$self->get_overview_page()->is_ssh_enabled()) {
        $self->get_overview_page()->enable_ssh_service();
    }
    if (!$self->get_overview_page()->is_ssh_port_open()) {
        $self->get_overview_page()->open_ssh_port();
    }
    return $self;
}

1;
