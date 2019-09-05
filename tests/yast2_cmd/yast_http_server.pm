# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Setup http-server and check if it works well.
# - setup main server
# - create and setup virtual host
# - check http server working well
# - setup other options
# - stop http server and clean up tmp files
# Maintainer: Shukui Liu <skliu@suse.com>

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
EOF';

sub check_bsc1145399 {
    my $ret_grep1 = script_run "grep 'SSL 0' /etc/apache2/vhosts.d/localhost.conf ";
    if ($ret_grep1 == 0) {
        record_soft_failure "bsc#1145399, yast http-server hosts create ... should not result in syntax error.";
        assert_script_run "sed -i '/SSL 0/d' /etc/apache2/vhosts.d/localhost.conf";
        return 1;
    }
    return;
}

sub run {
    select_console 'root-console';
    zypper_call 'in yast2-http-server';
    assert_script_run 'mkdir -p /srv/www/htdocs/new_dir';

    # create a tmp file for testing
    assert_script_run "$creat_tmp_file\n(exit $?)";


    # create and setup virtual host
    if (is_sle('=15-sp1')) {
        # setup main server
        my $output;
        $output = script_output('yast http-server configure host=main servername=sle serveradmin=root@sle documentroot=/srv/www/htdocs 2>&1', proceed_on_failure => 1);
        $output =~ m#Internal error# && record_soft_failure "bsc#1145538 yast http-server should not give internal error";

        type_string "yast http-server hosts create servername=localhost serveradmin=admin\@localhost documentroot=/srv/www/htdocs/new_dir \n";
        wait_still_screen 10;
        send_key "alt-d";
        send_key "alt-o";
        wait_still_screen 10;
    } else {
        # setup main server
        assert_script_run 'yast http-server configure host=main servername=sle serveradmin=root@sle documentroot=/srv/www/htdocs';

        assert_script_run 'yast http-server hosts create servername=localhost serveradmin=admin@localhost documentroot=/srv/www/htdocs/new_dir';
    }

    if (check_bsc1145399) {
        type_string "yast http-server hosts list \n";
        wait_still_screen 10;
        send_key "alt-d";
        send_key "alt-o";
        wait_still_screen 10;
    }

    #check http server working well
    my $server = script_output('yast http-server hosts list 2>&1|grep localhost');
    $server =~ s#/localhost##;
    systemctl('start apache2.service');
    systemctl('is-active apache2.service');
    validate_script_output "curl http://$server/tmp.html", sub { m/hello world!/ };

    # setup other options
    assert_script_run 'yast http-server listen add=81';
    validate_script_output 'yast http-server listen list 2>&1', sub { m/81/ };
    assert_script_run 'yast http-server mode wizard=on;! test -f /var/lib/YaST2/http_server';
    assert_script_run 'yast http-server mode wizard=off; test -f /var/lib/YaST2/http_server';
    assert_script_run 'yast http-server modules enable=cgi';
    validate_script_output 'yast http-server modules list 2>&1', sub { m/enabled\s+cgi/i };
    assert_script_run 'yast http-server modules disable=cgi';
    validate_script_output 'yast http-server modules list 2>&1', sub { m/disabled\s+cgi/i };

    # stop http server and clean up the tmp files
    systemctl('stop apache2.service');
    assert_script_run('rm -rf /srv/www/htdocs/new_dir/');
}

1;
