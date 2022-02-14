# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Repository URL.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::RepositoryURL::RepositoryURLPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{tbx_repo_name} = $self->{app}->textbox({id => 'repo_name'});
    $self->{tbx_url} = $self->{app}->textbox({id => 'url'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbx_url}->exist();
}

sub enter_repo_name {
    my ($self, $name) = @_;
    $self->{tbx_repo_name}->set($name);
}

sub enter_url {
    my ($self, $url) = @_;
    $self->{tbx_url}->set($url);
}

1;
