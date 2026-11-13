# Ribs

**A private, offline audio player for macOS. Free.**

Ribs plays the audio you already own — music, voice memos, lectures, recordings — and nothing else. No accounts, no streaming, no tracking, no ads. It has no network access at all: nothing ever leaves your Mac.

<!-- Screenshots: add images to a /screenshots folder and uncomment
![Ribs — dark mode](screenshots/dark.png)
![Ribs — light mode](screenshots/light.png)
-->

## Download

**[Get the latest version →](https://github.com/Michael-968/Ribs/releases/latest)**

Requires **macOS 26** or later.

## Features

- **Your library, your folder** — files are kept in `~/Music/Ribs`; originals are never modified
- **Songs, Albums, Playlists** — sort by any column, or drag songs into your own order
- **Folders** — *Archive* for recordings, with 1×–2× playback speed, and *Tapes*, a private shelf that can be locked with Touch ID
- **Edit Info** — change titles, artists, albums and artwork inside Ribs, for one song or many at once
- **Waveform seek bar**, menu bar mini player, media keys and Control Centre
- **Dark mode** in black and red; **light mode** in black or blue
- Opens audio straight from Finder; optional auto-import from Downloads
- **English and Russian** — switch in Settings → Language

Plays MP3, AAC / M4A, WAV, AIFF, FLAC and ALAC.

## Install

1. Download **Ribs.zip** from [Releases](https://github.com/Michael-968/Ribs/releases) and unzip it.
2. Drag **Ribs** into **Applications** and open it.
3. The first time, macOS will block it, because Ribs isn't signed with a paid Apple developer certificate. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. You only need to do this once.
4. Optional: **Ribs → Settings → Files → Open audio files with Ribs** to make it your default player.

**Check your download.** Each release lists a SHA-256 fingerprint. In Terminal:

```
shasum -a 256 ~/Downloads/Ribs.zip
```

The result should match the one on the release page exactly.

## Privacy

Ribs runs in the macOS App Sandbox with **no network permission**, so it cannot connect to the internet or send anything anywhere. Your library, edits and playlists are stored only on your Mac.

You can confirm this yourself — this lists everything Ribs is allowed to do:

```
codesign -d --entitlements - /Applications/Ribs.app
```

There is no `network` entry.

## Updates

Ribs never updates itself — it has no network access. New versions appear on the [Releases](https://github.com/Michael-968/Ribs/releases) page.

## Feedback

Found a bug or have an idea? Open an [issue](https://github.com/Michael-968/Ribs/issues).

## Credits

- Design and development — Michael Kemenov
- App icon — Michael Kemenov
- Font — [IBM Plex Mono](https://github.com/IBM/plex), SIL Open Font License 1.1

## Licence

Ribs is free, closed-source software. © 2026 Michael Kemenov. All rights reserved.
Free to download and use; not to be sold, modified or redistributed — see [LICENSE](LICENSE).
