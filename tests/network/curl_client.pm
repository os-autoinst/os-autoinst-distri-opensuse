# SUSE"s openQA tests
# #
# # Copyright © 2019 SUSE LLC
# #
# # Copying and distribution of this file, with or without modification,
# # are permitted in any medium without royalty provided the copyright
# # notice and this notice are preserved.  This file is offered as-is,
# # without any warranty.
#
# Summary: Test regression to curl.
#  this test curl with http, https, ldap, ftp and ntlm auth
#  poo#51536
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use lockapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    #waiting curl server ready.
    mutex_wait('curl_server_ready');
    record_info 'Waiting Server', 'Waiting Curl-server to start tests.';

    #start curl tests
    assert_script_run('curl -f -v http://10.0.2.101/get 2>&1');
    assert_script_run('curl -f -v https://httpbin.org/get 2>&1');
    assert_script_run('curl "ldap://10.0.2.101/dc=green,dc=com??sub?(uid=julius)"');
    assert_script_run('curl ftp://10.0.2.101');

    #Tests dones. Curl server stop.
    mutex_create('CURL_DONE');
    record_info 'Curl Done', 'Curl done tests';
}
1;
