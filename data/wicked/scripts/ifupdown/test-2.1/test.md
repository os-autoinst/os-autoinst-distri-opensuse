MACVLAN on VLAN on physical interface

- eth1 is not created or deleted by wicked on shutdown
- eth1.11 is created and deteled by wicked on shutdown

---

### tree:
```
    eth1    <-l-    eth1.11    <-l-    macvlan1
```

---

### ifup:

#### wicked ifup eth1

    - setup    eth1                requested
    - skip     eth1.11             unrequested / not required by setup interfaces
    - skip     macvlan1            unrequested / not required by setup interfaces

    options: --links

    - setup    eth1                requested
      - setup    eth1.11           via --links
        - setup    macvlan1        via --links

#### wicked ifup eth1.11

    - setup    eth1.11             requested
      - setup    eth1              required lower reference
    - skip     macvlan1            unrequested / not required by setup interfaces

    options: --links

    - setup    eth1.11             requested
      - setup    eth1              required lower reference
      - setup    macvlan1          via --links

#### wicked ifup macvlan1  

    - setup    macvlan1            requested
      - setup    eth1.11           required lower reference
        - setup    eth1            required lower reference

---

### ifdown:

#### wicked ifdown eth1

    - shutdown eth1                requested
      - shutdown eth1.11           depends on lower shutdown
        - shutdown macvlan1        depends on lower shutdown

#### wicked ifdown eth1.11

    - shutdown eth1.11             requested
      - shutdown macvlan1          depends on lower shutdown
    - skip     eth1                unrequested / no reference to shutdown interfaces

#### wicked ifdown macvlan1

    - shutdown macvlan1            requested
    - skip     eth1.11             unrequested / no reference to shutdown interfaces
    - skip     eth1                unrequested / no reference to shutdown interfaces

