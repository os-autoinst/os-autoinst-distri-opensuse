package Kernel::logging;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  kernel_info
  prepare_kernel_bug_report
);

sub kernel_info {
    return script_output('uname -a');
}

sub prepare_kernel_bug_report {
    my (%args) = @_;

    my $filename = $args{filename} // 'kernel_bug_report.txt';
    my $content = $args{content} // kernel_info();

    save_tmp_file($filename, $content);
    upload_logs($filename);

    return $filename;
}

1;
