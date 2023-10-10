# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test public cloud hardened images
#
# Maintainer: <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    # Basic tests required by https://github.com/SUSE-Enceladus/img-proof/issues/358
    assert_script_run('grep "Authorized uses only. All activity may be monitored and reported." /etc/motd');
    assert_script_run('sudo grep always,exit /etc/audit/rules.d/access.rules /etc/audit/rules.d/delete.rules');
    # Check that at least one account has password age
    assert_script_run("sudo awk -F: '\$5 ~ /[0-9]/ { print \$1, \$5; }' /etc/shadow  | grep '[0-9]'");
    # NOTE: Cannot run full evaluation with --fetch-remote-resources because of https://github.com/OpenSCAP/openscap/issues/1796
    assert_script_run("mkdir oscap");
    my $xml_path = "pub/projects/security/oval/suse.linux.enterprise.15.xml";
    # Downloaded file should have slashes replaced by hyphens
    my $xml_file = $xml_path =~ s/\//-/gr;
    assert_script_run("curl -o- https://ftp.suse.com/$xml_path.gz | gunzip -c > oscap/$xml_file", timeout => 180);
    my $ret = script_run("sudo oscap xccdf eval --report report.html --local-files oscap/ --profile pcs-hardening /usr/share/xml/scap/ssg/content/ssg-sle15-ds.xml", timeout => 300);
    upload_logs("report.html");
    record_soft_failure("bsc#1216088 - Public Cloud Hardened image fail SCAP test") if ($ret);
}

1;
