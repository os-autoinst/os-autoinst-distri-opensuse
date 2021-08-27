# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods Top Navigation Bar in yast2 lan YaST module.
# This is a part of a screen and it has to be included in Network Settings Controller.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::TopNavigationBar;
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
    $self->{menu_bar} = $self->{app}->menucollection({id => '_cwm_tab'});
    return $self;
}

sub select_hostname_dns_tab {
    my ($self) = @_;
    $self->{menu_bar}->select('Ho&stname/DNS');
}

1;
