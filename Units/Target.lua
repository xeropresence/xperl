-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Target and focus frames (XPerl_Target, XPerl_Focus): classification and elite graphics, creature type or
-- class, specialisation (target), combo points, target sounds, the focus marker, deferred updates. The rest
-- comes from Units/UnitFrame.lua, the target's assist counter from Units/TargetCounters.lua.

local UF = XPerl_UnitFrameMixin
local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local UnitName = UnitName

XPerl_TargetFrameMixin = {
	elementList = {
		"highlight", "targetChanged", "focusChanged", "name", "classification", "level", "targetType", "power",
		"health", "combat", "threat", "statusIcons", "role", "combo", "portrait", "range", "auras", "pvp",
		"healPrediction", "combatFeedback", "castBar", "petBattle", "targetTalents", "assistCounter",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "levelFrame", "portraitFrame", "creatureTypeFrame", "bossFrame", "cpFrame", "assistCounter"},
	flashFrameKeys = {"portraitFrame", "nameFrame", "levelFrame", "statsFrame", "bossFrame"},
	baseWidth = 128,
	portraitWidth = 60,
	portraitHiddenWidth = 2,
	optionalPower = true,
	useUnitWatch = true,
	auraOrder = "reaction",
}
local T = XPerl_TargetFrameMixin

local Define = XPerl_UnitFrame_DefineElement
local function IsTarget(self) return self.frameKey == "target" end
local function IsFocus(self) return self.frameKey == "focus" end

Define("targetChanged",	{events = {PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true}, method = "OnUnitChanged", full = false, enabled = IsTarget})
Define("focusChanged",	{events = {PLAYER_FOCUS_CHANGED = true, PLAYER_ENTERING_WORLD = true}, method = "OnUnitChanged", full = false, enabled = IsFocus})
Define("classification", {events = {UNIT_CLASSIFICATION_CHANGED = "unit", UNIT_LEVEL = "unit", UNIT_NAME_UPDATE = "unit"}, method = "UpdateClassification"})
Define("targetType",	{method = "UpdateType"})
Define("combo",		{method = "UpdateCombo", deferrable = true,
	init = function(self)
		local meter = self.nameFrame.cpMeter
		meter:SetMinMaxValues(0, 5)
		meter:GetStatusBarTexture():SetHorizTile(false)
		meter:GetStatusBarTexture():SetVertTile(false)
		-- Combo points are the player's (or vehicle's) power, so they're followed on a frame of their own
		local cp = self.cpFrame
		cp:SetScript("OnEvent", function(frame, event, unit, powerType)
			if (powerType == "COMBO_POINTS") then
				self:UpdateCombo()
			end
		end)
	end,
	-- combo.show off hides every combo point display (Blizzard's ComboFrame with it: SetupBlizzardComboFrame)
	apply = function(self)
		local cp = self.cpFrame
		cp:UnregisterAllEvents()
		if (self.active and conf.target.combo.show) then
			cp:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", "vehicle")
			cp:RegisterUnitEvent("UNIT_MAXPOWER", "player", "vehicle")
		end
	end})

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

-- InitType
function T:InitType()
	if (self.frameKey == "target") then
		self.statsFrame.focusTarget:SetVertexColor(0.7, 1, 1, 0.5)
	end
end

-- ApplyTypeSettings
function T:ApplyTypeSettings()
	self.eliteFrame:SetFrameLevel(self.portraitFrame:GetFrameLevel() + 3)
	self.classFrame.classTexture:SetShown(self.conf.classIcon and true or false)
	if (self.frameKey == "target") then
		self:SetupBlizzardComboFrame()
	end
end

-- OnHide
function T:OnHide()
	if (conf.target.sound) then
		PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT)
	end
end

-- OnUnitChanged: a new unit behind "target" / "focus"
function T:OnUnitChanged(event)
	if (self.frameKey == "target") then
		if (event == "PLAYER_TARGET_CHANGED" and conf.target.sound and UnitExists("target")) then
			if (UnitIsEnemy("target", "player")) then
				PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
			elseif (UnitIsFriend("player", "target")) then
				PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
			else
				PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
			end
		end
		local same = UnitIsUnit("target", "focus")
		self.statsFrame.focusTarget:SetShown(not issecretvalue(same) and same and true or false)
	elseif (event == "PLAYER_ENTERING_WORLD" and not UnitExists("focus")) then
		return
	end
	self:UnitChanged()
end

