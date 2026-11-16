-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Player frame (XPerl_Player): vehicle swap, experience / reputation / druid mana bars, class power
-- (death knight runes, Blizzard's class resource bar for the other classes, totems), PvP timer, raid group
-- number, the full screen out of control flash, and the player's buffs (which replace Blizzard's BuffFrame and
-- DebuffFrame).
-- Everything else comes from Units/UnitFrame.lua, the targeting counter from Units/TargetCounters.lua.

local UF = XPerl_UnitFrameMixin
local conf, pconf
XPerl_RequestConfig(function(new) conf = new pconf = new.player end, "$Revision$")

local playerClass = select(2, UnitClass("player"))
local isOutOfControl
local perc1F = "%.1f"..PERCENT_SYMBOL
local percD = "%.0f"..PERCENT_SYMBOL

-- Blizzard's class resource bar per class (Retail), shown as the special bar, and its name as the undocked bar's
-- Edit Mode label. Death knights get X-Perl's own runes instead; combo points show on the target frame.
local CLASS_BARS = {
	WARLOCK	= {frame = "WarlockPowerFrame", label = SOUL_SHARDS_POWER},
	PALADIN	= {frame = "PaladinPowerBarFrame", label = HOLY_POWER},
	MONK	= {frame = "MonkHarmonyBarFrame", label = CHI_POWER},
	MAGE	= {frame = "MageArcaneChargesFrame", label = ARCANE_CHARGES},
	EVOKER	= {frame = "EssencePlayerFrame", label = POWER_TYPE_ESSENCE},
}
local classBarInfo = not XPerlAPI.isForever and CLASS_BARS[playerClass]
local classBar = classBarInfo and _G[classBarInfo.frame]
local classBarParent, classBarPoints		-- Blizzard's placement while the class bar is ours

XPerl_PlayerFrameMixin = {
	elementList = {
		"highlight", "playerVehicle", "portrait", "name", "level", "playerLevel", "classIcon", "power",
		"playerTalent", "health", "playerHealth", "role", "playerGroup", "statusIcons", "pvp", "combat",
		"playerResting", "healPrediction", "combatFeedback", "auras", "castBar", "petBattle", "playerXP",
		"playerRep", "playerShapeshift", "playerRunes", "playerControl", "targetCounter",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "levelFrame", "portraitFrame", "groupFrame", "runeBorder", "targetCounter"},
	flashFrameKeys = {"portraitFrame", "nameFrame", "levelFrame", "statsFrame", "runeBorder"},
	baseWidth = 124,
	portraitWidth = 62,
	portraitHiddenWidth = 3,
	exactPowerText = true,
	showResting = true,
	pvpUnit = "player",
	auraSetup = {cancel = true, enchants = true},
	tickInterval = 0.2,
}
local P = XPerl_PlayerFrameMixin
P.GetTargetInfo = UF.ShownUnitTargetInfo	-- pings the vehicle while in one (the "unit" attribute stays "player")

local Define = XPerl_UnitFrame_DefineElement
local function XPBarEnabled() return pconf.xpBar end
local function RepBarEnabled() return pconf.repBar end
local function IsDruid() return playerClass == "DRUID" end
local function HasRunes(self) return self.runeButtons ~= nil end
local function FullScreenEnabled() return pconf.fullScreen.enable end

Define("playerVehicle",	{events = {UNIT_ENTERED_VEHICLE = "player", UNIT_EXITED_VEHICLE = "player", PLAYER_ENTERING_WORLD = true}, method = "UpdateVehicle", full = false})
Define("playerLevel",	{events = {PLAYER_LEVEL_UP = true}, method = "UpdateLevel", full = false})
Define("playerTalent",	{events = {PLAYER_TALENT_UPDATE = true}, method = "UpdatePower", full = false})
Define("playerHealth",	{events = {PLAYER_DEAD = true, PLAYER_ALIVE = true, PLAYER_UNGHOST = true}, method = "UpdateHealth", full = false})
Define("playerResting",	{events = {PLAYER_UPDATE_RESTING = true, PLAYER_ENTER_COMBAT = true, PLAYER_LEAVE_COMBAT = true}, method = "UpdateStatusIcons", full = false})
Define("playerGroup",	{events = {GROUP_ROSTER_UPDATE = true}, method = "UpdateGroupNumber"})
Define("playerXP",	{events = {PLAYER_XP_UPDATE = true, UPDATE_EXHAUSTION = true, PLAYER_LEVEL_UP = true, PLAYER_UPDATE_RESTING = true}, method = "UpdateXP", enabled = XPBarEnabled})
Define("playerRep",	{events = {UPDATE_FACTION = true}, method = "UpdateRep", enabled = RepBarEnabled})
Define("playerShapeshift", {events = {UPDATE_SHAPESHIFT_FORM = true}, method = "UpdateShapeshift", full = false, enabled = IsDruid})
Define("playerRunes",	{events = {RUNE_POWER_UPDATE = true}, method = "UpdateRunes", enabled = HasRunes})
Define("playerControl",	{events = {PLAYER_CONTROL_LOST = true, PLAYER_CONTROL_GAINED = true}, method = "UpdateControl", full = false, enabled = FullScreenEnabled})

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

-- InitType
function P:InitType()
	local nf = self.nameFrame

	-- Clicks on the frame go to the vehicle while in one (the secure templates swap player -> pet)
	self:SetAttribute("toggleForVehicle", true)
	nf:SetAttribute("toggleForVehicle", true)

	XPerl_RegisterUnitText(nf.group)

	nf.pvpIcon:SetSize(43, 43)
	nf.pvpIcon:ClearAllPoints()
	nf.pvpIcon:SetPoint("TOPLEFT", nf, "TOPLEFT", -4, 1)

	if (playerClass == "DEATHKNIGHT") then
		self:InitDeathKnight()
	elseif (classBar) then
		self:CreateSpecialBar()
	end
end

-- CreateBar(name): an extra bar under the mana bar (XPerl_PlayerstatsFrame<name>)
function P:CreateBar(name)
	local sf = self.statsFrame
	local bar = CreateFrame("StatusBar", sf:GetName()..name, sf, "XPerlStatusBar")
	bar:SetPoint("TOPLEFT", sf.manaBar, "BOTTOMLEFT", 0, 0)
	bar:SetHeight(10)
	bar:SetWidth(112)
	sf[name] = bar
	return bar
end

-- GetExtraBars
function P:GetExtraBars()
	local sf = self.statsFrame
	return {sf.druidBar, sf.xpBar, sf.repBar}
end

-- GetStatsBars
function P:GetStatsBars()
	local sf = self.statsFrame
	return {sf.healthBar, sf.manaBar, sf.xpBar, sf.repBar}
end

-- ExtraBarCount: rows below the mana bar (druid mana, experience, reputation)
function P:ExtraBarCount()
	local druidBar = self.statsFrame.druidBar
	return ((druidBar and druidBar:IsShown()) and 1 or 0) + (pconf.repBar and 1 or 0) + (pconf.xpBar and 1 or 0)
end

-- ApplyStatsHeight: the health and mana bars, and a row per extra bar
function P:ApplyStatsHeight()
	self.statsFrame:SetHeight(40 + self:ExtraBarCount() * 10)
end

-- StatsDrop: how far the stats reach below the portrait (they sit under the name, overlapping it by 2).
-- Worked out from the sizes, so it is right straight after they changed, and in combat while the frame's own
-- height can't follow.
function P:StatsDrop()
	return self.nameFrame:GetHeight() - 2 + self.statsFrame:GetHeight() - self.portraitFrame:GetHeight()
end

-- ApplySize(width)
function P:ApplySize(width)
	local c = self.conf
	local barWidth = (c.percent and 160 or 128) + width
	local sf = self.statsFrame
	self.nameFrame:SetWidth(barWidth)
	sf:SetWidth(barWidth)
	self:ApplyStatsHeight()
	self:SetWidth((c.portrait and 62 or 0) + (c.percent and 32 or 0) + 124 + width)

	if (c.extendPortrait) then
		self.portraitFrame:SetHeight(62 + self:ExtraBarCount() * 10)
	elseif (self:SpecialBarDocked()) then
		self.portraitFrame:SetHeight(62 + (((c.xpBar and 1 or 0) + (c.repBar and 1 or 0)) * 10))
	else
		self.portraitFrame:SetHeight(62)
	end
	self:SetHeight(self.portraitFrame:GetHeight() + max(0, self:StatsDrop()))
end

