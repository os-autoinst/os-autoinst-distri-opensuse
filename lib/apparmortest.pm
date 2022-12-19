# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Base module for AppArmor test cases
# Maintainer: QE Security <none@suse.de>

=head1 Apparmor Tests

Apparmor tests

=cut
package apparmortest;

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed is_alp);
use y2_module_guitest 'launch_yast2_module_x11';
use x11utils 'turn_off_gnome_screensaver';

use base 'consoletest';

our @EXPORT = qw(
  $audit_log
  $mail_err_log
  $mail_warn_log
  $mail_info_log
  $prof_dir
  $adminer_file
  $adminer_dir
  create_a_test_profile_name_is_special
  create_log_content_is_special
  test_profile_content_is_special
);

our $prof_dir = "/etc/apparmor.d";
our $audit_log = "/var/log/audit/audit.log";
our $mail_err_log = "/var/log/mail.err";
our $mail_warn_log = "/var/log/mail.warn";
our $mail_info_log = "/var/log/mail.info";

our $mail_recipient = "recipient";
our $mail_sender = "sender";
our $pw = "te5tpw";
our $mail_subject = "Subject: Postfix test";
our $mail_content = "hello world";
our $testdomain = "testdomain.com";

our $adminer_file = "adminer.php5";
our $adminer_dir = "/srv/www/htdocs/adminer/";

our $testuser = "testuser";
our $testdir = "testdir";

# $src_dir_name: Source file/directory name
# $dst_dir_name: Destination file/directory name
=head2 check_copy_file_dir
 check_copy_file_dir();
Check if source file/directory exists and destination file/directory does not exists, then copy
=cut

sub check_copy_file_dir {
    my ($src_dir_name, $dst_dir_name) = @_;

    my $ret = script_run("[ -e $src_dir_name ] && [ ! -e $dst_dir_name ] && cp -r $src_dir_name $dst_dir_name");
    return $ret;
}

# $prof_dir_tmp: The target temporary directory
# $type:
# 0  - Copy only the basic structure of profile directory
# != 0 (default) - Copy full contents under the profile directory

=head2 aa_tmp_prof_prepare

 aa_tmp_prof_prepare();

Prepare apparmor profile directory

=cut

sub aa_tmp_prof_prepare {
    my ($self, $prof_dir_tmp, $type) = @_;
    my $prof_dir = "/etc/apparmor.d";
    $type //= 1;

    if ($type == 0) {
        assert_script_run "mkdir $prof_dir_tmp";
        foreach my $file ("tunables", "abstractions", "abi", "disable", "program-chunks") {
            # if src_dir/file exists and dst_dir/file does not exists
            check_copy_file_dir("$prof_dir/$file", "$prof_dir_tmp/$file");
        }
    }
    else {
        assert_script_run "cp -r $prof_dir $prof_dir_tmp";
    }
}

# Verify the program could start with the temporary profiles
# Then restore it to the enforce status with normal profiles

=head2 aa_tmp_prof_verify

 aa_tmp_prof_verify();

Verify that program can start with temporary profiles and then restore to the enforce status with normal profiles

=cut

sub aa_tmp_prof_verify {
    my ($self, $prof_dir_tmp, $prog) = @_;

    assert_script_run("aa-disable $prog");

    assert_script_run("aa-enforce -d $prof_dir_tmp $prog");
    systemctl("restart $prog");
    assert_script_run("aa-disable -d $prof_dir_tmp $prog");

    assert_script_run("aa-enforce $prog");
    systemctl("restart $prog");
}

=head2 aa_tmp_prof_clean

 aa_tmp_prof_clean();

Remove appamor temporary profiles

=cut

sub aa_tmp_prof_clean {
    my ($self, $prof_dir_tmp) = @_;

    assert_script_run "rm -rf $prof_dir_tmp";
}

# Get the named profile for an executable program

=head2 get_named_profiled

 get_named_profiled();

Get the named profile for an executable program

=cut

sub get_named_profile {
    my ($self, $profile_name) = @_;

    # Recalculate profile name in case
    $profile_name = script_output("/sbin/apparmor_parser -N /etc/apparmor.d/$profile_name | head -1");
    return $profile_name;
}

# Check the output of aa-status: if a given profile belongs to a given mode

