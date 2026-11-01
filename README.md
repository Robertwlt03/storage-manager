<p align="center">
  <img src="assets/banner.svg" alt="Storage Manager. See at a glance where your storage goes." width="100%">
</p>

<p align="center">
  <a href="https://github.com/Robertwlt03/storage-manager/releases/latest/download/Storage-Manager.dmg">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/download-dark.svg">
      <img src="assets/pictures/download-light.svg" alt="Download Storage Manager for Mac" width="380">
    </picture>
  </a>
</p>

<p align="center">
  <sub><a href="#install-it-in-a-minute">How to install it</a> · <a href="https://github.com/Robertwlt03/storage-manager/releases">All versions</a></sub>
</p>

**Storage Manager** shows you where the storage on your Mac goes. It measures all the important areas, sorts them
into categories that make sense, and also finds what macOS otherwise hides from you. Then it tells you how much you can
free and walks you there, one step at a time. Everything stays on your Mac, because the app only reads sizes and sends
nothing to the internet.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/tour-dark.svg">
    <img src="assets/pictures/tour-light.svg" alt="A tour through Storage Manager: the overview, folders as rings, large files, clean up, duplicates and unused apps" width="100%">
  </picture>
</p>

<p align="center"><sub>The pictures show the demo with made-up data, which <code>make demo</code> opens.</sub></p>

## <img src="assets/icons/features.svg" height="33" align="absmiddle" alt="">What it does

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/features-dark.svg">
  <img src="assets/pictures/features-light.svg" alt="Overview, Folders, Large Files and Search, Clean Up, Duplicates, Unused Apps, menu bar, widget and report" width="100%">
</picture>

<details>
<summary><b>Every page in detail</b></summary>
<br>

The **Overview** is your home page. Right at the top it answers the real question: how much space you can free up. It
then lists the steps to get there in a sensible order, cleaning up, duplicates and unused apps, each with what it
frees and a button that takes you to its page. Below that, it shows your Mac with a colored bar and a legend, where a
click on a category such as photos or app data opens it. After every full scan it keeps the used space, so a line
shows how your storage changes over the weeks, and it lists the folders that grew most since the scan before.

In **Folders** you click your way through all folders just like in Finder, sorted by size. **Large Files** shows you
all files above a size you choose yourself, and **Search** finds folders and files by name. In each of these lists a
right-click moves a file you no longer need to the Trash, after you confirm it. A switch in the toolbar, like the view
buttons in Finder, shows a list or large tiles (⌘1 and ⌘2), and on Folders also **Rings** (⌘3): the subfolders as
rings around the current folder, where the wider a piece, the bigger the folder.

In **Clean Up** you remove files your system barely needs: caches that apps rebuild on their own, old logs, old
temporary files and, if you want, old installers in Downloads and the Trash. Apps that are currently running, and
macOS itself, are left untouched.

**Duplicates** shows large files from 10 MB that exist more than once with the same content, each group as a card
that says how much space the extra copies take. Each copy can go to the Trash right there after you confirm it.

**Unused Apps** reminds you of apps you have not opened for a long time. The date comes from macOS itself, so the app
records nothing, and anything you no longer need goes to the Trash from there.

For advanced users, the app also shows two areas you cannot see in Finder: the **temporary area** of macOS and the
**app copies** that macOS creates when it checks apps. They appear in the sidebar once you switch on “Show advanced
areas” in the settings. External drives and USB sticks appear in the sidebar too, as soon as you connect them.

The **menu bar** shows how much space is available, even with the window closed, and warns you when it runs low. The
**widget** shows the same on your desktop or in Notification Center: click the desktop with the right mouse button,
choose Edit Widgets and look for Storage Manager. With File › Export Report (⇧⌘E) you save the summary, every
category and the largest files as a **text file**, with the size first in each line, so it also pastes into a
spreadsheet.

Every page says in one sentence at the top what it is for, and the info button beside it explains more. The app takes
the light or dark appearance from your Mac, and if you have turned on “Reduce motion” in the Accessibility settings,
it leaves out its animations.

