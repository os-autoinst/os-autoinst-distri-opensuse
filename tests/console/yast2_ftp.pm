# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;



sub run() {

    select_console 'root-console';

    # install vsftps
    assert_script_run("/usr/bin/zypper -n -q in vsftpd yast2-ftp-server");

    # create DSA certificate for ftp server at first which canbe used for SSL configuration
    type_string("openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout /etc/vsftpd.pem -out /etc/vsftpd.pem\n");
    sleep 2;
    type_string "DE\n";
    type_string "bayern\n";
    type_string "nuremberg\n";
    type_string "SUSE\n";
    type_string "QA\n";
    type_string "localhost\n";
    type_string "admin\@localhost\n";


    assert_script_run("ls -l /etc/vsftpd.pem");    # check vsftpd.pem is created

    # start yast2 apache2 configuration
    script_run("/sbin/yast2 ftp-server; echo yast2-ftp-server-status-\$? > /dev/$serialdev", 0);
    assert_screen 'ftp-server';                    # check ftp server configuration page
    send_key 'alt-w';                              # make sure ftp start-up when booting
    check_screen 'ftp_server_when_booting';        # check service start when booting
    send_key 'shift-tab';                          # move to page General
    send_key 'down';
    send_key 'ret';                                # enter page General
    assert_screen 'ftp_welcome_mesage';            # check welcome message for add strings
    send_key 'alt-w';                              # select welcome message to edit
    for (1 .. 20) { send_key 'backspace'; }        # delete existing welcome strings
    type_string 'This is QA FTP server, welcome!'; # type new welcome text
    assert_screen 'ftp_welcome_message_added';     # check new welcome text
    send_key 'alt-u';                              # select umask for anounymous
    type_string '0022';                            # set 755
    send_key 'alt-s';                              # select umask for authenticated users
    type_string '0022';                            # set 755
    assert_screen 'ftp_umask_value';               # check umask value
    send_key 'alt-y';                              # give a new directory for anonymous users
    for (1 .. 20) { send_key 'backspace'; }
    type_string '/srv/ftp/anonymous';
    send_key 'alt-t';                              # give a new directory for authenticated users
    type_string '/srv/ftp/authenticated';
    assert_screen 'ftp_directories';               # check new directories for ftp users
    for (1 .. 8) { send_key 'shift-tab'; }         # move to Performance page
    send_key 'down';
    send_key 'ret';                                # change max idle time to 10 minutes
    send_key 'alt-m';
    for (1 .. 5) { send_key 'down'; }
    send_key 'alt-e';                              # change max client for one IP
    for (1 .. 4) { send_key 'up'; }
    send_key 'alt-x';                              # change max clients to 20
    for (1 .. 11) { send_key 'up'; }
    send_key 'alt-l';                              # change local max rate to 100 kb/s
    for (1 .. 20) { send_key 'up'; }
    send_key 'alt-r';                              # change anonymous max rate to 50 kb/s
    for (1 .. 10) { send_key 'up'; }
    assert_screen 'ftp_performance-settings';      # check performance settings
    for (1 .. 5) { send_key 'shift-tab'; }         # move to page Authentication
    send_key 'down';
    send_key 'ret';
    send_key 'alt-e';                              # enable upload
    send_key 'alt-y';
    send_key 'alt-s';
    send_key 'alt-s';                              # disable creating directories
    assert_screen 'ftp_anonymous_setting';         # check upload settings
    for (1 .. 6) { send_key 'shift-tab'; }         # move to page Expert Settings
    send_key 'down';
    send_key 'ret';
    assert_screen 'ftp_create_upload_dir';         # confirm to create upload directory
    send_key 'alt-y';
    assert_screen 'ftp_expert_settings';           # change passive mode value and enable SSL
    send_key 'alt-m';
    for (1 .. 4) { send_key 'down'; }
    send_key 'alt-a';
    for (1 .. 4) { send_key 'up'; }
    send_key 'alt-l';                              # enable SSL
    send_key 'alt-s';                              #  give path for DSA certificate
    type_string '/etc/vsftpd.pem';
    send_key 'alt-p';                              # open port in firewall
    assert_screen 'ftp_expert_settings_done';      # check expert settings to finish
    send_key 'alt-f';

    # yast might take a while on sle12 due to suseconfig
    wait_serial("yast2-ftp-server-status-0", 60) || die "'yast2 ftp-server' didn't finish";

    # let's try to run it
    assert_script_run "systemctl start vsftpd.service";
    assert_script_run "systemctl show -p ActiveState vsftpd.service|grep ActiveState=active";
    assert_script_run "systemctl show -p SubState vsftpd.service|grep SubState=running";

}
1;

# vim: set sw=4 et:
