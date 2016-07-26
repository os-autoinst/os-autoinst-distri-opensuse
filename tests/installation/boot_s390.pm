# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";

use testapi;
use strict;
use warnings;

use backend::console_proxy;

sub get_to_system() {
    my $s3270 = console('x3270');

    $s3270->sequence_3270("ENTER",);
    $s3270->sequence_3270("String(\"cp i cms\")",);
    $s3270->sequence_3270("ENTER",);
    $s3270->sequence_3270("ENTER",);
    $s3270->sequence_3270("String(\"cp i 150\")",);
    $s3270->sequence_3270("ENTER",);
    # sometimes we need to press an additional enter which shouldn't cause problems. This is actually how mgriessmeier would also do it, just blindly hit enter key until some stuff happens.
    $s3270->sequence_3270("ENTER",);

}

sub run() {
    my ($self) = @_;
    select_console 'x3270';
    $self->get_to_system();

    $self->result('ok');
}

1;
