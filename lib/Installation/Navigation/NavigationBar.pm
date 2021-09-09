# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles Navigation bar
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Navigation::NavigationBar;
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
    my ($self, $args) = @_;
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_next}->exist();
}

sub press_next {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            return $self->{btn_next}->is_enabled();
    }, message => "Next button takes too long to be enabled");
    return $self->{btn_next}->click();
}

1;