=head2 aa_status_stdout_check

 aa_status_stdout_check();

Check the output of aa-status: if a given profile belongs to a given mode
=cut

sub aa_status_stdout_check {
    my ($self, $profile_name, $profile_mode) = @_;

    my $start_line = script_output("aa-status | grep -n 'profiles are in' | grep $profile_mode | cut -d ':' -f1");
    my $total_line = script_output("aa-status | grep 'profiles are in' | grep $profile_mode | cut -d ' ' -f1");
    my $lines = $start_line + $total_line;

    assert_script_run("aa-status | head -$lines | tail -$total_line | sed 's/[ \t]*//g' | grep -x $profile_name");
}

=head2 ip_fetch

 ip_fetch();

Fetch ip details

=cut

sub ip_fetch {
    # "# hostname -i/-I" can not work in some cases
    my $ip = script_output("ip -4 -f inet -o a | grep -E \'eth0|ens\' | sed -n 's/\.*inet \\([0-9.]\\+\\)\.*/\\1/p'");
    return $ip;
}

# Set up mail server with Postfix and Dovecot:
#   setting Postfix for outgoing mail,
#   setting Dovecot for ingoing mail,

=head2 setup_mail_server_postfix_dovecot

 setup_mail_server_postfix_dovecot();

Set up mail server with Postfix and Dovecot:

=over

=item * 1. Setting Postfix for outgoing mail by: setting hostname and domain, restart rcnetwork services, double check the setting

=item * 2. Setting mail sender/recipient as needed

=item * 3. Setting Postfix for outgoing mail (SMTP server with Postfix) by: install Postfix by using zypper_call, start Postfix service, set "/etc/postfix/main.cf" file, output the setting for reference, restart Postfix service, output the status for reference

=item * 4. Setting Dovecot for ingoing mail by: set the config files $testfile, restart Dovecot service, output the status for reference
    
=back

=cut

sub setup_mail_server_postfix_dovecot {
    my ($self) = @_;
    my $ip = "";
    my $hostname = "mail";
    my $mail_dir = "/home";

    # 1. Set up mail server with Postfix and Dovecot

    # Setting hostname and domain
    if (is_tumbleweed) {
        $ip = script_output(q(ip address | awk '/inet/ && /\/24/ { split($2, ip, "/"); print ip[1] }'));
    }
    else {
        $ip = script_output(q(ip -4 address show eth0 | awk '/inet/ { split($2, ip, "/"); print ip[1] }'));
    }
    assert_script_run("echo $ip $hostname.$testdomain $hostname >> /etc/hosts");
    set_hostname($hostname);

    # Restart rcnetwork services:
    assert_script_run("rcnetwork restart");

    # Double check the setting
    validate_script_output("hostname --short", sub { m/$hostname/ });
    validate_script_output("hostname --domain", sub { m/$testdomain/ });
    validate_script_output("hostname --fqdn", sub { m/$hostname.$testdomain/ });
    validate_script_output("hostname --ip-address", sub { m/$ip/ });

    # 2. Setting mail sender/recipient as needed
    if (is_tumbleweed) {
        zypper_call("--no-refresh in expect");
    }
    script_run("userdel -rf $mail_sender");
    script_run("userdel -rf $mail_recipient");
    assert_script_run("useradd -m -d $mail_dir/$mail_recipient $mail_recipient");
    assert_script_run("useradd -m -d $mail_dir/$mail_sender $mail_sender");
    assert_script_run(
        "expect -c 'spawn passwd $mail_sender; expect \"New password:\"; send \"$pw\\n\"; expect \"Retype new password:\"; send \"$pw\\n\"; interact'");
    assert_script_run(
        "expect -c 'spawn passwd $mail_recipient; expect \"New password:\"; send \"$pw\\n\"; expect \"Retype new password:\"; send \"$pw\\n\"; interact'");

    # 3. Setting Postfix for outgoing mail (SMTP server with Postfix)

    # Install Postfix
    zypper_call("--no-refresh in dovecot");
    zypper_call("--no-refresh in --force-resolution postfix");

    # Start Postfix service
    systemctl("restart postfix");

    # Set "/etc/postfix/main.cf" file
    my $testfile = "/etc/postfix/main.cf";
    assert_script_run("sed -i '1i home_mailbox = Maildir/' $testfile");
    assert_script_run("sed -i '1i inet_interfaces = localhost, $ip' $testfile");
    assert_script_run("sed -i '1i inet_protocols = all' $testfile");
    assert_script_run("sed -i '/^mydestination =/d' $testfile");
    assert_script_run("echo 'mydestination = \$myhostname, localhost.\$mydomain, \$mydomain' >> $testfile");
    assert_script_run("echo 'myhostname = mail.testdomain.com' >> $testfile");
    # Output the setting for reference
    assert_script_run("tail -n 3 $testfile");
    assert_script_run("head -n 5 $testfile");
    assert_script_run("doveconf -n");

    # Restart Postfix service
    systemctl("restart postfix");
    # Output the status for reference
    systemctl("status postfix");

    # 4. Setting Dovecot for ingoing mail

    # Set the config files as following
    $testfile = "/etc/dovecot/dovecot.conf";
    assert_script_run("echo 'protocols = imap pop3 lmtp' >> $testfile");

    $testfile = "/etc/dovecot/conf.d/10-mail.conf";
    assert_script_run("echo 'mail_location = maildir:~/Maildir' >> $testfile");

    $testfile = "/etc/dovecot/conf.d/10-auth.conf";
    assert_script_run("echo 'disable_plaintext_auth = yes' >> $testfile");
    assert_script_run("echo 'auth_mechanisms = plain login' >> $testfile");

    $testfile = "/etc/dovecot/conf.d/10-master.conf";
    assert_script_run("echo 'service auth {' >> $testfile");
    assert_script_run("echo '  unix_listener auth-userdb {' >> $testfile");
    assert_script_run("echo '  }' >> $testfile");
    assert_script_run("echo '  unix_listener /var/spool/postfix/private/auth {' >> $testfile");
    assert_script_run("echo '    mode = 0660' >> $testfile");
    assert_script_run("echo '    user = postfix' >> $testfile");
    assert_script_run("echo '    group = postfix' >> $testfile");
    assert_script_run("echo '  }' >> $testfile");
    assert_script_run("echo '}' >> $testfile");

    $testfile = "/etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run("echo 'ssl = no' >> $testfile");

    # Restart Dovecot service
    systemctl("restart dovecot");

    # Output the status for reference
    systemctl("status dovecot");
}

