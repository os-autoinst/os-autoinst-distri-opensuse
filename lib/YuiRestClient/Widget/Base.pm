# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Widget::Base;

use strict;
use warnings;

sub new {
    my ($class, $args) = @_;

    return bless {
        widget_controller => $args->{widget_controller},
        filter            => $args->{filter},
    }, $class;
}

sub action {
    my ($self, %args) = @_;
    # Inject filter parameters to the request
    my $params = {%args, %{$self->{filter}}};
    $self->{widget_controller}->send_action($params);

    return $self;
}

sub exist {
    my ($self) = @_;

    eval { $self->find_widgets() };
    return 0 if $@;
    return 1;
}

sub property {
    my ($self, $property) = @_;

    my $res = $self->find_widgets();
    # JSON always contains array if results, return first entry
    if (ref $res eq 'ARRAY' && ref $res->[0] eq 'HASH') {
        return $res->[0]->{$property};
    }

    return undef;
}

sub find_widgets {
    my ($self) = @_;

    return $self->{widget_controller}->find($self->{filter});
}

sub sanitize {
    my ($self, $item) = @_;
    # remove shortcut
    $item =~ s/&//;
    return $item;
}

1;
