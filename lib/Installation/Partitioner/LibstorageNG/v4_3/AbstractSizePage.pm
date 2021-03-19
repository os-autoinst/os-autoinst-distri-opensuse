# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Expert Partitioner Page to handles shared functionality
# for partition size. Classes implementing it will provide a new() method
# and its own textbox for 'tb_size' which is different depending on the type
# of partitioning.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::AbstractSizePage;
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->{rb_custom_size} = $self->{app}->radiobutton({id => 'custom_size'});
    $self->{btn_next}       = $self->{app}->button({id => 'next'});
    return $self;
}

sub set_custom_size {
    my ($self, $size) = @_;
    if ($size) {
        $self->{rb_custom_size}->select();
        $self->{tb_size}->set($size);
    }
    $self->press_next();
}

sub press_next {
    my ($self) = @_;
    $self->{btn_next}->click();
}

1;
