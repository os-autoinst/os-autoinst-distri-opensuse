# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
    $self->{rtx_summary} = $self->{app}->richtext({id => 'summary'});
    $self->{btn_guided_setup} = $self->{app}->button({id => 'guided'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rtx_summary}->exist();
}

sub get_text_summary() {
    my ($self) = @_;
    return $self->{rtx_summary}->text();
}

sub select_guided_setup {
    my ($self) = @_;
    return $self->{btn_guided_setup}->click();
}

1;
