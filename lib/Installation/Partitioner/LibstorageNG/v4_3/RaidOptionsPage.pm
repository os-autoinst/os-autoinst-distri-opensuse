# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handle page to set RAID options, like chunk size in the Expert Partitioner
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::RaidOptionsPage;
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
    $self->{btn_next}      = $self->{app}->button({id => 'next'});
    $self->{cb_chunk_size} = $self->{app}->combobox({id => '"Y2Partitioner::Dialogs::MdOptions::ChunkSize"'});

    return $self;
}

sub select_chunk_size {
    my ($self, $chunk_size) = @_;
    $self->{cb_chunk_size}->select($chunk_size);
}

sub press_next {
    my ($self) = @_;
    $self->{btn_next}->click();
}

1;
