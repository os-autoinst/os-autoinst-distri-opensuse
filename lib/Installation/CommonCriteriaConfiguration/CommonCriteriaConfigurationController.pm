# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces business actions for Common Criteria page
#          using YuiRestClient.
#
# Maintainer: QE Security <none@suse.de>

package Installation::CommonCriteriaConfiguration::CommonCriteriaConfigurationController;
use strict;
use warnings;
use Installation::CommonCriteriaConfiguration::CommonCriteriaConfigurationPage;
use Installation::Popups::YesNoPopup;
use YuiRestClient;

=head1 PARTITIONING_SCHEME

=head2 SYNOPSIS

The class introduces business actions for Common Criteria screen using REST API.

=cut

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{CommonCriteriaConfigurationPage} = Installation::CommonCriteriaConfiguration::CommonCriteriaConfigurationPage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_common_criteria_configuration_page {
    my ($self) = @_;
    die "Common Criteria configuration page is not displayed" unless $self->{CommonCriteriaConfigurationPage}->is_shown();
    return $self->{CommonCriteriaConfigurationPage};
}

sub get_weak_password_warning {
    my ($self) = @_;
    die "Popup for too simple password is not displayed" unless $self->{WeakPasswordPopup}->is_shown();
    return $self->{WeakPasswordPopup};
}

sub configure_encryption {
    my ($self, $password) = @_;
    $self->get_common_criteria_configuration_page()->enter_password($password);
    $self->get_common_criteria_configuration_page()->enter_confirm_password($password);
}

sub go_forward {
    my ($self, $args) = @_;
    $self->get_common_criteria_configuration_page()->press_next();
}

1;
