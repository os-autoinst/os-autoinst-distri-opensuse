# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Page to handle partition type (exteded, primary) for msdos partitions
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::MsdosPartitionTypePage;
use parent 'Installation::Navigation::NavigationBase';
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
    $self->SUPER::init();
    $self->{rb_primary}  = $self->{app}->radiobutton({id => '"primary"'});
    $self->{rb_extended} = $self->{app}->radiobutton({id => '"extended"'});
    return $self;
}

sub set_type {
    my ($self, $type) = @_;
    $self->select_type($type) if $type;
    $self->press_next();
}

sub select_type {
    my ($self, $type) = @_;
    my %types = (
        primary  => $self->{rb_primary},
        extended => $self->{rb_extended}
    );
    return $types{$type}->select();
}

1;
