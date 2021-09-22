# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Warning Popups
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Warnings::WarningsController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Warnings::ConfirmationWarning;
use Test::Assert 'assert_matches';

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{ConfirmationWarning} = Installation::Warnings::ConfirmationWarning->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_warning {
    my ($self) = @_;
    return $self->{ConfirmationWarning};
}

sub get_text {
    my ($self) = @_;
    $self->get_warning->text();
}

sub check_warning {
    my ($self, $args_ref) = @_;
    my $expected_text = $args_ref->{expected_text};
    my $actual_text = $self->get_text();
    assert_matches(qr/$expected_text/, $actual_text, "Text not matching the expected \"$expected_text\"");
}

sub accept_warning {
    my ($self) = @_;
    $self->get_warning->press_yes();
}

1;
