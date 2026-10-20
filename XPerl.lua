-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local addonName = ...		-- folder name, which the AddOn memory/CPU functions expect
local conf
local percD	= "%d"..PERCENT_SYMBOL
local perc1F = "%.1f"..PERCENT_SYMBOL

XPerl_RequestConfig(function(New) conf = New end, "$Revision$")
XPerl_SetModuleRevision("$Revision$")

--Some local copies for speed
local strsub = strsub
local format = format
local cos, sin, abs = cos, sin, abs
local max = math.max
local min = math.min
local IsSpellInRange = C_Spell.IsSpellInRange
local GetDebuffDataByIndex = XPerlAPI.GetDebuffDataByIndex			-- secret-safe, see XPerl_Api.lua
local UnitCanAssist = UnitCanAssist
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsEnemy = UnitIsEnemy
local UnitIsPVP = XPerlAPI.UnitIsPVP
local UnitIsVisible = UnitIsVisible
local UnitPlayerControlled = UnitPlayerControlled
local UnitReaction = UnitReaction
local largeNumDiv = XPERL_LOC_LARGENUMDIV
local largeNumTag = XPERL_LOC_LARGENUMTAG
local hugeNumDiv = XPERL_LOC_HUGENUMDIV
local hugeNumTag = XPERL_LOC_HUGENUMTAG
local hugeNumDiv10 = hugeNumDiv * 10
local largeNumDiv100 = largeNumDiv * 100
local ArcaneExclusions = XPerl_ArcaneExclusions
local GetDifficultyColor = GetCreatureDifficultyColor or GetQuestDifficultyColor		-- by level (GetDifficultyColor takes a difficulty enum)

--[===[@debug@
local function d(...)
	ChatFrame1:AddMessage(format(...))
end
--@end-debug@]===]

------------------------------------------------------------------------------
-- Re-usable tables
local FreeTables = setmetatable({}, {__mode = "k"})
local requested, freed = 0, 0
function XPerl_GetReusableTable(...)
	requested = requested + 1
	for t in pairs(FreeTables) do
		FreeTables[t] = nil
		for i = 1, select("#", ...) do
			t[i] = select(i, ...)
		end
		return t
	end
	return {...}
end
function XPerl_FreeTable(t, deep)
	if (t) then
		if (type(t) ~= "table") then
			error("Usage: XPerl_FreeTable([table])")
		end
		if (FreeTables[t]) then
			error("XPerl_FreeTable - Table already freed")
		end

		freed = freed + 1

		FreeTables[t] = true
		for k,v in pairs(t) do
			if (deep and type(v) == "table") then
				XPerl_FreeTable(v, true)
			end
			t[k] = nil
		end
		t[''] = 0
		t[''] = nil
	end
end
function XPerl_TableStats()
	return requested, freed
end

local new, del = XPerl_GetReusableTable, XPerl_FreeTable

local function rotate(angle)
	local A = cos(angle)
	local B = sin(angle)
	local ULx, ULy = -0.5 * A - -0.5 * B, -0.5 * B + -0.5 * A
	local LLx, LLy = -0.5 * A - 0.5 * B, -0.5 * B + 0.5 * A
	local URx, URy = 0.5 * A - -0.5 * B, 0.5 * B + -0.5 * A
	local LRx, LRy = 0.5 * A - 0.5 * B, 0.5 * B + 0.5 * A
	return ULx+0.5, ULy+0.5, LLx+0.5, LLy+0.5, URx+0.5, URy+0.5, LRx+0.5, LRy+0.5
end

-- meta table for string based colours. Allows for other mods changing class colours and things all working
XPerlColourTable = setmetatable({},{
	__index = function(self, class)
		local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[strupper(class or "")]
		if (c) then
			c = format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)
		else
			c = "|c00808080"
		end
		self[class] = c
		return c
	end
})

--XPerl_Percent = setmetatable({},
--	{__mode = "kv",
--	__index = function(self, i)
--		if (type(i) == "number" and i >= 0) then
--			self[i] = format(percD, i)
--			return self[i]
--		end
--		return ""
--	end
--	})
--local xpPercent = XPerl_Percent

-- XPerl_ShowMessage
-- debug function: prints an event and its arguments (the event/arg1..arg9 globals it used to read are long gone)
function XPerl_ShowMessage(cMsg, event, ...)
	local str = "|c00FF7F00"..tostring(event).."|r"
	local first = 1
	local unit = ...
	if (type(unit) == "string" and (unit == "player" or unit == "pet" or unit == "target" or unit =="focus" or strfind(unit, "^raid") or strfind(unit, "^party"))) then
		local class = select(2, UnitClass(unit))
		if (class and not issecretvalue(class)) then
			str = str..", |c00808080"..unit.."("..XPerlColourTable[class]..UnitName(unit).."|c00808080)|r"
			first = 2
		end
	end

	for i = first, select("#", ...) do
		str = str..", "..tostring((select(i, ...)))
	end

	if (cMsg) then
		str = cMsg.." - "..str
	end

	local cf = ChatFrame2
	if (not cf:IsVisible()) then
		cf = DEFAULT_CHAT_FRAME
	end
	cf:AddMessage(str)
end

XPerl_AnchorList = {"TOP", "LEFT", "BOTTOM", "RIGHT"}

-- Status icons of the unit frames (Units/UnitFrame.lua): their settings keys, in the order icons line up
-- when several share a spot
XPerl_StatusIcons = {"raidTarget", "leader", "assistant", "masterLooter", "mainAssist", "mainTank", "combat"}

-- Spots on a unit frame a status icon can take; "NONE" hides it
XPerl_StatusIconSpots = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}

-- Default spots per settings section ("partytarget": the party targets, party.target.icons): the raid
-- target icon, the group icons (leader, assistant, master looter, main assist, main tank), the combat icon
local statusIconDefaults = {
	player			= {"TOPLEFT", "TOP", "TOPRIGHT"},
	pet			= {"TOPLEFT", "TOP", "TOPRIGHT"},
	party			= {"TOPLEFT", "TOP", "TOPRIGHT"},
	partypet		= {"TOPLEFT", "TOP", "TOPRIGHT"},
	partytarget		= {"RIGHT", "NONE", "RIGHT"},
	target			= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	focus			= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	targettarget		= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	targettargettarget	= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	focustarget		= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	pettarget		= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	boss			= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	arena			= {"TOPRIGHT", "TOP", "TOPRIGHT"},
	raid			= {"LEFT", "LEFT", "RIGHT"},
	raidpet			= {"LEFT", "LEFT", "RIGHT"},
}

-- XPerl_DefaultStatusIcons(section)
-- A fresh table of the section's default status icon spots ({[icon key] = spot})
function XPerl_DefaultStatusIcons(section)
	local d = statusIconDefaults[section]
	local raidTarget, group, combat = d[1], d[2], d[3]
	return {
		raidTarget = raidTarget,
		leader = group,
		assistant = group,
		masterLooter = group,
		mainAssist = group,
		mainTank = group,
		combat = combat,
	}
end

-- XPerl_StatusIconSections: the settings sections with status icons (the party targets' are party.target.icons)
XPerl_StatusIconSections = {"player", "pet", "party", "partypet", "target", "focus", "targettarget", "targettargettarget",
	"focustarget", "pettarget", "boss", "arena", "raid", "raidpet"}

-- A do-nothing placeholder until XPerl_StartupSpellRange has checked the range finder settings
function XPerl_UpdateSpellRange()
	return
end

-- HasCurableDebuff(unit)
-- Whether unit has a debuff you can cure, not counting XPerl_ArcaneExclusions. A restricted (secret) debuff name
-- can't be looked up, so that debuff counts as curable
local function HasCurableDebuff(unit)
	for i = 1, 100 do
		local aura = GetDebuffDataByIndex(unit, i, "RAID")
		if (not aura) then
			return false
		end
		if (issecretvalue(aura.name) or not ArcaneExclusions[aura.name]) then
			return true
		end
	end
	return false
end

-- DoRangeCheck(unit, opt)
-- Whether unit counts as in range for a range finder row (rangeFinder.Main/NameFrame/StatsFrame): true, false, or a
-- restricted (secret) boolean that only widgets can read (see SetRangeAlpha)
local function DoRangeCheck(unit, opt)
	if (opt.PlusDebuff and not HasCurableDebuff(unit)) then
		return false		-- Nothing to cure, so it fades whatever the distance
	end
	if (opt.spell and not opt.interact) then
		local inRange = IsSpellInRange(opt.spell, unit)
		if (issecretvalue(inRange)) then
			return inRange
		end
		return inRange == true
	end
	-- 40 yards, also when there's no usable spell. UnitInRange is always restricted (secret) for add-on code
	return (UnitInRange(unit))
end

-- RangeSpell(opt): the spell a range finder row checks, or nil for 40 yards
local function RangeSpell(opt)
	return not opt.interact and opt.spell or nil
end

-- SameRangeCheck(a, b)
-- Whether two range finder rows check the same thing, so one result serves both
local function SameRangeCheck(a, b)
	return RangeSpell(a) == RangeSpell(b) and (not a.PlusDebuff) == (not b.PlusDebuff)
end

-- RangePick(inRange, inAlpha, outAlpha)
-- inAlpha or outAlpha by a range check result. The client picks for a restricted (secret) result, and the alpha it
-- gives back is secret too, which only widgets can use
local function RangePick(inRange, inAlpha, outAlpha)
	if (issecretvalue(inRange)) then
		return C_CurveUtil.EvaluateColorValueFromBoolean(inRange, inAlpha, outAlpha)
	elseif (inRange) then
		return inAlpha
	end
	return outAlpha
end

-- SetRangeAlpha(region, inRange, inAlpha, outAlpha)
-- Sets region's alpha by a range check result, which may be restricted (secret)
local function SetRangeAlpha(region, inRange, inAlpha, outAlpha)
	if (issecretvalue(inRange)) then
		region:SetAlphaFromBoolean(inRange, inAlpha, outAlpha)
	elseif (inRange) then
		region:SetAlpha(inAlpha)
	else
		region:SetAlpha(outAlpha)
	end
end

-- XPerl_UpdateSpellRange(self, overrideUnit, isRaidFrame)
-- Fades the frame (rangeFinder.Main), its name (NameFrame) and its stats (StatsFrame) while the unit is out of
-- range or out of sight, and the whole frame while the unit is offline
function XPerl_UpdateSpellRange2(self, overrideUnit, isRaidFrame)
	local unit
	if (overrideUnit) then
		unit = overrideUnit
	else
		unit = self:GetAttribute("unit")
		if (not unit) then
			unit = SecureButton_GetUnit(self)
		end
	end
	if (unit) then
		local rf = conf.rangeFinder
		local frameA = conf.transparency.frame
		local mainIn, nameIn, statsIn = true, true, true		-- true, false or a restricted (secret) boolean

		if (rf.enabled and (isRaidFrame or not rf.raidOnly)) then
			if (not UnitIsVisible(unit)) or UnitInVehicle(unit) then
				-- Out of sight: the whole frame fades if that's enabled, otherwise its parts do
				if (rf.Main.enabled) then
					mainIn = false
				else
					nameIn = not rf.NameFrame.enabled
					statsIn = not rf.StatsFrame.enabled
				end

			elseif (UnitCanAssist("player", unit)) then
				if (rf.Main.enabled) then
					mainIn = DoRangeCheck(unit, rf.Main)
				end
				if (rf.NameFrame.enabled) then
					if (rf.Main.enabled and SameRangeCheck(rf.Main, rf.NameFrame)) then
						nameIn = mainIn
					else
						nameIn = DoRangeCheck(unit, rf.NameFrame)
					end
				end
				if (rf.StatsFrame.enabled) then
					if (rf.Main.enabled and SameRangeCheck(rf.Main, rf.StatsFrame)) then
						statsIn = mainIn
					else
						statsIn = DoRangeCheck(unit, rf.StatsFrame)
					end
				end
			end
		end

		local nameFrame, statsFrame = self.nameFrame, self.statsFrame
		if (not issecretvalue(mainIn) and mainIn and not UnitIsConnected(unit)) then
			-- Offline: the whole frame fades, and its parts with it
			local offA = frameA * rf.Main.FadeAmount
			self:SetAlpha(offA)
			if (nameFrame) then
				nameFrame:SetAlpha(offA)
			end
			if (statsFrame) then
				statsFrame:SetAlpha(offA)
			end
			return
		end

		SetRangeAlpha(self, mainIn, frameA, frameA * rf.Main.FadeAmount)
		if (nameFrame or statsFrame) then
			-- A part in range shows in full while the whole frame is faded
			local partA = RangePick(mainIn, frameA, 1)
			if (nameFrame) then
				SetRangeAlpha(nameFrame, nameIn, partA, rf.NameFrame.FadeAmount)
			end
			if (statsFrame) then
				SetRangeAlpha(statsFrame, statsIn, partA, rf.StatsFrame.FadeAmount)
			end
		end
	end
end

-- SetupRangeRow(opt, defaultSpell)
-- A spell the player can't use becomes the class's default range spell, or none (40 yards)
local function SetupRangeRow(opt, defaultSpell)
	if (type(opt.spell) ~= "string" or not C_Spell.GetSpellName(opt.spell)) then
		opt.spell = defaultSpell
	end
	if (not opt.FadeAmount) then
		opt.FadeAmount = 0.3
	end
end

-- XPerl_StartupSpellRange()
function XPerl_StartupSpellRange()
	local _, playerClass = UnitClass("player")
	local default = XPerl_DefaultRangeSpells[playerClass]
	local defaultSpell = default and default.spell

	local rf = conf.rangeFinder
	SetupRangeRow(rf.Main, defaultSpell)
	SetupRangeRow(rf.NameFrame, defaultSpell)
	SetupRangeRow(rf.StatsFrame, defaultSpell)

	-- Put the real work function in place
	XPerl_UpdateSpellRange = XPerl_UpdateSpellRange2
end

XPerl_RegisterOptionChanger(XPerl_StartupSpellRange)

-- XPerl_StatsFrame_SetGrey
local function XPerl_StatsFrame_SetGrey(self, r, g, b)
	if (not r) then
		r, g, b = 0.5, 0.5, 0.5
	end

	self.healthBar:SetStatusBarColor(r, g, b, 1)
	self.healthBar.bg:SetVertexColor(r, g, b, 0.5)
	if (self.manaBar) then
		self.manaBar:SetStatusBarColor(r, g, b, 1)
		self.manaBar.bg:SetVertexColor(r, g, b, 0.5)
	end
	self.greyMana = true
end

-- XPerl_SetChildMembers - Recursive
-- This iterates a frame's child frames and regions and assigns member variables
-- based on the sub-set part of the child's name compared to the parent frame name
function XPerl_SetChildMembers(self)
	local n = self:GetName()
	if (n) then
		local match = "^"..n.."(.+)$"

		local function AddList(list)
			for k,v in pairs(list) do
				local t = v:GetName()
				if (t) then
					local found = strmatch(t, match)
					if (found) then
						--if (self[found] == v) then
						--	break		-- Already done
						--end
						self[found] = v
					end
				end
			end
		end

		AddList({self:GetRegions()})

		local c = {self:GetChildren()}
		AddList(c, true)

		for k,v in pairs(c) do
			if (v:GetName()) then
				XPerl_SetChildMembers(v)
			end
			v:SetScript("OnLoad", nil)
		end

		self:SetScript("OnLoad", nil)
	end
end

do
	local shortlist
	local list
	local media

	-- XPerl_RegisterSMBarTextures
	function XPerl_RegisterSMBarTextures()
		if (LibStub) then
			media = LibStub("LibSharedMedia-3.0", true)
		end

		shortlist = {
			{"Perl v2", "Interface\\Addons\\XPerl\\Images\\XPerl_StatusBar"},
		}
		for i = 1,9 do
			local name = i == 2 and "BantoBar" or "X-Perl "..i
			tinsert(shortlist, {name, "Interface\\Addons\\XPerl\\Images\\XPerl_StatusBar"..(i + 1)})
		end

		if (media) then
			for k,v in pairs(shortlist) do
				media:Register("statusbar", v[1], v[2])
			end

			media:Register("border", "X-Perl Thin", "Interface\\Addons\\XPerl\\images\\XPerl_ThinEdge")
		end
	end

	-- XPerl_AllBarTextures
	function XPerl_AllBarTextures(short)
		if (not list) then
			if (short) then
				return shortlist
			end

			if (media) then
				list = {}
				local smlBars = media:List("statusbar")
				for k,v in pairs(smlBars) do
					tinsert(list, {v, media:Fetch("statusbar", v)})
				end
			else
				list = shortlist
			end
		end

		return list
	end
end

-- XPerl_GetBarTexture
function XPerl_GetBarTexture()
	return (conf and conf.bar and conf.bar.texture and conf.bar.texture[2]) or "Interface\\TargetingFrame\\UI-StatusBar"
end

-- XPerl_StatsFrame_Setup
function XPerl_StatsFrame_Setup(self)
	XPerl_SetChildMembers(self)
	self.SetGrey = XPerl_StatsFrame_SetGrey
end

-- XPerl_GetClassColour
local defaultColour = {r = 0.5, g = 0.5, b = 1}
-- A restricted (secret) class can't be used as a table key, so it gets the default colour
function XPerl_GetClassColour(class)
	if (not class or issecretvalue(class)) then
		return defaultColour
	end
	return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class] or defaultColour
end

---------------------------------
--Loading Function             --
---------------------------------

-- Blizzard frames we replace are reparented here so nothing (Edit Mode, other mods) can make them visible
local blizzHiddenParent = CreateFrame("Frame")
blizzHiddenParent:Hide()

-- blizzFrameOnShow
local function blizzFrameOnShow(self)
	if (not InCombatLockdown()) then
		self:Hide()
	end
end

-- blizzFrameDisable
local function blizzFrameDisable(self, keepParent)
	UnregisterUnitWatch(self)		-- Should stop Archaeologist from re-showing target frame
	self:UnregisterAllEvents()
	self:Hide()
	if (not keepParent) then
		self:SetParent(blizzHiddenParent)
	end
	if (not self.XPerlDisabled) then
		self.XPerlDisabled = true
		self:HookScript("OnShow", blizzFrameOnShow)
	end

	local bars = {self.healthbar, self.manabar, self.powerBarAlt, self.spellbar, self.PetFrame}
	for i = 1, 5 do
		if (bars[i]) then
			bars[i]:UnregisterAllEvents()
		end
	end

	-- Target of target (TargetFrame.totFrame) lives inside the target frame
	if (self.totFrame) then
		blizzFrameDisable(self.totFrame, true)
	end
end

local pendingDisable = {}

-- blizzFrameDisablePending
local function blizzFrameDisablePending()
	for frame, keepParent in pairs(pendingDisable) do
		pendingDisable[frame] = nil
		blizzFrameDisable(frame, keepParent)
	end
end

-- blizzFrameDisableSafe
local function blizzFrameDisableSafe(frame, keepParent)
	if (InCombatLockdown()) then
		pendingDisable[frame] = keepParent or false
		XPerl_ProtectedCall(blizzFrameDisablePending)
	else
		blizzFrameDisable(frame, keepParent)
	end
end

-- XPerl_BlizzFrameDisable
function XPerl_BlizzFrameDisable(self)
	if (not self) then
		return
	end

	blizzFrameDisableSafe(self)

	if (self == PartyFrame) then
		-- Party members are pooled children of PartyFrame; they go hidden with their parent
		if (PartyFrame.PartyMemberFramePool) then
			for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
				blizzFrameDisableSafe(frame, true)
			end
		else
			for i = 1, 4 do
				local frame = PartyFrame["MemberFrame"..i]
				if (frame) then
					blizzFrameDisableSafe(frame, true)
				end
			end
		end
	end
end

-- smoothColor
local function smoothColor(percentage)
	local r, g, b
	if (percentage < 0.5) then
		r = 1
		g = min(1, max(0, 2*percentage))
		b = 0
	else
		g = 1
		r = min(1, max(0, 2*(1 - percentage)))
		b = 0
	end

	return r, g, b
end

---------------------------------
--Smooth Health Bar Color      --
---------------------------------
function XPerl_SetSmoothBarColor(self, percentage)
	if (self) then
		local r, g, b
		if (conf.colour.classic) then
			r, g, b = smoothColor(percentage)
		else
			local c = conf.colour.bar
			r = min(1, max(0, c.healthEmpty.r + ((c.healthFull.r - c.healthEmpty.r) * percentage)))
			g = min(1, max(0, c.healthEmpty.g + ((c.healthFull.g - c.healthEmpty.g) * percentage)))
			b = min(1, max(0, c.healthEmpty.b + ((c.healthFull.b - c.healthEmpty.b) * percentage)))
		end

		self:SetStatusBarColor(r, g, b)

		if (self.bg) then
			self.bg:SetVertexColor(r, g, b, 0.25)
		end
	end
end

local barColours
function XPerl_ResetBarColourCache()
	barColours = setmetatable({}, {
		__index = function(self, k)
			local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[k]
			if (c) then
				if (not conf.colour.classbarBright) then
					conf.colour.classbarBright = 1
				end
				self[k] = {	r = max(0, min(1, c.r * conf.colour.classbarBright)),
						g = max(0, min(1, c.g * conf.colour.classbarBright)),
						b = max(0, min(1, c.b * conf.colour.classbarBright))}
				return self[k]
			end
		end
	})
end
XPerl_ResetBarColourCache()

-- The same colours as a colour curve, for restricted (secret) health: the client evaluates it from the unit's health
-- (UnitHealthPercent), so the bar keeps its gradient in combat. Rebuilt whenever the options change.
local healthColourCurve
local function BuildHealthColourCurve()
	if (healthColourCurve) then
		healthColourCurve:ClearPoints()
	else
		healthColourCurve = C_CurveUtil.CreateColorCurve()
	end
	if (conf.colour.classic) then
		-- smoothColor: red, through yellow at half health, to green
		healthColourCurve:AddPoint(0, CreateColor(1, 0, 0))
		healthColourCurve:AddPoint(0.5, CreateColor(1, 1, 0))
		healthColourCurve:AddPoint(1, CreateColor(0, 1, 0))
	else
		local c = conf.colour.bar
		healthColourCurve:AddPoint(0, CreateColor(c.healthEmpty.r, c.healthEmpty.g, c.healthEmpty.b))
		healthColourCurve:AddPoint(1, CreateColor(c.healthFull.r, c.healthFull.g, c.healthFull.b))
	end
end
XPerl_RegisterOptionChanger(BuildHealthColourCurve)

-- XPerl_SetSmoothBarColorFromUnit(bar, unit)
-- XPerl_SetSmoothBarColor by the unit's own health, which may be restricted (secret)
function XPerl_SetSmoothBarColorFromUnit(bar, unit)
	if (not healthColourCurve) then
		BuildHealthColourCurve()
	end
	local r, g, b = UnitHealthPercent(unit, false, healthColourCurve):GetRGB()
	bar:SetStatusBarColor(r, g, b)
	if (bar.bg) then
		bar.bg:SetVertexColor(r, g, b, 0.25)
	end
end

-- XPerl_ColourHealthBar(self, healthPct, partyid)
-- healthPct is the health fraction (0 to 1); nil colours the bar from the unit's health, for restricted (secret) health
function XPerl_ColourHealthBar(self, healthPct, partyid)
	if (not partyid) then
		partyid = self.partyid
	end
	local bar = self.statsFrame.healthBar
	if (conf.colour.classbar and UnitIsPlayer(partyid)) then
		local class = select(2, UnitClass(partyid))
		if (class and not issecretvalue(class)) then
			local c = barColours[class]
			if (c) then
				bar:SetStatusBarColor(c.r, c.g, c.b)
				if (bar.bg) then
					bar.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
				end
				return
			end
		end
	end

	if (healthPct) then
		XPerl_SetSmoothBarColor(bar, healthPct)
	else
		XPerl_SetSmoothBarColorFromUnit(bar, partyid)
	end
end
local XPerl_ColourHealthBar = XPerl_ColourHealthBar

-- Restricted (secret) health and power values can be handed to widgets and to the client's own formatting
-- helpers, but can't be used in Lua arithmetic, comparisons or as table keys. These build display text from them.
local secretPercentCurve = C_CurveUtil.CreateCurve()
secretPercentCurve:AddPoint(0, 0)
secretPercentCurve:AddPoint(1, 100)
local percentSuffix = format(PERCENT_SYMBOL)

