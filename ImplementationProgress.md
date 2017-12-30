## Implementation Progress

This file describes how much of libgit2 has successfully been wrapped by swift methods.

| libgit2 header | Swift file | Percentage | Notes |
| -------------- | ---------- | ---------- | ----- |
| branch.h | Branch.swift | 100% | |
| commit.h | Commit.swift | 100% | |
| diff.h | Diff.swift | 20% | |
| index.h | Index.swift | 10% | lots to do here |
| oid.h | OID.swift | 30% | sha+short sha |
| revwalk.h | RevWalk.swift | 20% | next |
| refs.h | Reference.swift | 30% | |
| remote.h | Remote.swift | 0% | Storing reference |
| repository.h | Repository.swift | 30% | lots left |
| signature.h | Signature.swift | 40% | create with name/email/time |
| status.h | Status.swift | 95% | all that is left is options |
| transport.h | Credential.swift | 80% | git_cred_ssh_interactive_new is left |
| tree.h | Tree.swift | 0% | storing reference |
| | | | |
| checkout.h | Repository+Checkout | 30% | |