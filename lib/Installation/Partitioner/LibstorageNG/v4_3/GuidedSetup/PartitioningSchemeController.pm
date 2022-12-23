# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces business actions for Partitioning Scheme page
#          in Guided Partitioning using YuiRestClient.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemeController;
use strict;
use warnings;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemePage;
use Installation::Popups::YesNoPopup;
use YuiRestClient;

=head1 PARTITIONING_SCHEME

=head2 SYNOPSIS

The class introduces business actions for Partitioning Scheme Screen of Guided Setup with libstorage-ng
Partitioner using REST API.

=cut

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{PartitioningSchemePage} = Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::PartitioningSchemePage->new({app => YuiRestClient::get_app()});
    $self->{WeakPasswordPopup} = Installation::Popups::YesNoPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_partitioning_scheme_page {
    my ($self) = @_;
    die "Partitioning Scheme is not displayed" unless $self->{PartitioningSchemePage}->is_shown();
    return $self->{PartitioningSchemePage};
}

sub get_weak_password_warning {
    my ($self) = @_;
    die "Popup for too simple password is not displayed" unless $self->{WeakPasswordPopup}->is_shown();
    return $self->{WeakPasswordPopup};
}

sub configure_encryption {
    my ($self, $password) = @_;
    $self->get_partitioning_scheme_page()->select_enable_disk_encryption();
    $self->get_partitioning_scheme_page()->enter_password($password);
    $self->get_partitioning_scheme_page()->enter_confirm_password($password);
}

sub enable_lvm {
    my ($self) = @_;
    $self->get_partitioning_scheme_page()->select_enable_lvm();
}

sub disable_lvm {
    my ($self) = @_;
    $self->get_partitioning_scheme_page()->unselect_enable_lvm();
}

sub go_forward {
    my ($self, $args) = @_;
    $self->get_partitioning_scheme_page()->press_next();
}

1;
