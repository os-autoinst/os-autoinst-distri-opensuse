# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen for textmode display.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootTextmodePage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {}, $class;
}

sub reboot {
    my ($self) = @_;
    enter_cmd 'reboot';
}

sub expect_is_shown {
    my ($self, %args) = @_;
   #  my $timeout = $args{timeout};
   my $timeout = 7200;
   #  my $s3270 = console('x3270');
   #  my $r;

    while (1) {
        # script_run('agama logs store');
        script_run('tail /var/log/YaST2/y2log');

        die "timeout ($timeout) hit on during installation" if $timeout <= 0;
        # $r = $s3270->expect_3270(
        #     output_delim => qr/Installation Finished/,
        #     timeout => 300
        #     );
        #      last;
        # } else {
            $timeout -= 30;
            diag("left total timeout: $timeout");
            next;
        }
}

1;
