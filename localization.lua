-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

XPerl_ProductName		= "|cFFD00000X-Perl|r UnitFrames"
XPerl_ShortProductName	= "|cFFD00000X-Perl|r"
XPerl_Author			= "|cFFFF8080Zek|r"
XPerl_Description		= XPerl_ProductName.." by "..XPerl_Author
XPerl_VersionNumber 	= "4.0.0"
XPerl_Version			= XPerl_Description.." - "..XPerl_VersionNumber
XPerl_LongDescription	= "UnitFrame replacement for new look Player, Pet, Party, Target, Target's Target, Focus, Raid"
XPerl_ModMenuIcon		= "Interface\\Icons\\INV_Misc_Gem_Pearl_02"

XPERL_COMMS_PREFIX		= "X-Perl"
XPERL_MINIMAP_HELP1		= "|c00FFFFFFLeft click|r for Options (and to |c0000FF00unlock frames|r)"
XPERL_MINIMAP_HELP2		= "|c00FFFFFFRight click|r to drag this icon"
XPERL_MINIMAP_HELP3		= "\rReal Raid Members: |c00FFFF80%d|r\rReal Party Members: |c00FFFF80%d|r"
XPERL_MINIMAP_HELP4		= "\rYou are leader of the real party/raid"
XPERL_MINIMAP_HELP5		= "|c00FFFFFFAlt|r for X-Perl memory usage"
XPERL_MINIMAP_HELP6		= "|c00FFFFFF+Shift|r for X-Perl memory usage since startup"

XPERL_MINIMENU_OPTIONS	= "Options"
XPERL_MINIMENU_RAIDBUFF = "Raid Buffs"
XPERL_MINIMENU_RAIDSORT = "Raid Sort"
XPERL_MINIMENU_RAIDSORT_GROUP = "Sort by Group"
XPERL_MINIMENU_RAIDSORT_CLASS = "Sort by Class"

XPERL_TYPE_NOT_SPECIFIED = "Not specified"
XPERL_TYPE_PET		= PET			-- "Pet"
XPERL_TYPE_BOSS 	= "Boss"
XPERL_TYPE_RAREPLUS = "Rare+"
XPERL_TYPE_ELITE	= "Elite"
XPERL_TYPE_RARE 	= "Rare"

-- Zones
--Any zones 4.x and higher can all be localized from EJ, in 5.0, even these above zones are in EJ which means the rest can go bye bye too

-- Status
XPERL_LOC_DEAD		= DEAD			-- "Dead"
XPERL_LOC_GHOST 	= "Ghost"
XPERL_LOC_FEIGNDEATH	= "Feign Death"
XPERL_LOC_OFFLINE	= PLAYER_OFFLINE	-- "Offline"
XPERL_LOC_RESURRECTED	= "Resurrected"
XPERL_LOC_UPDATING	= "Updating"
XPERL_RAID_GROUP	= "Group %d"
XPERL_RAID_GROUPSHORT	= "G%d"
XPERL_RAID_TOOLTIP_OFFLINE	= "Offline for %s"
XPERL_RAID_TOOLTIP_AFK		= "AFK for %s"
XPERL_RAID_TOOLTIP_DND		= "DND for %s"
XPERL_RAID_TOOLTIP_DYING	= "Dying in %s"
XPERL_RAID_RESSING		= " ressing"
XPERL_RAID_AFK			= "AFK"
XPERL_RAID_RESSER_AVAIL		= "Rezzers Available: "

XPERL_LOC_NONEWATCHED	= "none watched"
XPERL_LOC_RUNES		= "Runes"		-- Edit Mode label of the undocked death knight runes

-- Targeting counter (player frame) and its window
XPERL_TARGETCOUNTER_WINDOW		= "X-Perl Targeting"
XPERL_TARGETCOUNTER_TARGETING	= "Targeting Me"
XPERL_TARGETCOUNTER_HEALERS	= "Healers Targeting Me"
XPERL_TARGETCOUNTER_CLICK		= "Click to show or hide this list in the targeting window"

XPERL_LOC_STATUSTIP = "Status Highlights: " 	-- Tooltip explanation of status highlight on unit
XPERL_LOC_STATUSTIPLIST = {
	HOT = "Heal over Time",
	AGGRO = "Aggro",
	MISSING = "Missing your class' buff",
}

XPERL_OK		= "OK"
XPERL_CANCEL		= "Cancel"

XPERL_LOC_LARGENUMDIV	= 1000
XPERL_LOC_LARGENUMTAG	= "K"
XPERL_LOC_HUGENUMDIV	= 1000000
XPERL_LOC_HUGENUMTAG	= "M"

