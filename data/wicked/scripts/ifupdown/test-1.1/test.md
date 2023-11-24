VLAN on physical interface

- eth1 is not created or deleted by wicked on shutdown
- Using vlan11 to be consistent with test-1.2

---

### tree:
```
    eth1    <-l-    vlan11
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
    - skip     vlan11              unrequested / not required by setup interfaces

    options: --links

    - setup    eth1                requested
      - setup    vlan11            via --links

#### wicked ifup vlan11

    - setup    vlan11              requested
      - setup    eth1              required lower reference

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
      - shutdown vlan11            depends on lower shutdown

#### wicked ifdown vlan11

    - shutdown vlan11              requested
    - skip     eth1                unrequested / no reference to shutdown interfaces

