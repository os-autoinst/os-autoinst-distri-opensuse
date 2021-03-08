# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act on pop-up when license is not
#          accepted.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::SLE::AcceptLicensePopup;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_ok}   = $self->{app}->button({id => 'ok'});
    $self->{lbl_text} = $self->{app}->checkbox({label => 'You must accept the license to install this product'});

    return $self;
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_text}->exist();
}

1;
