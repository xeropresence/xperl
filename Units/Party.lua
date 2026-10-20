-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Party frames (XPerl_party1..4) under a SecurePartyHeaderTemplate header in XPerl_Party_Anchor, each with
-- its in-frame target (XPerl_party<N>targetFrame) and its pet (XPerl_partypet<N>): flip and portrait layouts,
-- phasing, debuffs beside the frame, show in raid / small raid. The rest comes from Units/UnitFrame.lua.
--
-- Settings: XPerlDB.party for the party frames, their targets (party.target) and the anchor (scale, anchor
-- point, spacing); XPerlDB.partypet for the pets, which follow the party's flip and healer mode.

local UF = XPerl_UnitFrameMixin
local pconf
XPerl_RequestConfig(function(new) pconf = new.party end, "$Revision$")

local UnitIsPVP = XPerlAPI.UnitIsPVP			-- secret-safe unit flags, see XPerl_Api.lua
local IsEventValid = C_EventUtils and C_EventUtils.IsEventValid

-- Plain(value): nil for a restricted (secret) value
local function Plain(value)
	if (issecretvalue(value)) then
		return nil
	end
	return value
end

-- M(point, flip): the point mirrored left/right for the flipped layout
local mirror = {TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT", LEFT = "RIGHT", RIGHT = "LEFT"}
local function M(point, flip)
	return flip and mirror[point] or point
end

-- XPerl_Party_SingleGroup
-- True when every group member is in raid group 1 (also used by the raid frames for party.smallRaid)
function XPerl_Party_SingleGroup()
	local num = GetNumGroupMembers()
	if (num > 5) then
		return
	end
	for i = 1, num do
		local group = select(3, GetRaidRosterInfo(i))
		if (group and group > 1) then
			return
		end
	end
	return true
end

local Define = XPerl_UnitFrame_DefineElement

------------------------------------------------------------------------------
-- Anchor and header
------------------------------------------------------------------------------

XPerl_PartyAnchorMixin = {}
local A = XPerl_PartyAnchorMixin

-- Where the header sits in the anchor, and its child offsets, per party.anchor
local headerPoints = {TOP = "TOPLEFT", LEFT = "TOPLEFT", BOTTOM = "BOTTOMLEFT", RIGHT = "BOTTOMRIGHT"}
local anchorEvents = {"GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE"}

function A:OnLoad()
	local point, _, _, x, y = self:GetPoint(1)
	self.defaultPosition = {point = point, x = x, y = y}
	self.updateVisibility = function() self:UpdateVisibility() end
	self.placeholders = {}
end

-- SetActive(on): the party type was switched on or off (out of combat, see UF:SetEnabled)
function A:SetActive(on)
	on = on and true or false
	if (on == (self.active or false)) then
		return
	end
	self.active = on

	if (on) then
		if (not self.registered) then
			self.registered = true
			XPerl_Party_SecureHeader:UnregisterEvent("UNIT_NAME_UPDATE")		-- IMPORTANT! Fix for WoW 2.1 UNIT_NAME_UPDATE lockup issues
			XPerl_EditMode_Register(self, "party", {label = PARTY, default = self.defaultPosition, preview = function(show) self:Preview(show) end})
		end
		for _, event in ipairs(anchorEvents) do
			if (not IsEventValid or IsEventValid(event)) then
				self:RegisterEvent(event)
			end
		end
	else
		self:UnregisterAllEvents()
		self:Preview(false)
	end
	XPerl_EditMode_SetEnabled(self, on)
	self:UpdateVisibility()
end

function A:OnEvent(event)
	if (event == "PET_BATTLE_OPENING_START") then
		self.petBattle = true
	elseif (event == "PET_BATTLE_CLOSE") then
		self.petBattle = nil
	end
	self:UpdateVisibility()
end

-- UpdateVisibility: the header shows in a party, and in raids with party.inRaid (or party.smallRaid while
-- everybody is in group 1); everything hides during pet battles
function A:UpdateVisibility()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(self.updateVisibility)
		return
	end
	local active = self.active and pconf
	local show = active and (pconf.inRaid or (pconf.smallRaid and XPerl_Party_SingleGroup()) or (GetNumGroupMembers() > 0 and not IsInRaid()))
	XPerl_Party_SecureHeader:SetShown(show and true or false)
	self:SetShown((active and not self.petBattle) and true or false)
end

-- ApplySettings: scale, header placement and child offsets, size. Run by XPerl_party1's settings (out of
-- combat), once the party frames have their size.
function A:ApplySettings()
	local header = XPerl_Party_SecureHeader
	local anchor = headerPoints[pconf.anchor] and pconf.anchor or "TOP"
	local spacing = tonumber(pconf.spacing) or 0

	self:SetScale(pconf.scale or 1)

	header:ClearAllPoints()
	header:SetPoint(headerPoints[anchor], self, headerPoints[anchor], 0, 0)
	header:SetAttribute("point", anchor)
	if (anchor == "TOP") then
		header:SetAttribute("xOffset", 0)
		header:SetAttribute("yOffset", -spacing)
	elseif (anchor == "BOTTOM") then
		header:SetAttribute("xOffset", 0)
		header:SetAttribute("yOffset", spacing)
	elseif (anchor == "LEFT") then
		header:SetAttribute("xOffset", spacing)
		header:SetAttribute("yOffset", 0)
	else
		header:SetAttribute("xOffset", -spacing)
		header:SetAttribute("yOffset", 0)
	end

	-- The Edit Mode selection covers four party frames
	local w, h = XPerl_party1:GetWidth(), XPerl_party1:GetHeight()
	if (anchor == "TOP" or anchor == "BOTTOM") then
		self:SetSize(w, max(h, h * 4 + spacing * 3))
	else
		self:SetSize(max(w, w * 4 + spacing * 3), h)
	end
	XPerl_EditMode_ApplyPosition(self)

	self:UpdateVisibility()
	if (self.previewing) then
		self:Preview(true)
	end
