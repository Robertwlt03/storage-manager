<p align="center">
  <img src="assets/banner-contributing.svg" alt="Contributing to Speicher-Explorer. How to build, check and extend the app." width="100%">
</p>

<p align="center"><a href="CONTRIBUTING.md">Deutsch</a> · <a href="CONTRIBUTING.en.md">English</a></p>

Great that you want to help. This guide explains how to build the app, where to find what and what to look out for.
How the code is structured and which rules apply on purpose is described in the
[architecture description](ARCHITECTURE.en.md).

## <img src="assets/icons/requirements.svg" height="33" align="absmiddle" alt="">What you need

You need a Mac with Apple silicon and macOS 27, because the app uses Swift 6.4, Liquid Glass and what is new in
macOS 27. That is exactly how it later runs for everyone who uses it.

To build, you also need Xcode 27 from the App Store. You never have to open Xcode, it only serves as a toolbox: the
Command Line Tools alone are no longer enough, because SwiftUI for macOS 27 uses macros that only Xcode ships with.
After installing it, switch the tools over to Xcode once. For the check chain you also need SwiftLint.

```bash
sudo xcode-select --switch /Applications/Xcode.app
```

```bash
brew install swiftlint
```

## <img src="assets/icons/editor.svg" height="33" align="absmiddle" alt="">Your editor

You can work with any editor you like, because the project is a plain Swift package with a `Package.swift`.
Building, testing and checking always happen on the command line, and there it does not matter what you write the
code with:

- **Xcode** opens `Package.swift` directly, so you do not need a separate Xcode project.
- **VS Code, Cursor and Zed** understand Swift through the official Swift extension or out of the box.
- **Neovim, Helix and other editors** talk to `sourcekit-lsp`. This language server already comes with Xcode.
- **JetBrains IDEs such as PhpStorm** can edit the files, but no longer offer their own Swift support. Building and
  checking happen in the terminal there.

So that the code still looks the same everywhere, the file `.swift-format` sets the layout. Many editors read it on
their own when you save, and otherwise `make format` puts everything into shape.

## <img src="assets/icons/terminal.svg" height="33" align="absmiddle" alt="">Short commands

You do not have to remember long commands. Just like npm scripts, every workflow is a short command in the
`Makefile`, and `make` on its own shows you the list:

| Command | What it does |
| --- | --- |
| `make run` | builds the app, quits it if it is open, and opens the new one |
| `make demo` | builds the app without a certificate and opens it in demo mode with made-up data |
| `make snapshots` | optional: photographs every page in demo mode, light and dark, and compares the pictures |
| `make restart` | quits the app if it is open and opens it again, without building |
| `make build` | builds the app and draws its icon |
| `make check` | runs the whole check chain, exactly as on GitHub |
| `make test` | runs only the tests |
| `make coverage` | shows how much of the code the tests reach, per folder |
| `make format` | puts all Swift files into the shared layout |
| `make selftest` | runs the built app as a self test, measures real folders and compares with `du` |
| `make stress` | opens a second app that clicks through all pages as fast as it can |
| `make identity` | creates your own certificate once, in a keychain of its own |
| `make release` | creates the DMG to pass on, in the `dist` folder |
| `make clean` | deletes everything the build produces |

The commands only call the scripts that are in the project anyway. So you can keep using them directly as well, for
example `./build.sh` or `scripts/check.py tests`.

## <img src="assets/icons/build.svg" height="33" align="absmiddle" alt="">Building and launching the app

A single command builds the app and launches it. `make run` puts it in the `build` folder, quits an app that is
already open and then opens the new one.

```bash
make run
```

Without further settings, the app is only signed ad hoc. macOS then asks for Full Disk Access again after every
build. If that bothers you, create a certificate of your own once. `make identity` creates it in a small keychain
just for this project and writes everything needed into the file `local.mk`, which Git ignores. So that macOS keeps Full Disk Access across all builds, macOS asks once for
your password in a normal dialog, to trust the certificate for signing. During the build, `build.sh` unlocks the
keychain by itself, and your password is never needed again after that. After the next `make run` you grant Full Disk Access one last
time, and from then on it survives every build.

```bash
make identity
```

## <img src="assets/icons/demo.svg" height="33" align="absmiddle" alt="">Demo mode

In demo mode the app shows every page with made-up data: an invented folder tree, a fixed volume, a few apps and
copies. It measures nothing, reads none of your files and cannot delete anything, because all the buttons for
cleaning up and deleting have no effect. That is why you need neither Full Disk Access nor your certificate for it,
and no private names appear on screen. `make demo` builds the app for this into a folder of its own, so your signed
app stays untouched.

```bash
make demo
```

This is how you check the look of the pages you changed before every contribution, in light and in dark
appearance. The screenshots for the README are also taken in demo mode. The made-up data lives in
`Sources/Diagnostics/DemoData.swift`.

