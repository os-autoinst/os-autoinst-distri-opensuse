# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Wait;
use strict;
use warnings;


sub wait_until {
    my (%args) = @_;
    $args{timeout} //= 10;
    $args{interval} //= 1;
    $args{message} //= '';

    die "No object passed to the method" unless $args{object};

    my $counter = $args{timeout} / $args{interval};
    my $result;
    while ($counter--) {
        eval { $result = $args{object}->() };
        return $result if $result;
        sleep($args{interval});
    }

    my $error = "Timed out: @{[$args{message}]}\n";
    $error .= "\n$@" if $@;
    die $error;
}

1;
