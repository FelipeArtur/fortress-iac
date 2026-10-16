# Contributing to Fortress IaC

This repository is archived and no longer accepts maintenance work. It remains
public as a record of the project that preceded AsusDebian.

To reuse the code, fork it and address the unresolved risks listed in
[README.md](README.md). The archive is not a supported security product.

## Inspecting the source

The following checks parse the Linux sources without installing the filter:

```bash
bash -n linux/files/fortress-update
ansible-playbook linux/playbook.yml --syntax-check
```

Runtime experiments require a disposable virtual machine with isolated test
data. The scripts change privileged system files, scheduled tasks and browser
policies. Syntax checks do not validate security or recovery behavior.

The Windows scripts were not executed or validated on Windows during archival.
The original development and contribution instructions remain in Git history.