-- ApplyTypeSettings
function P:ApplyTypeSettings()
	local c = self.conf
	local sf = self.statsFrame

	if (c.repBar) then
		(sf.repBar or self:CreateBar("repBar")):Show()
	elseif (sf.repBar) then
		sf.repBar:Hide()
	end

	if (c.xpBar) then
		if (not sf.xpBar) then
			self:CreateBar("xpBar")
			local rest = self:CreateBar("xpRestBar")
			rest:SetPoint("TOPLEFT", sf.xpBar, "TOPLEFT", 0, 0)
			rest:SetPoint("BOTTOMRIGHT", sf.xpBar, "BOTTOMRIGHT", 0, 0)
		end
		sf.xpBar:Show()
		sf.xpRestBar:Show()
	elseif (sf.xpBar) then
		sf.xpBar:Hide()
		sf.xpRestBar:Hide()
	end
	-- The bars made here start with the frame's text settings
	local values, percent = c.values and true or false, c.percent and true or false
	for _, bar in pairs({sf.xpBar, sf.repBar}) do
		bar.text:SetShown(values)
		bar.percent:SetShown(percent)
	end
	self:SetupRunes()		-- before the size: a docked special bar extends the portrait
	self:ApplySize(max(0, c.size.width or 0))

	self.highlight:ClearAllPoints()
	if (not c.level and not c.classIcon and not c.targetCounter) then
		self.highlight:SetPoint("TOPLEFT", self.portraitFrame, "TOPLEFT", 0, 0)
	else
		self.highlight:SetPoint("TOPLEFT", self.levelFrame, "TOPLEFT", 0, 0)
	end
	self.highlight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

	if (not c.totems) then
		c.totems = {enable = true, offsetX = 0, offsetY = 0}
	end
	self:UpdateTotems()

	self:ShowBlizzardAuras(not (c.buffs.enable and c.buffs.hideBlizzard))
end

-- OnActivate: a disabled player frame gives Blizzard's aura frames back, and hides the special bar (it can sit
-- on UIParent). The first activation also stops HealBot from switching Blizzard's player frame back on (only
-- while X-Perl's player frame is in use).
function P:OnActivate(on)
	if (not on) then
		self:ShowBlizzardAuras(true)
	elseif (not self.healBotOverridden and HealBot_Options_EnablePlayerFrame) then
		self.healBotOverridden = true
		HealBot_Options_EnablePlayerFrame = function() end
	end
	self:SetupRunes()
	self:UpdateTotems()
end

------------------------------------------------------------------------------
-- Unit
------------------------------------------------------------------------------

-- UpdateVehicle
function P:UpdateVehicle(event, unit, showVehicle)
	local inVehicle
	if (event == "UNIT_ENTERED_VEHICLE" and not issecretvalue(showVehicle)) then
		inVehicle = showVehicle
	elseif (event == "UNIT_EXITED_VEHICLE") then
		inVehicle = false
	else
		inVehicle = UnitHasVehicleUI("player")
	end
	if (event == "UNIT_ENTERED_VEHICLE" and not inVehicle) then
		return
	end

	local newUnit = inVehicle and "vehicle" or "player"
	if (newUnit ~= self.partyid) then
		self:SetUnit(newUnit)
	else
		self:UpdateDisplay()
	end
end

-- UpdateNameColour: red in combat; friendly colours otherwise
function P:UpdateNameColour()
	local text = self.nameFrame.text
	if (UnitAffectingCombat(self.partyid)) then
		text:SetTextColor(1, 0, 0)
	elseif (self.partyid ~= "player") then
		local c = conf.colour.reaction.none
		text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
	else
		XPerl_ColourFriendlyUnit(text, "player")
	end
end

-- UpdateCombat
function P:UpdateCombat(...)
	UF.UpdateCombat(self, ...)
	self:UpdateNameColour()
end

-- UpdateLevel: PLAYER_LEVEL_UP brings the new level before UnitLevel does
function P:UpdateLevel(event, newLevel)
	UF.UpdateLevel(self)
	if (event == "PLAYER_LEVEL_UP") then
		self.levelFrame.text:SetText(newLevel)
	end
end

-- UpdatePower
function P:UpdatePower(...)
	UF.UpdatePower(self, ...)
	if (playerClass == "DRUID") then
		self:UpdateDruidBar()
	end
end

