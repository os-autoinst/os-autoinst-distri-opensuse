# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Overview Tab in YaST2
# lan module dialog
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::v4_3::OverviewTab;
use parent 'YaST::NetworkSettings::OverviewTab';
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{tbl_devices} = $self->{app}->table({id => '"Y2Network::Widgets::InterfacesTable"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_devices}->exist();
}

1;
