# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle page to set RAID options, like chunk size in the Expert Partitioner
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::RaidOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;
use testapi;

use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{cmb_chunk_size} = $self->{app}->combobox({id => '"Y2Partitioner::Dialogs::MdOptions::ChunkSize"'});

    return $self;
}

sub select_chunk_size {
    my ($self, $chunk_size) = @_;
    $self->{cmb_chunk_size}->select($chunk_size);
}

1;
