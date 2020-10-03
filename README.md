# Vatsimbrief Helper

## Overview

The plugin provides information from the **Simbrief flightplan** and relevant **VATSIM frequencies** for ATC communications in X-Plane 2D and VR flight setups.

It solves two major issues that VR pilots usually face:

* A printed flightplan cannot be taken into VR. And even if the resolution of the VR device allows for, scrolling through tiny Simbrief flightplan fonts is usually very exhausting.
* VATSIM frequencies cannot be obtained from official charts (e.g. Navigraph). Also, taking notes in VR takes much more time than in the real world.

![All windows](screenshots/overview.png "All windows")

## Dependencies

Required runtime Lua dependencies: copas, luasocket, binaryheap.lua, coxpcall, timerwheel.lua, LIP, xml2lua

They are also part of the release artifact.

## Installation and Usage

* Install FlyWithLua plugin: https://forums.x-plane.org/index.php?/files/file/38445-flywithlua-ng-next-generation-edition-for-x-plane-11-win-lin-mac/
* Extract the zip-File into `<X-Plane-Directory>/Resources/plugins/FlyWithLua`
* During first launch, enter your *VATSIM-Username* and press *Set*
* Windows can be toggled inside the plugins menu: `Plugins / FlyWithLua / FlyWithLua Macros` and select one of the following windows:
  * `Vatsimbrief Helper Flightplan`: Opens/closes a window showing a relevant excerpt of the flightplan. Refreshes automatically every minute.
  * `Vatsimbrief Helper ATC`: Opens/closes a window showing relevant ATC frequencies. Refreshes automatically every minute.
  * `Vatsimbrief Helper Control`: Opens/closes a window for setting the Simbrief username or reloading the flightplan or ATC data manually.

**Happy Flying!**