end

-- Placeholder drags in the options window's unlocked mode move the anchor
local function PlaceholderDragStart()
	XPerl_Party_Anchor:StartDrag()
end
local function PlaceholderDragStop()
	XPerl_Party_Anchor:StopDrag()
end

-- Preview(on): placeholders where the four party frames go, for Edit Mode and the options window unlock
function A:Preview(on)
	self.previewing = on and true or nil
	local list = self.placeholders
	if (not on or not self.active) then
		for i = 1, #list do
			list[i]:Hide()
		end
		return
	end

	local anchor = headerPoints[pconf.anchor] and pconf.anchor or "TOP"
	local spacing = tonumber(pconf.spacing) or 0
	local w, h = XPerl_party1:GetWidth(), XPerl_party1:GetHeight()
	for i = 1, 4 do
		local p = list[i]
		if (not p) then
			p = CreateFrame("Frame", self:GetName().."Placeholder"..i, self, "BackdropTemplate")
			p:SetBackdrop(XPERL_BACKDROP_PARTY_VIRTUAL)
			p:SetBackdropColor(0, 0, 0, 1)
			p:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
			p:SetFrameLevel(self:GetFrameLevel())
			p.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			p.text:SetAllPoints()
			p.text:SetFormattedText("%s %d", PARTY, i)
			p:EnableMouse(true)
			p:RegisterForDrag("LeftButton")
			p:SetScript("OnDragStart", PlaceholderDragStart)
			p:SetScript("OnDragStop", PlaceholderDragStop)
			list[i] = p
		end
		local step = i - 1
		p:ClearAllPoints()
		p:SetSize(w, h)
		if (anchor == "TOP") then
			p:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -step * (h + spacing))
		elseif (anchor == "BOTTOM") then
			p:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, step * (h + spacing))
		elseif (anchor == "LEFT") then
			p:SetPoint("TOPLEFT", self, "TOPLEFT", step * (w + spacing), 0)
		else
			p:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -step * (w + spacing), 0)
		end
		p:Show()
	end
end

-- StartDrag / StopDrag: the options window's unlocked drag of any party frame; positions belong to Edit Mode
function A:StartDrag()
	if (XPerlLocked == 0 and not InCombatLockdown()) then
		self.xperlMoving = true
		self:StartMoving()
	end