BINDING_HEADER_XPERL = XPerl_ProductName
BINDING_NAME_TOGGLERAID = "Toggle Raid Windows"
BINDING_NAME_TOGGLERAIDSORT = "Toggle Raid Sort by Class/Group"
BINDING_NAME_TOGGLERAIDPETS = "Toggle Raid Pets"
BINDING_NAME_TOGGLEOPTIONS = "Toggle Options Window"
BINDING_NAME_TOGGLEBUFFTYPE = "Toggle Buffs/Debuffs/none"
BINDING_NAME_TOGGLEBUFFCASTABLE = "Toggle Castable/Curable"
BINDING_NAME_TEAMSPEAKMONITOR = "Teamspeak Monitor"
BINDING_NAME_TOGGLERANGEFINDER = "Toggle Range Finder"

XPERL_KEY_NOTICE_RAID_BUFFANY = "All buffs/debuffs shown"
XPERL_KEY_NOTICE_RAID_BUFFCURECAST = "Only castable/curable buffs or debuffs shown"
XPERL_KEY_NOTICE_RAID_BUFFS = "Raid Buffs shown"
XPERL_KEY_NOTICE_RAID_DEBUFFS = "Raid Debuffs shown"
XPERL_KEY_NOTICE_RAID_NOBUFFS = "No raid buffs shown"

XPERL_DRAGHINT1		= "|c00FFFFFFClick|r to scale window"
XPERL_DRAGHINT2		= "|c00FFFFFFShift+Click|r to resize window"

-- Usage
XPerlUsageNameList	= {XPerl = "Core", XPerl_Player = "Player", XPerl_PlayerPet = "Pet", XPerl_Target = "Target", XPerl_TargetTarget = "Target's Target", XPerl_Party = "Party", XPerl_PartyPet = "Party Pets", XPerl_RaidFrames = "Raid Frames", XPerl_RaidPets = "Raid Pets", XPerl_ArcaneBar = "Arcane Bar", XPerl_PlayerBuffs = "Player Buffs"}
XPERL_USAGE_MEMMAX	= "UI Mem Max: %d"
XPERL_USAGE_MODULES = "Modules: "
XPERL_USAGE_NEWVERSION	= "*Newer version"
XPERL_USAGE_AVAILABLE	= "%s |c00FFFFFF%s|r is available for download"

XPERL_CMD_MENU		= "menu"
XPERL_CMD_OPTIONS	= "options"
XPERL_CMD_LOCK		= "lock"
XPERL_CMD_UNLOCK	= "unlock"
XPERL_CMD_CONFIG	= "config"
XPERL_CMD_LIST		= "list"
XPERL_CMD_DELETE	= "delete"
XPERL_CMD_VERSION	= "version"
XPERL_VERSION_REPORT	= "%s on %s %s (build %s, interface %d)"
XPERL_CMD_EXPORT	= "export"
XPERL_CMD_IMPORT	= "import"
XPERL_PROFILE_EXPORT_TITLE	= "X-Perl profile - press Ctrl+C to copy"
XPERL_PROFILE_IMPORT_TITLE	= "Paste an X-Perl profile"
XPERL_PROFILE_IMPORT_BUTTON	= "Import"
XPERL_PROFILE_NOT_A_PROFILE	= "That is not an X-Perl profile string."
XPERL_PROFILE_CORRUPT		= "The profile string is damaged or incomplete."
XPERL_PROFILE_IN_COMBAT	= "Profiles cannot be imported in combat."
XPERL_PROFILE_OTHER_FLAVOR	= "Note: this profile was exported from %s; frame positions may need adjusting."
XPERL_PROFILE_IMPORTED		= "Imported profile from X-Perl %s into the Edit Mode layout \"%s\"."
XPERL_CMD_HELP		= "|c00FFFF80Usage: |c00FFFFFF/xperl menu | lock | unlock | config list | config delete <realm> <name>"
XPERL_CANNOT_DELETE_CURRENT = "Cannot delete you current config"
XPERL_CONFIG_DELETED		= "Deleted config for %s/%s"
XPERL_CANNOT_FIND_DELETE_TARGET = "Cannot find config to delete (%s/%s)"
XPERL_CANNOT_DELETE_BADARGS = "Please give realm name and player name"
XPERL_CONFIG_LIST		= "Config List:"
XPERL_CONFIG_CURRENT		= " (Current)"
XPERL_CONFIG_GLOBAL		= "Global settings"
XPERL_CONFIG_LAYOUTS		= "Edit Mode layouts with X-Perl frame settings and positions:"

