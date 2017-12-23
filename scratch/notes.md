# Debification
* add `etc` directory and conditionally install deb-specific PDNS
config files for API, etc.
## Debian packaging nuts and bolts
### The 'debian' directory
* `debian`
  * `changelog` (maintained by `dch` see man page for more
  details)
  * `compat` debhelper compatibility number: `10` (and nothing else)
  * `control` (package metadata, see `deb-control` man page for more
  details)
  * `copyright` empty for now.  Will need to figure out
  AppD-legal-friendly content here.
  * `rules` (debian-specific build-system rules)
  ```
  #!/usr/bin/make -f
   %:
           dh $@ --buildsystem=cmake
   ```
  * `source` (directory)
    * `format` (source tree layout version and type): `3.0 (git)`