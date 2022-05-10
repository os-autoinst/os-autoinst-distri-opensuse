# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: vsftpd yast2-ftp-server openssl
# Summary: Check yast ftp-server options and ability to start vsftpd with ssl support
# FTP Server Wizard
# Step 1: Installs the package and dependencies;
# Step 2: Create certificate;
# Step 3: Run yast2 ftp configuration, set it to start on boot - confirm with a needle;
# Step 4: Full file integrity check of /etc/vsftpd.conf;
# Step 5: All yast2 ftp sub-menu-screens are opened and checked with a needle;
# Step 6: A FTP server is created;
# Step 7: Send finish command exits the app.
# Maintainer: Sergio R Lemke <slemke@suse.com>

use strict;
use warnings;
use base "y2_module_consoletest";
use testapi;
use utils;
use version_utils;

sub vsftd_setup_checker {
    my ($self, $config_ref) = @_;
    my $error = "";
    my @vsftpd_conf_tested_dirs = qw(pasv_min_port pasv_max_port anon_mkdir_write_enable anon_root anon_umask anon_upload_enable anon_max_rate chroot_local_user ftpd_banner local_root local_umask local_max_rate max_clients max_per_ip pasv_enable ssl_tlsv1);
    push @vsftpd_conf_tested_dirs, $self->{cert_directive};

    foreach (@vsftpd_conf_tested_dirs) {
        if (script_run("grep \"^$_=$config_ref->{$_}\" \/etc\/vsftpd\.conf")) {
            $error .= "vsftpd directive \"$_=$config_ref->{$_}\" not found in \/etc\/vsftpd\.conf\n";
        }
    }
    if ($error ne "") {
        script_run("echo \"$error\" > /tmp/failed_vsftpd_directives.log");
        die "Missing vsftpd\.conf directives";
    }
}

sub vsftpd_firewall_checker {
    die "service configuration file is missing in firewalld" if script_run("[[ -e /usr/lib/firewalld/services/vsftpd.xml ]]");
    die "vsftpd is not enabled in firewalld" if script_run("firewall-cmd --list-services | grep vsftpd");
    die "Ports for passive ftp are not configured" if script_run("firewall-cmd --permanent --service vsftpd --get-ports");
}