-- Edit Mode (frame positions and frame settings follow the active Edit Mode layout)
XPERL_EDITMODE_LABEL			= "X-Perl %s"			-- name of a frame in Edit Mode
XPERL_EDITMODE_SCALE			= "Scale"
XPERL_EDITMODE_GROUP_FRAME		= "Frame"
XPERL_EDITMODE_GROUP_TEXT		= "Text and Icons"
XPERL_EDITMODE_GROUP_BARS		= "Bars"
XPERL_EDITMODE_GROUP_CASTBAR	= "Cast Bar"
XPERL_EDITMODE_GROUP_COMBO		= "Combo Points"
XPERL_EDITMODE_GROUP_BUFFS		= "Buffs"
XPERL_EDITMODE_GROUP_DEBUFFS	= "Debuffs"
XPERL_EDITMODE_GROUP_TOTEMS		= "Totems"
XPERL_EDITMODE_GROUP_WARNING	= "Low Health Warning"
XPERL_EDITMODE_GROUP_TARGETS	= "Party Targets"
XPERL_EDITMODE_GROUP_PARTYPETS	= "Party Pets"
XPERL_EDITMODE_GROUP_SORTING	= "Groups and Sorting"
XPERL_EDITMODE_GROUP_ICONS		= "Status Icons"
XPERL_EDITMODE_HEALERTYPE		= "Healer Text"
XPERL_EDITMODE_THREATMODE		= "Threat Display"
XPERL_EDITMODE_COMBOPOS		= "Position"
XPERL_EDITMODE_LAYOUT_ENTRY		= "%s (Edit Mode)"		-- an Edit Mode layout in the options window's Frame Layout list
XPERL_EDITMODE_LAYOUT_OTHERCHAR	= "%s (%s)"				-- another character's own Edit Mode layout: layout name, character
XPERL_EDITMODE_FRAME_TARGETTARGET		= "Target's Target"		-- frame names in Edit Mode (shown as "X-Perl <name>")
XPERL_EDITMODE_FRAME_TARGETTARGETTARGET	= "Target's Target's Target"
XPERL_EDITMODE_FRAME_FOCUSTARGET		= "Focus Target"
XPERL_EDITMODE_FRAME_PETTARGET			= "Pet Target"
XPERL_EDITMODE_FRAME_BOSS		= "Boss Frames"
XPERL_EDITMODE_FRAME_ARENA		= "Arena Frames"
XPERL_EDITMODE_UNIT_BOSS		= "Boss %d"				-- placeholder names of the boss and arena frames in Edit Mode
XPERL_EDITMODE_UNIT_ARENA		= "Arena %d"
XPERL_EDITMODE_SPACING			= "Spacing"
XPERL_EDITMODE_SPACING_DESC	= "Gap between the frames"
XPERL_EDITMODE_GROWTH			= "Growth"
XPERL_EDITMODE_GROWTH_DESC		= "Direction in which the frames are added below or above the first"
XPERL_EDITMODE_GROWTH_DOWN		= "Downwards"
XPERL_EDITMODE_GROWTH_UP		= "Upwards"
XPERL_EDITMODE_MOBTYPE			= "Creature Type"
XPERL_EDITMODE_MOBTYPE_DESC	= "Show the creature type below the portrait"
XPERL_EDITMODE_SPECICON		= "Specialization Icon"
XPERL_EDITMODE_SPECICON_DESC	= "Show the opponent's specialization icon (its class icon while the specialization isn't known)"
XPERL_EDITMODE_TRINKET			= "PvP Trinket"
XPERL_EDITMODE_TRINKET_DESC	= "Show the opponent's crowd control removal (PvP trinket) and its cooldown"
XPERL_EDITMODE_BUFFSIZE		= "Buff Size"
XPERL_EDITMODE_DEBUFFSIZE		= "Debuff Size"
XPERL_EDITMODE_AURAROWS		= "Aura Rows"
XPERL_EDITMODE_AURAROWS_DESC	= "Maximum number of rows of buffs (and of debuffs) when they wrap"
XPERL_EDITMODE_LINK_GROUPS		= "Link Raid Groups"	-- button in the raid groups' dialogs
XPERL_EDITMODE_GROUPS_LINKED	= "Raid groups linked: moving group 1 moves them all."
XPERL_EDITMODE_GROUPS_UNLINKED	= "Raid groups unlinked: group 1 now moves on its own. \"Link Raid Groups\" in a raid group's Edit Mode settings, or \"Link Groups\" in the options window's raid alignment, links them again."
XPERL_EDITMODE_TARGETCOUNTER_ME			= "Targeting Counter"	-- player frame
XPERL_EDITMODE_TARGETCOUNTER_ME_DESC		= "Show how many group members are targeting you. Click it for the list"
XPERL_EDITMODE_TARGETCOUNTER_HEALERS		= "Count Only Healers"
XPERL_EDITMODE_TARGETCOUNTER_HEALERS_DESC	= "The targeting counter counts only healers: players in the healer role, or of a class that can heal while roles aren't assigned"
XPERL_EDITMODE_ICON_RAIDTARGET		= "Raid Target"		-- status icons: where each shows; icons sharing a spot line up in this order
XPERL_EDITMODE_ICON_RAIDTARGET_DESC	= "Where the unit's raid target marker shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_LEADER			= "Leader"
XPERL_EDITMODE_ICON_LEADER_DESC		= "Where the group leader's crown shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_ASSISTANT		= "Raid Assistant"
XPERL_EDITMODE_ICON_ASSISTANT_DESC	= "Where the raid assistant icon shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_MASTERLOOTER	= "Master Looter"
XPERL_EDITMODE_ICON_MASTERLOOTER_DESC	= "Where the master looter's icon shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_MAINASSIST		= "Main Assist"
XPERL_EDITMODE_ICON_MAINASSIST_DESC	= "Where the icon of the raid's main assist shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_MAINTANK		= "Main Tank"
XPERL_EDITMODE_ICON_MAINTANK_DESC	= "Where the icon of the raid's main tank shows. Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_ICON_COMBAT			= "In Combat"
XPERL_EDITMODE_ICON_COMBAT_DESC		= "Where the crossed swords show while the unit is in combat (the player's frame shows resting there out of combat). Icons that share a spot line up in the order of this list"
XPERL_EDITMODE_SPOT_NONE			= "Hidden"
XPERL_EDITMODE_SPOT_TOPLEFT		= "Top Left"
XPERL_EDITMODE_SPOT_TOP			= "Top"
XPERL_EDITMODE_SPOT_TOPRIGHT		= "Top Right"
XPERL_EDITMODE_SPOT_LEFT			= "Left"
XPERL_EDITMODE_SPOT_CENTER			= "Center"
XPERL_EDITMODE_SPOT_RIGHT			= "Right"
XPERL_EDITMODE_SPOT_BOTTOMLEFT		= "Bottom Left"
XPERL_EDITMODE_SPOT_BOTTOM			= "Bottom"
XPERL_EDITMODE_SPOT_BOTTOMRIGHT	= "Bottom Right"


-- Status highlight spells
XPERL_HIGHLIGHT_SPELLS = {
	hotSpells  = XPerlAPI.SpellNameMap({
		[774] = 12,			-- Rejuvenation (old id 26982)
		[8936] = 6,			-- Regrowth (old id 26980)
		[139] = 12,			-- Renew (old id 25222)
	    [48438] = 7,			-- Wild Growth 
		[33763] = 8,			-- Lifebloom
		[28880] = 15,			-- Gift of the Naaru (Racial)
		[61295] = 15,			-- Riptide
		[115151] = 18,		-- Renewing Mist
		[119611] = 18,		-- Renewing Mist - furtherst instead of nearest
		[115175] = 8,			-- Soothing Mist
		[124682] = 6,			-- Enveloping Mist
		[114163] = 30,		-- Eternal Flame
	}),
}


-- Default spells for range checking in the healer visual out-of-range cues.
XPerl_DefaultRangeSpells = {
	DRUID	= {spell = C_Spell.GetSpellName(5185)},				-- Healing Touch
	PALADIN = {spell = C_Spell.GetSpellName(635)},				-- Holy Light
	PRIEST	= {spell = C_Spell.GetSpellName(2061)},				-- Flash Heal
	SHAMAN	= {spell = C_Spell.GetSpellName(331)},				-- Healing Wave
	MAGE	= {spell = C_Spell.GetSpellName(475)},				-- Remove Lesser Curse
	WARLOCK	= {spell = C_Spell.GetSpellName(5697)},				-- Underwater Breathing
}

-- Don't highlight these magical debuffs
XPerl_ArcaneExclusions = XPerlAPI.SpellNameMap({
	[63559] = true,						-- Bind Life
	[30451] = true,						-- Arcane Blast (again) (old 42897)
	[30108] = true,						-- Unstable Affliction (old 30405)
	[15822] = true,						-- Dreamless Sleep
	[24360] = true,						-- Greater Dreamless Sleep
	[28504] = true,						-- Major Dreamless Sleep
	[31257] = true,						-- Chilled
	[710] = true,							-- Banish
	[44836] = true,						-- Also Banish !?
	[24306] = true,						-- Delusions of Jin'do
	[46543] = {ROGUE = true, WARRIOR = true},	-- Ignite Mana
	[16567] = {ROGUE = true, WARRIOR = true},	-- Tainted Mind
	[39052] = {ROGUE = true},				-- Sonic Burst
	[41190] = {ROGUE = true, WARRIOR = true}, -- Mind-numbing Poison
	[25195] = {ROGUE = true},				-- Curse of Tongues
	[30129] = true,						-- Charred Earth - Nightbane debuff, can't be cleansed, but shows as magic
	[31651] = {MAGE = true, WARLOCK = true, PRIEST = true},	-- Banshee Curse, Melee hit rating debuff
	[38913] = {ROGUE = true},				-- Silence
	[31555] = {ROGUE = true, WARRIOR = true}, -- Decayed Intellect
})