-- UpdateDisplay: with conf.defer the slow parts (portrait, role icon, combo points) wait for the next tick
function T:UpdateDisplay()
	if (not UnitExists(self.partyid)) then
		return
	end
	if (self.conf.defer) then
		self.deferring = true
		self.tick = -0.3
		local pf, nf = self.portraitFrame, self.nameFrame
		pf.portrait:Hide()
		pf.portrait3D:Hide()
		nf.cpMeter:Hide()
		self.cpFrame:Hide()
	end
	UF.UpdateDisplay(self)
end

-- OnTick: range, and the deferred updates
function T:OnTick()
	UF.OnTick(self)
	if (self.deferring) then
		self.deferring = nil
		self:UpdateRole()
		self:UpdateCombo()
		self:UpdatePortrait()
	end
end

-- UpdatePower: the mana bar can come and go with the power type, and the aura rows' width with it
function T:UpdatePower(event, ...)
	UF.UpdatePower(self, event, ...)
	if (event == "UNIT_DISPLAYPOWER") then
		self:CheckAuraWidth()
	end
end

-- GetAuraLineWidth
-- Below the frame the creature type frame (or the portrait, when there's no mana bar) hangs lower than the
-- stats; the rows stay within the stats frame then
function T:GetAuraLineWidth()
	if (self.conf.buffs.wrap and not self.conf.buffs.above and (self.creatureTypeFrame:IsShown() or not self.statsFrame.manaBar:IsShown())) then
		return self.statsFrame:GetWidth()
	end
	return UF.GetAuraLineWidth(self)
end

------------------------------------------------------------------------------
-- Classification and type
------------------------------------------------------------------------------

local eliteTextures = {
	worldboss = "Interface\\Addons\\XPerl\\Images\\XPerl_Elite",
	elite = "Interface\\Addons\\XPerl\\Images\\XPerl_Elite",
	rareelite = "Interface\\Addons\\XPerl\\Images\\XPerl_Elite",
	rare = "Interface\\Addons\\XPerl\\Images\\XPerl_Rare",
}
local eliteColours = {
	worldboss = {1, 1, 0},
	elite = {1, 1, 0},
	rareelite = {1, 1, 1},
	rare = {1, 1, 1},
}
local bossTypes = {
	worldboss = {XPERL_TYPE_BOSS, 1, 0.5, 0.5},
	rareelite = {XPERL_TYPE_RAREPLUS, 0.8, 0.8, 0.8},
	elite = {XPERL_TYPE_ELITE, 1, 1, 0.5},
	rare = {XPERL_TYPE_RARE, 0.8, 0.8, 0.8},
}

-- FitWidth(frame, text): the frame sized to its text. A fontstring that was given a secret text measures as
-- secret from then on; the frame keeps its size then.
local function FitWidth(frame, text)
	local width = text:GetStringWidth()
	if (not issecretvalue(width)) then
		frame:SetWidth(width + 10)
	end
end

-- UpdateClassification: elite/rare dragon (conf.eliteGfx) or a text box (pet, elite, boss...)
function T:UpdateClassification()
	local unit = self.partyid
	local classification = UnitClassification(unit)
	local bossText, r, g, b
	local eliteGfx

	if (classification == "normal" and UnitPlayerControlled(unit)) then
		if (not UnitIsPlayer(unit)) then
			bossText, r, g, b = XPERL_TYPE_PET, 1, 1, 1
			self.classFrame:Hide()
		end
	elseif (self.conf.level or eliteTextures[classification]) then
		if (self.conf.eliteGfx) then
			local texture = eliteTextures[classification]
			if (texture) then
				eliteGfx = true
				local c = eliteColours[classification]
				self.eliteFrame.tex:SetTexture(texture)
				self.eliteFrame.tex:SetVertexColor(c[1], c[2], c[3], 1)
			end
		else
			local boss = bossTypes[classification]
			if (boss) then
				bossText, r, g, b = boss[1], boss[2], boss[3], boss[4]
			end
		end
		self.classFrame:Hide()
	end

	local bf = self.bossFrame
	if (bossText) then
		bf.text:SetText(bossText)
		bf.text:SetTextColor(r, g, b)
		FitWidth(bf, bf.text)
		bf:Show()
	else
		bf:Hide()
	end

	local lf, ac = self.levelFrame, self.assistCounter
	if (eliteGfx) then
		self.eliteFrame:Show()
		if (self.conf.level) then
			lf:ClearAllPoints()
			lf:SetPoint("TOPRIGHT", self.portraitFrame, "TOPRIGHT", 0, 0)
			lf:SetFrameLevel(self.portraitFrame:GetFrameLevel() + 2)
			lf.outOfPlace = true
		end
		-- The assist counter goes into the portrait's corner, out of the elite graphic's way
		if (ac and not ac.outOfPlace) then
			ac:ClearAllPoints()
			ac:SetPoint("BOTTOMRIGHT", self.portraitFrame, "BOTTOMRIGHT", 0, 0)
			ac:SetFrameLevel(self.portraitFrame:GetFrameLevel() + 2)
			ac.outOfPlace = true
		end
	else
		self.eliteFrame:Hide()
		if (lf.outOfPlace) then
			lf.outOfPlace = nil
			lf:ClearAllPoints()
			lf:SetPoint("TOPLEFT", self.portraitFrame, "TOPRIGHT", -2, 0)
			lf:SetFrameLevel(self.portraitFrame:GetFrameLevel())
		end
		if (ac and ac.outOfPlace) then
			ac.outOfPlace = nil
			ac:ClearAllPoints()
			ac:SetPoint("TOPLEFT", self.portraitFrame, "TOPRIGHT", -2, -19)
			ac:SetFrameLevel(lf:GetFrameLevel() + 1)
		end
	end
end

-- AdjustCreatureTypeFrame: a long type is anchored to the portrait's left so it doesn't cover the auras
local function AdjustCreatureTypeFrame(self)
	local ct = self.creatureTypeFrame
	ct:ClearAllPoints()
	if (ct:GetWidth() > self.portraitFrame:GetWidth()) then
		ct:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 0, 2)
	else
		ct:SetPoint("TOPRIGHT", self.portraitFrame, "BOTTOMRIGHT", 0, 2)
	end
