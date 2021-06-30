# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Filter;

use strict;
use warnings;

use YuiRestClient::Sanitizer;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        resolved => 1
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    # as only one regex makes sense, get the first element
    my ($regex_key) = grep { ref $args->{$_} eq ref qr// } keys %{$args};
    if ($regex_key) {
        $self->{regex} = {k => $regex_key, v => $args->{$regex_key}};
        delete $args->{$regex_key};
        $self->{resolved} = 0;
    }
    $self->{filter} = $args;
    return $self;
}

sub get_filter {
    my ($self) = @_;
    return $self->{filter};
}

sub is_resolved {
    my ($self) = @_;
    return $self->{resolved};
}

sub resolve {
    my ($self, $json) = @_;
    my ($k,    $v)    = ($self->{regex}->{k}, $self->{regex}->{v});
    my @widgets = grep {
        defined $_->{$k} && YuiRestClient::Sanitizer::sanitize($_->{$k}) =~ $v
    } @{$json};
    if (scalar @widgets == 1) {
        $self->{filter}->{$k} = YuiRestClient::Sanitizer::sanitize($widgets[0]->{$k});
        $self->{resolved} = 1;
    }
}

1;
