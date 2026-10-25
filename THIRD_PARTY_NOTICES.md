# Third-party notices

NyxOS itself is licensed under the **GNU GPL v3** (see `LICENSE`).
It bundles or installs the following components, each under its own licence.

| Component | Where | Author | Licence |
|-----------|-------|--------|---------|
| [Basalt2](https://github.com/Pyroxenium/Basalt2) UI library | `NyxOS/data/lib/basalt.lua` (minified build, with small NyxOS compatibility patches at the top of the file) | Pyroxenium | MIT |
| [RedioNet](https://github.com/Rypo/redionet) | `NyxApps/Redionet/` (installed on demand with `apt install redionet`) | Rypo | MIT (`NyxApps/Redionet/LICENSE.txt`) |
| CCTchat | `NyxApps/CCTchat/` | yolezz | MIT (`NyxApps/CCTchat/LICENSE.txt`) |
| CCRF | `NyxApps/CCRF/` | yolezz | MIT (`NyxApps/CCRF/LICENSE.txt`) |
| [NyxLoader](https://github.com/yo-le-zz/NyxLoader) | downloaded by `install.lua`, not part of this repository | yo-le-zz | see its repository |

The MIT licence of Basalt2 requires its copyright notice and permission
notice to be kept with copies of the library; they are reproduced in the
upstream repository linked above.

Every package in `NyxApps/` keeps its own `LICENSE.txt` and `ORIGIN.md`
(upstream project, author, licence).
