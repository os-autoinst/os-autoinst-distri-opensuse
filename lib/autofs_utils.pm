package autofs_utils;

use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_call);
use version_utils qw(is_sle is_jeos);

our @ISA    = qw(Exporter);
our @EXPORT = qw(setup_autofs_server check_autofs_service
  install_service enable_service start_service
  check_service configure_service full_autofs_check);

my $autofs_conf_file       = '/etc/auto.master';
my $autofs_map_file        = '/etc/auto.master.d/autofs_regression_test.autofs';
my $test_conf_file         = '/etc/auto.iso';
my $test_mount_dir         = '/mnt/test_autofs_local';
my $file_to_mount          = '/tmp/test-iso.iso';
my $test_conf_file_content = "echo  iso     -fstype=auto,ro         :$file_to_mount > $test_conf_file";

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

sub install_service {
    zypper_call 'in autofs';
}

sub enable_service {
    systemctl 'enable autofs';
}

sub start_service {
    systemctl 'start autofs';
}

sub check_service {
    systemctl 'is-enabled autofs.service';
    systemctl 'is-active autofs';
}

sub configure_service {
    my ($stage) = @_;
    $stage //= '';

    # mkisofs is not distributed in JeOS based on sle12
    my $mk_iso_tool = (is_jeos and is_sle('<15')) ? 'genisoimage' : 'mkisofs';

    if ($stage eq 'function') {
        zypper_call("in autofs $mk_iso_tool") if (is_sle('15+') or is_jeos);
    }
    assert_script_run("mkdir -p ${test_mount_dir}");
    assert_script_run("chmod 0777 ${test_mount_dir}");
    assert_script_run("dd if=/dev/urandom of=$test_mount_dir/README bs=4024 count=1");
    assert_script_run("$mk_iso_tool -o $file_to_mount $test_mount_dir");
    assert_script_run("ls -lh $file_to_mount");
    assert_script_run("test -f $autofs_conf_file");

    check_autofs_service() if ($stage eq 'function');
    setup_autofs_server(autofs_conf_file => $autofs_conf_file,
        autofs_map_file        => $autofs_map_file,
        test_conf_file         => $test_conf_file,
        test_conf_file_content => $test_conf_file_content,
        test_mount_dir         => $test_mount_dir);

    systemctl 'restart autofs';
}

sub check_function {
    assert_script_run("ls $test_mount_dir/iso");

    my $mount_output_triggered = script_output("mount | grep -e $file_to_mount");
    die "Something went wrong, target is already mounted" unless $mount_output_triggered =~ /$file_to_mount/;
}

# clean up
sub do_cleanup {
    assert_script_run("sed -i_bk 's:+dir\\:/etc/auto\\.master\\.d:#+dir\\:/etc/auto\\.master\\.d:' $autofs_conf_file");
    systemctl 'restart autofs';

    assert_script_run("ls -la $test_mount_dir");
    assert_script_run("rm -fr $test_mount_dir/README");
    assert_script_run("rm -fr $test_mount_dir");
    assert_script_run("rm -fr $autofs_map_file");
    assert_script_run("rm -fr $test_conf_file");
}

sub full_autofs_check {
    my ($stage) = @_;
    $stage //= '';

    select_console 'root-console';

    if ($stage eq 'before') {
        install_service();
        enable_service();
        start_service();
        configure_service();
        check_service();
        check_function();
    }
    else {
        check_service();
        check_function();
        do_cleanup();
    }
}

1;
