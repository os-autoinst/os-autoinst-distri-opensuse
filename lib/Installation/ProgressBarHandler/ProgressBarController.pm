# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for
#          taking care of progress bars that are shown in intermediate steps
#          during the installation.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ProgressBarHandler::ProgressBarController;
use strict;
use warnings;
use Installation::ProgressBarHandler::AbstractProgressBar;
use YuiRestClient;
use YuiRestClient::Wait;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{AbstractProgressBar} = Installation::ProgressBarHandler::AbstractProgressBar->new({app => YuiRestClient::get_app()});
    return $self;
}
my $iterations = 0;

sub check_progressbar_visible {
    my ($self, %args) = @_;
    $args{interval} //= 1;
    $args{clean_time} //= 20;

    if ($self->{AbstractProgressBar}->is_shown({timeout => 0})) {
        $iterations = 0;
        return 0;
    }

    $iterations++;
    if (($iterations * $args{interval}) < $args{clean_time}) {
        return 0;
    }
    return 1;
}

sub wait_progressbars_disappear {
    my ($self, $args) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->check_progressbar_visible(%$args);
    }, %$args);
}

1;