-- XPerl_UnitHealthPercentText
function XPerl_UnitHealthPercentText(unit)
	return C_StringUtil.RoundToNearestString(UnitHealthPercent(unit, true, secretPercentCurve))..percentSuffix
end

-- XPerl_UnitPowerPercentText
function XPerl_UnitPowerPercentText(unit, powerType)
	return C_StringUtil.RoundToNearestString(UnitPowerPercent(unit, powerType, false, secretPercentCurve))..percentSuffix
end

-- XPerl_UnitHealthDeficitText
-- Missing health as "-1234", or an empty string at full health
function XPerl_UnitHealthDeficitText(unit)
	return C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(UnitHealthMissing(unit)), "-")
end

-- XPerl_SetValuedText
function XPerl_SetValuedText(self, current, Max, suffix)
	if (issecretvalue(current) or issecretvalue(Max)) then
		-- Restricted values can't be measured or divided, so let the client abbreviate them
		self:SetText(AbbreviateNumbers(current).."/"..AbbreviateNumbers(Max)..(suffix or ""))
		return
	end

	if (Max >= hugeNumDiv) then
		if (abs(current) < largeNumDiv100) then
			-- 123/12.3M
			self:SetFormattedText("%d/%.1f%s%s", current, Max / hugeNumDiv, hugeNumTag, suffix or "")
		else
			if (abs(current) >= hugeNumDiv) then
				-- 1.2M/12.3M
				self:SetFormattedText("%.1f%s/%.1f%s%s", current / hugeNumDiv, hugeNumTag, Max / hugeNumDiv, hugeNumTag, suffix or "")
			else
				-- 12.3K/12.3M
				self:SetFormattedText("%.1f%s/%.1f%s%s", current / largeNumDiv, largeNumTag, Max / hugeNumDiv, hugeNumTag, suffix or "")
			end
		end
	else
		if (Max > largeNumDiv100) then
			if (abs(current) < largeNumDiv100) then
				-- 123/123.4K
				self:SetFormattedText("%d/%.1f%s%s", current, Max / largeNumDiv, largeNumTag, suffix or "")
			else
				-- 12345/123.4K
				self:SetFormattedText("%.1f%s/%.1f%s%s", current / largeNumDiv, largeNumTag, Max / largeNumDiv, largeNumTag, suffix or "")
			end
		else
			-- 12345/12345
			self:SetFormattedText("%d/%d%s", current, Max, suffix or "")
		end
	end
end
local SetValuedText = XPerl_SetValuedText

-- SetSecretHealthBar
-- Restricted (secret) health can't be turned into a percentage here, so the bar's colour comes from the client's
-- colour curve, its texture isn't cropped, and the texts come from the client's formatting helpers
local function SetSecretHealthBar(self, bar, hp, Max)
	local unit = self.partyid
	if (conf.bar.inverse) then
		bar:SetValue(UnitHealthMissing(unit))
	else
		bar:SetValue(hp)
	end
	bar.tex:SetTexCoord(0, 1, 0, 1)

	XPerl_ColourHealthBar(self)
	if (bar.percent) then
		if (self.conf.healerMode and self.conf.healerMode.enable and self.conf.healerMode.type == 2) then
			bar.percent:SetText(XPerl_UnitHealthDeficitText(unit))
		else
			bar.percent:SetText(XPerl_UnitHealthPercentText(unit))
		end
	end

	if (bar.text) then
		local hbt = bar.text
		if (self.conf.healerMode and self.conf.healerMode.enable and self.conf.healerMode.type ~= 2) then
			if (self.conf.healerMode.type == 1) then
				hbt:SetText("-"..AbbreviateNumbers(UnitHealthMissing(unit)).."/"..AbbreviateNumbers(Max))
			else
				hbt:SetText(XPerl_UnitHealthDeficitText(unit))
			end
		else
			SetValuedText(hbt, hp, Max)
		end
	end
	self:UpdateHealPrediction()
end

-- XPerl_SetHealthBar
function XPerl_SetHealthBar(self, hp, Max)
	local bar = self.statsFrame.healthBar
	--print(self.partyid .. hp .. ":" .. Max)
	bar:SetMinMaxValues(0, Max)
	if (issecretvalue(hp) or issecretvalue(Max)) then
		SetSecretHealthBar(self, bar, hp, Max)
		return
	end
	local percent
	if hp >= 1 and Max == 0 then--For some dumb reason max HP is 0, normal HP is not, so lets use normal HP as max
		Max = hp
		percent = 100
	elseif hp == 0 and Max == 0 then--Both are 0, so it's probably dead since usually current HP returns correctly when Max HP fails.
		percent = 0
	else
		percent = hp / Max
	end		
	if (percent > 1) then percent = 1 end -- a fraction: never more than full
    if (conf.bar.inverse) then

		bar:SetValue(Max - hp)
		bar.tex:SetTexCoord(0, max(0,(1 - percent)), 0, 1)
	
	else

		bar:SetValue(hp)
		bar.tex:SetTexCoord(0, max(0, percent), 0, 1)
	
	end

	XPerl_ColourHealthBar(self, percent)
	if (bar.percent) then
		if (self.conf.healerMode and self.conf.healerMode.enable and self.conf.healerMode.type == 2) then
			bar.percent:SetText(hp - Max)
		else
			local show = percent * 100
			if (show < 10) then
				bar.percent:SetFormattedText(perc1F or "%.1f%%", show + 0.05)
			else
				bar.percent:SetFormattedText(percD or "%d%%", show + 0.5)
			end
		end
	end

	if (bar.text) then
		local hbt = bar.text
		if (self.conf.healerMode and self.conf.healerMode.enable and self.conf.healerMode.type ~= 2) then
			local health = hp - Max
			if (self.conf.healerMode.type == 1) then
				SetValuedText(hbt, health, Max)
			else
				if (abs(health) >= hugeNumDiv10) then
					hbt:SetFormattedText("%d%s", health / hugeNumDiv, hugeNumTag)
				elseif (abs(health) >= largeNumDiv100) then
					hbt:SetFormattedText("%d%s", health / largeNumDiv, largeNumTag)
				else
					hbt:SetFormattedText("%d", health)
				end
			end
		else
			SetValuedText(hbt, hp, Max)
		end
	end
	self:UpdateHealPrediction()
end

---------------------------------
--Class Icon Location Functions--
---------------------------------
--local ClassPos = {
--	WARRIOR	= {0,    0.25,    0,	0.25},
--	MAGE	= {0.25, 0.5,     0,	0.25},
--	ROGUE	= {0.5,  0.75,    0,	0.25},
--	DRUID	= {0.75, 1,       0,	0.25},
--	HUNTER	= {0,    0.25,    0.25,	0.5},
--	SHAMAN	= {0.25, 0.5,     0.25,	0.5},
--	PRIEST	= {0.5,  0.75,    0.25,	0.5},
--	WARLOCK	= {0.75, 1,       0.25,	0.5},
--	PALADIN	= {0,    0.25,    0.5,	0.75},
--	none	= {0.25, 0.5, 0.5, 0.75},
--}
--function XPerl_ClassPos(class)
--	return unpack(ClassPos[class] or ClassPos.none)
--end

local ClassPos = CLASS_ICON_TCOORDS
function XPerl_ClassPos(class)
	local b = class and not issecretvalue(class) and ClassPos[class]		-- Blizzard's CLASS_ICON_TCOORDS; a secret class gets the unknown icon
	if (b) then
		return unpack(b)
	end
	return 0.25, 0.5, 0.5, 0.75
end

-- Raid class columns
-- When the raid frames sort by class there's one column (XPerl_Raid_GrpN) per playable class. This is
-- the default order; Demon Hunter and Evoker came after the original eleven.
local defaultRaidClasses = {"WARRIOR", "DEATHKNIGHT", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN", "MONK", "DEMONHUNTER", "EVOKER"}
XPERL_RAID_CLASS_COUNT = #defaultRaidClasses

-- XPerl_DefaultRaidClasses
function XPerl_DefaultRaidClasses()
	local list = {}
	for i, class in ipairs(defaultRaidClasses) do
		list[i] = {enable = true, name = class}
	end
	return list
end

-- XPerl_ValidateRaidClasses
-- Makes raid.class list every playable class exactly once, keeping the user's order and choices.
-- Lists saved before a class existed get it added, enabled, at the end.
function XPerl_ValidateRaidClasses(raid)
	local known, seen, list = {}, {}, {}
	for i, class in ipairs(defaultRaidClasses) do
		known[class] = true
	end
	if (type(raid.class) == "table") then
		for i, info in ipairs(raid.class) do
			if (type(info) == "table" and known[info.name] and not seen[info.name]) then
				seen[info.name] = true
				tinsert(list, info)
			end
		end
	end
	for i, class in ipairs(defaultRaidClasses) do
		if (not seen[class]) then
			tinsert(list, {enable = true, name = class})
		end
	end
	raid.class = list
end

-- XPerl_Toggle
-- Goes by whether the options window is actually up, so it still opens if the window was hidden some other
-- way than XPerl_LockFrames (which would otherwise leave XPerlLocked at 0 and make this "close" it again)
function XPerl_Toggle()
	if (XPerl_Options and XPerl_Options:IsShown() and XPerl_Options.Fading ~= "out") then
		XPerl_LockFrames()
	else
		XPerl_UnlockFrames()
	end
end

-- XPerl_UnlockFrames
-- Opens the options window; while it is open frames can be dragged and show their placeholders
-- (the preview callbacks given to XPerl_EditMode_Register)
function XPerl_UnlockFrames()
	XPerlLocked = 0

	if (XPerl_Options) then
		XPerl_Options:Show()
		XPerl_Options:SetAlpha(0)
		XPerl_Options.Fading = "in"
	end

	XPerl_EditMode_RefreshPreviews()
end

-- XPerl_LockFrames
function XPerl_LockFrames()
	XPerlLocked = 1
	if (XPerl_Options) then
		XPerl_Options.Fading = "out"
	end

	XPerl_EditMode_RefreshPreviews()

	XPerl_OptionActions()
end

-- Minimap Icon
function XPerl_MinimapButton_OnClick(self, button)
	GameTooltip:Hide()
	if (button == "LeftButton") then
		XPerl_Toggle()
	elseif (button == "RightButton") then
		XPerl_MinimapMenu(self)
	end
end

-- XPerl_MinimapMenu_OnLoad
function XPerl_MinimapMenu_OnLoad(self)
	self.displayMode = "MENU"
	UIDropDownMenu_Initialize(self, XPerl_MinimapMenu_Initialize)
end

-- XPerl_MinimapMenu_Initialize
function XPerl_MinimapMenu_Initialize(self, level)
	local info

	if (level == 2) then
		if (UIDROPDOWNMENU_MENU_VALUE == "raidbuffs") then
			info = UIDropDownMenu_CreateInfo()
			info.isTitle = 1
			info.text = XPERL_MINIMENU_RAIDBUFF
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = BINDING_NAME_TOGGLEBUFFCASTABLE
			info.func = function() XPerl_ToggleRaidBuffs(1) end
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()
			info.notCheckable = 1
			info.text = BINDING_NAME_TOGGLEBUFFTYPE
			info.func = function() XPerl_ToggleRaidBuffs() end
			UIDropDownMenu_AddButton(info, level)

		elseif (UIDROPDOWNMENU_MENU_VALUE == "raidsort") then

			info = UIDropDownMenu_CreateInfo()
			info.isTitle = 1
			info.text = XPERL_MINIMENU_RAIDSORT
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()
			info.checked = not XPerlDB.raid.sortByClass
			info.text = XPERL_MINIMENU_RAIDSORT_GROUP
			info.func = function() XPerl_ToggleRaidSort("group") end
			UIDropDownMenu_AddButton(info, level)

			info = UIDropDownMenu_CreateInfo()
			info.checked = XPerlDB.raid.sortByClass and true or false
			info.text = XPERL_MINIMENU_RAIDSORT_CLASS
			info.func = function() XPerl_ToggleRaidSort("class") end
			UIDropDownMenu_AddButton(info, level)
		end
		return
	end

	info = UIDropDownMenu_CreateInfo()
	info.isTitle = 1
	info.text = XPerl_ProductName
	UIDropDownMenu_AddButton(info)

	info = UIDropDownMenu_CreateInfo()
	info.notCheckable = 1
	info.func = XPerl_Toggle
	info.text = XPERL_MINIMENU_OPTIONS
	UIDropDownMenu_AddButton(info)

	info = UIDropDownMenu_CreateInfo()
	info.notCheckable = 1
	info.text = XPERL_MINIMENU_RAIDBUFF
	info.hasArrow = 1
	info.value = "raidbuffs"
	UIDropDownMenu_AddButton(info)

	info = UIDropDownMenu_CreateInfo()
	info.notCheckable = 1
	info.text = XPERL_MINIMENU_RAIDSORT
	info.hasArrow = 1
	info.value = "raidsort"
	UIDropDownMenu_AddButton(info)
end

-- XPerl_MinimapMenu
function XPerl_MinimapMenu(self)
	if (not XPerl_Minimap_Dropdown) then
		CreateFrame("Frame", "XPerl_Minimap_Dropdown")
		XPerl_MinimapMenu_OnLoad(XPerl_Minimap_Dropdown)
	end

	ToggleDropDownMenu(1, nil, XPerl_Minimap_Dropdown, "cursor", 0, 0)
end

local xpStartupMemory = 0

-- XPerl_MinimapButton_Init
function XPerl_MinimapButton_Init(self)
	self.time = 0
	collectgarbage()
	UpdateAddOnMemoryUsage()
	xpStartupMemory = GetAddOnMemoryUsage(addonName) or 0

	XPerl_MinimapButton_UpdatePosition(self)

	if (conf.minimap.enable) then
		self:Show()
	else
		self:Hide()
	end

	self.UpdateTooltip = XPerl_MinimapButton_OnEnter

	XPerl_MinimapButton_Init = nil
end

-- XPerl_MinimapButton_UpdatePosition
function XPerl_MinimapButton_UpdatePosition(self)
	if (not conf.minimap.radius) then
		conf.minimap.radius = 78
	end
	self:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - (conf.minimap.radius * cos(conf.minimap.pos)),
		(conf.minimap.radius * sin(conf.minimap.pos)) - 55
	)
