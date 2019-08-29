# Declarative Schedule
- [Introduction](#introduction)
- [Overview](#overview)
- [Getting started](#getting-started)
	- [1. Create declarative schedule](#1-create-declarative-schedule)
		- [name](#name)
		- [description](#description)
		- [vars](#vars)
		- [conditional_schedule](#conditional_schedule)
		- [schedule](#schedule)
		- [test_data](#test_data)
	- [2. Enable scheduler in settings](#2-enable-scheduler-in-settings)
	- [3. Enable scheduler in main file](#3-enable-scheduler-in-main-file)
	- [4. Use different schedules for the same scenario](#4-use-different-schedules-for-the-same-scenario)
- [Other uses](#other-uses)

## Introduction

This is the documentation for declarative scheduling of test modules
which allows testers to schedule existing test modules in a more flexible way replacing main.pm mechanism.
However it is still work-in-progress due to it missing some features to be a full working solution
to replace it.

## Overview

 Declarative schedule is using a [YAML](https://en.wikipedia.org/wiki/YAML) file to specify all the information related with a test suite:
 - Test suite name and description
 - Test variables
 - Sequence of test modules

## Getting started

Prerequisites to use this mechanism are the following:

### 1. Create declarative schedule

The file to be created should look as follows:
```yaml
name:           test_suite_name
description:    >
    Test suite description.
    Further info about the test suite
vars:
    setting1_string: value1
    setting2_num: 2
    setting3_string: value3
    ...
conditional_schedule:
    module1:
        VAR1:
            <valueA>:
                - path/to/module/moduleA1
                - path/to/module/moduleA2
            <valueB>:
                - path/to/module/moduleB1
    ...

schedule:
    - {{module1}}
    - path/to/module/module2
    ...
test_data:
  list:
    - item1
    - item2
  hash:
    key1: value1
    key2: value2  
```
Previous structure contains the following sections:

#### name
Name of the test suite

#### description
Description of the test suite.

#### vars
Most of your settings could be migrated from openQA WebUI to this declarative way, for instance:
  - `BOOTFROM: c`
  - `BOOT_HDD_IMAGE: 1`

There are a few exceptions:
  - `DESKTOP`: it produces wrong .json in openQA WebUI
  - `HDD_1`: if added, openQA will not publish the image in openQA WebUI due to it depends on os-autoinst.
  - `START_AFTER_TEST`: if added, openQA will not link dependencies on the corresponding tab in openQA WebUI due to it depends on os-autoinst.
-   `UEFI_PFLASH_VARS`: if added, openQA will not publish in UI

#### conditional_schedule
Depending on different values of an environmental variable we can schedule different set of modules.
For instance, depending on the value of DISTRI setting we can schedule an ordered sequence of different tests for openSUSE or SLE.

```yaml
  conditional_schedule:
      addons_repos:
          DISTRI:
              opensuse:
                  - installation/online_repos
                  - installation/installation_mode
                  - installation/logpackages
              sle:
                  - installation/scc_registration
                  - installation/addon_products_sle
                  - installation/addon_products_sle
```

#### schedule
Refers to a sequence of test modules to be executed in the test suite. For the moment it was chosen this format `{{}}`
to indicate that the module or modules executed at this position is conditional to some variable as described in [conditional_schedule](#conditional_schedule).

**NOTE:**
 - [conditional_schedule](#conditional_schedule) does not allow at the moment to represent complex logic like combination of 'and' or 'or' and it does intend to do it due to potentially it would create the same problem that occurs with main.pm. Other kind of logic like a simple exclusion list could be feasible in the near future, for example "run for all except when this variable value is set to some specific value". Reusing of blocks needs to be re-thinked as well and what would be a readable syntax for this. At the moment if the scenario you intend to migrate has complex conditional logic it would require changes in your test modules.
 - The only section that is mandatory is [schedule](#schedule). The rest of the sections in the YAML file can be skipped.

#### test_data
As vars.json has quite limited capabilities due to the design, in the yaml files
it's possible to define any structure, which can be described using plain yaml
format. This data will be parsed and available when calling `get_test_data()`
method from `lib/scheduler.pm`. This feature is designed to store test related
date for data driven tests and provide better structure for the test suite settings.

The whole section is parsed with perl structures, so in case you have following
settings:
```
...
test_data:
  list:
    - item1
    - item2
  hash:
    key1: value1
    key2: value2
...
```
Your test code will look like:
```
sub run {
    my $test_data = get_test_data();
    foreach my $item (@{$test_data->{list}}) {
        diag $item;
    }

    while (($key, $value) = each (%{$test_data->{hash}})) {
        diag "$key: $value";
    }
}
```

Besides having test_data in the same yaml file for scheduling, it is possible to import test_data from another file with the following constrains:
 - test_data will be in a dedicated file that only contains data.
 - test_data file will not import data from another file (only one nested level to avoid complexity).
 For instance, we can have a test data file named `scenario_name_test_data.yaml` containing data as follows:

 ```
 disks:
  - name: vda
    partitions:
      - size: 2mb
  ...
```
And we can include those data in `scenario_name.yaml` using `!include` and the path to the file:
```
name:           scenario_name_test_data.yaml
description:    >
  ...
vars:
...
schedule:
  - path/to/module
...
test_data:
  !include: schedule/path/to/scenario_name_test_data.yaml
```
-  it is allowed to use multiple `!include` tags in yaml scheduling
   file. In the case they should be provided as list:

```
...
test_data:
  - !include: path/to/first_test_data.yaml
  - !include: path/to/second_test_data.yaml
```

- `!include` tag can be mixed with the test data that is defined in
  scheduling file directly:

> **_IMPORTANT:_** Test data in scheduling file has priority over the
> same data from the imported file (i.e. it allows to override imported
> data).
```
...
test_data:
  disks:
    - name: vdb
      partitions:
        - size: 3mb
  !include: path/to/test_data.yaml
```

### 2. Enable scheduler in settings

It is required to add in openQA WebUI in the test suite configuration a new setting `YAML_SCHEDULE` pointing to .yaml file path, for instance:
`YAML_SCHEDULE=schedule/test-suite-name.yaml`


### 3. Enable scheduler in main file

This functionality needs to be imported in corresponding main.pm for your product.
Only if `YAML_SCHEDULE` setting is set, information contained in .yaml file will be loaded and
execution of main.pm will be exited earlier and in turn the old main.pm mechanism will not be executed.
It is recommended to call the function after all variables have been set in main.pm.
 ```perl
 use scheduler 'load_yaml_schedule';
...
return 1 if load_yaml_schedule;
```

### 4. Use different schedules for the same scenario

Due to the fact that different backends need extra steps and that we want to abstract from the details,
we might want to use single scenario even when there are distinct.
For example, RAID 0 on UEFI will require different partitioning then in case of legacy boot.
Since we got Job template YAML feature, we can easily manage small and big discrepancies.

Consider example with RAID 0, assume we have multiple architectures to test on, then our scenarios section
can look like following:

```yaml
scenarios:
  aarch64:
    medium:
    - RAID0:
        settings:
          YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_uefi.yaml
  ppc64le:
    medium:
    - RAID0:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_prep_boot.yaml
  ppc64le:
    medium:
    - RAID0:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_prep_boot.yaml
  x86_64:
    medium:
    - RAID0_gpt:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt.yaml
```

You have differences due to backend implementation? Not a problem, you can override
settings per machine:

```yaml
scenarios:
  x86_64:
    medium:
    - minimal+base_yast:
      machine: 64bit
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast.yaml
    - minimal+base_yast:
      machine: svirt-xen-hvm
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast-xen.yaml
    - minimal+base_yast:
      machine: svirt-hyperv
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast-svirt-hyperv.yaml
```

And on top of that you can use aliases to avoid duplication. For more details, check output
[official documentation of openQA](http://open.qa/docs/)

## Other uses

Even if you don't intend to migrate your scenario right now, you can play with it for debugging proposes. Instead of relying in the complex path of execution that main.pm creates, if you just need to put some test in some particular order, perhaps a new scenario you just created, you can speed up your development using this approach.
