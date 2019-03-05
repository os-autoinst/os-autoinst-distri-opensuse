# Copyright (C) 2017-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Base module for AppArmor test cases
# Maintainer: Wes <whdu@suse.com>

package apparmortest;

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);

use base 'consoletest';

our @EXPORT = qw (
  $audit_log
  $mail_err_log
  $mail_warn_log
  $mail_info_log
);

our $audit_log     = "/var/log/audit/audit.log";
our $mail_err_log  = "/var/log/mail.err";
our $mail_warn_log = "/var/log/mail.warn";
our $mail_info_log = "/var/log/mail.info";

our $mail_recipient = "recipient";
our $mail_sender    = "sender";
our $pw             = "te5tpw";
our $mail_subject   = "Subject: Postfix test";
our $mail_content   = "hello world";
our $testdomain     = "testdomain.com";

# $prof_dir_tmp: The target temporary directory
# $type:
# 0  - Copy only the basic structure of profile directory
# != 0 (default) - Copy full contents under the profile directory
sub aa_tmp_prof_prepare {
    my ($self, $prof_dir_tmp, $type) = @_;
    my $prof_dir = "/etc/apparmor.d";
    $type //= 1;

    if ($type == 0) {
        assert_script_run "mkdir $prof_dir_tmp";
        assert_script_run "cp -r $prof_dir/{tunables,abstractions} $prof_dir_tmp/";
        if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
            assert_script_run "cp -r $prof_dir/program-chunks $prof_dir/disable $prof_dir_tmp/";
        }
    }
    else {
        assert_script_run "cp -r $prof_dir $prof_dir_tmp";
    }
}

# Verify the program could start with the temporary profiles
# Then restore it to the enforce status with normal profiles
sub aa_tmp_prof_verify {
    my ($self, $prof_dir_tmp, $prog) = @_;

    assert_script_run("aa-disable $prog");

    assert_script_run("aa-enforce -d $prof_dir_tmp $prog");
    systemctl("restart $prog");
    assert_script_run("aa-disable -d $prof_dir_tmp $prog");

    assert_script_run("aa-enforce $prog");
    systemctl("restart $prog");
}

sub aa_tmp_prof_clean {
    my ($self, $prof_dir_tmp) = @_;

    assert_script_run "rm -rf $prof_dir_tmp";
}

# Get the named profile for an executable program
sub get_named_profile {
    my ($self, $profile_name) = @_;

    # Recalculate profile name in case
    $profile_name = script_output("grep ' {\$' /etc/apparmor.d/$profile_name | sed 's/ {//'");
    if ($profile_name =~ m/profile /) {
        $profile_name = script_output("echo $profile_name | cut -d ' ' -f2");
    }
    return $profile_name;
}

# Check the output of aa-status: if a given profile belongs to a given mode
sub aa_status_stdout_check {
    my ($self, $profile_name, $profile_mode) = @_;

    my $start_line = script_output("aa-status | grep -n 'profiles are in' | grep $profile_mode | cut -d ':' -f1");
    my $total_line = script_output("aa-status | grep 'profiles are in' | grep $profile_mode | cut -d ' ' -f1");
    my $lines      = $start_line + $total_line;

    assert_script_run("aa-status | head -$lines | tail -$total_line | sed 's/[ \t]*//g' | grep -x $profile_name");
}

# Set up mail server with Postfix and Dovecot:
#   setting Postfix for outgoing mail,
#   setting Dovecot for ingoing mail,
sub setup_mail_server_postfix_dovecot {
    my ($self)   = @_;
    my $ip       = "";
    my $hostname = "mail";
    my $mail_dir = "/home";

    # 1. Set up mail server with Postfix and Dovecot

    # Setting hostname and domain
    if (is_tumbleweed) {
        $ip = script_output("ip address | grep inet | grep /24 | awk '{ print \$2 }' | cut -d '/' -f1");
    }
    else {
        $ip = script_output("ip -4 address show eth0 | grep inet | awk '{ print \$2 }' | cut -d '/' -f1");
    }
    assert_script_run("echo $ip $hostname.$testdomain $hostname >> /etc/hosts");
    set_hostname($hostname);

    # Restart rcnetwork services:
    assert_script_run("rcnetwork restart");

    # Double check the setting
    validate_script_output("hostname --short",      sub { m/$hostname/ });
    validate_script_output("hostname --domain",     sub { m/$testdomain/ });
    validate_script_output("hostname --fqdn",       sub { m/$hostname.$testdomain/ });
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

    # Set "/etc/postfix/main.cf" file
    my $testfile = "/etc/postfix/main.cf";
    assert_script_run("sed -i '1i home_mailbox = Maildir/' $testfile");
    assert_script_run("sed -i '1i net_interfaces = localhost, $ip' $testfile");
    assert_script_run("sed -i '1i net_protocols = all' $testfile");
    assert_script_run("echo 'myhostname = mail.testdomain.com' >> $testfile");
    assert_script_run("echo 'mydestination = \$myhostname, localhost.\$mydomain, \$mydomain' >> $testfile");

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
                key    => "ctrl-]",
            },
            {
                prompt => qr/telnet>/m,
                string => "quit\n",
            },
        ],
        300
    );
}

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
                key    => "ctrl-]",
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
                string => "A08 logout\n",
            },
        ],
        300
    );
}

sub upload_logs_mail {
    # Upload mail warn, err and info logs for reference
    upload_logs("$mail_err_log");
    upload_logs("$mail_warn_log");
    upload_logs("$mail_info_log");
}

sub pre_run_hook {
    my ($self) = @_;

    select_console 'root-console';
    systemctl('restart auditd');
    systemctl('restart apparmor');
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs("$audit_log");
    $self->SUPER::post_fail_hook;
}

1;
