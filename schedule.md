### Sample of yaml file for declarative scheduling
```
---
conditional_schedule:
    <conditional_module_1>:
        <VAR_NAME>:
            <var_value_1>:
                - <path_to_module>/<module_name_1>
                - <path_to_module>/<module_name_2>
            <var_value_2>:
                - <path_to_module>/<module_name_1b>

schedule:
    - {{conditional_module_1}}
    - <path_to_module>/<module_name_3>
```
