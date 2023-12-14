package vagrant;
use testapi;
use strict;
use warnings;
use utils;

our @ISA = qw(Exporter);
our @EXPORT = qw(setup_vagrant_libvirt setup_vagrant_virtualbox run_vagrant_cmd);

sub install_vagrant {
    # no need to repeat if vagrant is already installed
    if (script_run('vagrant --version') == 0) {
        return;
    }

    # jq required for parsing the json
    zypper_call('in jq');
    assert_script_run('curl -O https://checkpoint-api.hashicorp.com/v1/check/vagrant');

    my $vagrant_version = script_output('jq -r ".current_version" < vagrant');
    my $download_url = script_output('jq -r ".current_download_url" < vagrant');

    # https://releases.hashicorp.com/vagrant/2.4.0/vagrant-2.4.0-1.x86_64.rpm
    my $vagrant_rpm = 'vagrant-' . $vagrant_version . '-1.x86_64.rpm';
    assert_script_run('rpm -i ' . $download_url . $vagrant_rpm);
}

# - install vagrant and virtualbox
# - launch the required daemons
sub setup_vagrant_virtualbox {
    select_console('root-console');

    install_vagrant();

    zypper_call("in virtualbox");
    systemctl("start vboxdrv");
    systemctl("start vboxautostart-service");
    assert_script_run("usermod -a -G vboxusers bernhard");
}

sub run_vagrant_cmd {
    my ($cmd, %args) = @_;

    my $logfile = 'vagrant_cmd.log';
    local $@;
    my $ret = eval {
        return script_run("VAGRANT_LOG=DEBUG vagrant $cmd 2> $logfile", %args);
    };
    return undef if $ret == 0;
    if (!$ret) {
        upload_logs($logfile);

        if ($@) {
            die $@;
        }
        die "'vagrant $cmd' failed with $ret";
    }
}