end

function A:StopDrag()
	if (self.xperlMoving) then
		self.xperlMoving = nil
		self:StopMovingOrSizing()
		XPerl_SavePosition(self)
	end
end

------------------------------------------------------------------------------
-- Party frames
------------------------------------------------------------------------------

XPerl_PartyFrameMixin = {
	elementList = {
		"highlight", "partyRoster", "portrait", "name", "level", "classIcon", "power", "health", "role",
		"statusIcons", "pvp", "combat", "partyPhase", "threat", "partyThreat", "partyTarget", "partyPet", "range",
		"readyCheck", "healPrediction", "combatFeedback", "auras", "castBar",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "levelFrame", "portraitFrame"},
	flashFrameKeys = {"nameFrame", "levelFrame", "statsFrame", "portraitFrame"},
	portraitHiddenWidth = 2,
}
local P = XPerl_PartyFrameMixin

Define("partyRoster",	{events = {GROUP_ROSTER_UPDATE = true, PLAYER_ENTERING_WORLD = true, PARTY_MEMBER_ENABLE = true, PARTY_MEMBER_DISABLE = true}, method = "RosterChanged", full = false})
Define("partyPhase",	{events = {UNIT_PHASE = "unit", UNIT_CONNECTION = "unit"}, method = "UpdatePhasing"})
Define("partyThreat",	{events = {UNIT_THREAT_LIST_UPDATE = "target", PLAYER_TARGET_CHANGED = true}, method = "UpdateThreat", full = false})
Define("partyTarget",	{events = {UNIT_TARGET = "unit"}, method = "OnUnitTarget", full = false})
Define("partyPet",	{events = {UNIT_PET = "unit"}, method = "OnUnitPet", full = false})

-- InitType
function P:InitType()
	self:GetParent():SetAttribute("child"..self:GetID(), self)

	local nf = self.nameFrame
	nf.pvpIcon:SetSize(36, 36)
	nf.pvpIcon:ClearAllPoints()
	nf.pvpIcon:SetPoint("RIGHT", nf, "RIGHT", 16, -7)

	local tf = CreateFrame("Button", self:GetName().."targetFrame", self, "XPerl_Party_TargetTemplate")
	tf:SetFrameLevel(self:GetFrameLevel() + 1)
	self.targetFrame = tf
end

-- SetUnit: the header gave the frame another unit; its target and pet follow
function P:SetUnit(unit)
	if (unit == self.partyid) then
		return
	end
	self.targetFrame:SetUnit(unit and unit.."target")
	local pet = self.petFrame
	if (pet) then
		local index = unit and strmatch(unit, "^party(%d)$")
		pet.ownerid = unit
		pet:SetUnit(index and "partypet"..index)
	end
	UF.SetUnit(self, unit)
end

-- RosterChanged: the same token can be somebody else now
function P:RosterChanged()
	self:UnitChanged()
	self.targetFrame:UnitChanged()
	if (self.petFrame) then
		self.petFrame:UnitChanged()
	end
end

-- OnUnitTarget: the member changed target
function P:OnUnitTarget()
	self.targetFrame:UnitChanged()
	self:UpdateThreat()
end

-- OnUnitPet: the member's pet was summoned, dismissed or replaced (same token, another unit)
function P:OnUnitPet()
	local pet = self.petFrame
	if (pet) then
		pet:UnitChanged()
	end
end

-- OnShow
function P:OnShow()
	UF.OnShow(self)
	self:UpdateDisplay()
end

-- OnActivate: the anchor (header, Edit Mode entry) follows the party type
function P:OnActivate(on)
	XPerl_Party_Anchor:SetActive(on)
end

-- The anchor carries party.scale
function P:ApplyScale()
end

-- Drags move the anchor
function P:OnDragStart()
	XPerl_Party_Anchor:StartDrag()
end

function P:OnDragStop()
	XPerl_Party_Anchor:StopDrag()
end

