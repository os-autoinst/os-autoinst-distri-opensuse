# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient;
use strict;
use warnings;

our $interval = 0.5;
our $timeout  = 10;

use constant API_VERSION => 'v1';

sub set_interval {
    $interval = shift;
}

sub set_timeout {
    $timeout = shift;
}

sub wait_until {
    my (%args) = @_;
    $args{timeout}  //= $timeout;
    $args{interval} //= $interval;
    $args{message}  //= '';

    die "No object passed to the method" unless $args{object};

    my $counter = $args{timeout} / $args{interval};
    my $result;
    while ($counter--) {
        eval { $result = $args{object}->() };
        return $result if $result;
        sleep(1);
    }

    my $error = "Timed out: @{[$args{message}]}\n";
    $error .= "\n$@" if $@;
    die $error;
}

1;
