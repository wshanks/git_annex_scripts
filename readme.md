# git annex scripts

This repo contains scripts helpful for working with
[git-annex](http://git-annex.branchable.com).

---

### git_annex_decrypt.sh

```text
Usage: git_annex_decrypt.sh -r REMOTE [-k SYMLINK] [-d FILE]

    Either lookups up key on REMOTE for annex file linked with SYMLINK
    or decrypts FILE encrypted for REMOTE.

    -r: REMOTE is special remote to use
    -k: SYMLINK is symlink in annex to print encrypted special remote key for
    -d: FILE is path to special remote file to decrypt to STDOUT

NOTES: 
    * Run in an indirect git annex repo.
    * Must specify -k or -d.
    * -k prints the key including the leading directory names used for a 
       directory remote (even if REMOTE is not a directory remote)
    * -d works on a locally accessible file. It does not fetch a remote file
    * Must have gpg and openssl
```
