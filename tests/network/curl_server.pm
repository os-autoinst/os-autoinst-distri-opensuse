# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Server configurations to test curl .
# Maintainer: Marcelo Martins <mmartins@@suse.com>

use base 'opensusebasetest';
use warnings;
use strict;
use testapi;
use mmapi;
use lockapi;

sub run {
    #run on serial console.
    my $self = shift;
    $self->select_serial_terminal;

    #preparing files will be use by client side.
    assert_script_run(' echo "Hello World!!" > /srv/www/htdocs/get');
    assert_script_run(' echo "Hello World!!" > /srv/ftp/file_test');

    #Server ready, mutex to client continue....
    mutex_create('curl_server_ready');
    record_info 'Curl start', 'Curl client test start.';

    # waiting Curl client end tests.
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_wait('CURL_DONE', $child_id);
    record_info 'Curl test ends', 'Curl client test ends.';
}
1;