sub run {
    my $self = shift;
    $self->{cert_directive} = (is_sle('>12-SP2') || is_opensuse) ? 'rsa_cert_file' : 'dsa_cert_file';
    my $vsftpd_directives = {
        pasv_min_port => '30000',
        pasv_max_port => '30100',
        anon_mkdir_write_enable => 'NO',
        anon_root => '/srv/ftp/anonymous',
        ftpd_banner => "This is QA FTP server, welcome!",
        anon_umask => '0022',
        anon_upload_enable => 'YES',
        anon_max_rate => 51200,
        local_max_rate => 102400,
        chroot_local_user => 'NO',
        idle_session_timeout => 600,
        local_root => '/srv/ftp/authenticated',
        local_umask => '0022',
        log_ftp_protocol => 'YES',
        max_clients => '20',
        max_per_ip => '7',
        pasv_enable => 'YES',
        ssl_tlsv1 => 'YES'
    };
    $vsftpd_directives->{$self->{cert_directive}} = '/etc/vsftpd.pem';
    select_console 'root-console';

    # install vsftps
    zypper_call("in vsftpd yast2-ftp-server", timeout => 180);

    # clear any existing vsftpd leftover configs:
    script_run("rm /etc/vsftpd.conf");
    assert_script_run("rm -f /etc/vsftpd.pem");    #-f to not trigger error if file does not exist

    # bsc#694167 bsc#1183786
    # create RSA certificate for ftp server at first which can be used for SSL configuration
    if (is_sle('<=12-SP2')) {
        # script_run is used due to semicolon breaks the output
        assert_script_run("openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\\n"
              . "-subj '/C=DE/ST=Bayern/L=Nuremberg/O=Suse/OU=QA/CN=localhost/emailAddress=admin\@localhost' \\\n"
              . "-keyout $vsftpd_directives->{dsa_cert_file} -out $vsftpd_directives->{dsa_cert_file}");
    }
    else {
        assert_script_run("openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\\n"
              . " -subj '/C=DE/ST=Bayern/L=Nuremberg/O=Suse/OU=QA/CN=localhost/emailAddress=admin\@localhost' \\\n"
              . " -keyout $vsftpd_directives->{rsa_cert_file} -out $vsftpd_directives->{rsa_cert_file}");
    }

    # check vsftpd.pem is created
    assert_script_run("ls /etc/vsftpd.pem");

    # start yast2 ftp configuration
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'ftp-server');

    assert_screen 'ftp-server', 90;    # check ftp server configuration page

    if (is_sle('>15') || is_leap('>15.0') || is_tumbleweed) {
        send_key 'alt-t';    #opens service popup (start service after this config)
        send_key 'up';    #selects 'Start'
        send_key 'ret';    #confirm

        send_key 'alt-a';    #opens service popup (enable service after reboot)
        send_key 'up';    #selects 'Start on boot'
        send_key 'ret';    #confirm
    } else {
        send_key 'alt-w';    # make sure ftp start-up when booting
        send_key 'alt-d' if is_sle('=15');    # only sle 15 has this specific combination
    }

    assert_screen 'ftp_server_when_booting';    # check service start when booting

    # General
    send_key_until_needlematch 'yast2_ftp_start-up_selected', 'tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };    # enter page General
    assert_screen 'yast2_tftp_general_selected';
    assert_screen 'ftp_welcome_mesage';    # check welcome message for add strings
    send_key 'alt-w';    # select welcome message to edit
    send_key_until_needlematch 'yast2_tftp_empty_welcome_message', 'backspace';    # delete existing welcome strings
    type_string($vsftpd_directives->{ftpd_banner});    # type new welcome text
    assert_screen 'ftp_welcome_message_added';    # check new welcome text
    send_key 'alt-u';    # select umask for anounymous
    wait_still_screen 1;
    type_string($vsftpd_directives->{anon_umask});    # set 755
    send_key 'alt-s';    # select umask for authenticated users
    wait_still_screen 1;
    type_string($vsftpd_directives->{local_umask});    # set 755
    assert_screen 'ftp_umask_value';    # check umask value
    wait_screen_change { send_key 'alt-y' };    # give a new directory for anonymous users
    send_key_until_needlematch 'yast2_tftp_empty_anon_dir', 'backspace';
    type_string($vsftpd_directives->{anon_root});
    send_key 'alt-t';    # give a new directory for authenticated users
    wait_still_screen 1;
    type_string($vsftpd_directives->{local_root});
    assert_screen 'yast2_ftp_general_directories';    # check new directories for ftp users
    send_key 'alt-o';
    assert_screen 'yast2_ftp_directory_browse';
    send_key 'alt-c';

    # Performance
    send_key_until_needlematch 'yast2_tftp_general_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };
    send_key 'alt-m';    # max idle time in minutes to 10
    enter_cmd_slow($vsftpd_directives->{idle_session_timeout} / 60 . "");
    send_key 'alt-e';    # change max client for one IP
    enter_cmd_slow($vsftpd_directives->{max_per_ip} . "");
    send_key 'alt-x';    # change max clients to 20
    enter_cmd_slow($vsftpd_directives->{max_clients} . "");
    send_key 'alt-l';    # change local max rate to 100 kb/s
    enter_cmd_slow($vsftpd_directives->{local_max_rate} / 1024 . "");
    send_key 'alt-r';    # change anonymous max rate to 50 kb/s
    enter_cmd_slow($vsftpd_directives->{anon_max_rate} / 1024 . "");
    assert_screen 'yast2_ftp_performance-settings';    # check performance settings

    # Authentication
    send_key_until_needlematch 'yast2_tftp_performance_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'ret' };
    send_key 'alt-b';    # enable anon upload by authenticated an anon users
    send_key 'alt-e';
    assert_screen 'yast2_ftp_authentication_enabled';
    wait_screen_change { send_key 'alt-y' };
    send_key_until_needlematch 'yast2_tftp_anon_create_dir_disabled', 'alt-s';    # disable creating directories
    assert_screen 'yast2_ftp_anonymous_upload';    # check upload settings

    # Expert Settings
    send_key_until_needlematch 'yast2_tftp_authentication_selected', 'shift-tab';
    wait_screen_change { send_key 'down' };
    send_key 'ret';
    # Soft-fail bsc#1041829 on TW
    if (check_var('VERSION', 'Tumbleweed') && check_screen('yast2_ftp_syntax_error_bsc#1041829', 30)) {
        record_soft_failure('bsc#1041829');
        wait_screen_change { send_key 'alt-c'; };
        wait_screen_change { send_key 'alt-f'; };
        wait_still_screen;
        return;
    }

    assert_screen 'yast2_ftp_create_upload_dir_confirm';    # confirm to create upload directory
    wait_screen_change { send_key 'alt-y' };
    assert_screen 'yast2_ftp_expert_settings';    # check passive mode value and enable SSL
    wait_still_screen;    # wait until yast loads expert settings data
    send_key 'alt-m';
    enter_cmd_slow($vsftpd_directives->{pasv_min_port} . "");
    send_key 'alt-a';
    enter_cmd_slow($vsftpd_directives->{pasv_max_port} . "");
    wait_screen_change { send_key 'alt-l' };    # enable SSL, and wait with next step
    wait_still_screen;
    wait_screen_change { send_key 'alt-s' };    # give path for RSA certificate

    if (is_sle('>=12-SP3') || is_opensuse) {
        type_string_slow($vsftpd_directives->{rsa_cert_file});
    } else {
        type_string_slow($vsftpd_directives->{dsa_cert_file});
    }

    assert_screen 'yast2_ftp_port_closed';
    send_key 'alt-p';    # open port in firewall
    assert_screen 'yast2_ftp_port_opened';
    send_key 'alt-f';    # done and close the configuration page now

    # yast might take a while on sle12 due to suseconfig
    die "'yast2 ftp-server' didn't exit with zero exit code in defined timeout" unless wait_serial("$module_name-0", 180);

    # check /etc/vsftpd.conf whether it has been updated accordingly
    $self->vsftd_setup_checker($vsftpd_directives);

    # check presence of vsftpd service in firewalld
    if ($self->firewall eq 'firewalld') {
        vsftpd_firewall_checker;
    }

    # let's try to run it
    systemctl 'start vsftpd';

    if (is_sle('<=12-SP2')) {
        record_soft_failure 'bsc#975538 - yast sets dsa instead rsa in /etc/vsftpd.conf';
    } else {
        systemctl 'is-active vsftpd', fail_message => 'bsc#975538';
    }
}

sub post_fail_hook {
    my ($self) = @_;

    upload_logs('/etc/vsftpd.conf');
    upload_logs('/tmp/failed_vsftpd_directives.log');
    $self->save_upload_y2logs();
}

1;
