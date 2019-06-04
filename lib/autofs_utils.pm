use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils 'systemctl';

our @EXPORT = qw(setup_autofs_server check_autofs_service);

sub setup_autofs_server {
    my (%args) = @_;
    my $grep_output = script_output("grep '#+dir' $args{autofs_conf_file}");
    if ($grep_output =~ /\#\+dir/) {
        assert_script_run("sed -i_bk 's:#+dir\\:/etc/auto\\.master\\.d:+dir\\:/etc/auto\\.master\\.d:' $args{autofs_conf_file}");
    }
    assert_script_run("echo $args{test_mount_dir} $args{test_conf_file} > $args{autofs_map_file}");
    assert_script_run($args{test_conf_file_content}, fail_message => "File $args{test_conf_file} could not be created");
}

sub check_autofs_service {
    systemctl 'start autofs';
    systemctl 'is-active autofs';
    systemctl 'stop autofs';
    systemctl 'is-active autofs', expect_false => 1;
    systemctl 'restart autofs';
    systemctl 'is-active autofs';
}

1;
