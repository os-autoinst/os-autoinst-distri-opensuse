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
    assert_script_run("mkdir oscap");
    my $xml_path = "pub/projects/security/oval/suse.linux.enterprise.15.xml";
    # Downloaded file should have slashes replaced by hyphens
    my $xml_file = $xml_path =~ s/\//-/gr;
    assert_script_run("curl -o- https://ftp.suse.com/$xml_path.gz | gunzip -c > oscap/$xml_file", timeout => 300);
    my $ret = script_run("sudo oscap xccdf eval --report report.html --local-files oscap/ --profile pcs-hardening /usr/share/xml/scap/ssg/content/ssg-sle15-ds.xml", timeout => 300);
    if ($ret != 0) {
        if (script_run("ls report.html") != 0) {
            record_soft_failure("gh#OpenSCAP/openscap#1796 - Killed because of OOM");
        } else {
            record_soft_failure("bsc#1216088 - Public Cloud Hardened image fail SCAP test");
            upload_logs("report.html");
        }
    }
}

1;
