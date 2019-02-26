# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for File System Options
# Page in Guided Setup.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::FileSystemOptionsPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::AbstractPage';
use Installation::Partitioner::ProposeSeparateHomePartitionCheckbox;

use constant {
    FILE_SYSTEM_OPTIONS_PAGE => 'inst-filesystem-options'
};

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{propose_separate_home_partition_checkbox} = Installation::Partitioner::ProposeSeparateHomePartitionCheckbox->new();
    return $self;
}

sub get_propose_separate_home_partition_checkbox {
    my ($self) = @_;
    return $self->{propose_separate_home_partition_checkbox};
}

sub set_state_propose_separate_home_partition_checkbox {
    my ($self, $state) = @_;
    assert_screen(FILE_SYSTEM_OPTIONS_PAGE);
    $self->get_propose_separate_home_partition_checkbox()->set_state($state);
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(FILE_SYSTEM_OPTIONS_PAGE);
}

1;
