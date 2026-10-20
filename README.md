# X-Perl UnitFrames

A complete replacement for Blizzard's unit frames: player, pet, target, focus, the
target-of frames, party, raid, raid pets, boss and arena. Portraits, cast bars, heal
prediction, range fading, HoT and aggro highlights, all configurable from one options
window and from Edit Mode.

X-Perl began as Zek's extended version of Nymbia's Perl UnitFrames. The original project
stopped in 2016 on the Legion client. This version runs on **Retail 12.1** and
**WoW: Forever**. It ships as a single add-on, its frames work with Edit Mode, and
health, auras and casts keep updating in combat under the add-on restrictions
introduced in 12.0.

## Supported clients

| Client | Patch | Interface | TOC |
| --- | --- | --- | --- |
| Retail | 12.1 | 120100 | `XPerl.toc` |
| WoW: Forever | 1.60.1 | 16001 | `XPerl_Camelot.toc` |

One download covers both clients; each client loads its own TOC.

## Features

### Frames

- **Every unit:** player, pet, target, focus, target's target and its target, focus
  target, pet target, party (with party targets and party pets), raid (up to 40),
  raid pets, boss 1-5 and arena 1-5 (Retail only).
- **Pick what you use:** Options → All → "X-Perl Frames" switches each frame type on or
  off. A frame type that is switched off leaves Blizzard's own frame in place.
- **Portraits:** 2D or 3D, with hit indicators over the portrait and a red or green
  flash on the frame border when the unit takes damage or healing.
- **Cast bars on every frame:** cast time and latency, and a shield icon when the
  cast can't be interrupted.
- **Heal prediction:** your incoming heals, other players' incoming heals, absorb
  shields and heal absorbs, in and out of combat. A glow marks absorbs that don't fit on
  the bar.
- **Status icons:** raid target marker, group leader, raid assistant, master looter,
  main tank, main assist, and in combat (or resting, on the player frame). You can put
  each icon on one of nine spots on the frame, or hide it.
- **Threat** on the pet, target, focus and party frames; **level, class icon,
  classification** (elite, rare, boss) and reaction colours.

### Raid

- Sort by group (8 groups) or class (13 columns) or by role, and filter by group
  or class.
- **Linked groups:** dragging group 1 moves the whole raid and keeps the arrangement.
  Moving any other group on its own breaks the link. "Link Raid Groups" restores it.
- "4 Wide" arranges the groups in rows of four.
- Ready check, role icons, and status texts (dead, ghost, offline, AFK, feigning death,
  being resurrected).
- Raid pets, filtered to hunter pets, warlock pets or both.

### Buffs, debuffs and highlights

- Buffs and debuffs are drawn by the game's own aura containers, so they stay
  visible in combat, encounters, keystones and PvP.
- HoT monitor: your own HoTs get a border or a timer bar (the timer runs out of combat),
  and an optional count shows how many HoTs a unit has. Aggro and your target are
  highlighted too.
- Player buff row with weapon enchants first; right-click a buff to cancel it.

### Range finder

