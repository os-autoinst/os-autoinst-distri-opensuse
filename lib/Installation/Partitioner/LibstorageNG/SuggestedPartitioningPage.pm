# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Suggested
# Partitioning Page.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::SuggestedPartitioningPage;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::Partitioner::SuggestedPartitioningPage';

use constant {
    NO_LVM_ENCRYPTED_PARTITION_IN_LIST => 'inst-encrypt-no-lvm',
};

sub press_guided_setup_button {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key('alt-g');
}

=head2 select_start_with_existing_partitions

  select_start_with_existing_partitions()

Opens existing partitioning of the Expert Partiotioner from the Suggested Partitioning page .

=cut

sub select_start_with_existing_partitions {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key 'alt-e';
    send_key 'p';
}


=head2 select_start_with_current_partitions

  select_start_with_current_partitions()

Opens current partitioning of the Expert Partiotioner from the Suggested Partitioning page .

=cut

sub select_start_with_current_partitions {
    my ($self) = @_;
    assert_screen($self->SUGGESTED_PARTITIONING_PAGE);
    send_key 'alt-e';
    send_key 'c';
}

sub assert_encrypted_partition_without_lvm_shown_in_the_list {
    assert_screen(NO_LVM_ENCRYPTED_PARTITION_IN_LIST);
}

1;
