# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: This class introduces methods to handle Suggested Partitioning page.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::SuggestedPartitioningPage;
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
    $self->{summary}          = $self->{app}->richtext({id => 'summary'});
    $self->{btn_guided_setup} = $self->{app}->button({id => 'guided'});
    $self->{btn_next}         = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{summary}->exist();
}

sub select_guided_setup {
    my ($self) = @_;
    return $self->{btn_guided_setup}->click();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

1;