</details>

## <img src="assets/icons/install.svg" height="33" align="absmiddle" alt="">Install it in a minute

You need a Mac with Apple silicon, meaning M1 or newer, running macOS 27 or later. Download
**[Storage-Manager.dmg](https://github.com/Robertwlt03/storage-manager/releases/latest/download/Storage-Manager.dmg)**,
then everything else you do with the mouse.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/install-dark.svg">
    <img src="assets/pictures/install-light.svg" alt="The five steps of the installation, one after another" width="100%">
  </picture>
</p>

1. **Open the DMG file and drag Storage Manager into the “Applications” folder.**
2. **Open the app.** The first time, macOS reports that it could not verify the app, because I do not distribute it
   through Apple’s paid developer program. Just click “Done” here.
3. **Allow the first launch.** In System Settings › Privacy & Security you find a notice about Storage Manager right
   at the bottom, with the button “Open Anyway”. You only do this once, and never again for later updates.
4. **Grant Full Disk Access.** The app asks for it at launch: click “Open System Settings” and turn Storage Manager
   on there. If it is missing from the list, add it with the plus button.
5. **In the app, click “Restart App”.** From now on it measures everything without asking you again.

<sub>Most pictures are redrawn sketches of the English interface; depending on your macOS version, the original looks a
little different.</sub>

<details>
<summary><b>Prefer the terminal?</b></summary>
<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/terminal-install-dark.svg">
  <img src="assets/pictures/terminal-install-light.svg" alt="Installing from the terminal: attach the disk image, copy the app, detach it, allow the first launch and open the app" width="100%">
</picture>

These commands open the DMG from your Downloads folder, copy the app to “Applications” and allow the first launch:

```bash
hdiutil attach ~/Downloads/Storage-Manager.dmg
cp -R "/Volumes/Storage Manager/Storage Manager.app" /Applications/
hdiutil detach "/Volumes/Storage Manager"
xattr -dr com.apple.quarantine "/Applications/Storage Manager.app"
open "/Applications/Storage Manager.app"
```

Not even the terminal can grant Full Disk Access; that only works with the switch. This command opens the right place
in System Settings for it:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
```

</details>

<details>
<summary><b>Why Full Disk Access?</b></summary>
<br>

Without it, macOS asks separately for every protected location, that is for the Desktop, Documents, Downloads, iCloud
Drive, the data of other apps and external drives. Full Disk Access replaces all of these questions with a single
switch. You can also carry on without it and answer the individual questions; then the scan only misses the areas
you decline.

</details>

## <img src="assets/icons/privacy.svg" height="33" align="absmiddle" alt="">Made to be trusted

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/promises-dark.svg">
  <img src="assets/pictures/promises-light.svg" alt="Private, easy on energy, free and open source, 28 languages" width="100%">
</picture>

The app only reads names and sizes, never the contents of your files, and it sends nothing to the internet. Something
is only deleted when you explicitly confirm it in Clean Up or for the app copies; apps and files you no longer need go
to the Trash, also only after you confirm it, and can be restored from there.

Storage Manager measures everything once, in a single pass on the energy-efficient cores of your Mac, and then
remembers the result. Clicking, sorting and searching never start a new scan, and in Low Power Mode the app does not
scan on its own.

## <img src="assets/icons/languages.svg" height="33" align="absmiddle" alt="">Speaks your language

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/languages-dark.svg">
  <img src="assets/pictures/languages-light.svg" alt="28 languages: Chinese (Simplified), Chinese (Traditional), Czech, Danish, Dutch, English, Finnish, French, German, Greek, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Norwegian, Polish, Portuguese (Brazil), Portuguese (Portugal), Romanian, Russian, Spanish, Swedish, Thai, Turkish, Ukrainian and Vietnamese" width="100%">
</picture>

The app follows the language of your Mac. To use it in a different one, pick it in the app's settings; it shows after
a restart.

## <img src="assets/icons/about.svg" height="33" align="absmiddle" alt="">Why this app exists

I always wanted to know exactly how the storage on my Mac is split up. macOS only shows this very roughly, though, and
a large part often just ends up in a block called “System Data” without you ever learning what is inside. A small
script was my first step: with it I found out, for example, that macOS had created over a hundred copies of Google
Chrome that together took up more than a hundred gigabytes. But a script is not something you can simply hand on to
others, so I turned it into a proper Mac app that anyone can use without a terminal. It is written in Swift with
SwiftUI, Apple’s own toolkit, which is why it looks like the apps that come with macOS, and it grew step by step
together with Claude.

## <img src="assets/icons/community.svg" height="33" align="absmiddle" alt="">Join in

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/pictures/terminal-develop-dark.svg">
  <img src="assets/pictures/terminal-develop-light.svg" alt="make run builds and opens the app; make check runs all 27 checks" width="100%">
</picture>

Storage Manager is open source. Anyone can read the code, improve it and bring in their own ideas. You can report
bugs and wishes in the [issues](../../issues), and I am happy to take improvements as pull requests. How to get
started is in the [contributing guide](CONTRIBUTING.md), where to find what in the code is in the
[architecture description](ARCHITECTURE.md), how we write code is in the [code rules](CODE_STYLE.md), and how the
guides draw their pictures is in [pictures for the guides](docs/pictures/README.md). For how we
treat each other, the [code of conduct](CODE_OF_CONDUCT.md) applies. Most translations were made by machine, so I am
especially glad about improvements from native speakers.

<details>
<summary><b>Build it yourself</b></summary>
<br>

You need Xcode 27 from the App Store, but only as a toolbox: building happens in the terminal, and you can use any
editor you like. After installing it, switch the tools over to Xcode once, then build and open the app:

```bash
sudo xcode-select --switch /Applications/Xcode.app
make run
```

`make` shows you all the short commands, and the [contributing guide](CONTRIBUTING.md) explains them. `make release`
builds the DMG to pass on. It signs the app with a free certificate of your own, which you create once with
`make identity`, so Full Disk Access survives every update. With a Developer ID from Apple, the script also notarizes
the DMG, and then steps 2 and 3 of the installation are no longer needed.

The code is split into small parts, and every file has exactly one job:

| Folder | Contents |
| --- | --- |
| `Sources/Features` | One folder for each page of the app, for example Overview, Folders and Clean Up. `Pages.swift` maps each page to its view. |
| `Sources/DesignSystem` | All interface building blocks in the `UI` namespace, with fixed variants, plus spacing, fonts and colors. |
| `Sources/Services` | Scanning, categories, cleaning up, apps, search and the summary for the report. |
| `Sources/State` | The app state that brings the services together. |
| `Sources/Core` | Constants and fixed choices such as pages and settings. |
| `Sources/Localization` and `Resources` | All texts in 28 languages, with German and English as the source. |
| `Sources/Diagnostics` | A self test with real data and a stress test for the running app. |
| `Widget` | The widget for the desktop and Notification Center, a target of its own that the build puts into the app. |
| `Tests` | The tests for the folder tree, categories, search, design, contrast and translations. |
| `scripts` | The code inspection, your own signing certificate, building the DMG and drawing the guides' pictures. |
| `docs` | The installation guide that comes with the DMG, and the descriptions of the guides' pictures. |

</details>

> <img src="assets/icons/windows.svg" height="22" align="absmiddle" alt=""> A version for **Windows** is planned, but not built yet.

<p align="center">
  <img src="assets/banner-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Storage Manager · See at a glance where your storage goes.</b><br>
  <sub><a href="README.md">Overview</a> · <a href="CONTRIBUTING.md">Contributing</a> · <a href="ARCHITECTURE.md">Architecture</a> · <a href="CODE_STYLE.md">Code rules</a> · <a href="CODE_OF_CONDUCT.md">Code of conduct</a> · <a href="CLAUDE.md">Working with Claude</a></sub><br>
  <sub>© 2026 Robertwlt03 · Released under the <a href="LICENSE">MIT license</a> · For macOS 27 on Macs with Apple silicon</sub>
</p>