end

-- UpdateType: creature type (or battle pet type) under the portrait, class icon or class text for players
function T:UpdateType()
	local unit = self.partyid
	local ct = self.creatureTypeFrame
	local creatureType = UnitCreatureType(unit)
	local secretType = issecretvalue(creatureType)
	if (not secretType and (creatureType == XPERL_TYPE_NOT_SPECIFIED or creatureType == "")) then
		creatureType = nil
	end

	ct:SetShown(self.conf.mobType and true or false)
	self.classFrame:Hide()

	if (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
		ct.text:SetText(PET_TYPE_SUFFIX[UnitBattlePetType(unit)])
	else
		ct.text:SetText(creatureType)
	end

	local isPlayer = UnitIsPlayer(unit)
	if (self.conf.classIcon and (isPlayer or UnitClassification(unit) == "normal")) then
		local localClass, class = UnitClass(unit)
		if (self.conf.classText) then
			local bf = self.bossFrame
			bf.text:SetText(localClass)
			bf.text:SetTextColor(1, 1, 1)
			bf:Show()
			FitWidth(bf, bf.text)
		elseif (isPlayer or not UnitPlayerControlled(unit)) then
			if (not issecretvalue(class)) then
				self.classFrame.classTexture:SetTexCoord(XPerl_ClassPos(class))
				self.classFrame:Show()
			end
		end
	end
	if (isPlayer) then
		ct:Hide()
	end
	-- A secret type is shown as it is; its width can't be measured, so the frame keeps its size
	if (creatureType) then
		ct.text:SetTextColor(1, 1, 1)
		FitWidth(ct, ct.text)
	else
		ct:Hide()
	end

	AdjustCreatureTypeFrame(self)
	self:UpdateTalents()
end

------------------------------------------------------------------------------
-- Specialisation (target only): LibGroupTalents, LibTalentQuery or our own inspect requests
------------------------------------------------------------------------------

do
	local function ShowSpec(self, spec)
		local ct = self.creatureTypeFrame
		ct.text:SetText(spec)
		FitWidth(ct, ct.text)
		ct:Show()
		AdjustCreatureTypeFrame(self)
		self:CheckAuraWidth()
	end

	local function UnitFullName(unit)
		local n, s = UnitName(unit)
		if (s and s ~= "") then
			return n.."-"..s
		end
		return n
	end

	local LGT = LibStub and LibStub("LibGroupTalents-1.0", true)
	local LTQ = LibStub and LibStub("LibTalentQuery-1.0", true)
	local inspectReady
	local lastInspectTime, lastInspectPending = 0, 0
	local lastInspectName
	local talentCache = setmetatable({}, {__mode = "kv"})

	if (LTQ) then
		LTQ:RegisterCallback("TalentQuery_Ready", function(e, name, realm, unit)
			local same = UnitIsUnit(unit, XPerl_Target.partyid)
			if (not issecretvalue(same) and same) then
				inspectReady = true
				XPerl_Target:UpdateTalents(UnitGUID(unit))
			end
		end)
	else
		hooksecurefunc("NotifyInspect", function(unit)
			local isPlayer = UnitIsUnit("player", unit)
			if (issecretvalue(isPlayer) or isPlayer or UnitInVehicle(unit) or not (UnitExists(unit) and CanInspect(unit) and UnitIsVisible(unit) and UnitIsConnected(unit)
					and XPerl_CanCheckInteractDistance(unit) and CheckInteractDistance(unit, 4))) then
				return
			end
			lastInspectPending = lastInspectPending + 1
			lastInspectTime = GetTime()
			lastInspectName = UnitFullName(unit)
		end)
	end

	-- Without LibTalentQuery the inspect results come with INSPECT_READY
	Define("targetTalents", {events = {INSPECT_READY = true}, method = "OnInspectReady", full = false,
		enabled = function(self) return not LTQ and IsTarget(self) end})
	-- Fires after anybody's NotifyInspect; an NPC target's GUID can be secret, and is never the one inspected
	function T:OnInspectReady(event, guid)
		local current = UnitGUID(self.partyid)
		if (not issecretvalue(current) and not issecretvalue(guid) and current == guid) then
			inspectReady = true
			self:UpdateTalents(guid)
		end
	end

	-- UpdateTalents(guid): conf.showTalents shows the specialisation where the creature type would be
	function T:UpdateTalents(guid)
		if (not self.conf.showTalents or self ~= XPerl_Target or self.creatureTypeFrame:IsShown()) then
			return
		end
		if (LGT) then
			local spec = LGT:GetUnitTalentSpec(self.partyid)
			if (spec) then
				ShowSpec(self, spec)
				return
			end
		end

		local unit = self.partyid
		if (not (UnitIsVisible(unit) and UnitExists(unit) and UnitIsPlayer(unit) and UnitLevel(unit) > 10)) then
			return
		end
		local name = UnitName(unit)
		if (not name or issecretvalue(name)) then
			return
		end

		local cached = talentCache[name]
		local spec = cached
		local unitGUID = UnitGUID(unit)
		if (not spec and inspectReady and not issecretvalue(guid) and not issecretvalue(unitGUID) and guid == unitGUID) then
			local group = C_SpecializationInfo.GetInspectSpecialization("target")
			spec = group and select(2, GetSpecializationInfoByID(group)) or "None"
			inspectReady = nil
		end
		if (spec) then
			talentCache[name] = spec
			ShowSpec(self, spec)
		end

		if (not cached) then
			local isMe = UnitIsUnit("player", unit)
			if (LTQ) then
				inspectReady = nil
				LTQ:Query(unit)
			elseif ((lastInspectPending == 0 or GetTime() > lastInspectTime + 15) and UnitExists(unit) and UnitIsVisible(unit)
					and XPerl_CanCheckInteractDistance(unit) and CheckInteractDistance(unit, 4) and not issecretvalue(isMe) and not isMe) then
				inspectReady = nil
				lastInspectPending = 0
				if (lastInspectName ~= UnitFullName(unit)) then
					NotifyInspect(unit)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Combo points
------------------------------------------------------------------------------

local comboColours = {
	{0, 1, 0},
	{0.5, 1, 0},
	{1, 1, 0},
	{1, 0.5, 0},
	{1, 0, 0},
}

-- UpdateCombo: our meter in the name frame (combo.enable) or the number box (neither our meter nor
-- Blizzard's ComboFrame), with the target's combo settings for target and focus alike; none with combo.show off
function T:UpdateCombo()
	local combo = conf.target.combo
	local meter, box = self.nameFrame.cpMeter, self.cpFrame
	if (not combo.show) then
		meter:Hide()
		box:Hide()
		return
	end
	local points = GetComboPoints(UnitHasVehicleUI("player") and "vehicle" or "player", self.partyid)
	local colour = not issecretvalue(points) and comboColours[points]

	if (combo.enable) then
		box:Hide()
		if (colour) then
			meter:SetValue(points)
			meter:SetStatusBarColor(colour[1], colour[2], colour[3], 0.7)
			meter:Show()
		else
			meter:Hide()
		end
	elseif (not combo.blizzard and colour) then
		meter:Hide()
		box.text:SetText(points)
		box.text:SetTextColor(colour[1], colour[2], colour[3])
		box:Show()
	else
		meter:Hide()
		box:Hide()
	end
end

-- Blizzard's ComboFrame (combo.show and combo.blizzard) moves onto our portrait, which carries our scale.
-- Blizzard's code keeps driving it (PlayerFrame calls into it as well, so none of it is replaced); its points are
-- only re-anchored to run in a line along the chosen edge of the portrait, in the order they fill. The frame
-- differs per client: Retail's has nine points, of which ComboFrame_UpdateMax picks the ones in use, starting at
-- the first or the second. WoW: Forever's has five, fills them from the last one back, and its LayoutPointsCircle
-- puts them back in a ring around Blizzard's portrait on every update.
local isForever = XPerlAPI.isForever
local comboLayoutHooked

-- Where the line starts (ComboFrame and the first point anchor there) and which way it runs, per combo.pos
local comboEdges = {
	top		= {point = "TOPLEFT", x = -1, y = 4, along = "LEFT", alongRel = "RIGHT"},
	bottom	= {point = "BOTTOMLEFT", x = -1, y = -4, along = "LEFT", alongRel = "RIGHT"},
	left	= {point = "BOTTOMLEFT", x = -1, y = 0, along = "BOTTOM", alongRel = "TOP"},
	right	= {point = "BOTTOMRIGHT", x = 2, y = 0, along = "BOTTOM", alongRel = "TOP"},
}

-- ComboFrame's events, [event] = unit filter. Retail's OnLoad registers them only when combo points are set to
-- show on the target frame; WoW: Forever's always does, with its power events for the player alone.
local comboFrameEvents = isForever and {
	PLAYER_TARGET_CHANGED = false, PLAYER_ENTERING_WORLD = false, UNIT_POWER_FREQUENT = "player",
	UNIT_POWER_UPDATE = "player", UNIT_POWER_POINT_CHARGE = "player", UNIT_MAXPOWER = "player",
} or {
	PLAYER_TARGET_CHANGED = false, PLAYER_ENTERING_WORLD = false, UNIT_POWER_FREQUENT = false, UNIT_MAXPOWER = false,
}

-- LayoutBlizzardComboPoints: also runs right after Blizzard's own layout, which it overrides
local function LayoutBlizzardComboPoints()
	local points = ComboFrame.ComboPoints
	for _, point in ipairs(points) do
		point:ClearAllPoints()
	end
	local combo = conf.target.combo
	local edge = combo.show and combo.blizzard and comboEdges[combo.pos]
	if (not edge) then
		return
	end

	local first, last, step
	if (isForever) then
		first, last, step = ComboFrame.maxComboPoints, 1, -1
	else
		first, last, step = ComboFrame.startComboPointIndex or 1, #points, 1		-- nil until ComboFrame_UpdateMax
	end
	local previous
	for i = first, last, step do
		local point = points[i]
		if (previous) then
			point:SetPoint(edge.along, previous, edge.alongRel)
		else
			point:SetPoint(edge.point)
		end
		previous = point
	end
end

-- SetupBlizzardComboFrame
function T:SetupBlizzardComboFrame()
	if (not ComboFrame or not ComboFrame.ComboPoints) then
		return
	end
	if (not comboLayoutHooked) then
		comboLayoutHooked = true
		if (isForever) then
			hooksecurefunc(ComboFrame, "LayoutPointsCircle", LayoutBlizzardComboPoints)
		else
			hooksecurefunc("ComboFrame_UpdateMax", LayoutBlizzardComboPoints)
		end
	end

	local combo = conf.target.combo
	ComboFrame:ClearAllPoints()
	if (combo.show and combo.blizzard) then
		local pf = self.portraitFrame
		local edge = comboEdges[combo.pos]
		ComboFrame:SetParent(pf)
		ComboFrame:SetScale(1)
		if (edge) then
			ComboFrame:SetPoint(edge.point, pf, edge.point, edge.x, edge.y)
		end
		for event, unit in pairs(comboFrameEvents) do
			if (unit) then
				ComboFrame:RegisterUnitEvent(event, unit)
			else
				ComboFrame:RegisterEvent(event)
			end
		end
	else
		ComboFrame:Hide()
		for event in pairs(comboFrameEvents) do
			ComboFrame:UnregisterEvent(event)
		end
	end
	LayoutBlizzardComboPoints()
end