=head2 send_mail_smtp

 send_mail_smtp();

Send mail with telnet SMTP by using script_run_interactive

=cut
# Send mail with telnet SMTP
sub send_mail_smtp {

    script_run_interactive(
        "telnet localhost smtp",
        [
            {
                prompt => qr/220.*ESMTP/m,
                string => "ehlo $testdomain\n",
            },
            {
                prompt => qr/250.*SMTPUTF8/m,
                string => "mail from: $mail_sender\@$testdomain\n",
            },
            {
                prompt => qr/250 2.1.0 Ok/m,
                string => "rcpt to: $mail_recipient\@$testdomain\n",
            },
            {
                prompt => qr/250 2.1.5 Ok/m,
                string => "data\n",
            },
            {
                prompt => qr/354 End data with.*/m,
                string => "$mail_subject\n$mail_content\n\n.\n",
            },
            {
                prompt => qr/250 2.0.0 Ok: queued as.*/m,
                key => "ctrl-]",
            },
            {
                prompt => qr/telnet>/m,
                string => "quit\n",
            },
        ],
        300
    );
}

=head2 Retrieve email with POP3

 retrieve_mail_pop3

Retrieve email with POP3 by using script_run_interactive

=cut
# Retrieve email with POP3
sub retrieve_mail_pop3 {
    # NOTE: Please put "prompt => qr/\+OK/m," to the end of the reference list
    # to avoid Perl regex match fail
    script_run_interactive(
        "telnet localhost pop3",
        [
            {
                prompt => qr/\+OK Dovecot ready./m,
                string => "user $mail_recipient\n",
            },
            {
                prompt => qr/\+OK Logged in./m,
                string => "retr 1\n",
            },
            {
                prompt => qr/.*$mail_subject.*/m,
                key => "ctrl-]",
            },
            {
                prompt => qr/telnet>/m,
                string => "quit\n",
            },
            {
                prompt => qr/\+OK/m,
                string => "pass $pw\n",
            },
        ],
        300
    );
}

