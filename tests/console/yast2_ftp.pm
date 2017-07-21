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
use base "console_yasttest";
use testapi;
use utils qw(type_string_slow zypper_call);

sub run {
    select_console 'root-console';

    # install vsftps
    zypper_call("-q in vsftpd yast2-ftp-server");

    # bsc#694167
    # create RSA certificate for ftp server at first which can be used for SSL configuration
    # type_string("openssl req -x509 -nodes -days 365 -newkey rsa:1024 -keyout /etc/vsftpd.pem -out /etc/vsftpd.pem\n");

    # create DSA certificate for ftp server at first which can be used for SSL configuration
    script_run("openssl dsaparam -out dsaparam.pem 1024");
    type_string_slow("openssl req -x509 -nodes -days 365 -newkey dsa:dsaparam.pem \\\n"
          . "-subj '/C=DE/ST=Bayern/L=Nuremberg/O=Suse/OU=QA/CN=localhost/emailAddress=admin\@localhost' \\\n"
          . "-keyout /etc/vsftpd.pem -out /etc/vsftpd.pem\n");

    assert_script_run("`[[ -e /etc/vsftpd.pem ]]`");    # check vsftpd.pem is created

    # start yast2 ftp configuration
    type_string "yast2 ftp-server; echo yast2-ftp-server-status-\$? > /dev/$serialdev\n";
    assert_screen 'ftp-server';                         # check ftp server configuration page
    send_key 'alt-w';                                   # make sure ftp start-up when booting
    assert_screen 'ftp_server_when_booting';            # check service start when booting

    # General
    send_key_until_needlematch 'yast2_ftp_start-up_selected', 'tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };              # enter page General

    assert_screen 'yast2_tftp_general_selected';
    assert_screen 'ftp_welcome_mesage';                 # check welcome message for add strings
    send_key 'alt-w';                                   # select welcome message to edit
    send_key_until_needlematch 'yast2_tftp_empty_welcome_message', 'backspace';    # delete existing welcome strings
    type_string 'This is QA FTP server, welcome!';                                 # type new welcome text
    assert_screen 'ftp_welcome_message_added';                                     # check new welcome text
    send_key 'alt-u';                                                              # select umask for anounymous
    type_string '0022';                                                            # set 755
    send_key 'alt-s';                                                              # select umask for authenticated users
    type_string '0022';                                                            # set 755
    assert_screen 'ftp_umask_value';                                               # check umask value
    wait_screen_change { send_key 'alt-y' };                                       # give a new directory for anonymous users
    send_key_until_needlematch 'yast2_tftp_empty_anon_dir', 'backspace';
    type_string '/srv/ftp/anonymous';
    send_key 'alt-t';                                                              # give a new directory for authenticated users
    wait_still_screen 1;
    type_string '/srv/ftp/authenticated';
    assert_screen 'yast2_ftp_general_directories';                                 # check new directories for ftp users
    send_key 'alt-o';
    assert_screen 'yast2_ftp_directory_browse';
    send_key 'alt-c';

    # Performance
    send_key_until_needlematch 'yast2_tftp_general_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };
    send_key 'alt-m';
    type_string_slow "10\n";
    send_key 'alt-e';                                                              # change max client for one IP
    type_string_slow "7\n";
    send_key 'alt-x';                                                              # change max clients to 20
    type_string_slow "20\n";
    send_key 'alt-l';                                                              # change local max rate to 100 kb/s
    type_string_slow "100\n";
    send_key 'alt-r';                                                              # change anonymous max rate to 50 kb/s
    type_string_slow "50\n";
    assert_screen 'yast2_ftp_performance-settings';                                # check performance settings

    # Authentication
    send_key_until_needlematch 'yast2_tftp_performance_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };
    send_key 'alt-e';
    assert_screen 'yast2_ftp_authentication_enabled';
    wait_screen_change { send_key 'alt-y' };
    send_key_until_needlematch 'yast2_tftp_anon_create_dir_disabled', 'alt-s';     # disable creating directories
    assert_screen 'yast2_ftp_anonymous_upload';                                    # check upload settings

    # Expert Settings
    send_key_until_needlematch 'yast2_tftp_authentication_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    assert_screen 'yast2_ftp_create_upload_dir_confirm';                           # confirm to create upload directory
    wait_screen_change { send_key 'alt-y' };
    wait_screen_change { send_key 'alt-m' };
    type_string_slow "30000\n";
    wait_screen_change { send_key 'alt-a' };
    type_string_slow "30100\n";
    wait_screen_change { send_key 'alt-l' };                                       # enable SSL
    assert_screen 'yast2_ftp_expert_settings';                                     # check passive mode value and enable SSL
    wait_screen_change { send_key 'alt-s' };                                       # give path for DSA certificate
    type_string '/etc/vsftpd.pem';
    wait_screen_change { send_key 'alt-p' };                                       # open port in firewall
    send_key 'alt-f';                                                              # done and close the configuration page now

    # yast might take a while on sle12 due to suseconfig
    die "'yast2 ftp-server' didn't exit with zero exit code in defined timeout" unless wait_serial("yast2-ftp-server-status-0", 180);

    # let's try to run it
    assert_script_run "systemctl start vsftpd.service";
    assert_script_run("systemctl is-active vsftpd", fail_message => 'bsc#975538');
}
1;

# vim: set sw=4 et:
