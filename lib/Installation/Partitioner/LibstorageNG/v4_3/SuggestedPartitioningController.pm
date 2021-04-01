# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Introduces business actions for Libstorage-NG (version 4.3+)
# in Suggested Partitioning.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningController;
use strict;
use warnings;

use Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningPage;

use YuiRestClient;

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

sub next {
    my ($self) = @_;
    return $self->get_suggested_partitioning_page()->press_next();
}

1;
