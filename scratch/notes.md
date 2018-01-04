# Debification
* add `etc` directory and conditionally install deb-specific PDNS
config files for API, etc.
## Debian packaging nuts and bolts
### The 'debian' directory
* `debian`
  * `changelog` (maintained by `dch` see man page for more
  details)
  * `compat` debhelper compatibility number: `10` (and nothing else)
  * `control` (See
  https://www.debian.org/doc/debian-policy/#document-ch-controlfields
  for more details)
  * `copyright` AppD-legal-friendly content here. (See
  http://dep.debian.net/deps/dep5/ for more information)<BR>
  Example:

```
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: pdns-api-scripts
Upstream-Contact: Mike Przybylski <mike.przybylski@appdynamics.com>
Source: https://github.com/appdynamics/pdns-api-scripts

Files: *
Copyright: Copyright 2018, AppDynamics LLC and its affiliates
License: Apache-2
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 .
 http://www.apache.org/licenses/LICENSE-2.0
 .
 or view it in /usr/share/common-licenses/Apache-2.0
 .
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
```

  * `rules` (debian-specific build-system rules)
  ```
  #!/usr/bin/make -f
   %:
           dh $@ --buildsystem=cmake
   ```
  * `source` (directory)
    * `format` (source tree layout version and type): `3.0 (git)` or
    `3.0 (native)`
  * `*package_name*.install` Useful for splitting a build into multiple
  packages.  See `dh_install` man page for more details.
## References
*