# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This class introduces methods to handle Common Criteria setup page.
#
# Maintainer: QE Security <none@suse.de>

package Installation::CommonCriteriaConfiguration::CommonCriteriaConfigurationPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{txb_password} = $self->{app}->textbox({id => 'passphrase'});
    $self->{txb_repeat_password} = $self->{app}->textbox({id => 'repeat_passphrase'});
    return $self;
}

sub enter_password {
    my ($self, $password) = @_;
    return $self->{txb_password}->set($password);
}

sub enter_confirm_password {
    my ($self, $password) = @_;
    return $self->{txb_repeat_password}->set($password);
}

sub is_shown {
    my ($self) = @_;
    return $self->{txb_password}->exist();
}

1;
