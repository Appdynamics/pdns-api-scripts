# Debification
* add `etc` directory and conditionally install deb-specific PDNS
config files for API, etc.
## Debian packaging nuts and bolts
### The 'debian' directory
* `debian`
  * `changelog` (maintained by `dch` see man page for more
  details)
  * `control` (package metadata, see `deb-control` man page for more
  details)