-- ApplySize(width): bar widths, then the layout of the parts (portrait or not, flipped or not)
function P:ApplySize(width)
	local c = self.conf
	local flip = c.flip and true or false
	local nf, lf, pf, sf, hl = self.nameFrame, self.levelFrame, self.portraitFrame, self.statsFrame, self.highlight
	local classTexture = lf.classTexture
	local x = flip and -1 or 1

	sf:SetWidth((c.percent and 142 or 106) + width)
	nf:SetWidth(106 + width / 2)

	pf:ClearAllPoints()
	nf:ClearAllPoints()
	lf:ClearAllPoints()
	sf:ClearAllPoints()
	classTexture:ClearAllPoints()
	lf.text:ClearAllPoints()
	hl:ClearAllPoints()

	if (c.portrait) then
		lf:SetSize(27, 22)
		lf:SetPoint(M("TOPLEFT", flip), self, M("TOPLEFT", flip), 0, 0)
		pf:SetPoint(M("TOPLEFT", flip), lf, M("TOPRIGHT", flip), -2 * x, 0)
		nf:SetPoint(M("TOPLEFT", flip), pf, M("TOPRIGHT", flip), -2 * x, 0)
		sf:SetPoint(M("TOPLEFT", flip), nf, M("BOTTOMLEFT", flip), 0, 3)
		lf.text:SetPoint("CENTER", lf, "CENTER", 0, 0)
		classTexture:SetPoint(M("BOTTOMRIGHT", flip), pf, M("BOTTOMLEFT", flip), 0, 3)
		hl:SetPoint(M("TOPLEFT", flip), lf, M("TOPLEFT", flip), 0, 0)
	else
		lf:SetSize(30, 41)
		nf:SetPoint(M("TOPLEFT", flip), self, M("TOPLEFT", flip), 0, 0)
		lf:SetPoint(M("TOPLEFT", flip), nf, M("BOTTOMLEFT", flip), 0, 3)
		sf:SetPoint(M("TOPLEFT", flip), lf, M("TOPRIGHT", flip), -2 * x, 0)
		lf.text:SetPoint("BOTTOM", lf, "BOTTOM", 0, 4)
		classTexture:SetPoint(M("TOPLEFT", flip), lf, M("TOPLEFT", flip), 5 * x, -5)
		hl:SetPoint(M("TOPLEFT", flip), nf, M("TOPLEFT", flip), 0, 0)
	end
	hl:SetPoint(M("BOTTOMRIGHT", flip), sf, M("BOTTOMRIGHT", flip), 0, 0)

	-- The level box holds the level and the class icon; without either it is a sliver
	lf.text:SetShown(c.level and true or false)
	classTexture:SetShown(c.classIcon and true or false)
	if (c.level or c.classIcon) then
		lf:Show()
	else
		lf:SetWidth(2)
		lf:Hide()
	end

	local w = sf:GetWidth() + lf:GetWidth() - 2
	if (c.portrait) then
		w = w + pf:GetWidth() - 2
	end
	self:SetWidth(w)
end

-- ApplyTypeSettings: name bar, the target and pet beside the frame, then their settings and the anchor's
function P:ApplyTypeSettings()
	local c = self.conf
	local flip = c.flip and true or false
	local x = flip and -1 or 1
	local nf, sf = self.nameFrame, self.statsFrame

	nf:SetHeight(c.name and 24 or 2)
	nf:SetShown(c.name and true or false)

	self.phasingIcon:ClearAllPoints()
	self.phasingIcon:SetPoint(M("BOTTOMLEFT", flip), nf, M("BOTTOMRIGHT", flip), 0, 2)

	local tf = self.targetFrame
	tf:ClearAllPoints()
	if (c.name) then
		tf:SetPoint(M("BOTTOMLEFT", flip), nf, M("BOTTOMRIGHT", flip), -2 * x, 0)
	else
		tf:SetPoint(M("TOPLEFT", flip), sf, M("BOTTOMLEFT", flip), -2 * x, 0)
	end
	tf:ApplySettings()

	local pet = self.petFrame
	if (pet) then
		pet:ClearAllPoints()
		pet:SetPoint(M("TOPLEFT", flip), sf, M("TOPRIGHT", flip), -2 * x, 0)
		pet:ApplySettings()
	end

	if (self:GetID() == 1) then
		XPerl_Party_Anchor:ApplySettings()
	end