=head2 retrieve_mail_imap

 retrieve_mail_imap();

Retrieve email with IMAP by using script_run_interactive

=cut
# Retrieve email with IMAP
sub retrieve_mail_imap {
    script_run_interactive(
        "telnet localhost imap",
        [
            {
                prompt => qr/\* OK.* Dovecot ready./m,
                string => "A01 login $mail_recipient $pw\n",
            },
            {
                prompt => qr/A01 OK .* Logged in/m,
                string => "A02 LIST \"\" \*\n",
            },
            {
                prompt => qr/A02 OK List completed .*/m,
                string => "A03 Select INBOX\n",
            },
            {
                prompt => qr/A03 OK .* Select completed .*/m,
                string => "A04 Search ALL\n",
            },
            {
                prompt => qr/A04 OK Search completed .*/m,
                string => "A05 Search new\n",
            },
            {
                prompt => qr/A05 OK Search completed .*/m,
                string => "A06 Fetch 1 full\n",
            },
            {
                prompt => qr/A06 OK Fetch completed .*/m,
                string => "A07 Fetch 1 RFC822\n",
            },
            {
                prompt => qr/.*$mail_subject.*/m,
                key => "ctrl-]",
            },
            {
                prompt => qr/telnet>/m,
                string => "quit\n",
            },
        ],
        300
    );
}

=head2 mariadb_setup

 mariadb_setup();

Set up Mariadb and test account by using zypper_call, assert_script_run, script_run_interactive

=cut
# Set up Mariadb and test account
sub mariadb_setup {
    # Install Mariadb
    zypper_call("in mariadb");
    # Start MySQL server
    assert_script_run("rcmysql start");
    # Set up test account
    script_run_interactive(
        "/usr/bin/mysql_secure_installation",
        [
            {
                prompt => qr/Enter current password for root/m,
                string => "\n",
            },
            {
                prompt => qr/Switch to unix_socket authentication \[Y\/n\]/m,
                string => "n\n",
            },
            {
                prompt => qr/Change the root password\? \[Y\/n\]/m,
                string => "Y\n",
            },
            {
                prompt => qr/Set root password\? \[Y\/n\]/m,
                string => "Y\n",
            },
            {
                prompt => qr/New password:/m,
                string => "$pw\n",
            },
            {
                prompt => qr/Re-enter new password:/m,
                string => "$pw\n",
            },
            {
                prompt => qr/Remove anonymous users\? \[Y\/n\]/m,
                string => "n\n",
            },
            {
                prompt => qr/Disallow root login remotely\? \[Y\/n\]/m,
                string => "n\n",
            },
            {
                prompt => qr/Remove test database and access to it\? \[Y\/n\]/m,
                string => "n\n",
            },
            {
                prompt => qr/Reload privilege tables now\? \[Y\/n\]/m,
                string => "n\n",
            },
        ],
        300
    );
}

=head2 adminer_setup

 adminer_setup();

Set up Web environment for running Adminer by:

=over

=item * use assert_script_run to enable php7 or php8, restart apache2 and mysql

=item * download Adminer and copy it to directory /srv/www/htdocs/adminer/

=item * test Adminer

=item * clean and start Firefox

=item * exit x11 and turn to console

=item * exit xterm

=item * send "ret" key in case of any pop up message

=back

