# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check the sysctl.d file load order of wicked. It's not like
#          `sysctl --system` as procps-ng >=3.3.17 changed the
#          sysctl.d load order like systemd.
#
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'wickedbase';
use testapi;
use serial_terminal 'select_serial_terminal';
use autotest ();
use File::Basename;
use Mojo::Util qw(trim);

our $wicked_show_config = 'wicked --log-level debug --debug all  show-config all';
our @sysctl_d = qw(
  /etc/sysctl.d
  /run/sysctl.d
  /usr/local/lib/sysctl.d
  /usr/lib/sysctl.d
  /lib/sysctl.d
);

sub wicked_get_file_order {
    my $out = script_output($wicked_show_config . ' |& grep "Reading sysctl file"');
    my @files = ($out =~ m/file\s+'([^']+)'/g);
    return \@files;
}

sub wicked_get_file_errors {
    my $out = script_output($wicked_show_config . ' |& grep "Cannot open"');
    my @files = ($out =~ m/Cannot open\s+'([^']+)'/g);
    return \@files;
}

sub sysctl_emu_file_order {
    state $boot_sysctl = '/boot/sysctl.conf-' . trim(script_output('uname -r'));
    my @retval = ($boot_sysctl);
    my @sysctl_d_files = split(/\r?\n/, script_output("find @sysctl_d -name '*.conf' 2> /dev/null", proceed_on_failure => 1));

    my %sysctl_d;
    for my $file (@sysctl_d_files) {
        my $basename = basename($file);
        $sysctl_d{$basename} = $file unless $sysctl_d{$basename};
    }

    push @retval, $sysctl_d{$_} foreach (sort keys %sysctl_d);
    push @retval, '/etc/sysctl.conf' if script_run('test -e /etc/sysctl.conf', die_on_timeout => 1) == 0;

    return \@retval;
}

sub check_load_order {
    my $exp_order = shift // sysctl_emu_file_order();
    my $wicked = wicked_get_file_order;

    unless (join(',', @$exp_order) eq join(',', @$wicked)) {
        die("wicked load the sysctl files in different order\n" .
              "expect: @$exp_order\n" .
              "wicked: @$wicked\n");
    }
}

sub check {
    my ($self, $ctx) = @_;

    check_load_order();

    # Check order of files in sysctl.d directories
    for my $dir (@sysctl_d) {
        assert_script_run("mkdir -p $dir && touch $dir/20-test.conf");
        check_load_order();
    }
    for my $dir (reverse @sysctl_d) {
        assert_script_run("mkdir -p $dir && touch $dir/21-test.conf");
        check_load_order();
    }

    for my $dir (@sysctl_d) {
        assert_script_run("rm -f $dir/20-test.conf");
        check_load_order();
    }

    for my $dir (reverse @sysctl_d) {
        assert_script_run("rm -f $dir/21-test.conf");
        check_load_order();
    }

    # Check SUSE special ifsysctl files
    my $sysctl_order = sysctl_emu_file_order();
    my $sysctl_f1 = '/etc/sysconfig/network/ifsysctl';
    my $sysctl_f2 = '/etc/sysconfig/network/ifsysctl-' . $ctx->iface();
    assert_script_run("touch $sysctl_f1");
    check_load_order([@$sysctl_order, $sysctl_f1]);

    assert_script_run("touch $sysctl_f2");
    check_load_order([@$sysctl_order, $sysctl_f1, $sysctl_f2]);

    assert_script_run("rm $sysctl_f1");
    check_load_order([@$sysctl_order, $sysctl_f2]);

    assert_script_run("rm $sysctl_f2");
    check_load_order();

    # Check broken symlinks
    for my $dir (reverse @sysctl_d) {
        my $file = "$dir/20-test.conf";
        next if (script_run('test -L /lib', die_on_timeout => 1) == 0);
        assert_script_run("mkdir -p $dir && ln -s /I_do_not_exists $file");
        check_load_order();
        die("Missing broken '$file' in logs") unless grep { $_ eq $file } @{wicked_get_file_order()};
        die("Missing error message for '$file'") unless grep { $_ eq $file } @{wicked_get_file_errors()};
    }

    # Exceptional behavior for /etc/sysctl.conf, it is silently ignored
    my $file = "/etc/sysctl.conf";
    assert_script_run("rm $file");
    assert_script_run("ln -s /I_do_not_exists $file");
    check_load_order();
    die("Wrongly showing broken '$file' in logs") if grep { $_ eq $file } @{wicked_get_file_order()};
    die("Wrongly showing missing '$file' in logs") if grep { $_ eq $file } @{wicked_get_file_errors()};
}

sub setup_interfaces {
    my ($self, $ctx) = @_;

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), <<EOT);
        STARTMODE='hotplug'
        BOOTPROTO='static'
EOT
    $self->wicked_command('ifreload', 'all');
}

sub run {
    my ($self, $ctx) = @_;
    select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.69');

    record_info('sysctl.d', script_output("ls -R @sysctl_d", proceed_on_failure => 1));

    $self->setup_interfaces($ctx);
    $self->check($ctx);
}

1;