end

-- UpdateName: names too long for the bar get the small font
function P:UpdateName(event)
	local text = self.nameFrame.text
	local name = UnitName(self.partyid)
	text:SetFontObject(GameFontNormal)
	text:SetText(name)
	if (not issecretvalue(name) and text:GetStringWidth() > self.nameFrame:GetWidth() - 4) then
		text:SetFontObject(GameFontNormalSmall)
	end
	self:UpdateNameColour()
	if (event) then
		-- Class and flags aren't known before the first UNIT_NAME_UPDATE
		self:UpdateClassIcon()
		self:UpdateHealth()
	end
end

-- UpdateNameColour
function P:UpdateNameColour()
	XPerl_ColourFriendlyUnit(self.nameFrame.text, self.partyid)
end

-- UpdateLevel: the level box is laid out by ApplySize
function P:UpdateLevel()
	XPerl_Unit_UpdateLevel(self)
end

-- UpdateClassIcon: the icon lives in the level box
function P:UpdateClassIcon()
	local texture = self.levelFrame.classTexture
	if (self.conf.classIcon) then
		texture:SetTexCoord(XPerl_ClassPos(Plain(select(2, UnitClass(self.partyid)))))
		texture:Show()
	else
		texture:Hide()
	end
end

-- GetHealthStatus: also "Updating" while the client has no health yet
function P:GetHealthStatus()
	local status = UF.GetHealthStatus(self)
	if (not status) then
		local hp, hpMax = UnitHealth(self.partyid), UnitHealthMax(self.partyid)
		if (not issecretvalue(hp) and not issecretvalue(hpMax) and hp == 1 and hpMax == 1) then
			status = XPERL_LOC_UPDATING
		end
	end
	return status
end

-- UpdateHealth: a status too wide for the percent column goes in the health text; level and class may only
-- be known once the maximum health arrives
function P:UpdateHealth(event, ...)
	local hp, hpMax = UF.UpdateHealth(self, event, ...)
	local sf = self.statsFrame
	local hb = sf.healthBar
	if (self.conf.percent) then
		local status = self:GetHealthStatus()
		if (status and hb.percent:GetStringWidth() > sf:GetWidth() - hb:GetWidth() - 8) then
			hb.percent:SetText("")
			hb.text:SetText(status)
			hb.text:Show()
		end
	end
	if (event == "UNIT_MAXHEALTH") then
		self:UpdateLevel()
		self:UpdateClassIcon()
	end
	return hp, hpMax
end

-- UpdatePhasing: the member is in another phase
function P:UpdatePhasing()
	local unit = self.partyid
	local phased = UnitPhaseReason and Plain(UnitPhaseReason(unit))
	self.phasingIcon:SetShown((phased and UnitIsConnected(unit)) and true or false)
end

-- UpdateRange: spell range fade only (the 30 yard icon can't measure group members in combat)
function P:UpdateRange()
	local unit = self.partyid
	if (unit and UnitExists(unit)) then
		XPerl_UpdateSpellRange(self, unit)
	end
end

-- PlaceAuras: buffs below the frame, from the side the frame grows from
function P:PlaceAuras()
	local bf = self.buffFrame
	bf:ClearAllPoints()
	if (self.conf.flip) then
		bf:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", -2, 0)
	else
		bf:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 2, 0)
	end
end

-- GetAuraLineWidth: wrapped rows span the frame
function P:GetAuraLineWidth()
	if (self.conf.buffs.wrap) then
		return self:GetWidth()
	end
end

-- PlaceDebuffs: debuffs beside the frame rather than below the buffs: right of the stats, or of the pet's
-- name while the pet frame shows (left of them when flipped)
local function PlaceDebuffs(self, debuffs, point)
	local anchor = self.statsFrame
	if (self.petFrame and self.petFrame:IsVisible()) then
		anchor = self.petFrame.nameFrame
	end
	if (self.conf.flip) then
		debuffs:SetPoint(point, anchor, "TOPLEFT", 0, -4)
	else
		debuffs:SetPoint(point, anchor, "TOPRIGHT", 0, -4)
	end
