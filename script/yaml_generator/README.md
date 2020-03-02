create a virtualenv and install the requirements.txt

run as
> python3 create_scheduler.py <jobid> <path_to_save> [<openqa_server>]

This will generate the <path_to_save>/template.yaml
ex:
> python3 create_scheduler.py 1 /tmp
or
> python3 create_scheduler.py 1 /tmp openqa.opensuse.org

If openqa_server is not given, OSD is used by default.
All the params are positional.

The template.yaml which is generated it has the
- name
- description
- vars
- schedule

Vars are taken by the suites variables
test_data are not included


Issues to address
---

- some environment variables are not translated. for example
> PUBLISH_HDD_1: SLES-%VERSION%-%ARCH%-%BUILD%@%MACHINE%-unregistered.qcow2
- todo: path should be setup to point to the schedule dir by default 
- todo: variables from a file
