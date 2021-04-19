# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods to create new partition table with
# Expert Partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::CreatePartitionTablePage;
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
    $self->{rb_msdos_part_table} = $self->{app}->radiobutton({id => '"msdos"'});
    $self->{rb_gpt_part_table}   = $self->{app}->radiobutton({id => '"gpt"'});
    $self->{btn_next}            = $self->{app}->button({id => 'next'});
    return $self;
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

sub select_partition_table_type {
    my ($self, $table_type) = @_;
    return ($table_type eq 'msdos') ? $self->{rb_msdos_part_table}->select() : $self->{rb_gpt_part_table}->select();
}

1;
