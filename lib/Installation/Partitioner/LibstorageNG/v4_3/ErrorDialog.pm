# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces methods in Expert Partitioner to handle
# an Error Dialog.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ErrorDialog;
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
    $self->{btn_ok}      = $self->{app}->button({id => 'ok'});
    $self->{rt_error}    = $self->{app}->richtext({type => 'YRichText'});
    $self->{lbl_heading} = $self->{app}->label({label => 'Error'});
    return $self;
}

sub text {
    my ($self) = @_;
    $self->{rt_error}->text();
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

sub is_shown {
    my ($self) = @_;
    $self->{lbl_heading}->exist();
}

sub confirm {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->is_shown();
    });
    $self->press_ok();
}

1;