If you like, let the Mac do the comparing. `make snapshots RECORD=1` photographs every page once light and once dark
and keeps the pictures as references in the `snapshots` folder, which git ignores, because the pictures depend on
your screen and wallpaper. After a change, `make snapshots` photographs the pages again and names every page on
which more than one per cent of the pixels changed; it shows the changed spots in red in `snapshots/difference`. For
this, macOS asks the first time whether your terminal may record the screen. That is the only reason for this
permission, which is why the comparison is optional and does not run on GitHub.

## <img src="assets/icons/checks.svg" height="33" align="absmiddle" alt="">Checks before every contribution

Before every contribution you run the check chain. It checks the layout, builds the app with warnings as errors, runs
all tests and checks the [code rules](CODE_STYLE.en.md), that is names, numbers, colours, design, texts and dead
code. It must not report a single error or a single warning. On GitHub the same check runs by itself on every pull
request and marks it red as long as something still needs fixing.

```bash
make check
```

The tests in the check chain also verify that every text exists in all 20 languages and has the same number of
placeholders, and that every text colour reaches a contrast of at least 4.5 to 1 in light and dark appearance. If you
change a rule, add the matching test, and `make coverage` shows you what is still untested.

You run two more checks yourself when needed. The self test measures real folders and compares the result with the
`du` command. The stress test operates the running app like a very fast human and tries to trigger errors. Both only
print counts and sizes, never file or folder names.

Both run as the built app and use its Full Disk Access. If it is missing, they stop right away, before macOS asks
separately for every protected folder. So build the app with your own certificate first, so that Full Disk Access
survives across all builds, and never start the self test as a bare binary from `.build/release`, because then macOS
asks hundreds of times.

```bash
make selftest
```

```bash
make stress
```

## <img src="assets/icons/rules.svg" height="33" align="absmiddle" alt="">Rules that always apply

- **Never print names:** Output, logs and tests never show names of files or folders, only counts and sizes. What is
  on the disk is private.
- **Never delete without asking:** The app only removes something after a confirmation, and copies of an app only
  when that app is not running. Tests never delete anything.
- **Texts in all languages:** Every new text gets an English key in `TextKey` and a line in all 20 files under
  `Resources`. German and English are the source. For the other languages we are especially glad about improvements
  from native speakers.
- **Code in English, guides in German and English:** You write names, comments and commit messages in English. Guides
  are written in German, and each has an English twin (`*.en.md`) that changes along with it.
- **Readable code:** Spelled-out names in everyday language, no numbers without names, colours only from `Theme`, and
  small, clearly separated steps. The details are in the [code rules](CODE_STYLE.en.md).

## <img src="assets/icons/newpage.svg" height="33" align="absmiddle" alt="">Adding a new page

1. Add a new case to `Pane` and give it its key, title, info text and symbol in the `details` table.
2. Write the page as its own file in a new folder under `Sources/Features`.
3. Register it in `Pane.page` in the file `Features/Pages.swift`.
4. Add the new texts in all languages.

The sidebar builds itself from `Pane`, so there is nothing else to do there.

## <img src="assets/icons/components.svg" height="33" align="absmiddle" alt="">Using the building blocks

All interface building blocks live in the `UI` namespace. When you type `UI.`, you see all of them. Every building
block has a few fixed variants, so that the same things look the same everywhere:

| Building block | What for | Variants |
| --- | --- | --- |
| `UI.Page` | a scrolling page with a header | with or without options |
| `UI.Card` | a rounded surface | with or without a heading |
| `UI.Rows`, `UI.NavigationRow`, `UI.Fields` | rows with dividers | navigation or label with value |
| `UI.Icon` | every symbol and image | kind and size, from very small to large |
| `UI.Note` | one line of information | hint, in progress, good, warning, error |
| `UI.Placeholder` | stand-in for missing content | empty, loading, not measured, on a page or card |
| `UI.Tile`, `UI.KeyFigure` | tiles | grid tile or key figure |
| `UI.ActionButton` | a button with text | normal, prominent, confirming, quiet, content |

Take spacing from `Space`, icon sizes from `IconSize` and fonts via `textRole` from `TextRole`. We avoid fixed
numbers or individual fonts directly in the code, because then one part of the app soon looks different from the
rest.

## <img src="assets/icons/issues.svg" height="33" align="absmiddle" alt="">Reporting bugs and suggesting ideas

You report bugs and wishes through the issues on GitHub. There is a template for each that asks for the most
important details. Please do not attach screenshots that show private file or folder names.

## <img src="assets/icons/community.svg" height="33" align="absmiddle" alt="">How we treat each other

We treat each other kindly and respectfully. The details are in the [code of conduct](CODE_OF_CONDUCT.en.md).

<p align="center">
  <img src="assets/banner-footer-en.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · See at a glance where your storage goes.</b><br>
  <sub><a href="README.en.md">Overview</a> · <a href="CONTRIBUTING.en.md">Contributing</a> · <a href="ARCHITECTURE.en.md">Architecture</a> · <a href="CODE_STYLE.en.md">Code rules</a> · <a href="CODE_OF_CONDUCT.en.md">Code of conduct</a></sub><br>
  <sub>© 2026 Robertwlt03 · Released under the <a href="LICENSE">MIT licence</a> · For macOS 27 on Macs with Apple silicon</sub>
</p>
