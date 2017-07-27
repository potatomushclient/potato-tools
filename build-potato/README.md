# Building Potato releases

## Remember to request updated translations from everyone!
  1. Rebuild Translation Template
  1. Merge template with all translations
  1. Request updated translations.

## Update the repository
  1. Update `potato.vfs/lib/potato-version.tcl` with the correct version and `git push`!
  1. Update the help release date, and make sure the help version is listed in both _Sidebar.md and PastVersions.md, then `git push` in `lib/help`.
  1. Create the git tag: `git tag -a <version> -m "Version <version> Release"` then push: `git push origin <version>`

## Get Potato and build it
  1. Check out a clean copy:
    1. `cd /cygdrive/e/potato-tools/build-potato/`
    1. `git clone --depth 1 --branch <version> https://github.com/talvo/potato.git build`
    1. `rm -rf build/.git`
    1. `git clone --depth 1 https://github.com/talvo/potato.wiki.git build/potato.vfs/lib/help`
    1. `rm -rf build/potato.vfs/lib/help/.git`
  1. Run `build-potato.tcl`

## NOTES

This script is intended for my own use, running on Windows. If you want to use it to build Potato yourself, you may need to make changes (especially if you're running on another OS). Current dependencies are:

  - Tcl/Tk installed
  - Basekits or Tclkits, or equivilent, for 32- and 64-bit Windows.
  - Resource Hacker
  - RC.exe from MSVC
  - 7zip
  