end

-- XPerl_MinimapButton_Dragging
function XPerl_MinimapButton_Dragging(self, elapsed)
	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70
	ypos = ypos/UIParent:GetScale()-ymin-70

	if (IsAltKeyDown()) then
		local radius = (xpos^2 + ypos^2)^0.5
		if (radius < 78) then
			radius = 78
		end
		if (radius > 148) then
			radius = 148
		end
		conf.minimap.radius = radius
		end

	local angle = math.deg(math.atan2(ypos,xpos))
	if (angle < 0) then
		angle = angle + 360
	end
	conf.minimap.pos = angle

	XPerl_MinimapButton_UpdatePosition(self)
end

-- DiffColour(diff, val)
local function DiffColour(val)
	local r, g, b, offset
	offset = max(0, min(0.5, 0.5 * min(1, val)))
	if (val < 0) then
		r = 0.5 + offset
		g = 0.5 - offset
		b = r
	else
		r = 0.5 + offset
		g = 0.5 - offset
		b = g
	end
	return format("|c00%02X%02X%02X", 255 * r, 255 * g, 255 * b)
end

-- XPerl_MinimapButton_OnEnter
function XPerl_MinimapButton_OnEnter(self)
	if (self.dragging) then
		return
	end

	GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
	XPerl_MinimapButton_Details(GameTooltip)
end

-- XPerl_MinimapButton_Details
function XPerl_MinimapButton_Details(tt, ldb)
	tt:SetText(XPerl_Version.." "..XPerl_GetRevision(), 1, 1, 1)
	tt:AddLine(XPERL_MINIMAP_HELP1)
	if (not ldb) then
		tt:AddLine(XPERL_MINIMAP_HELP2)
	end
	if (UpdateAddOnMemoryUsage) then
		if (IsAltKeyDown()) then
			tt:AddLine(XPERL_MINIMAP_HELP6)
		elseif (not IsShiftKeyDown()) then
			tt:AddLine(XPERL_MINIMAP_HELP5)
		end
	end
	--GetRealNumRaidMembers doesn't exist anymore in 5.0.4
	--[==[if (GetRealNumRaidMembers) then
		if (GetNumGroupMembers() > 0 and GetRealNumRaidMembers() > 0) then
			if (select(2, IsInInstance()) == "pvp") then
				tt:AddLine(format(XPERL_MINIMAP_HELP3, GetRealNumRaidMembers(), GetNumSubgroupMembers(LE_PARTY_CATEGORY_HOME)))

				if (IsRealPartyLeader()) then
					tt:AddLine(XPERL_MINIMAP_HELP4)
				end
			end
		end
	end]==]

	if (UpdateAddOnMemoryUsage and IsAltKeyDown()) then
		local showDiff = IsShiftKeyDown()

		local allAddonsCPU = 0
		for i = 1,C_AddOns.GetNumAddOns() do
			allAddonsCPU = allAddonsCPU + GetAddOnCPUUsage(i)
		end

		-- Show X-Perl memory usage
		UpdateAddOnMemoryUsage()
		UpdateAddOnCPUUsage()
		local usedKB = GetAddOnMemoryUsage(addonName) or 0
		local usedCPU = GetAddOnCPUUsage(addonName) or 0
		if (showDiff) then
			local diff = usedKB - xpStartupMemory
			tt:AddDoubleLine("Total", format("%.1fkb (%s%.1fkb|r)", usedKB, DiffColour(diff / 2000), diff), 1, 1, 1, 1, 1, 1)
		else
			tt:AddDoubleLine("Total", format("%.1fkb", usedKB), 1, 1, 1, 1, 1, 1)
		end

		if (usedCPU > 0 and allAddonsCPU > 0) then
			tt:AddDoubleLine(" XPerl CPU Usage Comparison", format("%.2f%%", 100 * (usedCPU / allAddonsCPU)), 0.5, 0.5, 1, 0.5, 0.5, 1)
		end
	end

	tt:Show()
	tt.updateTooltip = 1
end

function XPerl_GetDisplayedPowerType(unitID) -- copied from CompactUnitFrame.lua
	local barInfo = GetUnitPowerBarInfo(unitID);
	if ( barInfo and barInfo.showOnRaid and (UnitInParty(unitID) or UnitInRaid(unitID)) ) then
		return Enum.PowerType.Alternate;
	else
		return UnitPowerType(unitID);
	end
end

-- XPerl_SetManaBarType
local ManaColours = {
	[Enum.PowerType.Mana] = "mana",
	[Enum.PowerType.Rage] = "rage",
	[Enum.PowerType.Focus] = "focus",
	[Enum.PowerType.Energy] = "energy",
	[Enum.PowerType.Runes] = "runes",
	[Enum.PowerType.RunicPower] = "runic_power",
	[Enum.PowerType.Alternate] = "energy", -- used by some bosses, show it as energy bar
}
function XPerl_SetManaBarType(self)
	local m = self.statsFrame.manaBar
	if (m and not self.statsFrame.greyMana) then
		local unit = self.partyid		-- SecureButton_GetUnit(self)
		if (unit) then
			local p = XPerl_GetDisplayedPowerType(unit)
			if (p) then
				local c = conf.colour.bar[ManaColours[p]]
				if (c) then
					m:SetStatusBarColor(c.r, c.g, c.b, 1)
					m.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
				end
			end
		end
	end
end

-- XPerl_SetPowerBar(self, current, maxPower, powerType, exactText)
-- Power bar value and texts for every unit frame. The value text is "current/max" (exactText) or
-- abbreviated; the percent text shows a percentage for mana and the plain value for other power types.
-- Restricted (secret) power can't be compared or divided, so the client formats it then.
local powerPercent = "%.0f"..PERCENT_SYMBOL
function XPerl_SetPowerBar(self, current, maxPower, powerType, exactText)
	local mb = self.statsFrame.manaBar
	if (issecretvalue(current) or issecretvalue(maxPower)) then
		mb:SetMinMaxValues(0, maxPower)
		mb:SetValue(current)
		if (exactText) then
			mb.text:SetText(current.."/"..maxPower)
		else
			XPerl_SetValuedText(mb.text, current, maxPower)
		end
		if (powerType == 0) then
			mb.percent:SetText(XPerl_UnitPowerPercentText(self.partyid, powerType))
		else
			mb.percent:SetText(current)
		end
		mb.tex:SetTexCoord(0, 1, 0, 1)
		return
	end

	-- A unit with power but no maximum (it happens) counts as full; 0/0 as empty
	local fraction
	if (maxPower == 0) then
		fraction = current > 0 and 1 or 0
		maxPower = current
	else
		fraction = current / maxPower
	end
	mb:SetMinMaxValues(0, maxPower)
	mb:SetValue(current)

	if (exactText) then
		mb.text:SetFormattedText("%d/%d", current, maxPower)
	else
		XPerl_SetValuedText(mb.text, current, maxPower)
	end
	if (powerType == 0 and maxPower > 0) then
		mb.percent:SetFormattedText(powerPercent, fraction * 100)
	else
		mb.percent:SetText(current)
	end
	mb.tex:SetTexCoord(0, max(0, min(1, fraction)), 0, 1)
end

-- XPerl_TooltipModiferPressed()
function XPerl_TooltipModiferPressed(buffs)
	local mod, ic
	if (buffs) then
		if (not conf.tooltip.enableBuffs) then
			return
		end
		mod = conf.tooltip.buffModifier
		ic = conf.tooltip.buffHideInCombat
	else
		if (not conf.tooltip.enable) then
			return
		end
		mod = conf.tooltip.modifier
		ic = conf.tooltip.hideInCombat
	end

	if (mod == "alt") then
		mod = IsAltKeyDown()
	elseif (mod == "shift") then
		mod = IsShiftKeyDown()
	elseif (mod == "control") then
		mod = IsControlKeyDown()
	else
		mod = true
	end

	mod = mod and (not ic or not InCombatLockdown())

	return mod
end

-- XPerl_PlayerTip
function XPerl_PlayerTip(self, unitid)
	if (not unitid) then
		unitid = SecureButton_GetUnit(self)
	end

	if (not unitid or XPerlLocked == 0) then
		return
	end

	if (not XPerl_TooltipModiferPressed()) then
		return
	end

	if (SpellIsTargeting()) then
		if (SpellCanTargetUnit(unitid)) then
			SetCursor("CAST_CURSOR")
		else
			SetCursor("CAST_ERROR_CURSOR")
		end
	end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(unitid)

	XPerl_RaidTipExtra(unitid)

	XPerl_Highlight:TooltipInfo(unitid)
end

-- XPerl_PlayerTipHide
function XPerl_PlayerTipHide()
	if (conf.tooltip.fading) then
		GameTooltip:FadeOut()
	else
		GameTooltip:Hide()
	end
end

-- XPerl_ColourFriendlyUnit
function XPerl_ColourFriendlyUnit(self, partyid)
	local color
	if (UnitCanAttack("player", partyid) and UnitIsEnemy("player", partyid)) then	-- For dueling
		color = conf.colour.reaction.enemy
	else
		if (conf.colour.class) then
			color = XPerl_GetClassColour(select(2, UnitClass(partyid)))
		else
			if (UnitIsPVP(partyid)) then
				color = conf.colour.reaction.friend
			else
				color = conf.colour.reaction.none
			end
		end
	end

	self:SetTextColor(color.r, color.g, color.b, conf.transparency.text)
end

