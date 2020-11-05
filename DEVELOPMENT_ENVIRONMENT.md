# A320 NORMAL CHECKLIST Developer Notes

Link to the up-do-date version of this document: [DEVELOPMENT_ENVIRONMENT.md](https://github.com/VerticalLongboard/xplane-a320-checklist/blob/main/DEVELOPMENT_ENVIRONMENT.md)

## Development Environment
If you happen to develop FlyWithLua plugins and are crossing the threshold from "coding a bit and pressing buttons to see if my plugin works" to "I don't like LUA too much, but it's doing its job and I like to code a bit more", feel free to use and adapt the VS Code / LuaUnit environment boilerplate from A320 NORMAL CHECKLIST.

Perks:
* **Linting** and colors while coding
* **Testing** as you're used to
* Pressing **Build** runs all tests, copies the script and dependencies to X-Plane and triggers a running X-Plane instance to reload all scripts
* Building a **release package** is only one button away (ZIP + Installer)
* Takes about 15 minutes (including downloads) to set up

### Setup
Required (Coding + Testing):
* Vanilla Windows 10
* Visual Studio Code: https://code.visualstudio.com/
* Install Lua: https://github.com/rjpcomputing/luaforwindows
* Download the A320 NORMAL CHECKLIST repository and open the workspace in VS Code!
* Run default build task via **CTRL+SHIFT+B** once and update local paths in:
  * `<repository root>/LOCAL_ENVIRONMENT_CONFIGURATION.cmd`

Optional:
* git: https://git-scm.com/ (Versioning)
* Install 7zip: https://www.7-zip.org/ (ZIP release package)
* Install NSIS: https://nsis.sourceforge.io/ (EXE release installer)
* Install Packetsender: https://packetsender.com/ (X-Plane remote command interface)
* Install VS Code extensions:
  * vscode-lua (linting): https://marketplace.visualstudio.com/items?itemName=trixnz.vscode-lua
  * Code Runner (lets you run selected snippets of code): https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner
  * NSIS (linting): https://marketplace.visualstudio.com/items?itemName=idleberg.nsis
* Update local paths and plugin name in:
  * `<repository root>/LOCAL_ENVIRONMENT_CONFIGURATION.cmd`
  * `<repository root>/build_configuration.cmd`

### Build
To build your plugin (and copy it to your locally running X-Plane instance), press **CTRL+SHIFT+B**, which runs the default build task.

### Release Package Generation
Creating a release package is done via pressing **CTRL+P** and typing `task packReleasePackage` into the little command panel that pops up.
