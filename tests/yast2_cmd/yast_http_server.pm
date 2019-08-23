#-*- coding: utf-8 -*-
# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: this test checks "yast http-server" module.
#          this module configure ftp-server services in yast command line mode.
# Maintainer: Shukui Liu <skliu@suse.com>

=head1 Create regression test for http-server and verify

Reference:
https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.15

title: "yast http-server" regression tests.

description: use "yast http-server" to setup HTTP server.

environment:

1), mkdir for virtual host.
#mkdir -p /srv/www/htdocs/new_dir

2), make temp html file for 为virtual host.
#cat /srv/www/htdocs/new_dir/tmp.html
<!DOCTYPE html>
<html>

<head>
<meta charset="utf-8">
<title>hello world</title>
</head>

<body>
hello world!
</body>

</html>


test case:
=====================================================
usecase1: setup HTTP server

steps:

1: setup main server

    #yast http-server configure host=main servername=sles15-vt5810 serveradmin=root@sles15-vt5810 documentroot=/srv/www/htdocs

2, create and setup virtual host
    #yast http-server hosts create servername=localhost serveradmin=admin@localhost documentroot=/srv/www/htdocs/new_dir

3, start http server
    #systemctl start apache2.service

4, check http server working well.
    #curl http://127.0.0.1/tmp.html

expected result:
html content is printed on screen.

=====================================================
usecase2: setup the listening port for http server

    #yast http-server listen add=81
    #yast http-server listen list

expected result:
all listening ports of the http server.

=====================================================
usecase3: open, close wizard mode
steps:

1, #yast http-server mode wizard=on
2, #yast http-server mode wizard=off

expected result:
step1, /var/lib/YaST2/http_server file does not exist.
step2, /var/lib/YaST2/http_server file exists.

=====================================================
usecase4: enable, disable http server's module wsgi-python3

steps:

1,
    #yast http-server modules enable=cgi
    #yast http-server modules list 2>&1 | grep cgi
2,
    #yast http-server modules disable=cgi
    #yast http-server modules list 2>&1 | grep cgi

expected result:
step1, Enabled cgi
step2, Disabled cgi


=cut

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';


# this is a tmp file for testing
my $creat_tmp_file = 'cat > /srv/www/htdocs/new_dir/tmp.html << EOF
<!DOCTYPE html>
<html>

<head>
    <meta charset="utf-8">
    <title>hello world</title>
</head>

<body>
hello world!
</body>

</html>
EOF
(exit $?)';

sub check_bsc1145399 {
    my $ret_grep1 = script_run "grep 'SSL 0' /etc/apache2/vhosts.d/localhost.conf ";
    if ($ret_grep1 == 0) {
        record_soft_failure "bsc#1145399, yast http-server hosts create ... should not result in syntax error.";
        assert_script_run "sed -i '/SSL 0/d' /etc/apache2/vhosts.d/localhost.conf";
        return 1;
    }
    return 0;
}

sub run {
    select_console 'root-console';
    zypper_call 'in yast2-http-server';
    assert_script_run 'mkdir -p /srv/www/htdocs/new_dir';
    # create a tmp file for testing
    assert_script_run $creat_tmp_file;

    assert_script_run 'yast http-server configure host=main servername=sle serveradmin=root@sle documentroot=/srv/www/htdocs';


    if (is_sle('=15-sp1')) {
        type_string "yast http-server hosts create servername=localhost serveradmin=admin\@localhost documentroot=/srv/www/htdocs/new_dir \n";
        wait_still_screen 10;
        send_key "alt-d";
        send_key "alt-o";
        wait_still_screen 10;
        record_soft_failure "bsc#1145538 yast http-server should not give internal error";

    } else {
        assert_script_run 'yast http-server hosts create servername=localhost serveradmin=admin@localhost documentroot=/srv/www/htdocs/new_dir';
    }


    if (check_bsc1145399) {
        type_string "yast http-server hosts list \n";
        wait_still_screen 10;
        send_key "alt-d";
        send_key "alt-o";
        wait_still_screen 10;
    }

    my $server = script_output('yast http-server hosts list 2>&1|grep localhost');
    $server =~ s#/localhost##;
    systemctl('start apache2.service');
    systemctl('is-active apache2.service');
    validate_script_output "curl http://$server/tmp.html", sub { m/hello world!/ };

    assert_script_run 'yast http-server listen add=81';
    validate_script_output 'yast http-server listen list 2>&1', sub { m/81/ };

    assert_script_run 'yast http-server mode wizard=on;! test -f /var/lib/YaST2/http_server';

    assert_script_run 'yast http-server mode wizard=off; test -f /var/lib/YaST2/http_server';

    assert_script_run 'yast http-server modules enable=cgi';
    validate_script_output 'yast http-server modules list 2>&1', sub { m/enabled\s+cgi/i };
    assert_script_run 'yast http-server modules disable=cgi';
    validate_script_output 'yast http-server modules list 2>&1', sub { m/disabled\s+cgi/i };
    systemctl('stop apache2.service');
    assert_script_run('rm -rf /srv/www/htdocs/new_dir/');

}

1;
