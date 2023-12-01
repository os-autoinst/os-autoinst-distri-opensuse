VLAN on virtual interface

- dummy0 is created and deleted by wicked on shutdown
- Using vlan11, see https://gitlab.suse.de/wicked-maintainers/wicked/-/issues/427

---

### tree:
```
    dummy1    <-l-    vlan11
```

---

### ifup:

#### wicked ifup dummy1

    - setup    dummy1              requested
    - skip     vlan11              unrequested / not required by setup interfaces

    trigger: links=enabled

    - setup    dummy1              requested
      - setup    vlan11            via links trigger

#### wicked ifup vlan11

    - setup    vlan11              requested
      - setup    dummy1            required lower reference

---

### ifdown:

#### wicked ifdown dummy1

    - shutdown dummy1              requested
      - shutdown vlan11            depends on lower shutdown

#### wicked ifdown vlan11

    - shutdown vlan11              requested
    - skip     dummy1              unrequested / no reference to shutdown interfaces

