# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods action buttons in yast2 lan YaST module.
# The buttons in the bottom of the screen that are available across all the pages (e.g. "Next", "Cancel");
# This is a part of a screen and it has to be included in Network Settings Controller.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::ActionButtons;
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
    $self->{btn_ok} = $self->{app}->button({id => 'next'});
    return $self;
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

1;