end

-- ConfigureAuras
function P:ConfigureAuras()
	local c = self.conf
	local opts = XPerl_Auras_UnitOptions(self, {flip = c.flip, lineWidth = self:GetAuraLineWidth()})

	if (not c.debuffs.below) then
		opts.placeDebuffs = PlaceDebuffs
		if (c.debuffs.halfSize) then
			-- Aura counts are unknowable, so debuffs can't shrink only once there are too many to fit:
			-- they're always half size instead, wrapping at the frame's width (two rows where one fitted)
			opts.debuffs = setmetatable({
				size = (tonumber(c.debuffs.size) or 20) / 2,
				lineWidth = self:GetWidth(),
			}, {__index = c.debuffs})
		else
			-- Beside the frame debuffs stay one line whether or not the buffs wrap
			opts.debuffs = setmetatable({lineWidth = false}, {__index = c.debuffs})
		end
	end

	XPerl_Auras_Configure(self, opts)
end

------------------------------------------------------------------------------
-- Party targets (party.target settings; polled, the *target tokens have no events)
------------------------------------------------------------------------------

XPerl_PartyTargetFrameMixin = {
	elementList = {"partyTargetName", "partyTargetHealth", "statusIcons", "partyTargetCombat", "partyTargetPvP", "range"},
	perlFrameKeys = {"nameFrame"},
	flashFrameKeys = {},
	statusIconSize = 12,
}
local PT = XPerl_PartyTargetFrameMixin

Define("partyTargetName",	{method = "UpdateName"})
Define("partyTargetHealth",	{method = "UpdateHealth"})
Define("partyTargetCombat",	{method = "UpdateCombat"})
Define("partyTargetPvP",	{method = "UpdatePvP"})

-- InitType
function PT:InitType()
	local nf = self.nameFrame
	nf.text:SetFontObject(GameFontNormalSmall)
	nf.text:ClearAllPoints()
	nf.text:SetPoint("TOPLEFT", nf, "TOPLEFT", 3, -4)
	nf.text:SetPoint("BOTTOMRIGHT", nf, "TOPRIGHT", -3, -14)
	nf.pvpIcon:SetSize(32, 32)
	nf.pvpIcon:ClearAllPoints()
	nf.pvpIcon:SetPoint("TOPLEFT", nf, "TOPLEFT", -3, 0)
	nf.healthBar.text:SetTextColor(1, 1, 1)
	XPerl_RegisterHighlight(nf, 3)
end

-- StatusIconSpots: party.target.icons
function PT:StatusIconSpots()
	return self.conf.target.icons
end

-- GetStatsBars: no stats frame
function PT:GetStatsBars()
	return {}
end

-- ApplyScale: sized within the party frame
function PT:ApplyScale()
end

-- ApplySize: party.target.size wide, taller with the health bar (party.target.large)
function PT:ApplySize()
	local t = self.conf.target
	self:SetWidth(tonumber(t.size) or 120)
	self:SetHeight(t.large and 28 or 20)
	self.nameFrame.healthBar:SetShown(t.large and true or false)
end

-- UpdateWatch: shown while the member has a target and party.target.enable is on
function PT:UpdateWatch()
	if (self.active and self.conf.target.enable) then
		RegisterUnitWatch(self)
	else
		UnregisterUnitWatch(self)
		self:Hide()
	end
end

function PT:OnActivate()
	self:UpdateWatch()
end

function PT:ApplyTypeSettings()
	self:UpdateWatch()
end

-- OnShow
function PT:OnShow()
	UF.OnShow(self)
	self:UpdateDisplay()
end

-- Drags move the party anchor
function PT:OnDragStart()
	self:GetParent():OnDragStart()
end

function PT:OnDragStop()
	self:GetParent():OnDragStop()
end

