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

sub run() {
    my $self = shift;

    my $salt_master   = 'fake-salt-master.com';
    my $smt_url       = 'http://fake.smt.com';
    my $regcode       = 'fake-reg-code';
    my $reg_email     = 'fake@fake.com';
    my $autoinst_file = '/root/autoinst.xml';

    # Generate autoyast profile using all possible arguments with fake values
    my $autoinst_with_args = script_output("create_autoyast_profile --salt-master $salt_master --smt-url $smt_url --regcode $regcode --reg-email $reg_email");

    my $xml  = XML::Simple->new;
    my $data = $xml->XMLin($autoinst_with_args);

    # Check for salt_master value in XML
    unless ($data->{scripts}{'chroot-scripts'}{script}{source} =~ /$salt_master/) {
        $self->write_detail_output("salt-master missing", "Value $salt_master for salt-master missing in xml", "fail");
    }

    # Check for smt_url value in XML
    unless ($data->{suse_register}{reg_server} =~ /$smt_url/) {
        $self->write_detail_output("reg-server missing", "Value $smt_url for reg-server missing in xml", "fail");
    }

    # Check for regcode value in XML
    unless ($data->{suse_register}{reg_code} =~ /$regcode/) {
        $self->write_detail_output("regcode missing", "Value $regcode for regcode missing in xml", "fail");
    }

    # Check for reg_email value in XML
    unless ($data->{suse_register}{email} =~ /$reg_email/) {
        $self->write_detail_output("reg-email missing", "Value $reg_email for reg-email missing in xml", "fail");
    }

    # Generate generic autoinst.xml without using additional args
    script_output("create_autoyast_profile -o $autoinst_file");
    upload_asset $autoinst_file;
}

sub test_flags() {
    return {important => 1};
}

1;
