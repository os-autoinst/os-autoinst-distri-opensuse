# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Expert Partitioner
# Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4::_3::ExpertPartitionerPage;
use strict;
use warnings;
use testapi;
use parent 'Installation::Partitioner::LibstorageNG::ExpertPartitionerPage';

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

    $self->{btn_add_partition} = $self->{app}->button({id => '"Y2Partitioner::Widgets::PartitionAddButton"'});
    $self->{tree_system_view}  = $self->{app}->tree({id => '"Y2Partitioner::Widgets::OverviewTree"'});

    return $self;
}

sub select_disk {
    my ($self, $disk) = @_;

    YuiRestClient::wait_until(object => sub {
            $self->{tree_system_view}->exist();
    }, message => 'Cannot access system view tree');

    $self->{tree_system_view}->select('Hard Disks|' . $disk);

    return $self;
}

sub press_add_partition_button {
    my ($self) = @_;
    $self->{btn_add_partition}->click();
    return $self;
}

1;
