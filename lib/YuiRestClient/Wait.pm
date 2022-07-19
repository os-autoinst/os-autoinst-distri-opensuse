# SUSE's openQA tests

package YuiRestClient::Wait;
use strict;
use warnings;

use DateTime;

sub wait_until {
    my (%args) = @_;
    $args{timeout} //= 10;
    $args{interval} //= 1;
    $args{message} //= '';

    my $result;
    my $error;

    die "No object passed to the method" unless $args{object};

    if ($args{timeout}) {
        my $end_time = DateTime->now()->clone->add(seconds => $args{timeout});
        while ($end_time->compare(DateTime->now()) > 0) {
            eval { $result = $args{object}->() };
            return $result if $result;
            sleep($args{interval});
        }
        $error = "Timed out: @{[$args{message}]}\n";
    }
    else {
        eval { $result = $args{object}->() };
        return $result if $result;
    }

    $error .= "\n$@" if $@;
    die $error;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Wait - Wait for something

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

wait_until ( object => sub {...}, timeout => 10, interval => 1, message => '');


=head1 DESCRIPTION

=head2 Overview

This class implements a method to wait for external triggers. The trigger is defined as
a parameter called object which should define a sub that e.g. runs external commands. 
The method waits for a defined amount of time if the object function returned a value,
if not it will die with a timeout message.

=head2 Class and object methods

B<wait_until(%args)> - Wait until trigger or timeout

The %args hash has the following named elements:

=over 4

=item * B<{object}> - defines the external function that should return a value within the specified time. 
If no object is provided the method will die with an error message.

=item * B<{timeout}> - defines the time to wait in seconds for the trigger to occur. The default is 10.

=item * B<{intervall}> - defines how many seconds to wait before evaluating the object function again. 
The default is 1.

=item * B<{message}> - the error message that is used when the method timed out. 

=back

With all defaults this means, that the object function is evaluated every second for a maximum
time of 10 seconds. If the object function does not succeed then the method dies and displays the
error message. If the object function returned an error code in $@ then this error will be appended 
to the message. 

=cut
