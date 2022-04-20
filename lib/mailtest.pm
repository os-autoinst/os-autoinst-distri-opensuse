# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

package mailtest;
use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';
use lockapi;
use mmapi;
use mm_network;

our @EXPORT = qw($mail_server_name $mail_server_ip $mail_client_ip
  postfix_dns_lookup_off postfix_config_update
  prepare_mail_server prepare_mail_client
  mailx_setup mailx_send_mail
);

our $mail_server_name = undef;
our $mail_server_ip = undef;
our $mail_client_ip = undef;

# Disable postfix dns lookup if mail server isn't FQDN
sub postfix_dns_lookup_off {
    script_run "sed -i 's/^\\(disable_dns_lookups\\) = .*/\\1 = yes/' /etc/postfix/main.cf";
    systemctl "restart postfix.service";
}

# Update postfix config file to avoid some known issues
sub postfix_config_update {
    #https://bugzilla.suse.com/show_bug.cgi?id=1057349
    if (is_tumbleweed) {
        script_run "sed -i '/^smtpd_sasl_path =\$/s/^/#/' /etc/postfix/main.cf";
        script_run "sed -i '/^smtpd_sasl_type =\$/s/^/#/' /etc/postfix/main.cf";
    }
    systemctl "restart postfix.service";
}

sub prepare_mail_server {
    my $ip_addr = "127.0.1.1";
    my $ip_mask;

    $mail_server_name = get_var("MAIL_SERVER_NAME", "mail.openqa.suse");

    # Stop PackageKit
    quit_packagekit;

    # Configure network for mail server (multi-machine test)
    if (get_var('MAIL_SERVER')) {
        $mail_server_ip = get_var("MAIL_SERVER_IP", "10.0.2.10/15");
        ($ip_addr, $ip_mask) = split(/\//, $mail_server_ip);
        configure_default_gateway;
        configure_static_dns(get_host_resolv_conf());
        configure_static_ip(ip => "$mail_server_ip");
        set_var("MAIL_SERVER_IP", "$mail_server_ip") if not get_var("MAIL_SERVER_IP");
        restart_networking();
    }

    set_var("MAIL_SERVER_NAME", "$mail_server_name") if not get_var("MAIL_SERVER_NAME");
    bmwqemu::save_vars();

    script_run "echo '$ip_addr $mail_server_name' >> /etc/hosts";
}

sub prepare_mail_client {

    $mail_server_name = get_var("MAIL_SERVER_NAME", "mail.openqa.suse");
    $mail_server_ip = get_var("MAIL_SERVER_IP");

    # Stop PackageKit
    quit_packagekit;

    # Configure network for mail client (multi-machine test)
    if (get_var('MAIL_CLIENT')) {
        $mail_client_ip = get_var("MAIL_CLIENT_IP", "10.0.2.20/15");
        configure_default_gateway;
        configure_static_dns(get_host_resolv_conf());
        configure_static_ip(ip => "$mail_client_ip");
        restart_networking();

        # Wait for the mail server ready
        mutex_lock "mail_server";
        mutex_unlock "mail_server";

        # Get parent job info
        my $parents = get_parents;
        my $mail_server_job = $parents->[0];
        my $mail_server_vars = get_job_autoinst_vars($mail_server_job);
        $mail_server_name = $mail_server_vars->{MAIL_SERVER_NAME};
        $mail_server_ip = $mail_server_vars->{MAIL_SERVER_IP};
    }

    if ($mail_server_ip) {
        my $server_ip_addr;
        my $server_ip_mask;
        ($server_ip_addr, $server_ip_mask) = split(/\//, $mail_server_ip);
        script_run "echo '$server_ip_addr $mail_server_name' >> /etc/hosts";
    }
    script_run "ping -c 4 $mail_server_name";
}

sub mailx_setup {
    my %args = @_;
    my $user = $args{user} || "$username";
    my $pass = $args{pass} || "$password";
    my $host = $args{host} || "localhost";
    my $port = $args{port} || "25";
    my $ssl = $args{ssl} || "no";
    my $mailrc = "~/.mailrc";

    # Configure mailx via mailrc to avoid long command-line
    script_run "echo 'set smtp-auth=plain' > $mailrc";
    script_run "echo 'set smtp-auth-user=$user' >> $mailrc";
    script_run "echo 'set smtp-auth-password=$pass' >> $mailrc";
    script_run "echo 'set smtp=${host}:${port}' >> $mailrc";
    if ($ssl eq "yes") {
        script_run "echo 'set smtp-use-starttls' >> $mailrc";
        script_run "echo 'set ssl-verify=ignore' >> $mailrc";
    }
}

sub mailx_send_mail {
    my %args = @_;
    my $to = $args{to};
    my $subject = $args{subject} || "Testing Mail";
    my $opts = $args{opts} || "";

    assert_script_run "echo 'Mail body' | mailx -v -s '$subject' $opts $to";
}

1;
