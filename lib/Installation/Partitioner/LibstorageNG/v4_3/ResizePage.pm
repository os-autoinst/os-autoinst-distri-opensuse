# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Page to handle resize of a partition in the Expert Partitioner.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::v4_3::ResizePage;
use strict;
use warnings;
use parent 'Installation::Partitioner::LibstorageNG::v4_3::AbstractSizePage';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self) = shift;
    $self->SUPER::init();
    $self->{txb_size} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::BlkDeviceResize::CustomSizeWidget"'});
    return $self;
}

1;