-- UpdateGroupNumber: the raid group number, in the name or above it
function P:UpdateGroupNumber()
	local nf = self.nameFrame
	if (pconf.partyNumber and IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local isPlayer = UnitIsUnit("raid"..i, "player")
			if (not issecretvalue(isPlayer) and isPlayer) then
				local subgroup = select(3, GetRaidRosterInfo(i))
				if (pconf.withName) then
					nf.group:SetFormattedText(XPERL_RAID_GROUPSHORT, subgroup)
					nf.group:Show()
					self.groupFrame:Hide()
				else
					self.groupFrame.text:SetFormattedText(XPERL_RAID_GROUP, subgroup)
					self.groupFrame:Show()
					nf.group:Hide()
				end
				return
			end
		end
	end
	nf.group:Hide()
	self.groupFrame:Hide()
end

-- UpdateAuras
function P:UpdateAuras(event, ...)
	UF.UpdateAuras(self, event, ...)
	if (event) then
		if (playerClass == "DRUID") then
			self:UpdatePower()
		end
		if (isOutOfControl and pconf.fullScreen.enable and not UnitOnTaxi("player")) then
			self:UpdateFullScreen()
		end
	end
end

-- UpdateShapeshift
function P:UpdateShapeshift()
	self:UpdateDruidBar()
	self:UpdatePortrait()
end

-- OnTick: PvP flag countdown
function P:OnTick()
	local timer = self.nameFrame.pvpTimer
	if (self.nameFrame.pvpIcon:IsShown() and IsPVPTimerRunning()) then
		local timeLeft = GetPVPTimer()
		if (timeLeft > 0 and timeLeft < 300000) then		-- 5 * 60 * 1000
			timeLeft = floor(timeLeft / 1000)
			timer:SetFormattedText("%d:%02d", timeLeft / 60, timeLeft % 60)
			timer:Show()
			return
		end
	end
	timer:Hide()
end

------------------------------------------------------------------------------
-- Experience, reputation, druid mana
------------------------------------------------------------------------------

-- UpdateRep
function P:UpdateRep()
	local rb = self.statsFrame.repBar
	if (not rb) then
		return
	end
	local data = C_Reputation.GetWatchedFactionData()
	local name, minValue, maxValue, value, color
	if (data and data.factionID ~= 0) then
		name = data.name
		minValue = data.currentReactionThreshold
		maxValue = data.nextReactionThreshold
		value = data.currentStanding
		color = FACTION_BAR_COLORS[data.reaction]
	else
		name = XPERL_LOC_NONEWATCHED
		minValue, maxValue, value = 0, 1, 0
		color = FACTION_BAR_COLORS[4]
	end

	value = value - minValue
	maxValue = maxValue - minValue

	rb:SetMinMaxValues(0, maxValue)
	rb:SetValue(value)
	rb:SetStatusBarColor(color.r, color.g, color.b, 1)
	rb.bg:SetVertexColor(color.r, color.g, color.b, 0.25)

	local fraction = maxValue > 0 and value / maxValue or 0
	rb.percent:SetFormattedText(perc1F, fraction * 100)

	if (maxValue == 1) then
		rb.text:SetText(name)
	else
		rb.text:SetFormattedText("%d/%d", value, maxValue)
	end
end

local restedColour, normalColour = {r = 0.3, g = 0.3, b = 1}, {r = 0.6, g = 0, b = 0.6}

-- UpdateXP: experience with the rested amount in the shortest form that fits
function P:UpdateXP()
	local xpBar = self.statsFrame.xpBar
	if (not xpBar) then
		return
	end
	local restBar = self.statsFrame.xpRestBar
	local xp, xpMax = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion() or 0
	local fraction = xpMax > 0 and min(1, xp / xpMax) or 0
	xpBar:SetMinMaxValues(0, xpMax)
	restBar:SetMinMaxValues(0, xpMax)
	xpBar:SetValue(xp)

	local color = rested > 0 and restedColour or normalColour
	local w = (xpBar:GetRight() or 0) - (xpBar:GetLeft() or 0)
	for mode = 1, 3 do
		local suffix
		if (rested > 0) then
			if (mode == 1) then
				suffix = format(" +%d", rested)
			elseif (mode == 2) then
				suffix = rested >= 1000000 and format(" +%.1fM", rested / 1000000) or format(" +%.1fK", rested / 1000)
			else
				suffix = rested >= 1000000 and format(" +%dM", rested / 1000000) or format(" +%dK", rested / 1000)
			end
		end
		if (pconf.xpDeficit) then
			XPerl_SetValuedText(xpBar.text, xp - xpMax, xpMax, suffix)
		else
			XPerl_SetValuedText(xpBar.text, xp, xpMax, suffix)
		end
		if (xpBar.text:GetStringWidth() <= w) then
			break
		end
	end

	xpBar:SetStatusBarColor(color.r, color.g, color.b, 1)
	xpBar.bg:SetVertexColor(color.r, color.g, color.b, 0.25)

	restBar:SetValue(xp + rested)
	restBar:SetStatusBarColor(color.r, color.g, color.b, 0.5)
	restBar.bg:SetVertexColor(color.r, color.g, color.b, 0.5)
	xpBar.percent:SetFormattedText(percD, fraction * 100)
end

-- UpdateDruidBar: mana while shapeshifted into a form that uses another power
function P:UpdateDruidBar()
	local sf = self.statsFrame
	local druidBar = sf.druidBar
	if (pconf.noDruidBar) then
		if (druidBar and druidBar:IsShown()) then
			druidBar:Hide()
			self:LayoutBars()
		end
		return
	end
	if (not druidBar) then
		druidBar = self:CreateBar("druidBar")
		local c = conf.colour.bar.mana
		druidBar:SetStatusBarColor(c.r, c.g, c.b)
		druidBar.bg:SetVertexColor(c.r, c.g, c.b, 0.25)
		druidBar:Hide()			-- so showing it the first time lays the bars out
	end

	local maxMana, mana = UnitPowerMax("player", 0), UnitPower("player", 0)
	druidBar:SetMinMaxValues(0, maxMana)
	druidBar:SetValue(mana)
	if (issecretvalue(mana) or issecretvalue(maxMana)) then
		druidBar.text:SetText(mana.."/"..maxMana)
		druidBar.percent:SetText(XPerl_UnitPowerPercentText("player", 0))
	else
		druidBar.text:SetFormattedText("%d/%d", ceil(mana), maxMana)
		druidBar.percent:SetFormattedText(percD, maxMana > 0 and mana * 100 / maxMana or 0)
	end

	-- UnitPowerType has no answer while the unit's data is unavailable (zoning, logging in)
	local powerType = UnitPowerType(self.partyid)
	local show = powerType ~= nil and powerType > 0
	druidBar.text:SetShown(show)
	druidBar.percent:SetShown(show and pconf.percent and true or false)
	if (show ~= druidBar:IsShown()) then
		druidBar:SetShown(show)
		self:LayoutBars()
	end
end

-- LayoutBars: after a bar came or went. The bars and the aura holder follow straight away; the frame's and the
-- portrait's heights are protected in combat, so those wait for it to end.
function P:LayoutBars()
	if (InCombatLockdown()) then
		self:ApplyStatsHeight()
		XPerl_ProtectedCall(self.applySettingsDeferred)
	else
		self:ApplySize(max(0, pconf.size.width or 0))
	end
	XPerl_StatsFrameSetup(self, self:GetExtraBars())
	self:PlaceAuras()
end

------------------------------------------------------------------------------
-- Full screen flash
------------------------------------------------------------------------------

-- UpdateFullScreen: being out of control (not on a taxi) flashes the screen
function P:UpdateFullScreen()
	if (pconf.fullScreen.enable and not UnitOnTaxi("player")) then
		if (isOutOfControl and not XPerl_OutOfControlFrame.frameFlash) then
			XPerl_FrameFlash(XPerl_OutOfControlFrame)
		elseif (not isOutOfControl and XPerl_OutOfControlFrame.frameFlash) then
			XPerl_FrameFlashStop(XPerl_OutOfControlFrame, "out")
		end
	elseif (XPerl_OutOfControlFrame.frameFlash) then
		XPerl_FrameFlashStop(XPerl_OutOfControlFrame)
	end
end

-- UpdateControl
function P:UpdateControl(event)
	if (event == "PLAYER_CONTROL_LOST") then
		if (not UnitOnTaxi("player")) then
			isOutOfControl = true
		end
	else
		isOutOfControl = nil
		self:UpdateFullScreen()
	end
end

------------------------------------------------------------------------------
-- Class power: the special bar (conf.player.showRunes) in XPerl_Runes, docked under the stats (dockRunes) or
-- free, where Edit Mode places it
------------------------------------------------------------------------------

-- CreateSpecialBar(template): XPerl_Runes. Undocked, it can also be dragged while the options window has the
-- frames unlocked.
function P:CreateSpecialBar(template)
	local runes = CreateFrame("Frame", "XPerl_Runes", self, template)
	self.runes = runes
	runes:SetMovable(true)
	runes:RegisterForDrag("LeftButton")
	runes:SetScript("OnDragStart", function(frame)
		if (XPerlLocked == 0 and not pconf.dockRunes and not InCombatLockdown()) then
			frame:StartMoving()
			frame.xperlMoving = true
		end
	end)
	runes:SetScript("OnDragStop", function(frame)
		if (frame.xperlMoving) then
			frame.xperlMoving = nil
			frame:StopMovingOrSizing()
			XPerl_SavePosition(frame)
		end
	end)
	return runes
end

-- InitDeathKnight: our own rune buttons, on a backdrop
function P:InitDeathKnight()
	local runes = self:CreateSpecialBar("BackdropTemplate")
	self.runeBorder = runes
	runes:SetBackdrop({bgFile = "Interface\\Addons\\XPerl\\Images\\XPerl_FrameBack",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 32, edgeSize = 12,
			insets = {left = 3, right = 3, top = 3, bottom = 3}})
	runes:SetBackdropColor(0, 0, 0, 0.8)
	runes:SetBackdropBorderColor(1, 1, 1, 1)

	self.runeButtons = {}
	for i = 1, 6 do
		local rune = CreateFrame("Button", "XPerl_RuneButtonIndividual"..i, runes, "XPerl_RuneButtonIndividualTemplate")
		rune:EnableMouse(false)
		rune:SetID(i)
		self.runeButtons[i] = rune
	end
end

-- SpecialBarDocked: whether the special bar takes room under the frame. Blizzard's class bar is only there while
-- Blizzard shows it: in the specializations with that resource, and out of vehicles.
function P:SpecialBarDocked()
	local runes = self.runes
	if (not (runes and runes:IsShown() and pconf.dockRunes)) then
		return false
	end
	return self.runeButtons ~= nil or (classBarParent ~= nil and classBar:IsShown())
end

-- UpdateClassBar(take): Blizzard's class bar into XPerl_Runes, or back where it was. Like TotemFrame (see
-- UpdateTotems) it is a managed frame of PlayerBottomManagedFrameContainer, under Blizzard's hidden PlayerFrame,
-- and its OnShow would put it back there whenever Blizzard shows it again (a specialization change, leaving a
-- vehicle), so taking it clears its OnShow / OnHide for good, as for TotemFrame. Blizzard's code keeps driving
-- it: neither XPerl_Runes nor the player frame has the .unit field it would read (and be tainted by). Secure
-- hooks on its Show / Hide lay out our frame when it comes or goes.
function P:UpdateClassBar(take)
	if (not classBar) then
		return
	end
	if (take) then
		if (classBarParent) then
			return
		end
		local parent = classBar:GetParent()
		if (parent ~= PlayerFrame and parent ~= PlayerBottomManagedFrameContainer) then
			return		-- another add-on has it
		end
		classBarParent, classBarPoints = parent, {}
		for i = 1, classBar:GetNumPoints() do
			classBarPoints[i] = {classBar:GetPoint(i)}
		end
		classBar:SetScript("OnShow", nil)
		classBar:SetScript("OnHide", nil)
		classBar:SetParent(self.runes)
		classBar:ClearAllPoints()
		classBar:SetPoint("CENTER")

		if (not self.classBarHooked) then
			self.classBarHooked = true
			local shown
			local function Toggled()
				if (classBar:IsShown() == shown) then
					return		-- Blizzard shows it again on every setup
				end
				shown = classBar:IsShown()
				if (classBarParent and pconf.dockRunes) then
					self:LayoutBars()
					self:UpdateTotems()
				end
			end
			hooksecurefunc(classBar, "Show", Toggled)
			hooksecurefunc(classBar, "Hide", Toggled)
			hooksecurefunc(classBar, "SetShown", Toggled)
		end
	elseif (classBarParent) then
		classBar:SetParent(classBarParent)
		classBar:ClearAllPoints()
		for _, point in ipairs(classBarPoints) do
			classBar:SetPoint(unpack(point))
		end
		classBarParent, classBarPoints = nil, nil
	end
