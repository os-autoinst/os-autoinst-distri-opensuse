# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Expert Partitioner Page to handle partition size
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::NewPartitionSizePage;
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
    $self->{tb_size} = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::PartitionSize::CustomSizeInput"'});
    return $self;
}

1;
