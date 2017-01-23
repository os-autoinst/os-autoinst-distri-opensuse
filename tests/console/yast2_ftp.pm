# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check yast ftp-server options and ability to start vsftpd with ssl support
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "consoletest";
use testapi;

sub run() {
    select_console 'root-console';

    # install vsftps
    assert_script_run("zypper -n -q in vsftpd yast2-ftp-server");

    # bsc#694167
    # create RSA certificate for ftp server at first which can be used for SSL configuration
    # type_string("openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout /etc/vsftpd.pem -out /etc/vsftpd.pem\n");

    # create DSA certificate for ftp server at first which can be used for SSL configuration
    script_run("openssl dsaparam -out dsaparam.pem 1024");
    type_string(
        "openssl req -x509 -nodes -days 365 -newkey dsa:dsaparam.pem -keyout /etc/vsftpd.pem -out /etc/vsftpd.pem\n");

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
    script_run("yast2 ftp-server; echo yast2-ftp-server-status-\$? > /dev/$serialdev", 0);
    assert_screen 'ftp-server';                    # check ftp server configuration page
    send_key 'alt-w';                              # make sure ftp start-up when booting
    check_screen 'ftp_server_when_booting';        # check service start when booting

    # General
    send_key_until_needlematch 'yast2_ftp_start-up_selected', 'shift-tab';
    wait_still_screen 1;
    send_key 'down';
    wait_still_screen 1;
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
    wait_still_screen 1;
    type_string '/srv/ftp/authenticated';
    assert_screen 'yast2_ftp_general_directories';    # check new directories for ftp users
    send_key 'alt-o';
    assert_screen 'yast2_ftp_directory_browse';
    send_key 'alt-c';

    # Performance
    send_key_until_needlematch 'yast2_tftp_general_selected', 'shift-tab';
    send_key 'down';
    wait_still_screen 1;
    send_key 'ret';
    wait_still_screen 1;
    send_key 'alt-m';
    for (1 .. 5) { send_key 'down'; }
    send_key 'alt-e';    # change max client for one IP
    for (1 .. 4) { send_key 'up'; }
    send_key 'alt-x';    # change max clients to 20
    for (1 .. 11) { send_key 'up'; }
    send_key 'alt-l';    # change local max rate to 100 kb/s
    for (1 .. 20) { send_key 'up'; }
    send_key 'alt-r';    # change anonymous max rate to 50 kb/s
    for (1 .. 10) { send_key 'up'; }
    assert_screen 'yast2_ftp_performance-settings';    # check performance settings

    # Authentication
    send_key_until_needlematch 'yast2_tftp_performance_selected', 'shift-tab';
    send_key 'down';
    wait_still_screen 1;
    send_key 'ret';
    wait_still_screen 1;
    send_key 'alt-e';
    assert_screen 'yast2_ftp_authentication_enabled';
    send_key 'alt-y';
    wait_still_screen 1;
    send_key 'alt-s';
    send_key 'alt-s';                              # disable creating directories
    assert_screen 'yast2_ftp_anonymous_upload';    # check upload settings

    # Expert Settings
    send_key_until_needlematch 'yast2_tftp_authentication_selected', 'shift-tab';
    send_key 'down';
    wait_still_screen 1;
    send_key 'ret';
    wait_still_screen 1;
    assert_screen 'yast2_ftp_create_upload_dir_confirm';    # confirm to create upload directory
    send_key 'alt-y';
    wait_still_screen 1;
    send_key 'alt-m';
    for (1 .. 4) { send_key 'down'; }
    send_key 'alt-a';
    for (1 .. 4) { send_key 'up'; }
    send_key 'alt-l';                                       # enable SSL
    assert_screen 'yast2_ftp_expert_settings';              # check passive mode value and enable SSL
    send_key 'alt-s';                                       # give path for DSA certificate
    type_string '/etc/vsftpd.pem';
    send_key 'alt-p';                                       # open port in firewall
    wait_still_screen 1;
    send_key 'alt-f';                                       # done and close the configuration page now


    # yast might take a while on sle12 due to suseconfig
    wait_serial("yast2-ftp-server-status-0", 60) || die "'yast2 ftp-server' didn't finish";

    # let's try to run it
    assert_script_run "systemctl start vsftpd.service";
    assert_script_run("systemctl is-active vsftpd", fail_message => 'bsc#975538');
}
1;

# vim: set sw=4 et:
