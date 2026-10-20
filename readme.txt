A much enchanced version of Nymbia's Perl UnitFrames, and a complete replacement for Blizzard's default unit frames, including raid frames, with many additions and improvements over the original Nymbia code.

Range Finder (combined with an optional debuff check) for all frames based on a spell range test or a fixed 40 yard check.

HoT Monitor will highlight units clearly that have your own active Heal over Time spells. Regardless of how many other heal over time buffs are on the raid members, you can keep track of your own ones and when they expire.

Raid Frames, buff icons and some other portions or X-Perl are Created on demand. Saving a lot of time and memory at system startup. Defering the creation of many parts of X-Perl to when they are actually required. And of course, most often outside of raids they are never required and are never created.

Raid Target icon support for Target, Target's Target.

Raid tooltip will show combat rezzers available (druids with Rebirth ready (or very soon available) and any normal rezzers out of combat) if you bring up tooltip of a dead person.

'In-combat' indicators for Pet, Target, Target's Target, Party, Party pets, Raid.

3D Portraits for player, pet, target, focus, party. Optional. Of course this may degrade your framerate somewhat because you are displaying more 3D character models that without this option. But some like it pretty, and it does look cool.

Red and Green combat flashes for frames when player, pet, target, party, partypets, raid take damage/heals. Useful indication of things happening.

Added time left on party member/target buffs/debuffs when in a raid, these depend somewhat on CTRA sending appropriate information over the addon channel, although some of it can be determined at run time by X-Perl, when a player gets a buff for example, we know how long it should last, and therefor when it should expire.

Totally new options window including all X-Perl options and access via minimap icon.

Configurable colours for borders and backgrounds. Including class coloured names, and configurable reaction colours.

Much care has been taken with code size, memory load, memory usage per cycle and so on. LuaProfiler/OnEvent mods used extensively and regularly to ensure that X-Perl does not do more work than is absolutely necessary.

With that in mind, the event system was totally re-written, and is as kind to system performance as possible. The majority of events are disabled while zoning to alleviate any event backlog issues. And where most addons use 1 event handler per unit frame, which although standard, the alternative has improved X-Perl's performance. By using single main event handlers, we can route the events to appropriate units. So, for example, when a single UNIT_HEALTH update is fired, then just a single raid frame or party frame etc. gets the event, rather than 40 raid frame's handlers, 4 party and so on. Nymbia's Perl used to do a lot of crazy full frame udpates all over the place, eating away at CPU cycles. This was all fixed to only update what was necessary based on events.

XPerl_GrimReaper sub-addon
--------------------------
The Grim Reaper remembers the most recent combat events for each unit in the party or raid, so that you may mouse over someone and immediately see the kind of damage/healing they took prior to death.

/grim for options

Right click Reaper for menu (when un-docked)
Alt-Mousewheel to scale the reaper window (when un-docked)

Supported Addons
----------------
CT_RaidAssist. Shows tooltip info and player status, improves raid frames, shows player status, resurrection monitor, buff timers aware.
MobInfo-2 / MobHealth3 - Shows target health from MobHealth database.
DruidBar - Shows druid mana bar from SimpleDruidBar, DruidBar or SmartyCat when shapeshifted.
Clique compatible. And any other click cast addon that uses the same communication method. (see below)

Notes for other mod authors
---------------------------
The ClickCastFrames table (as used by Clique) is maintained by all X-Perl's unit frames.

Defined as:

	if (not ClickCastFrames) then
		ClickCastFrames = {}
	end
        ClickCastFrames[SomeSecureUnitFrame] = true

With this you can change the attributes for various click methods.

Frame names:
        XPerl_Player
        XPerl_Player_Pet
        XPerl_Target
        XPerl_TargetTarget
        XPerl_TargetTargetTarget
        XPerl_Focus
        XPerl_FocusTarget
        XPerl_party1 (&2, 3, 4)
        XPerl_partypet1 (&2, 3, 4)

        Raid frames are defined by groups (class columns when sorting by class)
        XPerl_Raid_Grp[1-13], and the raid pets by XPerl_Raid_GrpPets
        You can query each raid group by doing
                XPerl_Raid_Grp1:GetAttribute("child1") for example

Alternatively, ignore the frame names and dynamically use them from the ClickCastFrames table.

TODO
----
Big Party option for 10 man raids to show 9 party member frames rather than needing raid frames.
Player Buffs.
Class Coloured Health Bars.
Improved options with more independance with some global options that could be set per frame.
Setup Wizard.

Known Issues
------------
Large non-standard fonts can exclude all text in frames. Please let me know which ones, where, when, what addon, settings etc.

While every care is taken to ensure there are few or no bugs, it is always possible that some slip through. And often other mods can interfere with normal behaviour. Popup error messages are annoying, so it is highly recommended that you install an improved error catcher. BugSack(Ace2) is particularly good, or ImprovedErrorFrame would also suffice. These divert the popups away to a little minimap button that you can ignore mostly.

--
X-Perl UnitFrames by Zek <Blood Cult> - Bloodhoof-EU