end

-- SetupRunes: shown while the player frame is in use, docked under the portrait or free (then Edit Mode places it)
function P:SetupRunes()
	local runes = self.runes
	if (not runes) then
		return
	end
	if (not (pconf.showRunes and self.active)) then
		self:UpdateClassBar(false)
		runes:Hide()
		if (runes.editModeRegistered) then
			XPerl_EditMode_SetEnabled(runes, false)
		end
		return
	end
	runes:Show()

	runes:ClearAllPoints()
	if (pconf.dockRunes) then
		runes:SetParent(self)
		runes:SetScale(1)
		runes:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 0, 2)
		runes:SetPoint("BOTTOMRIGHT", self.statsFrame, "BOTTOMRIGHT", 0, -30)
		if (runes.editModeRegistered) then
			XPerl_EditMode_SetEnabled(runes, false)
		end
	else
		runes:SetParent(UIParent)
		runes:SetScale(self:GetScale())
		runes:SetSize(214, 32)
		runes:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 23, -80)
		if (not runes.editModeRegistered) then
			runes.editModeRegistered = true
			XPerl_EditMode_Register(runes, "player", {
				label = classBarInfo and classBarInfo.label or XPERL_LOC_RUNES,
				default = {point = "TOPLEFT", x = 23, y = -80},
				index = 2,
				preview = function(on) runes:EnableMouse(on and true or false) end,
			})
		end
		XPerl_EditMode_SetEnabled(runes, true)
		XPerl_EditMode_ApplyPosition(runes)
	end

	if (not self.runeButtons) then
		self:UpdateClassBar(true)
		return
	end
	local wide = runes:GetWidth() >= 200
	local prev
	for i = 1, 6 do
		local rune = self.runeButtons[i]
		rune:ClearAllPoints()
		rune:SetSize(22, 22)
		if (prev) then
			rune:SetPoint("LEFT", prev, "RIGHT", wide and (4 + ((i % 2) * 16)) or (1 + ((i % 2) * 5)), 0)
		else
			rune:SetPoint("LEFT", wide and 10 or 1, 0)
		end
		prev = rune
	end
