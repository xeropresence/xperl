-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Edit Mode settings dialogs: one per registered frame, editing that frame's settings section of the layout
-- LibEditMode passes (always the active one). They are a second view of the same settings the options
-- window edits, with its labels (XPERL_CONF_*). Built at login, when every localization file is loaded.

XPerl_SetModuleRevision("$Revision$")

local _, ns = ...
local LEM = LibStub("LibEditMode")
local SettingType = LEM.SettingType

local defaults			-- fresh default settings: "Reset to default" values
local expanded = {}		-- [expander id] = open; only for this session
local scaleSettings = {}	-- scale sliders, whose maximum follows XPerlDB.maximumScale
local built = {}		-- [frameKey] = settings list, or false when the key has no dialog

local function Text(key)
	return _G[key] or key
end

local function SplitPath(path)
	local parts = {}
	for part in gmatch(path, "[^.]+") do
		parts[#parts + 1] = tonumber(part) or part
	end
	return parts
end

local function Read(t, parts)
	for i = 1, #parts do
		if (type(t) ~= "table") then
			return nil
		end
		t = t[parts[i]]
	end
	return t
end

local function Write(t, parts, value)
	for i = 1, #parts - 1 do
		local nextTable = t[parts[i]]
		if (type(nextTable) ~= "table") then
			nextTable = {}
			t[parts[i]] = nextTable
		end
		t = nextTable
	end
	t[parts[#parts]] = value
end

------------------------------------------------------------------------------
-- Builder: each call appends one LibEditMode setting
------------------------------------------------------------------------------

local Builder = {}
Builder.__index = Builder

local function NewBuilder(frameKey)
	return setmetatable({frameKey = frameKey, section = frameKey, list = {}}, Builder)
end

-- Settings after this belong to another section (party pets inside the party dialog)
function Builder:Section(section)
	self.section = section
end

-- An expander; the settings after it are hidden while it is closed
function Builder:Group(label, open)
	local id = self.frameKey.."/"..label
	if (open) then
		expanded[id] = true
	end
	self.hidden = function()
		return not expanded[id]
	end
	tinsert(self.list, {
		kind = SettingType.Expander,
		name = Text(label),
		default = open or false,
		get = function()
			return expanded[id]
		end,
		set = function(_, value)
			expanded[id] = value
		end,
	})
end

-- Adds a value setting. convert(stored) -> widget value, store(widget value) -> stored value.
-- fallback: the stored default for "Reset to default" where the default settings have none
function Builder:Add(setting, path, convert, store, fallback)
	local section = self.section
	local parts = SplitPath(path)

	setting.hidden = self.hidden
	local default = Read(defaults[section], parts)
	if (default == nil) then
		default = fallback
	end
	setting.default = convert(default)
	setting.get = function(layoutName)
		local frames = ns.EditMode.GetFrames(layoutName)
		return convert(Read(frames and frames[section], parts))
	end
	setting.set = function(layoutName, value)
		local frames = ns.EditMode.GetFrames(layoutName)
		if (not frames) then
			return
		end
		local t = frames[section] or ns.EditMode.CreateSection(layoutName, section)
		Write(t, parts, store(value))
		ns.EditMode.SettingChanged(layoutName)
	end
	tinsert(self.list, setting)
	return setting
end

local function Describe(label)
	return _G[label.."_DESC"]
end

local function FlagGet(v)		return v ~= nil and v ~= false end	-- any value but nil/false is on
local function FlagSet(v)		return v and 1 or nil end
local function StrictGet(v)		return v == 1 or v == true end		-- castable/curable: 0 means off
local function BoolSet(v)		return v and true or false end
local function Same(v)			return v end

-- mode: nil (1/nil flag), "strict" (only 1/true is on), "bool" (stored as true/false)
-- generic: the label is shared with other frames, so its description (written for one frame) is left out
-- fallback: default when the default settings have none
function Builder:Check(path, label, mode, generic, fallback)
	local get, set = FlagGet, FlagSet
	if (mode == "strict") then
		get = StrictGet
	elseif (mode == "bool") then
		set = BoolSet
	end
	self:Add({kind = SettingType.Checkbox, name = Text(label), desc = not generic and Describe(label) or nil}, path, get, set, fallback)
end

-- fallback: default when the default settings have none (else 0, kept within the range)
function Builder:Slider(path, label, minValue, maxValue, step, generic, fallback)
	local function get(v)
		v = tonumber(v)
		return v and min(max(v, minValue), maxValue) or minValue
	end
	if (fallback == nil) then
		fallback = min(max(0, minValue), maxValue)
	end
	self:Add({kind = SettingType.Slider, name = Text(label), desc = not generic and Describe(label) or nil,
		minValue = minValue, maxValue = maxValue, valueStep = step or 1}, path, get, Same, fallback)
end

-- Scales are stored as factors and shown in percent, as in the options window
function Builder:Scale(label, minPercent, generic)
	minPercent = minPercent or 50
	local function get(v)
		v = tonumber(v)
		return v and floor(v * 100 + 0.5) or 100
	end
	local function set(v)
		return v / 100
	end
	local setting = self:Add({kind = SettingType.Slider, name = Text(label), desc = not generic and Describe(label) or nil,
		minValue = minPercent, maxValue = 150, valueStep = 1}, "scale", get, set)
	tinsert(scaleSettings, setting)
end

-- values: {{label, value}, ...}
function Builder:Dropdown(path, label, values)
	local options = {}
	for i, entry in ipairs(values) do
		options[i] = {text = Text(entry[1]), value = entry[2]}
	end
	local function get(v)
		if (v == nil) then
			return values[1][2]
		end
		return v
	end
	self:Add({kind = SettingType.Dropdown, name = Text(label), desc = Describe(label), values = options}, path, get, Same)
end

function Builder:Healer()
	self:Check("healerMode.enable", "XPERL_CONF_HEALER_MODE", "bool")
	self:Dropdown("healerMode.type", "XPERL_EDITMODE_HEALERTYPE", {
		{"XPERL_CONF_HEALERMODE_DEFICIT", 0},
		{"XPERL_CONF_HEALERMODE_DEFICITMAX", 1},
		{"XPERL_CONF_HEALERMODE_CURMAXDEFICIT", 2},
	})
end

function Builder:Threat(prefix)
	self:Check("threat", prefix.."THREAT")
	self:Dropdown("threatMode", "XPERL_EDITMODE_THREATMODE", {
		{prefix.."THREAT_PORTRAIT", "portraitFrame"},
		{prefix.."THREAT_NAME", "nameFrame"},
	})
end

local function AnchorValues()
	local values = {}
	for i, anchor in ipairs(XPerl_AnchorList) do
		values[i] = {anchor, anchor}
	end
	return values
end

-- Status icons (Units/UnitFrame.lua): a spot dropdown per icon, in the order icons sharing a spot line up.
-- path: the settings table of the spots ("icons", "target.icons" for the party targets)
function Builder:StatusIcons(path)
	local values = {{"XPERL_EDITMODE_SPOT_NONE", "NONE"}}
	for _, spot in ipairs(XPerl_StatusIconSpots) do
		values[#values + 1] = {"XPERL_EDITMODE_SPOT_"..spot, spot}
	end
	for _, key in ipairs(XPerl_StatusIcons) do
		self:Dropdown(path.."."..key, "XPERL_EDITMODE_ICON_"..strupper(key), values)
	end
end

------------------------------------------------------------------------------
-- Dialog contents per frame key
------------------------------------------------------------------------------

local specs = {}

function specs.player(s)
	local P = "XPERL_CONF_PLAYER_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale(P.."SCALE")
	s:Slider("size.width", P.."WIDTHBONUS", 0, 100)
	s:Check("portrait", P.."PORTRAIT")
	s:Check("portrait3D", P.."PORTRAIT3D")
	s:Check("extendPortrait", P.."EXTENDPORTRAIT")
	s:Check("hitIndicator", "XPERL_CONF_HIT_INDICATOR")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("level", P.."LEVEL")
	s:Check("classIcon", P.."ICON")
	s:Check("pvpIcon", P.."PVPICON")
	s:Check("values", P.."VALUES")
	s:Check("percent", P.."PERCENT")
	s:Check("partyNumber", "XPERL_CONF_RAID_PARTY_NUM")
	s:Check("withName", "XPERL_CONF_RAID_PARTYWITHNAME")
	s:Healer()
	s:Check("targetCounter", "XPERL_EDITMODE_TARGETCOUNTER_ME", "bool")
	s:Check("targetCounterHealers", "XPERL_EDITMODE_TARGETCOUNTER_HEALERS", "bool")

	s:Group("XPERL_EDITMODE_GROUP_BARS")
	s:Check("xpBar", P.."XP")
	s:Check("xpDeficit", P.."XPDEFICIT")
	s:Check("repBar", P.."REP")
	s:Check("noDruidBar", P.."DRUIDBAR")
	s:Check("showRunes", P.."SHOW_RUNES")
	s:Check("dockRunes", P.."DOCKRUNES")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", "XPERL_CONF_ARCANE_BAR")
	s:Check("castBar.precast", "XPERL_CONF_ARCANE_PRECAST")
	s:Check("castBar.castTime", "XPERL_CONF_CAST_TIME")
	s:Check("castBar.inside", "XPERL_CONF_CAST_TIME_INSIDE")
	s:Check("castBar.original", "XPERL_CONF_ORIGINAL_CASTBAR")

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", P.."BUFFS")
	s:Check("buffs.above", P.."BUFFSABOVE")
	s:Check("buffs.wrap", P.."WRAPBUFFS")
	s:Check("buffs.hideBlizzard", P.."BUFFSHIDEBLIZZ")
	s:Check("buffs.cooldown", P.."BUFFSCOOLDOWNS")
	s:Slider("buffs.size", P.."BUFFSIZE", 7, 38)
	s:Slider("buffs.rows", P.."BUFF_ROWS", 1, 10)
	s:Slider("buffs.count", P.."MAXBUFFS", 4, 40)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", P.."DEBUFFS")
	s:Slider("debuffs.size", P.."DEBUFFSIZE", 7, 45)

	-- Blizzard's totem frame is taken over for these classes only (Units/Player.lua); the player code creates
	-- the same settings at runtime, so they are the "Reset to default" values
	local class = select(2, UnitClass("player"))
	if (class == "SHAMAN" or class == "DRUID" or class == "MAGE") then
		s:Group("XPERL_EDITMODE_GROUP_TOTEMS")
		s:Check("totems.enable", P.."TOTEMS_ENABLE", "bool", nil, true)
		s:Slider("totems.offsetX", P.."TOTEM_OFFSETX", -1100, 1100, nil, nil, 0)
		s:Slider("totems.offsetY", P.."TOTEM_OFFSETY", -800, 800, nil, nil, 0)
	end

	s:Group("XPERL_EDITMODE_GROUP_WARNING")
	s:Check("fullScreen.enable", "XPERL_CONF_PARTY_FULLSCREEN")
end

function specs.pet(s)
	local P = "XPERL_CONF_PLAYER_PET_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale(P.."SCALE")
	s:Slider("size.width", P.."WIDTHBONUS", 0, 100)
	s:Check("portrait", P.."PORTRAIT")
	s:Check("portrait3D", P.."PORTRAIT3D")
	s:Check("extendPortrait", P.."EXTENDPORTRAIT")
	s:Check("hitIndicator", P.."HIT_INDICATOR")
	s:Threat(P)
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("name", P.."NAME")
	s:Check("level", P.."LEVEL")
	s:Check("values", P.."VALUES")
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", P.."CASTBAR")

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", P.."BUFFS")
	s:Check("buffs.castable", P.."CASTABLE", "strict")
	s:Check("buffs.above", P.."ABOVE")
	s:Check("buffs.big", P.."BIGBUFFS")
	s:Check("buffs.wrap", P.."WRAPBUFFS")
	s:Slider("buffs.size", P.."BUFF_SIZE", 7, 38)
	s:Slider("buffs.rows", P.."BUFF_ROWS", 1, 10)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", P.."DEBUFFS")
	s:Check("debuffs.curable", P.."CURABLE", "strict")
	s:Check("debuffs.big", P.."BIGDEBUFFS")
	s:Slider("debuffs.size", P.."DEBUFF_SIZE", 7, 38)
end

local function TargetLike(s, P, isTarget)
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale(P.."SCALE")
	s:Slider("size.width", P.."WIDTHBONUS", 0, 100)
	s:Check("portrait", P.."PORTRAIT")
	s:Check("portrait3D", P.."PORTRAIT3D")
	s:Check("hitIndicator", P.."HIT_INDICATOR")
	s:Threat(P)
	s:Check("reactionHighlight", P.."REACTION")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")
	if (isTarget) then
		s:Check("range30yard", P.."30YD")
		s:Check("defer", P.."DEFER")
		s:Check("sound", P.."SOUNDS")
	end

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("level", P.."LEVEL")
	s:Check("classIcon", P.."ICON")
	s:Check("classText", P.."CLASSTEXT")
	s:Check("mobType", P.."MOBTYPE")
	s:Check("eliteGfx", P.."ELITEGFX")
	s:Check("pvpIcon", P.."PVPICON")
	s:Check("mana", P.."MANA")
	s:Check("values", P.."VALUES")
	s:Check("percent", P.."PERCENT")
	if (isTarget) then
		s:Check("showTalents", P.."TALENTS")
	end
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", P.."ARCANE_BAR")

	if (isTarget) then
		s:Group("XPERL_EDITMODE_GROUP_COMBO")
		s:Check("combo.enable", P.."CP")
		s:Check("combo.blizzard", P.."CPBLIZZ")
		s:Dropdown("combo.pos", "XPERL_EDITMODE_COMBOPOS", {
			{P.."CPBLIZZ_POSTOP", "top"},
			{P.."CPBLIZZ_POSBOTTOM", "bottom"},
			{P.."CPBLIZZ_POSLEFT", "left"},
			{P.."CPBLIZZ_POSRIGHT", "right"},
		})
	end

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", P.."BUFFS_ENABLE")
	s:Check("buffs.castable", P.."CASTABLE", "strict")
	s:Check("buffs.onlyMine", P.."ONLYMYBUFFS")
	s:Check("buffs.big", P.."BIGBUFFS")
	if (isTarget) then
		s:Check("buffs.bigStealable", P.."BIGSTEALABLE")
	end
	s:Check("buffs.wrap", P.."WRAPBUFFS")
	s:Check("buffs.above", P.."BUFFSABOVE")
	s:Slider("buffs.size", P.."BUFF_SIZE", 7, 38)
	s:Slider("buffs.rows", P.."BUFF_ROWS", 1, 10)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", P.."DEBUFFS_ENABLE")
	s:Check("debuffs.curable", P.."CURABLE", "strict")
	s:Check("debuffs.onlyMine", P.."ONLYMYDEBUFFS")
	s:Check("debuffs.big", P.."BIGDEBUFFS")
	s:Slider("debuffs.size", P.."DEBUFF_SIZE", 7, 45)
end

function specs.target(s)
	TargetLike(s, "XPERL_CONF_TARGET_", true)
end

function specs.focus(s)
	TargetLike(s, "XPERL_CONF_FOCUS_")
end

-- Target's target, its target, focus target, pet target. P: the section's own labels; buffsLabel and
-- debuffsLabel: their enable labels. Labels the options window shares with the target are the target's.
local function TargetOfLike(s, P, buffsLabel, debuffsLabel, minScale)
	local T = "XPERL_CONF_TARGET_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale(P.."SCALE", minScale)
	s:Slider("size.width", P.."WIDTHBONUS", 0, 100)
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("level", P.."LEVEL")
	s:Check("pvpIcon", T.."PVPICON")
	s:Check("mana", P.."MANA")
	s:Check("values", P.."VALUES")
	s:Check("percent", P.."PERCENT")
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", buffsLabel)
	s:Check("buffs.castable", T.."CASTABLE", "strict")
	s:Check("buffs.onlyMine", T.."ONLYMYBUFFS")
	s:Check("buffs.big", P.."BIGBUFFS")
	s:Check("buffs.wrap", T.."WRAPBUFFS")
	s:Check("buffs.above", P.."BUFFSABOVE")
	s:Slider("buffs.size", T.."BUFF_SIZE", 7, 38)
	s:Slider("buffs.rows", T.."BUFF_ROWS", 1, 10)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", debuffsLabel)
	s:Check("debuffs.curable", T.."CURABLE", "strict")
	s:Check("debuffs.onlyMine", T.."ONLYMYDEBUFFS")
	s:Check("debuffs.big", P.."BIGDEBUFFS")
	s:Slider("debuffs.size", T.."DEBUFF_SIZE", 7, 45)
end

function specs.targettarget(s)
	TargetOfLike(s, "XPERL_CONF_TARGETTARGET_", "XPERL_CONF_TARGETTARGET_BUFFS", "XPERL_CONF_TARGETTARGET_DEBUFFS")
end

function specs.targettargettarget(s)
	TargetOfLike(s, "XPERL_CONF_TARGETTARGET_", "XPERL_CONF_TARGETTARGETTARGET_BUFFS", "XPERL_CONF_TARGET_DEBUFFS_ENABLE")
end

function specs.focustarget(s)
	TargetOfLike(s, "XPERL_CONF_FOCUSTARGET_", "XPERL_CONF_FOCUSTARGET_BUFFS", "XPERL_CONF_TARGET_DEBUFFS_ENABLE", 40)
end

function specs.pettarget(s)
	TargetOfLike(s, "XPERL_CONF_PETTARGET_", "XPERL_CONF_PETTARGET_BUFFS", "XPERL_CONF_TARGET_DEBUFFS_ENABLE", 40)
end

function specs.party(s)
	local P = "XPERL_CONF_PARTY_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale(P.."SCALE")
	s:Slider("size.width", P.."WIDTHBONUS", 0, 100)
	s:Dropdown("anchor", "XPERL_CONF_ANCHORMENU", AnchorValues())
	s:Slider("spacing", "XPERL_CONF_ALIGN_SPACING", -20, 100)
	s:Check("flip", P.."FLIP")
	s:Check("portrait", P.."PORTRAIT")
	s:Check("portrait3D", P.."PORTRAIT3D")
	s:Check("hitIndicator", P.."HIT_INDICATOR")
	s:Threat(P)
	s:Check("inRaid", P.."INRAID")
	s:Check("smallRaid", P.."SMALLRAID")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("name", P.."NAMES")
	s:Check("level", P.."LEVEL")
	s:Check("classIcon", P.."ICON")
	s:Check("pvpIcon", P.."PVPICON")
	s:Check("values", P.."VALUES")
	s:Check("percent", P.."PERC")
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", P.."ARCANE_BAR")

	s:Group("XPERL_EDITMODE_GROUP_TARGETS")
	s:Check("target.enable", P.."TARGET")
	s:Check("target.large", P.."TARGETLARGE")
	s:Slider("target.size", P.."TARGETSIZE", 66, 200)
	s:StatusIcons("target.icons")

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", P.."BUFFS")
	s:Check("buffs.castable", P.."CASTABLE", "strict")
	s:Check("buffs.onlyMine", P.."ONLYMYBUFFS")
	s:Check("buffs.big", P.."BIGBUFFS")
	s:Check("buffs.wrap", P.."WRAPBUFFS")
	s:Slider("buffs.size", P.."BUFF_SIZE", 7, 38)
	s:Slider("buffs.rows", P.."BUFF_ROWS", 1, 10)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", P.."DEBUFFS")
	s:Check("debuffs.curable", P.."CURABLE", "strict")
	s:Check("debuffs.below", P.."DEBUFFSBELOW")
	s:Check("debuffs.halfSize", P.."DEBUFFSHALFSIZE")
	s:Slider("debuffs.size", P.."DEBUFF_SIZE", 7, 45)

	s:Group("XPERL_EDITMODE_GROUP_PARTYPETS")
	s:Section("partypet")
	s:Scale("XPERL_CONF_PARTYPET_SCALE")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")
	s:Check("name", P.."PETNAME")
	s:Check("level", P.."PETLEVEL")
	s:Check("mana", P.."PETMANA")
	s:Check("buffs.enable", P.."PETBUFFS")
	s:Check("buffs.castable", P.."CASTABLE", "strict")
	s:Slider("buffs.size", P.."PETBUFF_SIZE", 5, 20)
	s:Check("debuffs.enable", P.."DEBUFFS")
	s:Check("debuffs.curable", P.."CURABLE", "strict")
	s:Slider("debuffs.size", P.."PETDEBUFF_SIZE", 5, 20)
	s:StatusIcons("icons")
end

function specs.raid(s)
	local P = "XPERL_CONF_RAID_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Check("notInBG", P.."NOTINBG")
	s:Scale(P.."SCALE")
	s:Dropdown("anchor", "XPERL_CONF_ANCHORMENU", AnchorValues())
	s:Slider("spacing", P.."SPACING", -5, 20)
	s:Check("titles", P.."TITLES")
	s:Check("role_icons", P.."ROLE_ICONS")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("percent", P.."HEALTHTEXT")
	s:Check("values", P.."VALUES")
	s:Check("precisionPercent", P.."PRECISIONPERCENTS")
	s:Check("mana", P.."MANA")
	s:Check("manaPercent", P.."MANAPERCENT")
	s:Check("precisionManaPercent", P.."MANAPRECISIONPERCENT")
	s:Check("healerMode.enable", "XPERL_CONF_HEALER_MODE")	-- raid frames show the deficit; 1/nil or boolean

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", P.."BUFFS")
	s:Check("buffs.castable", P.."CASTABLE", "strict")
	s:Check("buffs.right", P.."BUFFSRIGHT")
	s:Check("buffs.inside", P.."BUFFSINSIDE")
	s:Check("buffs.untilDebuffed", "XPERL_CONF_BUFFSUNTILDEBUFFED")
	s:Check("debuffs.enable", P.."DEBUFFS")

	s:Group("XPERL_EDITMODE_GROUP_SORTING")
	s:Check("sortByClass", P.."SORTBYCLASS")
	s:Check("sortByRole", P.."SORTBYROLE")
	s:Check("sortAlpha", P.."ALPHABETICAL")
	for i = 1, 8 do
		s:Check("group."..i, format("%s %d", GROUP, i))
	end
end

function specs.raidpet(s)
	local P = "XPERL_CONF_RAID_PETS"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Check("alignToRaid", P.."_ALIGN")
	s:Check("hunter", P.."_HUNTERS")
	s:Check("warlock", P.."_WARLOCKS")
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")
end

-- Boss and arena stacks: frame count is fixed, spacing and growth direction place the frames below or above
-- the first. Labels are the options window's where its text isn't about the target.
local function Stack(s)
	s:Slider("spacing", "XPERL_EDITMODE_SPACING", 0, 100)
	s:Dropdown("growth", "XPERL_EDITMODE_GROWTH", {
		{"XPERL_EDITMODE_GROWTH_DOWN", "down"},
		{"XPERL_EDITMODE_GROWTH_UP", "up"},
	})
end

-- Buff and debuff rows of hostile units (boss, arena): own buffs and curable debuffs don't apply to them
local function HostileAuras(s)
	local T = "XPERL_CONF_TARGET_"
	s:Group("XPERL_EDITMODE_GROUP_BUFFS")
	s:Check("buffs.enable", T.."BUFFS_ENABLE", nil, true)
	s:Check("buffs.bigStealable", T.."BIGSTEALABLE", nil, true)
	s:Check("buffs.wrap", T.."WRAPBUFFS", nil, true)
	s:Check("buffs.above", T.."BUFFSABOVE", nil, true)
	s:Slider("buffs.size", "XPERL_EDITMODE_BUFFSIZE", 7, 38, nil, true)
	s:Slider("buffs.rows", "XPERL_EDITMODE_AURAROWS", 1, 10)

	s:Group("XPERL_EDITMODE_GROUP_DEBUFFS")
	s:Check("debuffs.enable", T.."DEBUFFS_ENABLE", nil, true)
	s:Check("debuffs.onlyMine", T.."ONLYMYDEBUFFS", nil, true)
	s:Check("debuffs.big", T.."BIGDEBUFFS", nil, true)
	s:Slider("debuffs.size", "XPERL_EDITMODE_DEBUFFSIZE", 7, 45, nil, true)
end

-- Boss frames (Units/Boss.lua): target frames in a stack
function specs.boss(s)
	local A, T = "XPERL_CONF_ALL_", "XPERL_CONF_TARGET_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale("XPERL_EDITMODE_SCALE", nil, true)
	s:Slider("size.width", A.."WIDTHBONUS", 0, 100, nil, true)
	Stack(s)
	s:Check("portrait", A.."PORTRAIT", nil, true)
	s:Check("portrait3D", A.."PORTRAIT3D", nil, true)
	s:Check("hitIndicator", "XPERL_CONF_HIT_INDICATOR", nil, true)
	s:Check("reactionHighlight", T.."REACTION", nil, true)
	s:Check("range30yard", T.."30YD", nil, true)
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("level", A.."LEVEL", nil, true)
	s:Check("eliteGfx", T.."ELITEGFX", nil, true)
	s:Check("mobType", "XPERL_EDITMODE_MOBTYPE")
	s:Check("mana", T.."MANA", nil, true)
	s:Check("values", A.."VALUES", nil, true)
	s:Check("percent", A.."PERCENT", nil, true)
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", "XPERL_CONF_ARCANE_BAR", nil, true)

	HostileAuras(s)
end

-- Arena enemy frames (Units/Arena.lua)
function specs.arena(s)
	local A, T = "XPERL_CONF_ALL_", "XPERL_CONF_TARGET_"
	s:Group("XPERL_EDITMODE_GROUP_FRAME", true)
	s:Scale("XPERL_EDITMODE_SCALE", nil, true)
	s:Slider("size.width", A.."WIDTHBONUS", 0, 100, nil, true)
	Stack(s)
	s:Check("portrait", A.."PORTRAIT", nil, true)
	s:Check("portrait3D", A.."PORTRAIT3D", nil, true)
	s:Check("hitIndicator", "XPERL_CONF_HIT_INDICATOR", nil, true)
	s:Check("reactionHighlight", T.."REACTION", nil, true)
	s:Check("range30yard", T.."30YD", nil, true)
	s:Check("healPrediction", "XPERL_CONF_HEALPREDICTION", "bool")

	s:Group("XPERL_EDITMODE_GROUP_TEXT")
	s:Check("classIcon", "XPERL_EDITMODE_SPECICON")
	s:Check("trinket", "XPERL_EDITMODE_TRINKET")
	s:Check("mana", T.."MANA", nil, true)
	s:Check("values", A.."VALUES", nil, true)
	s:Check("percent", A.."PERCENT", nil, true)
	s:Healer()

	s:Group("XPERL_EDITMODE_GROUP_ICONS")
	s:StatusIcons("icons")

	s:Group("XPERL_EDITMODE_GROUP_CASTBAR")
	s:Check("castBar.enable", "XPERL_CONF_ARCANE_BAR", nil, true)

	HostileAuras(s)
end

------------------------------------------------------------------------------

ns.EditModeSettings = {}

-- Settings list for a frame key's dialog (shared by all frames of that key), or nil
function ns.EditModeSettings.Get(frameKey)
	if (built[frameKey] == nil) then
		local spec = specs[frameKey]
		if (spec) then
			if (not defaults) then
				defaults = {}
				XPerl_Options_Defaults(defaults)
			end
			local builder = NewBuilder(frameKey)
			spec(builder)
			built[frameKey] = builder.list
		else
			built[frameKey] = false
		end
	end
	return built[frameKey] or nil
end

-- Called when Edit Mode opens: scale sliders go up to the maximum frame scale (options window, Colours tab)
function ns.EditModeSettings.RefreshLimits()
	local maxScale = floor(((XPerlDB and tonumber(XPerlDB.maximumScale)) or 1.5) * 100 + 0.5)
	for _, setting in ipairs(scaleSettings) do
		setting.maxValue = max(maxScale, setting.minValue + 1)
	end
end
