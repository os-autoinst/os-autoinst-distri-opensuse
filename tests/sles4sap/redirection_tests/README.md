# Redirection test modules

## Overview

Test modules in this directory are intended for testing scenarios with remote SUT (System under test).  
This means worker VM is serving only as an SSH jumphost to SUT.

```| OpenQA instance| --> | QEMU Worker | --> Open SSH terminal --> | System under test|```   

This is achieved using console redirection located in `lib/sles4sap/console_redirection.pm`.  

Test modules are independent of a particular deployment solution and do not contain code related to it. 
Technically, you should be able to run test with two (or more)
local workers where one worker serves as an SSH gateway and test coordinator to the others.

One exception is base test with post-fail/post-run hooks as there is no solution yet to separate those from test code.

### Practical goal

At the moment, there are multiple projects in SLES4SAP/HA that use different deployment solutions,
and the test code is tied to it to some degree.
This means that each test scenario requires separate test modules for each platform/project.
The goal is to decrease redundant work done while increasing the coverage. 

**Specifically, projects below:**
- Cloud tests deployed using [qe-sap-deployment](https://github.com/SUSE/qe-sap-deployment)
- Azure tests deployed using [SAP deployment automation framework](https://github.com/Azure/sap-automation)
- Tests with SUT running directly on OpenQA worker - using one of the workers as an SSH Jump host
- Remote VMWare deployments

### Ideal goal

One test to rule them all!
Completely independent test modules which will work on any deployment solution if test start criteria are met.
They should solve a problem with poverty, invent panacea, end all conflicts and achieve world peace.

## Rules

- `K`eep `I`t `S`imple `S`tupid
- Do not base test modules on specific deployment type but on use of console redirection principle:
  - worker serves as SSH jumphost to SUT
  - standard OpenQA API calls are executed transparently on remote host the console is redirected to (in most cases SUT) 
- Ideally test module should work regardless of deployment if required start conditions are met (input variables, SUT state, etc...)
- Always document test module requirements, input parameters in `SYNOPSIS` or create an .md file
- Keep documentation up to date
- Sadly, there will be projects that won't be able to benefit from this concept, please don't make compromises and shortcuts for the sake of one project. 

## Requirements

- working passwordless SSH connection from worker VM to SUT  

## Redirection data structure

There is a standard required data that has to be provided to test module using `$run_args->{redirection_data}`.
Redirection data contains a list of hosts which belong to the tested infrastructure and SSH connection data.

```
$run_args->{redirection_data} = {
    host_group_type => {
        'hostname' => {
            ip_address => '',
            ssh_user   => ''
        }
    }
};
```

Example:
```
$run_args->{redirection_data} = {
    ha_node => {
        cluster_01 => {
            ip_address => '192.168.1.3',
            ssh_user   => 'hanaadmin'
        },
        cluster_02 => {
            ip_address => '192.168.1.4',
            ssh_user   => 'hanaadmin'
        },
        cluster_03 => {
            ip_address => '192.168.1.3',
            ssh_user   => 'hanaadmin'
        },        
    },
    db_hana => {
        hanadb_a => {
            ip_address => '192.168.1.3',
            ssh_user   => 'hanaadmin'
        },
        hanadb_b => {
            ip_address => '192.168.1.4',
            ssh_user   => 'hanaadmin'
        }
    },
    db_ase => {
        asedb => {
            ip_address => '192.168.1.5',
            ssh_user   => 'hanaadmin'
        }
    },    
    nw_pas   => {
        nw_pas => {
            ip_address => '192.168.1.6',
            ssh_user   => 'hanaadmin'
        }
    },
    nw_aas   => {
        nw_aas_01 => {
            ip_address => '192.168.1.7',
            ssh_user   => 'hanaadmin'
        },
        nw_aas_02 => {
            ip_address => '192.168.1.8',
            ssh_user   => 'hanaadmin'
        }
    },
    nw_ascs  => {
        nw_ascs => {
            ip_address => '192.168.1.9',
            ssh_user   => 'hanaadmin'
        }
    },
    nw_ers   => {
        nw_ers => {
            ip_address => '192.168.1.10',
            ssh_user   => 'hanaadmin'
        }
    }
};
```

Please keep information in the data structure only relevant to console redirection.  
If a test module needs additional information (data about sap instances),
create a new required structure and document it.
Try to make this structure generic, not based on a specific document outputted from a specific deployment solution like
a tfvars file.

For data to be passed between test modules, it is required to include variable `TEST_CONTEXT: OpenQA::Test::RunArgs`
into YAML schedule:

```
vars:
  TEST_CONTEXT: 'OpenQA::Test::RunArgs'
```

# Test module example

Below is an example of a basic test module which loops over all hosts and tests common API calls:

```
sub run {
    my ($self, $run_args) = @_;
    my %redirection_data = %{ $run_args->{redirection_data} };
    
    for my $instance_type (keys(%redirection_data)) {
        my $hosts = redirection_data{$instance_type};
        for my $hostname (keys %$hosts) {
            my $ip_addr = $hosts->{$hostname}{ip_address};
            my $user = $hosts->{$hostname}{user};
            
            # Redirect console to SUT
            connect_target_to_serial(destination_ip=>$ip_addr, ssh_user=>$user);
            
            # Do your things on SUT
            record_info(script_output('sudo crm status'));
            my $hostname_real = script_output('hostname');
            assert_script_run("echo \$(hostname) > /tmp/hostname_$hostname_real");
            upload_logs("/tmp/hostname_$hostname_real");
            
            # Disconnect serial from SUT <- never forget to do that. 
            disconnect_target_from_serial();
        }
    }
}
```