end

-- UpdateRunes
-- The payload can be secret (restricted combat), so every rune is refreshed, as Blizzard's RuneFrame does.
function P:UpdateRunes()
	for i = 1, 6 do
		local rune = self.runeButtons[i]
		local start, duration, isReady = GetRuneCooldown(i)
		if (issecretvalue(start) or issecretvalue(duration) or issecretvalue(isReady)) then
			-- Restricted rune timings can't be handed to a cooldown from add-on code
			rune.cooldown:Hide()
		elseif (not isReady) then
			if (start) then
				CooldownFrame_Set(rune.cooldown, start, duration, 1)
			end
		else
			rune.cooldown:Hide()
		end
	end
end

-- UpdateTotems: Blizzard's TotemFrame under the player frame, or under the docked special bar (conf.player.totems,
-- while the player frame is in use), or back where it was. Every class can have one (statues, Consecration,
-- Efflorescence and the like).
-- TotemFrame is a managed frame of PlayerBottomManagedFrameContainer, a child of Blizzard's PlayerFrame: its
-- OnShow puts it back into that container (hidden along with PlayerFrame) each time a totem appears, mostly in
-- combat, where it could not be taken again. Those OnShow / OnHide scripts do nothing else, so taking the frame
-- clears them. Given back, it keeps them cleared: the container leaves it where it was until a reload (scripts
-- put back by add-on code would run tainted, and their layout pass moves the protected PetFrame).
local totemParent, totemPoints		-- Blizzard's placement while TotemFrame is ours
function P:UpdateTotems()
	local totems = pconf.totems
	if (not TotemFrame or not totems) then
		return
	end
	if (InCombatLockdown()) then
		self.updateTotemsDeferred = self.updateTotemsDeferred or function() self:UpdateTotems() end
		XPerl_ProtectedCall(self.updateTotemsDeferred)
		return
	end

	if (totems.enable and self.active) then
		if (not totemParent) then
			totemParent, totemPoints = TotemFrame:GetParent(), {}
			for i = 1, TotemFrame:GetNumPoints() do
				totemPoints[i] = {TotemFrame:GetPoint(i)}
			end
			TotemFrame:SetScript("OnShow", nil)
			TotemFrame:SetScript("OnHide", nil)
		end
		TotemFrame:SetParent(self)
		TotemFrame:ClearAllPoints()
		TotemFrame:SetPoint("TOP", self:SpecialBarDocked() and self.runes or self, "BOTTOM", totems.offsetX, totems.offsetY)
	elseif (totemParent) then
		TotemFrame:SetParent(totemParent)
		TotemFrame:ClearAllPoints()
		for _, point in ipairs(totemPoints) do
			TotemFrame:SetPoint(unpack(point))
		end
		totemParent, totemPoints = nil, nil
	end