Fades units that are out of range, using a class spell (or one you drop on the range
finder's spell button) or a fixed 40 yard check. Classes without a range spell get the
40 yard check. The whole frame, the name or the bars can fade separately. The optional
debuff check also fades units that have nothing to cure, so only units in range that
need curing stay clear.

### Targeting counter

The player frame counts the group members targeting you (healers only by default).
Click the counter to list them in the "X-Perl Targeting" window.

## Installation

1. Download the latest release and extract it into the client's `Interface\AddOns`
   folder:
   - Retail: `World of Warcraft\_retail_\Interface\AddOns\XPerl`
   - WoW: Forever: `World of Warcraft\_forever_\Interface\AddOns\XPerl`
2. The folder must be named `XPerl`. If you install from a clone of this repository,
   rename the folder to `XPerl`.
3. **Upgrading from an older X-Perl:** older versions came as separate add-ons. Delete
   every `XPerl_*` folder (`XPerl_Player`, `XPerl_RaidFrames`, `XPerl_Options`, ...)
   from `Interface\AddOns` before starting the game. Your settings carry over.

## Getting started

- **Options:** left-click the minimap button or type `/xperl`. While the options window
  is open, all frames are unlocked and empty frames show placeholders so you can see and
  drag them. Right-click the minimap button for quick raid toggles. If you use a
  LibDataBroker display, X-Perl also adds a launcher to it.
- **Edit Mode:** open Edit Mode (Esc → Edit Mode). Every X-Perl frame is listed as
  "X-Perl Player", "X-Perl Target", "X-Perl Raid Group 1" and so on. Drag a frame to
  move it, or click it to open its settings dialog.

## Edit Mode layouts

Frame positions and frame settings (scale, portrait, texts, buffs, cast bar, status
icons, ...) are saved per Edit Mode layout. Modern, Classic, your own layouts and
character-specific layouts can each arrange the frames differently. Switching
layouts, including through a specialization change, switches the frames with them.
Copying a layout copies its X-Perl setup, and renaming or deleting a layout carries over.

Colours, bar textures, tooltips, highlights, the range finder and the other global
options are the same in every layout. "Save Settings Per Character" applies to these
global options only.

The first time X-Perl sees a layout, it fills it with your existing settings and frame
positions, so an upgrade keeps your setup.

## Commands

| Command | |
| --- | --- |
| `/xperl` | Open the options window |
| `/xperl lock`, `/xperl unlock` | Lock or unlock the frames (unlocked shows placeholders) |
| `/xperl export` | Show your settings, the active layout's frame settings and positions as a profile string |
| `/xperl import` | Paste a profile string into the active layout |
| `/xperl config list` | List saved per-character settings and the Edit Mode layouts X-Perl has data for |
| `/xperl config delete <realm> <name>` | Delete another character's saved settings |
| `/xperl version` | Show the add-on version, client, build and interface |

Profile strings are plain text. They are an easy way to share a setup or to keep a
backup outside the game.

## Key bindings

Under Options → Key Bindings → X-Perl:

| Binding | |
| --- | --- |
| Toggle Options Window | Open or close the options window |
| Toggle Raid Windows | Show or hide the raid frames |
| Toggle Raid Sort by Class/Group | Switch the raid sort |
| Toggle Raid Pets | Cycle all pets → hunter pets → warlock pets → off |
| Toggle Buffs/Debuffs/none | Switch what the raid frames show |
| Toggle Castable/Curable | Show only buffs you can cast or debuffs you can cure on the raid frames |
| Toggle Range Finder | Switch range fading on or off |

## Click casting

Every X-Perl unit button is registered in the `ClickCastFrames` table, so Clique and
other click-cast add-ons that use it work without extra setup.

Frame names, for add-ons and macros that need them:

| Frame | Name |
| --- | --- |
| Player, pet | `XPerl_Player`, `XPerl_Player_Pet` |
| Target, focus | `XPerl_Target`, `XPerl_Focus` |
| Target-of frames | `XPerl_TargetTarget`, `XPerl_TargetTargetTarget`, `XPerl_FocusTarget`, `XPerl_PetTarget` |
| Party | `XPerl_party1` - `XPerl_party4`, pets `XPerl_partypet1` - `XPerl_partypet4` |
| Raid | group headers `XPerl_Raid_Grp1` - `XPerl_Raid_Grp13`, raid pets `XPerl_Raid_GrpPets` |
| Boss, arena | `XPerl_Boss1` - `XPerl_Boss5`, `XPerl_Arena1` - `XPerl_Arena5` |

Raid buttons are children of their group header, e.g.
`XPerl_Raid_Grp1:GetAttribute("child1")`.

## Not included

Some modules from older X-Perl versions are gone, because the game no longer gives add-ons the
information they need:

- **Raid Helper** (main tank list, aggro warning). Its target counters live on as the
  player frame's targeting counter.
- **Raid Monitor** (cast monitor, mana and health totals).
- **Raid Admin** (roster save/load, item check, roster text).
- **Custom raid highlight** (per-zone debuff icons).
- Features that read the combat log: shield absorb tracking, HoT cast detection,
  "own damage only" hit indicators.
- Shield, Prayer of Mending and incoming-heal highlights: in combat the game hides which
  spell an aura is and how much healing is incoming. Absorbs and incoming heals show on
  the health bar with heal prediction instead.
- Voice-chat speaking indicators.
- Features that stopped working in combat, encounters or instances once the game started
  hiding unit health, auras, ranges and add-on messages:
  - frame borders and backgrounds coloured by debuff type (the debuff icons keep their
    debuff-type borders)
  - fading bars
  - the range finder's health check, its 10 and 30 yard modes and item (bandage) range
    checks
  - the 30 yard indicator on party frames
  - the low-health screen flash (the out-of-control flash stays)
  - threat on boss frames
  - the death knight rune flash
  - Spirit of Redemption shown as dead
  - the target frame's "Assisting" counter and counting enemies that target you
  - the Tooltip Buff Helper and caster names in aura tooltips
  - CT_RaidAssist soulstone, resurrection-accepted and cooldown statuses

## Reporting problems

Install [BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) and
[BugSack](https://www.curseforge.com/wow/addons/bugsack) so errors are captured instead of popping up. When you
report a problem, include:

- the output of `/xperl version`
- the full error text from BugSack
- what you were doing (solo, party, raid, instance, combat) and which frame was affected

## Languages

English, German, Spanish, French, Italian, Korean, Russian, Simplified Chinese and
Traditional Chinese.

## Development

| Path | Contents |
| --- | --- |
| `XPerl.toc`, `XPerl_Camelot.toc` | The two TOCs; identical apart from the interface number |
| `XPerl*.lua`, `XPerl*.xml`, `localization*.lua` | Core: settings, templates, minimap button, highlights, slash commands, profiles |
| `XPerl_EditMode.lua`, `XPerl_EditModeSettings.lua` | Edit Mode frames, per-layout data and the settings dialogs |
| `Units/` | Shared unit frame framework (`UnitFrame.lua`, `CastBar.lua`, `Templates.xml`) and one Lua/XML pair per frame type |
| `XPerl_Options/` | Options window and its localizations |
| `Libs/` | LibStub and LibEditMode, bundled unmodified |
| `Images/` | Textures |

Checks (CI runs all three on every push):

- `python3 .github/scripts/check_tocs.py`: both TOCs agree and every listed file
  exists with the exact case.
- `luac5.1 -p` on every Lua file.
- `luacheck .`: `.luacheckrc` declares the client API as read-only globals, so a call to
  a function the client no longer has shows up as an undefined global. `Libs/` is
  excluded.

## Releases

Pushing a tag to GitHub publishes the release in two places:

- **CurseForge** builds its file through a repository webhook (see CurseForge's
  [automatic packaging](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging)).
- **GitHub**: `.github/workflows/release.yml` builds the same zip and publishes it as a
  GitHub release named after the tag, with the commits since the previous tag as
  release notes.

Both read `.pkgmeta`: the zip holds one `XPerl` folder with both TOCs, so one file
covers Retail and WoW: Forever. Dotfiles and `.github/` are left out.

1. Set the new version in `XPerl.toc` and `XPerl_Camelot.toc` (`## Version:`) and in
   `localization.lua` (`XPerl_VersionNumber`), and commit.
2. Tag that commit with the same version and push the tag:

   ```sh
   git tag -a 4.0.1 -m "4.0.1"
   git push origin 4.0.1
   ```

3. A tag containing `alpha` or `beta` (e.g. `4.1.0-beta1`) becomes an alpha or beta
   file on CurseForge and a pre-release on GitHub; any other tag is a release.

If the GitHub release is missing for a tag (its run failed, or the tag predates the
workflow), run the Release workflow from the Actions tab with that tag; this doesn't
touch CurseForge.

## Credits

- **Nymbia**: Perl UnitFrames, the original.
- **Zek**: X-Perl.
- **Resike, Asixandur, playerlin, tharai** and the translators: maintenance from
  2013 to 2016.
- **p3lim**: LibEditMode.

## License

GNU General Public License v3; see [LICENSE.txt](LICENSE.txt).
