# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test for generating worker autoinst profile for CaaSP poo#17174
# Maintainer: Tomas Hehejik <thehejik@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use caasp;
use XML::Simple;

sub run {
    my $salt_master   = 'fake-salt-master.com';
    my $smt_url       = 'http://fake.smt.com';
    my $regcode       = 'fake-reg-code';
    my $reg_email     = 'fake@fake.com';
    my $autoinst_file = '/root/autoinst.xml';

    # Generate autoyast profile using all possible arguments with fake values
    my $autoinst_with_args = script_output("create_autoyast_profile --salt-master $salt_master --smt-url $smt_url --regcode $regcode --reg-email $reg_email");

    my $xml  = XML::Simple->new;
    my $data = $xml->XMLin($autoinst_with_args, ForceArray => ['script']);

    # Check autoyast scripts in XML
    my $ntp_hostname = 'NTP=' . script_output("hostname -f 2> /dev/null || hostname");
    my $script_arref = \@{$data->{scripts}{'chroot-scripts'}{script}};

    my $counter = 0;
    foreach my $script (@$script_arref) {
        if ($script->{source} =~ /$salt_master/)  { $counter += 1; next; }
        if ($script->{source} =~ /$ntp_hostname/) { $counter += 2; next; }
    }
    record_info('scripts missing', "Values $salt_master and $ntp_hostname missing in xml", result => 'fail') if ($counter == 0);
    # Softfail due bsc#1035665 and XEN snapshot incompatabily
    record_info('ntp missing',         "Value $ntp_hostname for ntp missing in xml",        result => 'softfail') if ($counter == 1);
    record_info('salt_master missing', "Value $salt_master for salt-master missing in xml", result => 'fail')     if ($counter == 2);

    # Check for smt_url value in XML
    unless ($data->{suse_register}{reg_server} =~ /$smt_url/) {
        record_info 'reg-server missing', "Value $smt_url for reg-server missing in xml", result => 'fail';
    }

    # Check for regcode value in XML
    unless ($data->{suse_register}{reg_code} =~ /$regcode/) {
        record_info 'regcode missing', "Value $regcode for regcode missing in xml", result => 'fail';
    }

    # Check for reg_email value in XML
    unless ($data->{suse_register}{email} =~ /$reg_email/) {
        record_info 'reg-email missing', "Value $reg_email for reg-email missing in xml", result => 'fail';
    }

    # Generate generic autoinst.xml without using additional args
    script_output("create_autoyast_profile -o $autoinst_file");
    upload_asset $autoinst_file;
}

1;
