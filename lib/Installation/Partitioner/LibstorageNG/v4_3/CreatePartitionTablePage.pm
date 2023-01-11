# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to create new partition table with
# Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::CreatePartitionTablePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{rdb_msdos_part_table} = $self->{app}->radiobutton({id => '"msdos"'});
    $self->{rdb_gpt_part_table} = $self->{app}->radiobutton({id => '"gpt"'});
    return $self;
}

sub select_partition_table_type {
    my ($self, $table_type) = @_;
    return ($table_type eq 'msdos') ? $self->{rdb_msdos_part_table}->select() : $self->{rdb_gpt_part_table}->select();
}

1;
