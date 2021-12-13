# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for the Performing Installation
#          Page in the installer.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::PerformingInstallation::PerformingInstallationController;
use strict;
use warnings;
use Installation::PerformingInstallation::PerformingInstallationPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{PerformingInstallationPage} = Installation::PerformingInstallation::PerformingInstallationPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_performing_installation_page {
    my ($self) = @_;
    die 'Performing Installation Page is not displayed' unless $self->{PerformingInstallationPage}->is_shown();
    return $self->{PerformingInstallationPage};
}

sub perform {
    my ($self, $timeout) = @_;
    $self->get_performing_installation_page()->wait_finished($timeout);
}

1;
