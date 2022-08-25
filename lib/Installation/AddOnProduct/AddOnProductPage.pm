# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Add On Product
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AddOnProduct::AddOnProductPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{chb_add_addon} = $self->{app}->checkbox({id => 'add_addon'});
    $self->{rdb_specify_url} = $self->{app}->radiobutton({id => 'specify_url'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    # on slower archs like aarch64 the system probing might take longer, so
    # we extend the timeout for this page to appear
    return $self->{rdb_specify_url}->exist({timeout => 240});
}

sub confirm_like_additional_add_on {
    my ($self) = @_;
    $self->{chb_add_addon}->check();
}

1;