end

-- TypePreview: the undocked special bar can be dragged while unlocked
function P:TypePreview(on)
	if (self.runes) then
		self.runes:EnableMouse(on and not pconf.dockRunes and true or false)
	end
end

------------------------------------------------------------------------------
-- Buffs: the player's aura rows replace Blizzard's BuffFrame and DebuffFrame
------------------------------------------------------------------------------

-- Blizzard's player aura frames are moved here while ours replace them
local blizzHiddenParent = CreateFrame("Frame")
blizzHiddenParent:Hide()

-- ShowBlizzardAuras(show)
-- Blizzard's frames are only touched to hide them, or to bring them back after we did
function P:ShowBlizzardAuras(show)
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(self.applySettingsDeferred)
		return
	end
	for _, frame in pairs({BuffFrame, DebuffFrame}) do
		if (show) then
			if (frame.XPerlParent) then
				frame:SetParent(frame.XPerlParent)
				frame.XPerlParent = nil
				frame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
				frame:Show()
			end
		else
			frame:UnregisterEvent("UNIT_AURA")
			frame:Hide()
			if (not frame.XPerlParent) then
				frame.XPerlParent = frame:GetParent()
				frame:SetParent(blizzHiddenParent)
			end
		end
	end
end

-- Row settings handed to XPerl_Auras_Configure: "Player Buffs" is the master switch for both rows, and the
-- wrap and row limit settings apply to both
local buffRow, debuffRow = {}, {}
local auraOpts = {buffs = buffRow, debuffs = debuffRow}

