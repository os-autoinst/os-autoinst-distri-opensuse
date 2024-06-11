use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self, $run_args) = @_;
    record_info($run_args->{msg});
    $run_args->{msg} = 'Bye';
}

1;
