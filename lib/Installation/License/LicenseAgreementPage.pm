# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Page to handle License Agreement page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::License::LicenseAgreementPage;
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
    my ($self, $args) = @_;
    $self->{btn_next}    = $self->{app}->button({id => 'next'});
    $self->{cb_language} = $self->{app}->combobox($args->{cb_language_filter});
    $self->{rt_eula}     = $self->{app}->richtext($args->{rt_eula_filter});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rt_eula}->exist();
}

sub get_available_languages {
    my ($self) = @_;
    return $self->{cb_language}->items();
}

sub get_eula_content {
    my ($self) = @_;
    return $self->{rt_eula}->text();
}

sub get_selected_language {
    my ($self) = @_;
    return $self->{cb_language}->value();
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}

sub select_language {
    my ($self, $item) = @_;
    return $self->{cb_language}->select($item);
}

1;
