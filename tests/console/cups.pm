# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test basic capabilities of cups
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_jeos';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call("in cups", exitcode => [0, 102, 103]);
    zypper_call("in cups-filters", exitcode => [0, 102, 103]) if is_jeos;

    script_run 'echo FileDevice Yes >> /etc/cups/cups-files.conf';
    validate_script_output 'cupsd -t', sub { m/is OK/ };
    systemctl 'enable cups.service';
    systemctl 'start cups.service';
    validate_script_output 'systemctl --no-pager status cups.service | cat', sub { m/Active:\s*active/ };

    # Add printers
    record_info "lpadmin", "Try to add printers and enable them";
    validate_script_output 'lpstat -p -d -o 2>&1 || test $? -eq 1', sub { m/lpstat: No destinations added/ };
    assert_script_run 'lpadmin -p printer_tmp -v file:/tmp/test_cups -m raw -E';
    assert_script_run 'lpadmin -p printer_null -v file:/dev/null -m raw -E';
    assert_script_run 'cupsenable printer_tmp printer_null';
    assert_script_run 'lpoptions -d printer_tmp';
    validate_script_output 'lpstat -p -d -o', sub { m/printer_tmp is idle/ };

    assert_script_run 'curl --fail -s -O -L ' . data_url('console/sample.ps');
    assert_script_run 'curl --fail -s -O -L ' . data_url('console/testpage.pdf');

    # Submit print job to the queue, list them and cancel them
    record_info "lp, lpstat, cancel", "Submitting and canceling jobs";
    foreach my $printer (qw(printer_tmp printer_null)) {
        assert_script_run "cupsdisable $printer";
        assert_script_run "lp -d $printer -o cpi=12 -o lpi=8 sample.ps";
        validate_script_output 'lpstat -o',          sub { m/$printer-\d+/ };
        validate_script_output 'ls /var/spool/cups', sub { m/d\d+/ };
        assert_script_run "cancel -a $printer";
    }

    systemctl 'restart cups.service';
    validate_script_output 'systemctl --no-pager status cups.service | cat', sub { m/Active:\s*active/ };

    # Do the printing
    record_info "lp, lpq", "Printing jobs";
    foreach my $printer (qw(printer_tmp printer_null)) {
        assert_script_run "cupsenable $printer";
        assert_script_run "lp -d $printer testpage.pdf";
        validate_script_output "lpq $printer", sub { m/is ready/ };
    }

    # Check logs
    record_info "access_log", "Access log should containt successful job submits";
    assert_script_run 'grep "Send-Document successful-ok" /var/log/cups/access_log';

    # Remove printers
    record_info "lpadmin -x", "Removing printers";
    assert_script_run "lpadmin -x $_" foreach (qw(printer_tmp printer_null));
    validate_script_output 'lpstat -p -d -o 2>&1 || test $? -eq 1', sub { m/No destinations added/ };
    systemctl 'disable cups.service';
    systemctl 'stop cups.service';
    validate_script_output '{ systemctl --no-pager status cups.service | cat; } || test $? -eq 3', sub { m/Active:\s*inactive/ };
}

1;