=cut
# Set up Web environment for running Adminer
sub adminer_setup {
    if (is_sle(">=15-SP4") || is_leap(">15.4") || is_tumbleweed() || is_alp()) {
        assert_script_run("a2enmod php8");
    } else {
        assert_script_run("a2enmod php7");
    }
    assert_script_run("systemctl restart apache2");
    assert_script_run("systemctl restart mysql");

    # Download Adminer and copy it to /srv/www/htdocs/adminer/
    assert_script_run("wget --quiet " . data_url("apparmor/$adminer_file"));
    # NOTE: Use *.php5 instead of *.php[7] to avoid file decoding error
    assert_script_run("mkdir -p $adminer_dir");
    assert_script_run("mv $adminer_file $adminer_dir");

    # Test Adminer can work
    select_console 'x11';

    # Clean and Start Firefox
    x11_start_program('xterm');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    enter_cmd("killall -9 firefox; rm -rf .moz* .config/iced* .cache/iced* .local/share/gnome-shell/extensions/* ");
    enter_cmd("firefox http://localhost/adminer/$adminer_file &");

    my $ret;
    $ret = check_screen([qw(adminer-login unresponsive-script)], timeout => 300);    # nocheck: old code, should be updated
    if (!defined($ret)) {
        # Wait more time
        record_info("Firefox loading adminer failed", "Retrying workaround");
        check_screen([qw(adminer-login unresponsive-script)], timeout => 300);    # nocheck: old code, should be updated
    }
    if (match_has_tag("unresponsive-script")) {
        send_key_until_needlematch("adminer-login", 'ret', 6, 5);
    }
    elsif (match_has_tag("adminer-login")) {
        record_info("Firefox is loading adminer", "adminer login page shows up");
    }
    elsif (match_has_tag("firefox-blank-page")) {
        record_info("Firefox loading adminer failed", "but blank page shows up");
    }
    else {
        record_info("Firefox loading adminer failed", "but the testing can be continued");
    }

    # Exit x11 and turn to console
    send_key "alt-f4";
    $ret = check_screen("quit-and-close-tabs", timeout => 30);
    if (defined($ret)) {
        # Click the "quit and close tabs" button
        send_key_until_needlematch("close-button-selected", 'tab', 6, 5);
        send_key "ret";
    }
    wait_still_screen(stilltime => 3, timeout => 30);
    # Exit xterm
    if (is_tumbleweed()) {
        send_key_until_needlematch("generic-desktop", 'alt-f4', 6, 5);
    }
    # Send "ret" key in case of any pop up message
    send_key_until_needlematch("generic-desktop", 'ret', 6, 5);
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;
}

=head2 adminer_database_delete

 adminer_database_delete();

Log in Adminer, seletct "test" database and delete it

=over

=item * do some operations on web, e.g., log in, select/delete a database

=item * exit x11 and turn to console

=back

=cut
# Log in Adminer, seletct "test" database and delete it
sub adminer_database_delete {
    select_console 'x11';
    x11_start_program("firefox --setDefaultBrowser http://localhost/adminer/$adminer_file", target_match => "adminer-login", match_timeout => 300);

    # Do some operations on web, e.g., log in, select/delete a database
    type_string("root");
    send_key "tab";
    type_string("$pw");
    send_key "tab";
    send_key "tab";
    send_key "ret";
    assert_screen("adminer-save-passwd");
    send_key "alt-s";
    assert_screen("adminer-select-database");
    assert_and_click("adminer-click-database-test");
    assert_and_click("adminer-click-drop-database-test");
    # Confirm drop
    send_key_until_needlematch("adminer-database-dropped", 'ret', 11, 1);
    # Exit x11 and turn to console
    send_key "alt-f4";
    # Handle exceptions when "Quit and close tabs" in Firefox, the warning FYI:
    # "You are about to close 2 tabs. Are you sure want to continue?"
    if (check_screen("firefox-quit-and-close-tabs", 5)) {
        assert_and_click("firefox-close-tabs");
    }
    assert_screen("generic-desktop");
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;
}

# Yast2 Apparmor set up
sub yast2_apparmor_setup {
    # Start Apparmor in case and check it is active
    systemctl("start apparmor");
    systemctl("is-active apparmor");

    # Turn to x11 and start "xterm"
    select_console("x11");
    x11_start_program("xterm");
    become_root;
}

# Yast2 Apparmor: check apparmor is enabled
sub yast2_apparmor_is_enabled {
    enter_cmd("yast2 apparmor &");
    assert_screen("AppArmor-Configuration-Settings", timeout => 300);
    assert_and_click("AppArmor-Launch", timeout => 60);
    assert_screen("AppArmor-Settings-Enable-Apparmor", timeout => 60);
}

# Yast2 Apparmor clean up
sub yast2_apparmor_cleanup {
    # Exit x11 and turn to console
    send_key "alt-f4";
    assert_screen("generic-desktop");
    select_console("root-console");
    send_key "ctrl-c";
    clear_console;

    # Upload logs for reference
    upload_logs("$audit_log");
}

# Create a test profile with name contains '('
sub create_a_test_profile_name_is_special {
    my ($testfile, $str) = @_;

    my $testfile2 = "$testfile" . "$str";
    assert_script_run("cp $testfile $testfile2");
    assert_script_run("aa-autodep $testfile2");
    assert_script_run("ll /etc/apparmor.d/ | grep $str");
}

