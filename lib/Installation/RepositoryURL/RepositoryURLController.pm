# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Repository URL dialog.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::RepositoryURL::RepositoryURLController;
use strict;
use warnings;
use Installation::RepositoryURL::RepositoryURLPage;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{RepositoryURL} = Installation::RepositoryURL::RepositoryURLPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_repository_url_page {
    my ($self) = @_;
    die 'Repository URL page is not displayed' unless $self->{RepositoryURL}->is_shown();
    return $self->{RepositoryURL};
}

sub add_repo {
    my ($self, $args) = @_;
    $self->get_repository_url_page()->enter_repo_name($args->{name}) if $args->{name};
    $self->get_repository_url_page()->enter_url($args->{url});
    $self->get_repository_url_page()->press_next();
}

1;
