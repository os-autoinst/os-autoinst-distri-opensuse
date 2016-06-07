# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package virt_utils;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use Exporter;
use Data::Dumper;
use XML::Writer;
use IO::File;

our @EXPORT=qw(set_serialdev);

sub set_serialdev(){
	if (get_var("XEN") || check_var("HOST_HYPERVISOR","xen")){
		my $hostReleaseInfo=script_output("cat /etc/SuSE-release");
		if ($hostReleaseInfo =~ /VERSION = 12\nPATCHLEVEL = 2\n/m){
		    $serialdev = "hvc0";
		}else {
		    $serialdev = "xvc0";
		}
	}else {
		$serialdev = "ttyS1";
	}
}

1;

