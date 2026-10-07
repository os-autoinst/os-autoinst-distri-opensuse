# Kernel bare metal multimachine tests with a topology

This guide explains how to write and run kernel multimachine tests on
bare metal, where a YAML file describes the machines with their real
names, addresses, cards and disks.

## When to use it

Use a topology when:

* the test runs on bare metal machines, so peer names and addresses are
  not fixed by openQA
* the setup has more than a server and a client, for example a router
  between two networks
* a machine takes part without running an openQA job, for example a
  storage appliance
* several tests use the same machines

## How it works

```
test_data/kernel/multimachine/<setup>.yaml   machines, roles, networks, interfaces
        |  included by the schedule
        v
openQA scheduler -> test_data
        |
        v
Kernel::multimachine_topology                reads and validates it, answers questions:
        |                                    which node am I, who are my peers,
        |                                    which interface, which network
        v
kernel/multimachine_barriers                 creates the barriers
Kernel::net_tests and other libraries        set up the machine
test modules                                 the actual test
```

The same test modules run on any setup. A different pair of machines or
other addresses only need another YAML file and a schedule that includes
it. Each job only needs its `ROLE` and the worker it runs on.

## The topology file

The examples in this guide use a two machine "hello" setup to show the
pieces. They are not in the repository; the complete example is listed at
the end of "The test module".

```yaml
multimachine_topology:
  name: hello_2hosts

  networks:
    - id: lab
      ipv4_cidr: "192.0.2.0/24"

  nodes:
    - id: node1              # unique name of the node
      role: sut              # matches ROLE of the job on this machine
      interfaces:
        - id: eth0           # interface name on the machine
          network: lab       # id of a network above
          ipv4: "192.0.2.10"

    - id: node2
      role: peer
      interfaces:
        - id: eth0
          network: lab
          ipv4: "192.0.2.11"
```

Fields:

* `networks`: `id`, and `ipv4_cidr` or `ipv6_cidr`.
* `nodes`: `id` and `role` (both unique) and `interfaces`.
  * `external: 1` marks a node that does not run a job, for example a
    storage appliance. Other nodes can look it up, but it does not take
    part in barriers.
* `interfaces`: `id`, `network`, and optionally `ipv4` and `ipv6`.
  * `static: 1` means that the test adds the addresses. Without it, the
    addresses come from the lab network, for example from DHCP, and the
    test only waits for them.
* Tests can add their own keys to nodes and interfaces. Only the test that
  uses a key defines its meaning.

### Roles and external nodes

The topology gives each node a `role`, for example `sut` or `peer`. A
role belongs to one node only. The test module decides which roles it
expects and what each one does.

Each openQA job sets the job variable `ROLE` to the role of its node.
`get_local_node()` finds the node of the job from it. Set `ROLE` in the
test suite of the job: define one test suite per role in the job group,
see "Running it in openQA".

A node with `external: 1` is part of the setup but does not run a job,
for example a storage appliance. No job has its role, it does not take
part in barriers and it cannot be the local node; other nodes look it up
by its role.

## The schedule

```yaml
name: hello_2hosts
vars:
    INST_AUTO: agama_auto/sle_default_ipmi.jsonnet
    DESKTOP: textmode
test_data:
    <<: !include test_data/kernel/multimachine/hello_2hosts.yaml
    multimachine_barriers:
        - HELLO_READY
        - HELLO_DONE
schedule:
    - kernel/multimachine_barriers   # first, before the installation
    - installation/ipxe_install
    - installation/agama_reboot
    - installation/grub_test
    - installation/first_boot
    - kernel/hello                   # the test
```

Both jobs use the same schedule. Barrier names belong to the test code, so
they are in the schedule, not in the topology file.

`kernel/multimachine_barriers` creates the barriers in `multimachine_barriers`.
Every job schedules it. openQA finds the barriers of a job only in the job
itself and its parallel parents, so the job without parallel parents
creates them for all jobs of the openQA cluster and then signals the
other jobs with a mutex. With a topology, it also checks that the nodes
that run a job match the jobs of the cluster. It is the only generic
module: each test sets up what it needs on the machine itself, see the
next section.

## The test module

```perl
use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use Kernel::multimachine_topology qw(get_local_node get_peers get_node_interface);
use Kernel::net_tests qw(set_link_up wait_for_ipv4_addr);

sub run {
    my $me = get_local_node();
    my $if = get_node_interface($me, 0);
    set_link_up($if->{id});
    wait_for_ipv4_addr($if->{id}, $if->{ipv4});
    barrier_wait({name => 'HELLO_READY', check_dead_job => 1});
    for my $peer (@{get_peers($me)}) {
        my $ip = get_node_interface($peer, 0)->{ipv4};
        assert_script_run("ping -c 3 $ip");
        record_info('Hello', "$me->{id} ($me->{role}) reached $peer->{id} at $ip");
    }
    barrier_wait({name => 'HELLO_DONE', check_dead_job => 1});
}
```

Helpers of `Kernel::multimachine_topology` (see its POD):

| Helper | Returns |
|---|---|
| `get_local_node()` | the node of this job, from `ROLE` |
| `get_node_by_role($role)` | the node with that role |
| `get_peers($node)` | all other nodes, external ones included |
| `get_job_nodes()` | the nodes that run a job |
| `get_node_interface($node, $index)` | an interface entry of a node |
| `get_topology_network($id)` | a network entry |
| `get_topology()` | the whole topology |
| `require_field($value, $message)` | `$value`, or dies with `$message` |

The topology library only reads the topology; it does not change the
machine. Libraries such as `Kernel::net_tests` set up the machine with
getters and setters that take plain values, for example an interface
name and an address, not topology entries. The test module reads the
topology and passes the values on. `setup_interface` in
`irq_delivery_network` also adds `static` addresses.

Use `check_dead_job => 1` in `barrier_wait`, so that a job stops waiting
when the other job died, instead of hanging until the timeout.

A complete example is `irq_delivery_network` with
`schedule/kernel/agama_irq_delivery_2hosts_baremetal.yaml` and
`test_data/kernel/multimachine/irq_delivery_2hosts.yaml`.

## Running it in openQA

A multimachine test needs one job per node that runs a job:

* each job has its own `ROLE` and `WORKER_CLASS` (the machine)
* the jobs are linked with `PARALLEL_WITH`, so that they start together:
  one job is the parallel parent of all other jobs. Which node it is does
  not matter.
* both jobs use the same `YAML_SCHEDULE`

In a job group, define one test suite per role, with its `ROLE` and
`WORKER_CLASS`. The test suites of the other roles name the parallel
parent in `PARALLEL_WITH`:

```yaml
- irq_delivery_2hosts_sut:
    testsuite: null
    settings:
      ROLE: sut
      WORKER_CLASS: 64bit-epyc-eth25G-coppi
      YAML_SCHEDULE: schedule/kernel/agama_irq_delivery_2hosts_baremetal.yaml
- irq_delivery_2hosts_peer:
    testsuite: null
    settings:
      ROLE: peer
      WORKER_CLASS: 64bit-epyc-eth25G-merckx
      YAML_SCHEDULE: schedule/kernel/agama_irq_delivery_2hosts_baremetal.yaml
      PARALLEL_WITH: irq_delivery_2hosts_sut
```
