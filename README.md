# Vatsimbrief Helper

## Overview

The plugin provides information from the **Simbrief flight plan** and/or relevant **VATSIM frequencies** for ATC communications in X-Plane 2D and VR flight setups.

It solves major issues that VR pilots usually face:

* A printed flight plan can not be taken into VR. And even if the resolution of the VR device allows for, scrolling through tiny Simbrief flight plan fonts is usually very exhausting.
* VATSIM frequencies can not be obtained from official charts (e.g. Navigraph). Also, taking notes in VR takes a lot of time, which easily distresses pilots.
* Air traffic control stations are highly volatile. When using the plugin it can be avoided to approach an unmonitored airport. Instead, pilots can divert to their alternate where there are air traffic controllers on service.

![All windows](screenshots/overview.png "All windows")

## Installation

* Install FlyWithLua plugin: https://forums.x-plane.org/index.php?/files/file/38445-flywithlua-ng-next-generation-edition-for-x-plane-11-win-lin-mac/
* Download the [latest release of this plugin](https://github.com/RedXi/vatsimbrief-helper/releases/latest)
* Extract the folders in the zip-File to `<X-Plane-Directory>/Resources/plugins/FlyWithLua` and, if asked, overwrite existing files
* During first launch, a configuration window will show automatically. Enter your *Simbrief Username* and press *Set*.

## Usage

* Create your flight plan on [simbrief](https://www.simbrief.com/) as usual, at some time before takeoff.
* Windows can be toggled inside the plugins menu `Plugins / FlyWithLua / FlyWithLua Macros`:
  * `Vatsimbrief Helper Flight Plan`: Opens/closes a window showing a relevant excerpt of the flight plan.
  * `Vatsimbrief Helper ATC`: Opens/closes a window showing relevant ATC frequencies.
  * `Vatsimbrief Helper Control`: Opens/closes a window for setting the Simbrief username or reloading the flight plan or ATC data manually.
* If an attribute has two values separated by `/`, the left value refers to the **destination** and the right one to the **alternate**
* Windows will refresh automatically every minute.
* If you find that the font in a window is too small, scale it up by dragging the bottom right corner of each window.

**Happy Flying!**

## Dependencies

Required runtime Lua dependencies: copas, luasocket, binaryheap.lua, coxpcall, timerwheel.lua, LIP, xml2lua

They are bundled with the release artifact.

## FAQ

*Could the plugin provide more automatism and/or interactivity, e.g. calculate the remaining time to scheduled take off?*

The plugin is not going to become another FMC. It's meant to provide the pilot with necessary information to do his job.

*I'm not using VATSIM. Does it make sense to use this plugin?*

One can close the ATC window and only use the precious flight plan information. On the other hand, only using VATSIM without Simbrief does not make sense as the output of the ATC window depends on an active flight plan.

## Feedback

You're welcome to provide feedback or report issues on [gitlab](https://github.com/RedXi/vatsimbrief-helper).
