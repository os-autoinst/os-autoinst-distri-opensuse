---
salttestgroup:
  group.present

salttestuser:
  user.present:
    - fullname: Salt Test
    - shell: /usr/bin/sh
    - home: /home/salttestuser
    - groups:
      - salttestgroup
