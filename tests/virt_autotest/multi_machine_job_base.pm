# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: base class for virtualization multi-machine job
# Maintainer: alice <xlai@suse.com>

package multi_machine_job_base;
use base "virt_autotest_base";
use strict;
use warnings;
use testapi;
use utils;
use mmapi;
use Data::Dumper;
use Carp;

sub get_var_from_parent {
    my ($self, $var) = @_;
    my $parents = get_parents();
    #Query every parent to find the var
    for my $job_id (@$parents) {
        my $ref = get_job_autoinst_vars($job_id);
        return $ref->{$var} if defined $ref->{$var};
    }
    return;
}

sub get_var_from_child {
    my ($self, $var) = @_;
    my $child = get_children();
    #Query every child to find the var
    for my $job_id (keys %$child) {
        my $ref = get_job_autoinst_vars($job_id);
        return $ref->{$var} if defined $ref->{$var};
    }
    return;
}

sub set_ip_and_hostname_to_var {
    my $self = shift;
    my $ip_out = $self->execute_script_run('ip route show|grep kernel|cut -d" " -f12|head -1', 30);
    my $name_out = $self->execute_script_run('hostname', 10);

    set_var('MY_IP', $ip_out);
    set_var('MY_NAME', $name_out);
    bmwqemu::save_vars();
}

sub set_hosts {
    my ($self, $role) = @_;

    my ($target_ip, $target_name);

    if ($role =~ /parent/) {

        $target_ip = $self->get_var_from_child('MY_IP');
        $target_name = $self->get_var_from_child('MY_NAME');

    }
    else {

        $target_ip = $self->get_var_from_parent('MY_IP');
        $target_name = $self->get_var_from_parent('MY_NAME');
    }

    $self->execute_script_run("sed -i '/$target_ip/d' /etc/hosts ;echo $target_ip $target_name >>/etc/hosts", 15);
    my $self_ip = get_var('MY_IP');
    my $self_name = get_var('MY_NAME');
    $self->execute_script_run("sed -i '/$self_ip/d' /etc/hosts ;echo $self_ip $self_name >>/etc/hosts", 15);

}

#mmapi mutex_lock has flaws to get lock from child in parent job
#workaround is to do it via var, that is use var instead of lock
sub workaround_for_reverse_lock {
    my ($self, $var, $timeout) = @_;
    my $try_times = 0;

    while (not(my $pesudo_lock = $self->get_var_from_child("$var"))) {
        sleep 60;
        die if ($try_times == $timeout / 60);
        $try_times++;
    }

}

sub setup_passwordless_ssh_login {
    my ($self, $ip_addr) = @_;

    croak("Missing ssh host ip!") unless $ip_addr;
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa <<< y');
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root\@$ip_addr");
}

1;
