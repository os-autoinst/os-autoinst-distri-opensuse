# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Introduces business actions for Libstorage-NG (version 4.3+)
# in Suggested Partitioning.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{SuggestedPartitioningPage} = Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_suggested_partitioning_page {
    my ($self) = @_;
    die "Suggested Partitioning is not displayed" unless $self->{SuggestedPartitioningPage}->is_shown();
    return $self->{SuggestedPartitioningPage};
}

sub select_guided_setup {
    my ($self) = @_;
    return $self->get_suggested_partitioning_page()->select_guided_setup();
}

sub get_partitioning_changes_summary {
    my ($self) = @_;
    return $self->get_suggested_partitioning_page()->get_text_summary();
}

1;
