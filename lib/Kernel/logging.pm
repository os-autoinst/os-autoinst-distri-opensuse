package Kernel::logging;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use Utils::Logging;

our @EXPORT_OK = qw(
  kernel_info
  prepare_kernel_bug_report
);

sub kernel_info {
    return script_output('uname -a');
}

sub prepare_kernel_bug_report {
    my (%args) = @_;

    my $content = $args{content} // kernel_info();

    # kernel_bug_report.txt hardcoded value as this is expected in the UI (report bug button)
    save_and_upload_log('kernel_bug_report.txt', $content);
}

1;
