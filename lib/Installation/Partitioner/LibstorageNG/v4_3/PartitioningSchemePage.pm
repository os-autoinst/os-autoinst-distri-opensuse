# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces methods to handle Partitioning Scheme page.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::PartitioningSchemePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

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
    $self->{cb_enable_lvm} = $self->{app}->combobox({id => 'lvm'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cb_enable_lvm}->exist();
}

1;
