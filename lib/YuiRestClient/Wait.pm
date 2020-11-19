# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Wait;
use strict;
use warnings;


sub wait_until {
    my (%args) = @_;
    $args{timeout}  //= 10;
    $args{interval} //= 1;
    $args{message}  //= '';

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