-- XPerl_ReactionColour
function XPerl_ReactionColour(argUnit)
	if (UnitPlayerControlled(argUnit) or not UnitIsVisible(argUnit)) then
		if (UnitFactionGroup("player") == UnitFactionGroup(argUnit)) then
			if (UnitIsEnemy("player", argUnit)) then
				-- Dueling
				return conf.colour.reaction.enemy

			elseif (UnitIsPVP(argUnit)) then
				return conf.colour.reaction.friend
			end
		else
			if (UnitIsPVP(argUnit)) then
				if (UnitIsPVP("player")) then
					return conf.colour.reaction.enemy
				else
					return conf.colour.reaction.neutral
				end
			end
		end
	else
		if (UnitIsTapDenied(argUnit)) then
			return conf.colour.reaction.tapped
		else
			local reaction = UnitReaction(argUnit, "player")
			if (reaction) then
				if (reaction >= 5) then
					return conf.colour.reaction.friend
				elseif (reaction <= 2) then
					return conf.colour.reaction.enemy
				elseif (reaction == 3) then
					return conf.colour.reaction.unfriendly
				else
					return conf.colour.reaction.neutral
				end
			else
				if (UnitFactionGroup("player") == UnitFactionGroup(argUnit)) then
					return conf.colour.reaction.friend
				elseif (UnitIsEnemy("player", argUnit)) then
					return conf.colour.reaction.enemy
				else
					return conf.colour.reaction.neutral
				end
			end
		end
	end

	return conf.colour.reaction.none
end

-- XPerl_SetUnitNameColor
function XPerl_SetUnitNameColor(self, unit)
	local color
	if (UnitIsPlayer(unit) or not UnitIsVisible(unit)) then			-- Changed UnitPlayerControlled to UnitIsPlayer for 2.3.5
		-- 1.8.3 - Changed to override pvp name colours
		if (conf.colour.class) then
			color = XPerl_GetClassColour(select(2, UnitClass(unit)))
		else
			color = XPerl_ReactionColour(unit)
		end
	else
		if (UnitIsTapDenied(unit)) then
			color = conf.colour.reaction.tapped
		else
			color = XPerl_ReactionColour(unit)
		end
	end

	self:SetTextColor(color.r, color.g, color.b, conf.transparency.text)
end

-- XPerl_CombatFlashSet
function XPerl_CombatFlashSet(self, elapsed, argNew, argGreen)
	if (not conf.combatFlash) then
		self.PlayerFlash = nil
		return
	end

	if (self) then
		if (argNew) then
			self.PlayerFlash = 1.5
			self.PlayerFlashGreen = argGreen
		else
			if (elapsed and self.PlayerFlash) then
				self.PlayerFlash = self.PlayerFlash - elapsed

				if (self.PlayerFlash <= 0) then
					self.PlayerFlash = 0
					self.PlayerFlashGreen = nil
				end
			else
				return
			end
		end

		return true
	end
end

-- XPerl_CombatFlashSetFrames
function XPerl_CombatFlashSetFrames(self)
	if (self.PlayerFlash) then
		local baseColour = conf.colour.border

		local r, g, b, a
		if (self.PlayerFlash > 0) then
			local flashOffsetColour = min(self.PlayerFlash,1) / 2
			if (self.PlayerFlashGreen) then
				r = min(1, max(0, baseColour.r - flashOffsetColour))
				g = min(1, max(0, baseColour.g + flashOffsetColour))
			else
				r = min(1, max(0, baseColour.r + flashOffsetColour))
				g = min(1, max(0, baseColour.g - flashOffsetColour))
			end
			b = min(1, max(0, baseColour.b - flashOffsetColour))
			a = min(1, max(0, baseColour.a + flashOffsetColour))
		else
			r, g, b, a = baseColour.r, baseColour.g, baseColour.b, baseColour.a
			self.PlayerFlash = false
		end

		for i, frame in pairs(self.FlashFrames) do
			frame:SetBackdropBorderColor(r, g, b, a)
		end
	end
end

local normalEdge = "Interface\\Tooltips\\UI-Tooltip-Border"

-- BackdropTemplateMixin:SetBackdrop ignores the table a frame already holds, so each
-- edge/size/inset combination gets its own cached table instead of one shared mutated table
local bgDefs = {}
local function GetBgDef(edgeFile, edgeSize, edgeInsets)
	local bySize = bgDefs[edgeFile]
	if (not bySize) then
		bySize = {}
		bgDefs[edgeFile] = bySize
	end
	local byInsets = bySize[edgeSize]
	if (not byInsets) then
		byInsets = {}
		bySize[edgeSize] = byInsets
	end
	local bgDef = byInsets[edgeInsets]
	if (not bgDef) then
		bgDef = {bgFile = "Interface\\Addons\\XPerl\\Images\\XPerl_FrameBack",
			edgeFile = edgeFile,
			tile = true, tileEdge = true, tileSize = 32, edgeSize = edgeSize,
			insets = { left = edgeInsets, right = edgeInsets, top = edgeInsets, bottom = edgeInsets }
		}
		byInsets[edgeInsets] = bgDef
	end
	return bgDef
end

-- XPerl_ApplyFrameBackdrop(self)
-- Gives the frame's borders (self.FlashFrames) their backdrop (self.edgeFile/edgeSize/edgeInsets) and the configured
-- frame and border colours
function XPerl_ApplyFrameBackdrop(self)
	if (not self.FlashFrames) then
		return
	end
	local bgDef = GetBgDef(self.edgeFile or normalEdge, self.edgeSize or 16, self.edgeInsets or 5)
	local frame, border = conf.colour.frame, conf.colour.border
	for i, f in pairs(self.FlashFrames) do
		f:SetBackdrop(bgDef)
		f:SetBackdropColor(frame.r, frame.g, frame.b, frame.a)
		f:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
	end
end

--[[
local colourList = {}
for class,localClass in pairs(LOCALIZED_CLASS_NAMES_MALE) do
	colourList[localClass] = class
end
for class,localClass in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
	colourList[localClass] = class
end

-- XPerl_WhoList_Update
function XPerl_WhoList_Update()
	if (conf.colour.class and conf.colour.guildList) then
		local numWhos, totalCount = GetNumWhoResults()
		local whoOffset = FauxScrollFrame_GetOffset(WhoListScrollFrame)

		local myZone = GetRealZoneText()
		local myRace = UnitRace("player")
		local myGuild = GetGuildInfo("player")

		for i=1, WHOS_TO_DISPLAY, 1 do
			local name, guild, level, race, class, zone = GetWhoInfo(whoOffset + i)
			local color
			if (not name) then
				break
			end

			_G["WhoFrameButton"..i.."Name"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			if (conf.tooltip.xperlInfo and XPerl_GetUsage) then
				local u = XPerl_GetUsage(name)
				if (u) then
					_G["WhoFrameButton"..i.."Name"]:SetTextColor(1, 0.4, 0.4)
				end
			end

			if (conf.colour.class and conf.colour.guildList) then
				if (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 1) then
					-- Zone
					if (zone == myZone) then
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(0, 1, 0)
					else
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
					end
				elseif (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 2) then
					if (guild == myGuild) then
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(0, 1, 0)
					else
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
					end

				elseif (UIDropDownMenu_GetSelectedID(WhoFrameDropDown) == 3) then
					if (race == myRace) then
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(0, 1, 0)
					else
						_G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
					end
				end

				_G["WhoFrameButton"..i.."Class"]:SetTextColor(1, 1, 1)
				class = colourList[class]
				if (class) then
					local color = XPerl_GetClassColour(class)
					if (color) then
						_G["WhoFrameButton"..i.."Class"]:SetTextColor(color.r, color.g, color.b)
					end
				end

				local color = GetDifficultyColor(level)
				_G["WhoFrameButton"..i.."Level"]:SetTextColor(color.r, color.g, color.b)
			else
				_G["WhoFrameButton"..i.."Variable"]:SetTextColor(1, 1, 1)
				_G["WhoFrameButton"..i.."Level"]:SetTextColor(1, 1, 1)
				_G["WhoFrameButton"..i.."Class"]:SetTextColor(1, 1, 1)
			end
		end
	end
end

hooksecurefunc("WhoList_Update", XPerl_WhoList_Update)
]]

-- XPerl_RegisterClickCastFrame
function XPerl_RegisterClickCastFrame(self)
	if (not ClickCastFrames) then
		ClickCastFrames = {}
	end
	ClickCastFrames[self] = true
end

function XPerl_UnregisterClickCastFrame(self)
	if (ClickCastFrames) then
		ClickCastFrames[self] = nil
	end
end

-- unitmenuOnPostClick
local function unitmenuOnPostClick(self)
	if (UIDROPDOWNMENU_OPEN_MENU == self.dropdownMenu and DropDownList1:IsShown())   then
		local parent = self
		if (self:GetParent() and self:GetParent().nameFrame == self) then
			parent = self:GetParent()
		end

		local point, relativePoint
		if (parent:GetTop() * parent:GetEffectiveScale() > UIParent:GetHeight() * UIParent:GetEffectiveScale() / 2) then
			point, relativePoint = "TOPLEFT", "BOTTOMLEFT"
		else
			point, relativePoint = "BOTTOMLEFT", "TOPLEFT"
		end

		DropDownList1:ClearAllPoints()
		DropDownList1:SetPoint(point, parent, relativePoint, 0, 0)
	end
end

-- XPerl_SecureUnitButton_OnLoad
function XPerl_SecureUnitButton_OnLoad(self, unit, menufunc, m1, m2, toggledisabled)
	self:SetAttribute("*type1", "target")
	if (toggledisabled) then
		self:SetAttribute("type2", "menu")
	else
	    self:SetAttribute("type2", "togglemenu")
	end
	
	if (unit) then
		self:SetAttribute("unit", unit)
	end

	self.menu = menufunc
	self.dropdownMenu = m1
	self:SetAttribute("_menu", m2)
	self:SetScript("PostClick", unitmenuOnPostClick)

	XPerl_RegisterClickCastFrame(self)
end

------------------------------------------------------------------------------
-- Generic menus

-- XPerl_ShowGenericMenu
-- self, unit, button are passed from secure template handler (SecureTemplates.lua, line 288 in SecureActionButton_OnClick)
function XPerl_ShowGenericMenu(self, unit, button, actionType)
	if (not unit) then
		unit = SecureButton_GetUnit(self)
	end

	if (unit) then
		local menu
		local name

		-- Comparisons of compound tokens (targettarget...) can be secret on restricted maps; such a unit isn't
		-- treated as the player or pet then
		local isPlayer, isPet = UnitIsUnit(unit, "player"), UnitIsUnit(unit, "pet")
		if (not issecretvalue(isPlayer) and isPlayer) then
			menu = "SELF"
		elseif (not issecretvalue(isPet) and isPet) then
			menu = "PET"
		elseif ( UnitIsPlayer(unit) ) then
			if ( UnitInRaid(unit) ) then
				menu = "RAID_PLAYER"		-- "RAID" ?
			elseif ( UnitInParty(unit) ) then
				menu = "PARTY"
			else
				menu = "PLAYER"
			end
		else
			menu = "RAID_TARGET_ICON"
			name = RAID_TARGET_ICON
		end

		UnitPopup_OpenMenu(menu, {unit = unit, name = name})
	end
end

------------------------------------------------------------------------------
-- Aura rows
--
-- Unit frame buffs and debuffs are drawn by the client's custom aura containers (Blizzard_AuraContainer).
-- While aura restrictions are in force (combat, encounters, keystones, PvP matches) add-on code can't read
-- auras at all, but a container still shows them: X-Perl picks the filters, sizes and placement, and the
-- client fills in the icons.
--
-- Each unit frame gets a buff container and a debuff container on its buffFrame, each holding a group for
-- the player's own auras followed by one for everybody else's (or a single group, for raid frames). Icons
-- are built AURA_ICON pixels square and the container is scaled to the configured size; own auras can be
-- drawn double size. Once a container lays out auras its size is secret, so the only thing anchored to one
-- is the other container (both carry the "no untrusted layout scripts" aspect that makes this legal).
-- Add-on code can't touch the icons while auras are secret either, so restyling existing icons (double
-- size, cooldown swipe, countdown text) waits until they aren't.

local AURA_ICON = 32
local AURA_ICON_CROP = 0.078125
local StealAsset = {asset = "Interface\\Addons\\XPerl\\Images\\StealMe"}
-- Group keys per row, in display order. Buffs others cast are split by whether we can spellsteal them, so
-- those can sit with our own (and be drawn big with conf.buffs.bigStealable).
local AuraGroupKeys = {buffs = {"mine", "steal", "other"}, debuffs = {"mine", "other"}}
local AuraSingleGroupKeys = {buffs = {"all"}, debuffs = {"all"}}
local AuraGroupCandidates = {steal = {isStealable = true}, other = {isStealable = false}}

-- Debuffs left off aura rows: seasonal ones when conf.buffs.ignoreSeasonal is set, and on raid frames also
-- the lockout ones. Only spells the client never keeps secret can be filtered by ID on friendly units.
local SeasonalDebuffIDs = {
	[26004] = true,					-- Mistletoe
	[26680] = true,					-- Adored
	[26898] = true,					-- Heartbroken
	[64805] = true,					-- Bested Darnassus
	[64808] = true,					-- Bested the Exodar
	[64809] = true,					-- Bested Gnomeregan
	[64810] = true,					-- Bested Ironforge
	[64811] = true,					-- Bested Orgrimmar
	[64812] = true,					-- Bested Sen'jin
	[64813] = true,					-- Bested Silvermoon City
	[64814] = true,					-- Bested Stormwind
	[64815] = true,					-- Bested Thunder Bluff
	[64816] = true,					-- Bested the Undercity
	[36900] = true,					-- Soul Split: Evil!
	[36901] = true,					-- Soul Split: Good
	[36899] = true,					-- Transporter Malfunction
	[24755] = true,					-- Tricked or Treated
	[69127] = true,					-- Chill of the Throne
	[69438] = true,					-- Sample Satisfaction
}
local RaidIgnoredDebuffIDs = {
	[26013] = true,					-- Deserter
	[71041] = true,					-- Dungeon Deserter
	[71328] = true,					-- Dungeon Cooldown
}
local SeasonalAndRaidDebuffIDs = {}
for id in pairs(SeasonalDebuffIDs) do SeasonalAndRaidDebuffIDs[id] = true end
for id in pairs(RaidIgnoredDebuffIDs) do SeasonalAndRaidDebuffIDs[id] = true end

-- AuraCountdownCurve
-- Countdown text only shows for the last conf.buffs.countdownStart seconds: its colour comes from a step
-- curve over the remaining time that turns transparent above that.
local auraCountdownCurve, auraCountdownStart
local function AuraCountdownCurve()
	local start = tonumber(conf.buffs.countdownStart) or 20
	if (not auraCountdownCurve) then
		auraCountdownCurve = C_CurveUtil.CreateColorCurve()
		auraCountdownCurve:SetType(Enum.LuaCurveType.Step)
	end
	if (start ~= auraCountdownStart) then
		auraCountdownStart = start
		auraCountdownCurve:ClearPoints()
		auraCountdownCurve:AddPoint(0, CreateColor(1, 1, 0, 1))
		auraCountdownCurve:AddPoint(start, CreateColor(1, 1, 0, 0))
	end
	return auraCountdownCurve
end

-- AuraButton_Style
local function AuraButton_Style(button, style)
	button:SetSize(style.size, style.size)
	button.CooldownHolder:SetAlpha(style.cooldown and 1 or 0)
	if (style.countdown) then
		button:SetDurationText(button.CountdownHolder.Countdown, {textColor = {curve = AuraCountdownCurve(), property = Enum.DurationTextBindingProperty.RemainingDuration}})
		button.CountdownHolder:SetAlpha(1)
	else
		button:ClearDurationText()
		button.CountdownHolder:SetAlpha(0)
	end
	-- Icons made before the settings are loaded get this from the first XPerl_Auras_Configure
	if (conf) then
		button:SetHideTooltipInCombat(conf.tooltip.buffHideInCombat and true or false)
	end
end

-- AuraButton_Init
-- Runs once per icon as the container creates it, before the client locks the icon away from add-on code
local function AuraButton_Init(button, kind, style, setup)
	local textLevel = button.CooldownHolder.Cooldown:GetFrameLevel() + 1
	button.TextHolder:SetFrameLevel(textLevel)
	button.CountdownHolder:SetFrameLevel(textLevel)

	button:SetIcon(button.Icon)
	button:SetApplicationCount(button.TextHolder.Count)
	button:SetDurationCooldown(button.CooldownHolder.Cooldown)

	if (kind == "debuffs") then
		button:AddDispelTypeTexture(button.Border, {
			showWhenHarmful = true,
			showWithoutDispelType = true,
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
		})
	else
		button:AddDispelTypeTexture(button.Steal, {
			showWhenHarmful = false,
			showWhenHelpful = true,
			showWithoutDispelType = true,
			stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
			customDispelAssetMap = {Magic = StealAsset, None = StealAsset},
		})
		if (setup.cancel) then
			button:SetCancelAuraButtons("RightButtonUp")
		end
	end

	if (setup.crop) then
		button.Icon:SetTexCoord(AURA_ICON_CROP, 1 - AURA_ICON_CROP, AURA_ICON_CROP, 1 - AURA_ICON_CROP)
	end
	button:SetTooltipAnchorPoint(setup.tooltipAnchor or "ANCHOR_BOTTOMRIGHT")

	AuraButton_Style(button, style)
end

-- Auras_CreateContainer
local function Auras_CreateContainer(self, kind, setup)
	local container = CreateFrame("AuraContainer", nil, self.buffFrame, "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
	local styles = {}
	for i, key in ipairs((setup.single and AuraSingleGroupKeys or AuraGroupKeys)[kind]) do
		local style = {size = AURA_ICON}
		styles[key] = style
		container:AddAuraGroup(key, (kind == "buffs") and "HELPFUL" or "HARMFUL", {
			templateNames = {"XPerl_AuraButtonTemplate"},
			initializeFrame = function(button) AuraButton_Init(button, kind, style, setup) end,
			candidateFilters = (kind == "buffs") and AuraGroupCandidates[key] or nil,
			layout = {elementSpacing = (kind == "debuffs") and 2 or 1, lineSpacing = 1, layoutIndex = i},
		})
	end
	return container, styles
end

-- Auras_RestyleNow
local function Auras_RestyleNow(self)
	local auras = self.auras
	for _, kind in ipairs({"buffs", "debuffs"}) do
		local container = auras[kind]
		for key, style in pairs(auras.style[kind]) do
			for i = 1, container:GetAuraGroupFrameCount(key) do
				AuraButton_Style(container:GetAuraGroupFrame(key, i), style)
			end
		end
	end
	for _, button in ipairs(auras.enchants) do
		AuraButton_Style(button, auras.style.buffs.mine)
	end
end

-- Auras_Restyle
-- Icons are off limits to add-on code while auras are secret, so a restyle then waits until they aren't
local auraRestyleQueue, auraRestyleWatcher = {}
local function Auras_Restyle(self)
	if (not C_Secrets.ShouldAurasBeSecret()) then
		auraRestyleQueue[self] = nil
		Auras_RestyleNow(self)
		return
	end

	auraRestyleQueue[self] = true
	if (not auraRestyleWatcher) then
		auraRestyleWatcher = CreateFrame("Frame")
		auraRestyleWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		auraRestyleWatcher:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
		auraRestyleWatcher:SetScript("OnEvent", function()
			if (not C_Secrets.ShouldAurasBeSecret()) then
				for frame in pairs(auraRestyleQueue) do
					auraRestyleQueue[frame] = nil
					Auras_RestyleNow(frame)
				end
			end
		end)
	end
end

-- Auras_On
-- Old option values are 1/0 numbers (0 being "off") as well as booleans
local function Auras_On(value)
	return value == 1 or value == true
end

-- Auras_ConfigureRow
local function Auras_ConfigureRow(self, kind)
	local auras = self.auras
	local opts = auras.opts
	local row = opts[kind]
	local container = auras[kind]

	local enabled = (row and row.enable) and true or false
	container:SetEnabled(enabled)
	if (not enabled) then
		return
	end

	local scale = (tonumber(row.size) or 20) / AURA_ICON
	container:SetScale(scale)

	local Dir = AnchorUtil.FlowDirection
	container:SetFlowLayoutAxis(opts.vertical and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal)
	container:SetFlowLayoutAnchorPoint((opts.above and "BOTTOM" or "TOP")..(opts.flip and "RIGHT" or "LEFT"))
	container:SetFlowLayoutGrowthDirection(opts.flip and Dir.Left or Dir.Right, opts.above and Dir.Up or Dir.Down)

	-- Line length is in the container's own (scaled) units
	local lineWidth = row.lineWidth
	if (lineWidth == nil) then
		lineWidth = opts.lineWidth
	end
	local lineSize = lineWidth and (lineWidth / scale) or nil
	container:SetFlowLayoutMaximumLineSize(lineSize)

	local maxCount = row.max or math.huge
	if (not row.max and lineSize and row.rows) then
		local spacing = (kind == "debuffs") and 2 or 1
		maxCount = max(1, floor((lineSize + spacing) / (AURA_ICON + spacing))) * row.rows
	end
	auras.maxCount[kind] = maxCount

	for key, style in pairs(auras.style[kind]) do
		local mine = key == "mine" or key == "all"
		local big = (key == "mine" and row.big) or (key == "steal" and row.bigStealable)
		style.size = big and (AURA_ICON * 2) or AURA_ICON
		style.cooldown = opts.cooldown and (mine or opts.cooldownAny) and true or false
		style.countdown = opts.countdown and (mine or opts.countdownAny) and true or false
	end
end

-- Auras_ApplyFilters
-- Filters and limits that depend on whether the unit is hostile
local function Auras_ApplyFilters(self)
	local auras = self.auras
	local opts = auras.opts
	local hostile = auras.hostile

	for _, kind in ipairs({"buffs", "debuffs"}) do
		local row = opts[kind]
		if (row and row.enable) then
			local container = auras[kind]
			local base, raid, onlyMine
			if (kind == "buffs") then
				-- Castable-only applies to any unit, own-only to friendly ones (we're not likely to buff enemies)
				base, raid, onlyMine = "HELPFUL", Auras_On(row.castable), row.onlyMine and not hostile
			else
				-- Curable-only applies to friendly units, own-only to hostile ones
				base, raid, onlyMine = "HARMFUL", Auras_On(row.curable) and not hostile, row.onlyMine and hostile
			end
			local suffix = raid and "|RAID" or ""
			local maxCount = auras.maxCount[kind]

			local exclude
			if (kind == "debuffs") then
				if (auras.setup.raid) then
					exclude = conf.buffs.ignoreSeasonal and SeasonalAndRaidDebuffIDs or RaidIgnoredDebuffIDs
				elseif (conf.buffs.ignoreSeasonal) then
					exclude = SeasonalDebuffIDs
				end
			end

			for key in pairs(auras.style[kind]) do
				if (key == "all") then
					container:SetAuraGroupFilterString(key, base..suffix)
					container:SetAuraGroupMaxFrameCount(key, maxCount)
				elseif (key == "mine") then
					container:SetAuraGroupFilterString(key, base.."|PLAYER"..suffix)
					container:SetAuraGroupMaxFrameCount(key, maxCount)
				elseif (key == "steal") then
					container:SetAuraGroupFilterString(key, base.."|!PLAYER"..suffix)
					container:SetAuraGroupMaxFrameCount(key, maxCount)
				else
					container:SetAuraGroupFilterString(key, base.."|!PLAYER"..suffix)
					container:SetAuraGroupMaxFrameCount(key, onlyMine and 0 or maxCount)
				end

				if (auras.exclude[container] ~= exclude) then
					container:SetAuraGroupCandidateFilters(key, exclude and {excludeSpellIDs = exclude} or nil)
				end
			end
			auras.exclude[container] = exclude
		end
	end
end

-- XPerl_Auras_Arrange
-- Places the rows. The first sits in the corner of self.buffFrame the rows grow away from, the second
-- follows it (below/above, or alongside with opts.across), unless opts.placeDebuffs puts the debuff
-- row somewhere of its own.
function XPerl_Auras_Arrange(self)
	local auras = self.auras
	local opts = auras and auras.opts
	if (not opts) then
		return
	end

	local h = opts.flip and "RIGHT" or "LEFT"
	local v = opts.above and "BOTTOM" or "TOP"
	local point = v..h

	local first, second = auras.buffs, auras.debuffs
	if (not opts.placeDebuffs and (opts.order == "debuffs" or (opts.order == "reaction" and auras.hostile))) then
		first, second = second, first
	end

	-- A disabled row is empty and so has no size; the other row just takes its place
	first:ClearAllPoints()
	first:SetPoint(point, self.buffFrame, point, 0, 0)
	second:ClearAllPoints()
	if (opts.placeDebuffs) then
		opts.placeDebuffs(self, second, point)
	elseif (opts.across) then
		second:SetPoint(point, first, v..(opts.flip and "LEFT" or "RIGHT"), opts.flip and -1 or 1, 0)
	else
		second:SetPoint(point, first, (opts.above and "TOP" or "BOTTOM")..h, 0, opts.above and 2 or -2)
	end
end

-- XPerl_Auras_Init(self, setup)
-- Creates the buff and debuff containers on self.buffFrame. setup (all optional):
--	single		one group per row instead of own auras + everybody else's (raid frames)
--	raid		raid frame rules (lockout debuffs left out)
--	crop		trim the icon edges
--	cancel		right-clicking an own buff cancels it (player frame)
--	enchants	temporary weapon enchants lead the buff row (player frame)
--	tooltipAnchor	GameTooltip anchor for the icons (default ANCHOR_BOTTOMRIGHT)
function XPerl_Auras_Init(self, setup)
	setup = setup or {}
	local auras = {setup = setup, style = {}, maxCount = {}, exclude = {}, enchants = {}, hostile = false}
	self.auras = auras
	auras.buffs, auras.style.buffs = Auras_CreateContainer(self, "buffs", setup)
	auras.debuffs, auras.style.debuffs = Auras_CreateContainer(self, "debuffs", setup)

	if (setup.enchants) then
		local style = auras.style.buffs.mine
		for _, slot in ipairs({AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand}) do
			tinsert(auras.enchants, auras.buffs:AddItemEnchantment(slot, {
				templateNames = {"XPerl_AuraButtonTemplate"},
				initializeFrame = function(button) AuraButton_Init(button, "buffs", style, setup) end,
			}))
		end
	end
end

-- XPerl_Auras_Configure(self, opts)
-- (Re)applies the aura row settings:
--	buffs, debuffs	row settings, usually the frame's conf.buffs/conf.debuffs: enable, size, big (own auras
--			double size), bigStealable (buffs we can spellsteal double size), rows (with lineWidth),
--			max (icon limit per group), lineWidth (this row's wrap width, false for none; overrides
--			opts.lineWidth), and castable (buffs), curable (debuffs), onlyMine
--	cooldown, cooldownAny, countdown, countdownAny	swipe/countdown on own auras, or on all of them
--	lineWidth	wrap width in the unit frame's pixels (nil: one line)
--	above, flip	rows grow upwards / right to left
--	vertical	icons stack in columns (lineWidth is the column height then)
--	order		"buffs" (default) or "debuffs" row first, or "reaction" (debuffs first on hostile units)
--	across		the second row continues beside the first instead of below/above it
--	placeDebuffs	function(self, debuffContainer, point) placing the debuff row on its own
function XPerl_Auras_Configure(self, opts)
	local auras = self.auras
	auras.opts = opts
	Auras_ConfigureRow(self, "buffs")
	Auras_ConfigureRow(self, "debuffs")
	Auras_ApplyFilters(self)
	XPerl_Auras_Arrange(self)
	Auras_Restyle(self)

	local shown = (opts.buffs and opts.buffs.enable) or (opts.debuffs and opts.debuffs.enable)
	self.buffFrame:SetShown(shown and true or false)
end

-- XPerl_Auras_UnitOptions(self, layout)
-- XPerl_Auras_Configure options for a regular unit frame: the rows come from self.conf and the shared
-- cooldown/countdown settings from conf.buffs; layout adds the frame's placement fields.
function XPerl_Auras_UnitOptions(self, layout)
	local opts = layout or {}
	opts.buffs = self.conf.buffs
	opts.debuffs = self.conf.debuffs
	opts.cooldown = conf.buffs.cooldown
	opts.cooldownAny = conf.buffs.cooldownAny
	opts.countdown = conf.buffs.countdown
	opts.countdownAny = conf.buffs.countdownAny
	return opts
end

-- XPerl_Auras_SetUnit(self, unit)
-- Points the rows at a unit (nil for none) and refreshes them. Call it whenever the unit behind the frame
-- may have changed, even if the token is the same (target changes, roster changes): containers only follow
-- UNIT_AURA by themselves.
function XPerl_Auras_SetUnit(self, unit)
	local auras = self.auras
	if (not auras) then
		return
	end

	unit = unit or "none"
	local hostile = UnitCanAttack("player", unit) and true or false
	if (hostile ~= auras.hostile) then
		auras.hostile = hostile
		if (auras.opts) then
			Auras_ApplyFilters(self)
			XPerl_Auras_Arrange(self)
		end
	end

	auras.buffs:SetUnit(unit)
	auras.debuffs:SetUnit(unit)
	auras.buffs:UpdateAllAuras()
	auras.debuffs:UpdateAllAuras()
end

------------------------------------------------------------------------------
-- Flashing frames handler. Is hidden when there's nothing to do.
local FlashFrame = CreateFrame("Frame", "XPerl_FlashFrame")
FlashFrame.list = {}

-- XPerl_FrameFlash_OnUpdate(self, elapsed)
function XPerl_FrameFlash_OnUpdate(self, elapsed)
	for k,v in pairs(self.list) do
		if (k.frameFlash.out) then
			k.frameFlash.alpha = k.frameFlash.alpha - elapsed
			if (k.frameFlash.alpha < 0.2) then
				k.frameFlash.alpha = 0.2
				k.frameFlash.out = nil

				if (k.frameFlash.method == "out") then
					XPerl_FrameFlashStop(k)
				end
			end
		else
			k.frameFlash.alpha = k.frameFlash.alpha + elapsed
			if (k.frameFlash.alpha > 1) then
				k.frameFlash.alpha = 1
				k.frameFlash.out = true

				if (k.frameFlash.method == "in") then
					XPerl_FrameFlashStop(k)
				end
			end
		end

		if (k.frameFlash) then
			k:SetAlpha(k.frameFlash.alpha)
		end
	end
end

FlashFrame:SetScript("OnUpdate", XPerl_FrameFlash_OnUpdate)

-- XPerl_FrameFlash
function XPerl_FrameFlash(self)
	if (not FlashFrame.list[self]) then
		if (self.frameFlash) then
			error("X-Perl ["..self:GetName()..".frameFlash is set with no entry in FlashFrame.list]")
		end

		self.frameFlash = XPerl_GetReusableTable()
		self.frameFlash.out = true
		self.frameFlash.alpha = 1
		self.frameFlash.shown = self:IsShown()
		--self.frameFlash = {out = true, alpha = 1, shown = self:IsShown()}

		FlashFrame.list[self] = true
		FlashFrame:Show()
		self:Show()
	end
end

-- XPerl_FrameIsFlashing(self)
function XPerl_FrameIsFlashing(self)
	return self.frameFlash		--FlashFrame.list[self]
end

-- XPerl_FrameFlashStop
function XPerl_FrameFlashStop(self, method)
	if (not self.frameFlash) then
		return
	end

	if (method) then
		self.frameFlash.method = method
		return
	end

	if (not self.frameFlash.shown) then
		self:Hide()
	end

	XPerl_FreeTable(self.frameFlash)
	self.frameFlash = nil

	self:SetAlpha(1)

	FlashFrame.list[self] = nil

	if (not next(FlashFrame.list)) then
		FlashFrame:Hide()
	end
end

-- XPerl_ProtectedCall
function XPerl_ProtectedCall(func, self)
	if (func) then
		if (InCombatLockdown()) then
			XPerl_OutOfCombatQueue[func] = self == nil and false or self
			--if (self) then
			--	tinsert(XPerl_OutOfCombatQueue, {func, self})
			--else
			--	tinsert(XPerl_OutOfCombatQueue, func)
			--end
		else
			func(self)
		end
	end
end

-- XPerl_Unit_UpdatePortrait()
function XPerl_Unit_UpdatePortrait(self)

	
	if (self.conf and self.conf.portrait) then
		SetPortraitTexture(self.portraitFrame.portrait, self.partyid)			-- If a player moves out of range for a 3D portrait, it will show their proper 2D one
		if (self.conf.portrait3D and UnitIsVisible(self.partyid)) then
			self.portraitFrame.portrait:Hide()
			self.portraitFrame.portrait3D:Show()
			self.portraitFrame.portrait3D:ClearModel()
			self.portraitFrame.portrait3D:SetUnit(self.partyid)
			self.portraitFrame.portrait3D:SetPortraitZoom(1)
		else
			self.portraitFrame.portrait:Show()
			self.portraitFrame.portrait3D:Hide()
		end
	end	
	
end

-- XPerl_Unit_UpdateLevel
function XPerl_Unit_UpdateLevel(self)
	local level = UnitLevel(self.partyid)
	local color = GetDifficultyColor(level)
	if (self.levelFrame) then
		self.levelFrame.text:SetTextColor(color.r,color.g,color.b)
		self.levelFrame.text:SetText(level)
	elseif (self.nameFrame.level) then
		if (level == 0) then
			level = ""
		end
		self.nameFrame.level:SetTextColor(color.r,color.g,color.b)
		self.nameFrame.level:SetText(level)
	end
end

-- XPerl_Unit_GetHealth
--This function sucks, it needs reworking so it self corrects /0 problems here. But i haven't quite figured out how to approach it here yet. So i just fix stuff at sethealth functions.
function XPerl_Unit_GetHealth(self)
	local partyid = self.partyid
	local hp, hpMax = UnitHealth(partyid), UnitHealthMax(partyid)

	-- Restricted (secret) health can't be compared or clamped, so it's passed on as it is
	if (issecretvalue(hp) or issecretvalue(hpMax)) then
		return hp, hpMax, false
	end

	if (hp > hpMax) then
		if (UnitIsDeadOrGhost(partyid)) then
			hp = 0
		else
			hp = hpMax
		end
	end

	return hp or 0, hpMax or 1, (hpMax == 100)
end

-- XPerl_Unit_OnEnter
function XPerl_Unit_OnEnter(self)
	XPerl_PlayerTip(self)
	if (self.highlight) then
		self.highlight:Select()
	end

	if (self.statsFrame and self.statsFrame.healthBar and self.statsFrame.healthBar.text and not self.statsFrame.healthBar.text:IsShown()) then
		self.hideValues = true
		self.statsFrame.healthBar.text:Show()
		if (self.statsFrame.manaBar) then
			self.statsFrame.manaBar.text:Show()
		end
		if (self.statsFrame.xpBar and self.statsFrame.xpBar:IsShown()) then
			self.statsFrame.xpBar.text:Show()
		end
		if (self.statsFrame.repBar and self.statsFrame.repBar:IsShown()) then
			self.statsFrame.repBar.text:Show()
		end
	end
end

-- XPerl_Unit_OnLeave
function XPerl_Unit_OnLeave(self)
	XPerl_PlayerTipHide()
	if (self.highlight) then
		self.highlight:Deselect()
	end

	if (self.hideValues) then
		self.hideValues = nil

		self.statsFrame.healthBar.text:Hide()
		if (self.statsFrame.manaBar) then
			self.statsFrame.manaBar.text:Hide()
		end
		if (self.statsFrame.xpBar and self.statsFrame.xpBar:IsShown()) then
			self.statsFrame.xpBar.text:Hide()
		end
		if (self.statsFrame.repBar and self.statsFrame.repBar:IsShown()) then
			self.statsFrame.repBar.text:Hide()
		end
	end
end

-- XPerl_Unit_UpdateReadyState
function XPerl_Unit_UpdateReadyState(self)
	local status = conf.showReadyCheck and self.partyid and GetReadyCheckStatus(self.partyid)
	if (status) then
		self.statsFrame.ready:Show()
		if (status == "ready") then
			self.statsFrame.ready.check:SetTexture(READY_CHECK_READY_TEXTURE)
		elseif (status == "waiting") then
			self.statsFrame.ready.check:SetTexture(READY_CHECK_WAITING_TEXTURE)
		else -- "notready"
			self.statsFrame.ready.check:SetTexture(READY_CHECK_NOT_READY_TEXTURE)
		end
	else
		self.statsFrame.ready:Hide()
	end
end

-- XPerl_SwitchAnchor(self, new)
-- Re-anchors a frame that has one anchor between the same corners (e.g. TOPLEFT to TOPLEFT) to another corner
-- of the same region, without moving it
function XPerl_SwitchAnchor(self, new)
	if (self:GetNumPoints() ~= 1) then
		return
	end
	local point, relativeTo, relativePoint = self:GetPoint(1)
	if (point ~= relativePoint or point == new) then
		return
	end
	relativeTo = relativeTo or self:GetParent()

	local left, bottom, width, height = self:GetRect()
	local rLeft, rBottom, rWidth, rHeight = relativeTo:GetRect()
	if (not (left and rLeft)) then
		return
	end
	-- The other region's rectangle in this frame's units
	local ratio = relativeTo:GetEffectiveScale() / self:GetEffectiveScale()
	rLeft, rBottom, rWidth, rHeight = rLeft * ratio, rBottom * ratio, rWidth * ratio, rHeight * ratio

	local h = strmatch(new, "LEFT") or strmatch(new, "RIGHT")
	local v = strmatch(new, "TOP") or strmatch(new, "BOTTOM")
	local x, y
	if (h == "LEFT") then
		x = left - rLeft
	elseif (h == "RIGHT") then
		x = (left + width) - (rLeft + rWidth)
	else
		x = (left + width / 2) - (rLeft + rWidth / 2)
	end
	if (v == "BOTTOM") then
		y = bottom - rBottom
	elseif (v == "TOP") then
		y = (bottom + height) - (rBottom + rHeight)
	else
		y = (bottom + height / 2) - (rBottom + rHeight / 2)
	end

	self:ClearAllPoints()
	self:SetPoint(new, relativeTo, new, x, y)
end

---------------------------------
-- Scaling frame corner thingy --
---------------------------------
-- Seems a convoluted way of doing things, rather than just anchoring bottomleft, topright.. but
-- doing that introduces a really ugly latency between the anchor moving and the frame scaling because
-- the OnSizeChanged event is fired on the frame after the actual resize took place.

local scaleIndication

local function scaleMouseDown(self)

	GameTooltip:Hide()

	if (self.resizable and IsShiftKeyDown()) then
		self.sizing = true
	elseif (self.scalable) then
		self.scaling = true
	end

	if (not scaleIndication) then
		scaleIndication = CreateFrame("Frame", nil, UIParent)
		scaleIndication:SetWidth(100)
		scaleIndication:SetHeight(18)
		scaleIndication.text = scaleIndication:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		scaleIndication.text:SetAllPoints()
		scaleIndication.text:SetJustifyH("LEFT")
	end

	scaleIndication:Show()
	scaleIndication:ClearAllPoints()
	scaleIndication:SetPoint("LEFT", self, "RIGHT", 4, 0)

	if (self.scaling) then
		scaleIndication.text:SetFormattedText("%.1f%%", self.frame:GetScale() * 100)
	else
		scaleIndication.text:SetFormattedText("%dx%d", self.frame:GetWidth(), self.frame:GetHeight())
	end

	self.anchor:StartSizing(self.resizeTop and "TOPRIGHT")

	self.oldBdBorder = {self.frame:GetBackdropBorderColor()}
	self.frame:SetBackdropBorderColor(1, 1, 0.5, 1)
end

local function scaleMouseUp(self)
	self.anchor:StopMovingOrSizing()

	scaleIndication:Hide()

	if (self.resizeTop) then
		XPerl_SwitchAnchor(self.anchor, "BOTTOMLEFT")
	end

	if (self.scaling) then
		if (self.onScaleChanged) then
			self:onScaleChanged(self.frame:GetScale())
		elseif (self.onSizeChanged) then
			self:onSizeChanged(self.frame:GetWidth(), self.frame:GetHeight())
		end
	end

	if (self.oldBdBorder) then
		self.frame:SetBackdropBorderColor(unpack(self.oldBdBorder))
		self.oldBdBorder = nil
	end

	self.scaling = nil
	self.sizing = nil
end

local function scaleMouseChange(self)
	if (self.corner.sizing) then
		self.corner.frame:SetWidth(self:GetWidth() / self.corner.frame:GetScale())
		self.corner.frame:SetHeight(self:GetHeight() / self.corner.frame:GetScale())

		self.corner.startSize.w = self.corner.frame:GetWidth()
		self.corner.startSize.h = self.corner.frame:GetHeight()

		if (scaleIndication and scaleIndication:IsShown()) then
			scaleIndication.text:SetFormattedText("|c00FFFF80%d|c00808080x|c00FFFF80%d", self.corner.frame:GetWidth(), self.corner.frame:GetHeight())
		end

	elseif (self.corner.scaling) then
		local w = self:GetWidth()
		if (w) then
			self.corner.scaling = nil
			local ratio = self.corner.frame:GetWidth() / self.corner.frame:GetHeight()
			local s = min(self.corner.maxScale, max(self.corner.minScale, w / self.corner.startSize.w))	-- New Scale

			w = self.corner.startSize.w * s		-- Set height and width of anchor window to match ratio of actual
			if (self.corner.resizeTop) then
				XPerl_SwitchAnchor(self, "BOTTOMLEFT")
				local bottom, left = self:GetBottom(), self:GetLeft()
				self:SetWidth(w)
				self:SetHeight(w / ratio)
			else
				self:SetWidth(w)
				self:SetHeight(w / ratio)
			end

			if (scaleIndication and scaleIndication:IsShown()) then
				scaleIndication.text:SetFormattedText("%.1f%%", s * 100)
			end

			self.corner.frame:SetScale(s)
			self.corner.scaling = true
		end
	end
end

-- scaleMouseEnter
local function scaleMouseEnter(self)
	self.tex:SetVertexColor(1, 1, 1, 1)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if (self.scalable) then
		GameTooltip:SetText(XPERL_DRAGHINT1, nil, nil, nil, nil, true)
	end
	if (self.resizable) then
		GameTooltip:AddLine(XPERL_DRAGHINT2, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

-- scaleMouseLeave
local function scaleMouseLeave(self)
	self.tex:SetVertexColor(1, 1, 1, 0.5)
	GameTooltip:Hide()
end

-- XPerl_RegisterScalableFrame
function XPerl_RegisterScalableFrame(self, anchorFrame, minScale, maxScale, resizeTop, resizable, scalable)
	if (scalable == nil) then
		scalable = true
	end

	if (not self.corner) then
		self.corner = CreateFrame("Frame", nil, self)
		self.corner:SetFrameLevel(self:GetFrameLevel() + 3)
		self.corner:EnableMouse(true)
		self.corner:SetScript("OnMouseDown", scaleMouseDown)
		self.corner:SetScript("OnMouseUp", scaleMouseUp)
		self.corner:SetScript("OnEnter", scaleMouseEnter)
		self.corner:SetScript("OnLeave", scaleMouseLeave)
		self.corner:SetHeight(12)
		self.corner:SetWidth(12)

		anchorFrame:SetScript("OnSizeChanged", scaleMouseChange)
		anchorFrame.corner = self.corner

		self.corner.tex = self.corner:CreateTexture(nil, "BORDER")
		self.corner.tex:SetTexture("Interface\\Addons\\XPerl\\images\\XPerl_Elements")
		self.corner.tex:SetAllPoints()
		self.corner.tex:SetVertexColor(1, 1, 1, 0.5)

		self.corner.anchor = anchorFrame
		self.corner.frame = self
	end

	self:SetResizeBounds(10, 10)

	self.corner.scalable = scalable
	self.corner.resizable = resizable
	self.corner.resizeTop = resizeTop
	self.corner.minScale = minScale or 0.4
	self.corner.maxScale = maxScale or 5
	self.corner.startSize = {w = self:GetWidth(), h = self:GetHeight()}

	local bgDef = self:GetBackdrop()

	self.corner:ClearAllPoints()
	if (resizeTop) then
		self.corner.tex:SetTexCoord(0.78125, 1, 0.5, 0.703125)
		self.corner:SetPoint("TOPRIGHT", -bgDef.insets.right, -bgDef.insets.top)
		self.corner:SetHitRectInsets(0, -6, -6, 0)		-- So the click area extends over the tooltip border
	else
		self.corner.tex:SetTexCoord(0.78125, 1, 0.78125, 1)
		self.corner:SetPoint("BOTTOMRIGHT", -bgDef.insets.right, bgDef.insets.bottom)
		self.corner:SetHitRectInsets(0, -6, 0, -6)		-- So the click area extends over the tooltip border
	end

	self.corner.scaling = true
	scaleMouseChange(anchorFrame)
	self.corner.scaling = nil
end

-- Threat Display
local function DrawHand(self, percent)
	local angle = 360 - (percent * 2.7 - 135)
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = rotate(angle)
	self.needle:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

local function DrawSlider(self, percent)
	local offset = (self:GetWidth() - 9) / 100 * percent
	self.needle:ClearAllPoints()
	self.needle:SetPoint("CENTER", self, "TOPLEFT", offset + 5, -2)

	local r, g, b
	if (percent <= 70) then
		r, g, b = 0, 1, 0
	else
		r, g, b = smoothColor(abs((percent - 100) / 30))
	end

	self.needle:SetVertexColor(r, g, b)
end

-- XPerl_ThreatDisplayOnLoad
function XPerl_ThreatDisplayOnLoad(self, mode)
	XPerl_SetChildMembers(self)
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 4)
	self.text:SetWidth(100)
	self.current, self.target = 0, 0
	self.mode = mode

	if (mode == "nameFrame") then
		self.Draw = DrawSlider
	else
		self.Draw = DrawHand
	end
	self:Draw(0)
end

-- threatOnUpdate
local function threatOnUpdate(self, elapsed)
	local diff = (self.target - self.current) * 0.2
	self.current = min(100, max(0, self.current + diff))
	if (abs(self.current - self.target) <= 0.01) then
		self.current = self.target
		self:SetScript("OnUpdate", nil)
	end

	self:Draw(self.current)
end

-- XPerl_Unit_ThreatStatus
function XPerl_Unit_ThreatStatus(self, relative, immediate)
	if (not self.partyid or not self.conf) then
		return
	end

	local mode = self.conf.threatMode or (self.conf.portrait and "portraitFrame" or "nameFrame")
	local t = self.threatFrames and self.threatFrames[mode]
	if (not self.conf.threat) then
		if (t) then
			t:Hide()
		end
		return
	end

	if (not t) then
		if (self.threatFrames) then
			for mode,frame in pairs(self.threatFrames) do
				frame:SetScript("OnUpdate", nil)
				frame.current, frame.target = 0, 0
				frame:Hide()
			end
		else
			self.threatFrames = {}
		end
		if (self[mode]) then		-- If desired parent frame exists
			t = CreateFrame("Frame", self:GetName().."Threat"..mode, self[mode], "XPerl_ThreatTemplate"..mode)
			t:SetAllPoints()
			self.threatFrames[mode] = t
		end

		self.threat = self.threatFrames[mode]
	end

	if (t) then
		local isTanking, state, scaledPercent, rawPercent, threatValue
		local one, two
		if (UnitAffectingCombat(self.partyid) or (relative and UnitAffectingCombat(relative))) then
			if (relative and UnitCanAttack(relative, self.partyid)) then
				one, two = relative, self.partyid
			else
				if (UnitExists("target") and UnitCanAttack(self.partyid, "target")) then
					one, two = self.partyid, "target"
				elseif (UnitCanAttack("player", self.partyid)) then
					one, two = "player", self.partyid
				elseif (UnitCanAttack(self.partyid, self.partyid.."target")) then
					one, two = self.partyid, self.partyid.."target"
				end
			end

			if (one) then
				-- scaledPercent is 0% - 100%, 100 means you pull agro
				-- rawPercent is before normalization so can go up to 110% or 130% before you pull agro
				isTanking, state, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(one, two)
			end
		end

		-- Restricted (secret) threat can't be compared or drawn, so the gauge hides then
		if (scaledPercent and not issecretvalue(scaledPercent)) then
			if (scaledPercent ~= t.target) then
				t.target = scaledPercent
				if (immediate) then
					t.current = scaledPercent
				end
				t.one = one
				t.two = two
				t:SetScript("OnUpdate", threatOnUpdate)
			end

			t.text:SetFormattedText("%d%%", scaledPercent)
			local r, g, b = smoothColor(1 - scaledPercent / 100)		-- green, turning red as you near pulling aggro
			t.text:SetTextColor(r, g, b)

			t:Show()
			return
		end

		t:Hide()
	end
end