-- OnTick: range every tick, the health bar every tick while it shows, everything twice a second
function PT:OnTick()
	local unit = self.partyid
	if (not unit or not UnitExists(unit)) then
		return
	end
	self:UpdateRange()
	local slow = (self.slowTick or 0) + 1
	if (slow >= 3) then
		slow = 0
		self:UpdateDisplay()
	elseif (self.conf.target.large) then
		self:UpdateHealth()
	end
	self.slowTick = slow
end

-- UpdateRange: spell range fade only
function PT:UpdateRange()
	XPerl_UpdateSpellRange(self, self.partyid)
end

-- UpdateHealth: health bar with the percentage, or dead/ghost
function PT:UpdateHealth()
	if (not self.conf.target.large) then
		return
	end
	local unit = self.partyid
	local bar = self.nameFrame.healthBar
	local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
	bar:SetMinMaxValues(0, hpMax)
	bar:SetValue(hp)

	if (UnitIsDeadOrGhost(unit)) then
		bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
		bar.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		bar.text:SetText(UnitIsDead(unit) and XPERL_LOC_DEAD or XPERL_LOC_GHOST)
	elseif (issecretvalue(hp) or issecretvalue(hpMax)) then
		-- Restricted (secret) health can't be divided, so the client colours the bar and formats the percentage
		XPerl_SetSmoothBarColorFromUnit(bar, unit)
		bar.text:SetText(XPerl_UnitHealthPercentText(unit))
	else
		local percent = hpMax > 0 and min(hp / hpMax, 1) or 0
		XPerl_SetSmoothBarColor(bar, percent)
		bar.text:SetFormattedText("%d%%", 100 * percent)
	end
	bar.text:Show()
end

------------------------------------------------------------------------------
-- Party pets (partypet settings; flip and healer mode from party)
------------------------------------------------------------------------------

XPerl_PartyPetFrameMixin = {
	elementList = {"highlight", "name", "level", "partyPetPower", "health", "statusIcons", "combat", "range", "auras",
		"healPrediction", "combatFeedback"},
	perlFrameKeys = {"nameFrame", "statsFrame"},
	flashFrameKeys = {"nameFrame", "statsFrame"},
	useUnitWatch = true,
	highlightRatio = 2,
	statsOffset = 2,
	statusIconSize = 12,
}
local PP = XPerl_PartyPetFrameMixin

local function PetManaEnabled(self) return self.conf.mana end
Define("partyPetPower",	{events = {UNIT_POWER_FREQUENT = "unit", UNIT_MAXPOWER = "unit", UNIT_DISPLAYPOWER = "unit"}, method = "UpdatePower", enabled = PetManaEnabled})

-- InitType
function PP:InitType()
	self:GetParent().petFrame = self
	local nf = self.nameFrame
	nf.text:SetFontObject(GameFontNormalSmall)
	nf.text:SetJustifyH("LEFT")
	nf.text:ClearAllPoints()
	nf.text:SetPoint("TOPLEFT", nf, "TOPLEFT", 5, 0)
	nf.text:SetPoint("BOTTOMRIGHT", nf, "BOTTOMRIGHT", 0, 2)
	XPerl_RegisterUnitText(nf.level)
end

-- SetEnabled: only with the party frames
function PP:SetEnabled(on)
	UF.SetEnabled(self, on and pconf and pconf.enable)
end

-- GetStatsBars: the texts are fixed (health text only)
function PP:GetStatsBars()
	return {}
end

-- ApplySize: fixed size; shorter without the mana bar
function PP:ApplySize()
	local c = self.conf
	local nf, sf = self.nameFrame, self.statsFrame
	nf:SetShown(c.name and true or false)
	nf:SetHeight(c.name and 20 or 4)
	sf.manaBar:SetShown(c.mana and true or false)
	sf:SetHeight(c.mana and 33 or 23)
	self:SetHeight(c.mana and 50 or 40)
end

-- ApplyTypeSettings
function PP:ApplyTypeSettings()
	local sf = self.statsFrame
	sf.healthBar.text:Show()
	sf.healthBar.percent:Hide()
	sf.manaBar.text:Hide()
	sf.manaBar.percent:Hide()
end

