# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Page to handle resize of a partition in the Expert Partitioner.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ResizePage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{tb_size}        = $self->{app}->textbox({id => '"Y2Partitioner::Dialogs::BlkDeviceResize::CustomSizeWidget"'});
    $self->{rb_custom_size} = $self->{app}->radiobutton({id => 'custom_size'});
    $self->{btn_next}       = $self->{app}->button({id => 'next'});
    return $self;
}

sub set_custom_size {
    my ($self, $size) = @_;
    $self->{rb_custom_size}->select();
    return $self->{tb_size}->set($size);
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