-- GetAuraLineWidth: wrapped rows span the frame, less the holder's indent
function P:GetAuraLineWidth()
	if (pconf.buffs.wrap) then
		return self:GetWidth() - 3
	end
end

-- ConfigureAuras
function P:ConfigureAuras()
	local buffs, debuffs = pconf.buffs, pconf.debuffs

	buffRow.enable = buffs.enable
	buffRow.size = buffs.size
	buffRow.rows = buffs.rows
	-- An explicit icon cap overrides the row limit, so the buff count only applies to an unwrapped row
	buffRow.max = (not buffs.wrap) and buffs.count or nil

	debuffRow.enable = buffs.enable and debuffs.enable
	debuffRow.size = debuffs.size
	debuffRow.rows = buffs.rows

	auraOpts.cooldown = conf.buffs.cooldown and buffs.cooldown
	auraOpts.cooldownAny = conf.buffs.cooldownAny
	auraOpts.countdown = conf.buffs.countdown
	auraOpts.countdownAny = conf.buffs.countdownAny
	auraOpts.countdownExternal = conf.buffs.countdownExternal
	auraOpts.above = buffs.above
	auraOpts.lineWidth = self:GetAuraLineWidth()

	XPerl_Auras_Configure(self, auraOpts)
end

-- PlaceAuras: the holder follows the frame's layout (bars, runes, portrait) and re-wraps the rows when the
-- frame's width has changed. It goes under the portrait, or 5 under the stats where those reach lower.
function P:PlaceAuras()
	local buffFrame = self.buffFrame
	buffFrame:ClearAllPoints()
	if (pconf.buffs.above) then
		buffFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 3, 0)
	elseif (self:SpecialBarDocked()) then
		buffFrame:SetPoint("TOPLEFT", self.runes, "BOTTOMLEFT", 3, 0)
	else
		local drop = self:StatsDrop()
		buffFrame:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 3, drop > 0 and -(drop + 5) or 0)
	end
	self:CheckAuraWidth()
end