# Refer to "https://bugs.launchpad.net/apparmor/+bug/1848227"
# to create a test profile with content "local include above the '}'",
# then run "aa-complain, aa-disable, aa-enforce, aa-logprof"
# to verify all the commands should be succeeded
sub test_profile_content_is_special {
    my ($self, $cmd, $msg) = @_;
    my $test = "test_profile";
    my $test_profile = "/etc/apparmor.d/usr.sbin." . "$test";
    my $local_profile = "/etc/apparmor.d/local/usr.sbin.cupsd";

    # Create an empty local profile under "/etc/apparmor.d/local/"
    assert_script_run("rm -rf $local_profile");
    assert_script_run("touch $local_profile");

    # Create a test profile under "/etc/apparmor.d/"
    assert_script_run("echo '/usr/sbin/cupsd {' > $test_profile");
    assert_script_run("echo '}' >> $test_profile");
    assert_script_run("echo '#include <local/usr.sbin.cupsd>' >> $test_profile");

    # Run aa-* commands and check the output
    my $current_ver = script_output("rpm -q --qf '%{version}' apparmor-utils");

    my $cmd1 = $cmd eq "aa-logprof" ? $cmd : "$cmd $test_profile";
    my $ret = script_run($cmd1, sub { m/$msg/ });
    if ($ret == 0) {
        if ("$cmd" eq "aa-disable") {
            # The profile will not be listed out if disabled
            my $ret = script_run("aa-status | grep $test");
            if ($ret == 0) {
                $self->result("fail");
            }
        }
    }
    elsif ($ret && ($current_ver lt "2.13.4")) {
        record_soft_failure("bsc#1182840 - apparmor commands \"aa_*\" reports errors when profile name/content and audit log have some exceptions");
    }

    # Clean up
    assert_script_run("rm -rf $test_profile");
    assert_script_run("rm -rf $local_profile");
}

# Refer to "https://apparmor.net/news/release-2.13.4/" setup env to verify the fix:
# "Fix crash when log message contains a filename with unbalanced parenthesis".
# Create a test profile with content "local include above the '}'" in order
# to run "aa-logprof" to verify the commands should be succeeded
sub create_log_content_is_special {
    my ($self, $testfile, $test_special) = @_;

    # Enable & Start auditd service
    systemctl("enable auditd");
    systemctl("start auditd");

    # Clean up audit log
    assert_script_run("echo '' > $audit_log");

    # Generate an audit record which "contains a filename with unbalanced parenthesis"
    assert_script_run("cp $testfile $test_special");
    assert_script_run("aa-autodep $test_special");
    assert_script_run("$test_special ./");

    # Check the record which "contains a filename with unbalanced parenthesis"
    validate_script_output("cat $audit_log", sub { m/.*type=AVC.*profile=.*$test_special.*/sx });
}

=head2 upload_logs_mail

 upload_logs_mail();

Upload mail warn, err and info logs for reference

=cut

sub upload_logs_mail {
    # Upload mail warn, err and info logs for reference
    if (script_run("! [[ -e $mail_err_log ]]")) {
        upload_logs("$mail_err_log");
    }
    if (script_run("! [[ -e $mail_warn_log ]]")) {
        upload_logs("$mail_warn_log");
    }
    if (script_run("! [[ -e $mail_info_log ]]")) {
        upload_logs("$mail_info_log");
    }
}

=head2 pre_run_hook

 pre_run_hook();

Restart auditd and apparmor in root-console

=cut

sub pre_run_hook {
    my ($self) = @_;

    select_console 'root-console';
    systemctl('restart auditd');
    systemctl('restart apparmor');
    $self->SUPER::pre_run_hook;
}

=head2 post_fail_hook

 post_fail_hook();

Run post_fail_hook and upload audit logs

=cut

sub post_fail_hook {
    my ($self) = shift;

    return if get_var('NOLOGS');
    # Exit x11 and turn to console in case
    send_key("alt-f4");
    select_console("root-console");
    if (script_run("! [[ -e $audit_log ]]")) {
        upload_logs("$audit_log");
    }
    $self->SUPER::post_fail_hook;
}

1;
