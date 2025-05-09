use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_host_agent;

subtest '[parse_instance_name] ' => sub {
    my ($sid, $id) = @{parse_instance_name('POO08')};
    is $sid, 'POO', "Return correct SID: $sid";
    is $id, '08', "Return correct ID: $id";
};

subtest '[parse_instance_name] Exceptions' => sub {
    dies_ok { parse_instance_name('POO0') } 'Instance name with less than 5 characters';
    dies_ok { parse_instance_name('POO0ASDF') } 'Instance name with more than 5 characters';
    dies_ok { parse_instance_name('POO0 ') } 'Instance name contains spaces';
    dies_ok { parse_instance_name('Poo0a') } 'Instance name contains lowercase characters';
    dies_ok { parse_instance_name('POO0.') } 'Instance name contains any non-word characters';
};

done_testing;