-- OnShow / OnHide: the party frame's debuffs sit beside the pet while it shows
function PP:OnShow()
	UF.OnShow(self)
	self:UpdateDisplay()
	XPerl_Auras_Arrange(self:GetParent())
end

function PP:OnHide()
	XPerl_Auras_Arrange(self:GetParent())
end

-- Drags move the party anchor
function PP:OnDragStart()
	self:GetParent():OnDragStart()
end

function PP:OnDragStop()
	self:GetParent():OnDragStop()
end

-- UpdateNameColour: green while the owner is PvP flagged
function PP:UpdateNameColour()
	local owner = self.ownerid
	if (owner and UnitIsPVP(owner)) then
		self.nameFrame.text:SetTextColor(0, 1, 0)
	else
		self.nameFrame.text:SetTextColor(0.5, 0.5, 1)
	end
end

-- UpdateLevel: in the name bar
function PP:UpdateLevel()
	local c = self.conf
	XPerl_Unit_UpdateLevel(self)
	self.nameFrame.level:SetShown((c.name and c.level) and true or false)
end

-- UpdateCombat: the warning for a charmed pet (not when the owner drives a vehicle). Whether the pet is
-- charmed can be secret, so the client shows or clears the icon through its alpha.
function PP:UpdateCombat()
	local unit, owner, icon = self.partyid, self.ownerid, self.nameFrame.warningIcon
	if (UnitIsVisible(unit) and not (owner and UnitUsingVehicle(owner))) then
		icon:SetAlphaFromBoolean(UnitIsCharmed(unit), 1, 0)
		icon:Show()
	else
		icon:Hide()
	end
end

-- UpdateHealth: the health text is the percentage, or the party's healer mode deficit
function PP:UpdateHealth()
	local unit = self.partyid
	local sf = self.statsFrame
	local text = sf.healthBar.text
	local hp, hpMax = XPerl_Unit_GetHealth(self)
	XPerl_SetHealthBar(self, hp, hpMax)

	if (UnitIsDead(unit)) then
		text:SetText(XPERL_LOC_DEAD)
		sf:SetGrey()
		return
	end

	local healer = pconf.healerMode
	if (issecretvalue(hp) or issecretvalue(hpMax)) then
		-- Restricted (secret) health can't be used in arithmetic, so the client formats it
		if (healer.enable) then
			if (healer.type == 1) then
				text:SetText("-"..AbbreviateNumbers(UnitHealthMissing(unit)).."/"..AbbreviateNumbers(hpMax))
			else
				text:SetText(XPerl_UnitHealthDeficitText(unit))
			end
		else
			text:SetText(XPerl_UnitHealthPercentText(unit))
		end
	elseif (healer.enable) then
		if (healer.type == 1) then
			text:SetFormattedText("%d/%d", hp - hpMax, hpMax)
		else
			text:SetText(hp - hpMax)
		end
	else
		text:SetFormattedText("%.0f%%", hpMax > 0 and (100 * hp / hpMax) or 0)
	end
	text:Show()

	if (sf.greyMana) then
		sf.greyMana = nil
		XPerl_SetManaBarType(self)
	end
end

-- PlaceAuras: below the stats, growing away from the party frame
function PP:PlaceAuras()
	local bf = self.buffFrame
	bf:ClearAllPoints()
	if (pconf.flip) then
		bf:SetPoint("TOPRIGHT", self.statsFrame, "BOTTOMRIGHT", -5, 0)
	else
		bf:SetPoint("TOPLEFT", self.statsFrame, "BOTTOMLEFT", 5, 0)
	end
end

-- GetAuraLineWidth: one line
function PP:GetAuraLineWidth()
end

-- ConfigureAuras: the buffs switch covers the debuffs too; debuffs without a size of their own take the
-- buff size
function PP:ConfigureAuras()
	local c = self.conf
	local opts = XPerl_Auras_UnitOptions(self, {flip = pconf.flip})
	opts.debuffs = setmetatable({
		enable = c.buffs.enable and c.debuffs.enable,
		size = c.debuffs.size or c.buffs.size,
	}, {__index = c.debuffs})
	XPerl_Auras_Configure(self, opts)
end
