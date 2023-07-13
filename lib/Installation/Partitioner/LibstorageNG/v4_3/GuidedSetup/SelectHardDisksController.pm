# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces business actions for Select Hard Disk(s) page
#          in Guided Partitioning using YuiRestClient.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksController;
use strict;
use warnings;
use Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksPage;
use YuiRestClient;

=head1 SELECT_HARD_DISKS

=head2 SYNOPSIS

The class introduces business actions for Select Hard Disk(s) Screen of Guided Setup with libstorage-ng
using REST API.

=cut

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SelectDisksPage} = Installation::Partitioner::LibstorageNG::v4_3::GuidedSetup::SelectHardDisksPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_select_disks_to_use_page {
    my ($self) = @_;
    die "Select Hard Disk(s) page is not displayed" unless $self->{SelectDisksPage}->is_shown();
    return $self->{SelectDisksPage};
}

sub select_disks {
    my ($self, $disks) = @_;
    $self->get_select_disks_to_use_page()->select_hard_disks($disks);
}

sub go_forward {
    my ($self) = @_;
    $self->get_select_disks_to_use_page()->press_next();
}

1;
