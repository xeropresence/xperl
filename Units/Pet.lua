-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Pet frame (XPerl_Player_Pet): shows the player while the player is in a vehicle (the player frame shows the
-- vehicle then), the pet's threat on the player's target, the portrait-side layout with the level box left of
-- the portrait, the optional name bar, and on WoW: Forever the hunter pet's happiness below the level box.
-- Everything else comes from Units/UnitFrame.lua.

local UF = XPerl_UnitFrameMixin
local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

XPerl_PetFrameMixin = {
	elementList = {
		"highlight", "petVehicle", "portrait", "name", "level", "happiness", "power", "health", "statusIcons", "combat",
		"petCombat", "threat", "petThreat", "healPrediction", "combatFeedback", "auras", "castBar", "petBattle",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "portraitFrame", "levelFrame", "happinessFrame"},
	flashFrameKeys = {"nameFrame", "levelFrame", "statsFrame", "portraitFrame"},
	statsOffset = 2,
	exactPowerText = true,
	useUnitWatch = true,
	highlightRatio = 2,
}
local P = XPerl_PetFrameMixin
P.GetTargetInfo = UF.ShownUnitTargetInfo	-- pings the player while in a vehicle (the "unit" attribute stays "pet")

local Define = XPerl_UnitFrame_DefineElement
Define("petVehicle",	{events = {UNIT_ENTERED_VEHICLE = "player", UNIT_EXITED_VEHICLE = "player", UNIT_PET = "player", PLAYER_ENTERING_WORLD = true}, method = "UpdateVehicle", full = false})
Define("petCombat",	{events = {PET_ATTACK_START = true, PET_ATTACK_STOP = true}, method = "UpdateStatusIcons", full = false})
-- The pet's threat is measured on the player's target
Define("petThreat",	{events = {UNIT_THREAT_LIST_UPDATE = "target", PLAYER_TARGET_CHANGED = true}, method = "UpdateThreat", full = false})
-- WoW: Forever's hunter pet happiness. Blizzard's indicator follows UNIT_HAPPINESS and UNIT_PET itself; the
-- frame refreshes it along with the unit.
Define("happiness",	{method = "UpdateHappiness", enabled = function(self) return self.happinessFrame ~= nil end,
	init = function(self) if (XPerlAPI.isForever) then self:CreateHappiness() end end})

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

-- InitType
function P:InitType()
	local nf = self.nameFrame

	-- In a vehicle the secure templates resolve "pet" to the player, as this frame shows then
	self:SetAttribute("toggleForVehicle", true)
	nf:SetAttribute("toggleForVehicle", true)

	local text = nf.text
	text:SetFontObject(GameFontNormalSmall)
	text:SetJustifyH("LEFT")
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", nf, "TOPLEFT", 6, 0)
	text:SetPoint("BOTTOMRIGHT", nf, "BOTTOMRIGHT", 0, 1)
end

-- CreateHappiness: Blizzard's happiness indicator (PetFrameHappinessTemplate: icon, tooltip with damage,
-- loyalty and diet) in an X-Perl box. The indicator hides itself without a hunter pet, and the box goes with it.
function P:CreateHappiness()
	local hf = CreateFrame("Frame", nil, self, "XPerl_BorderStyleTemplate")
	hf:SetSize(34, 34)
	hf:Hide()
	local indicator = CreateFrame("Frame", nil, hf, "PetFrameHappinessTemplate")
	indicator:SetPoint("CENTER")
	hooksecurefunc(indicator, "UpdateHappiness", function(ind) hf:SetShown(ind:IsShown()) end)
	hf.indicator = indicator
	self.happinessFrame = hf
end

-- ApplySize(width): the name and stats bars
function P:ApplySize(width)
	self.nameFrame:SetWidth(80 + width)
	self.statsFrame:SetWidth(80 + width)
end

-- ApplyTypeSettings: portrait size, the optional name bar, the level and happiness boxes beside the portrait
-- (or the stats), the highlight area and the frame's own size
function P:ApplyTypeSettings()
	local c = self.conf
	local pf, nf, sf, lf = self.portraitFrame, self.nameFrame, self.statsFrame, self.levelFrame

	pf:SetWidth(c.portrait and 50 or 3)
	pf:SetHeight(c.extendPortrait and 66 or 56)

	nf:SetShown(c.name and true or false)
	nf:SetHeight(c.name and 24 or 2)

	local beside = (c.name or c.portrait) and pf or sf
	lf:ClearAllPoints()
	lf:SetPoint("TOPRIGHT", beside, "TOPLEFT", 2, 0)

	-- Happiness at the bottom of the portrait side, else left of the level box sharing the stats' side
	local hf = self.happinessFrame
	if (hf) then
		hf:ClearAllPoints()
		if (beside == pf) then
			hf:SetPoint("BOTTOMRIGHT", pf, "BOTTOMLEFT", 2, 0)
		elseif (c.level) then
			hf:SetPoint("TOPRIGHT", lf, "TOPLEFT", 2, 0)
		else
			hf:SetPoint("TOPRIGHT", sf, "TOPLEFT", 2, 0)
		end
	end

	local hl = self.highlight
	hl:ClearAllPoints()
	hl:SetPoint("BOTTOMLEFT", beside, "BOTTOMLEFT", 0, 0)
	hl:SetPoint("TOPRIGHT", nf, "TOPRIGHT", 0, 0)

	self:SetWidth(pf:GetWidth() - 3 + nf:GetWidth())
	self:SetHeight(max(nf:GetHeight() + sf:GetHeight() - 2, c.portrait and pf:GetHeight() or 0))
end

-- OnShow: Feed-O-Matic's feed button follows the pet frame
function P:OnShow()
	UF.OnShow(self)
	if (FOM_FeedButton and Set_FOM_FeedButton) then
		XPerl_ProtectedCall(Set_FOM_FeedButton)
	end
end

------------------------------------------------------------------------------
-- Unit
------------------------------------------------------------------------------

-- UpdateVehicle: the frame shows the player while the player is in a vehicle, else the pet; a new pet
-- (UNIT_PET) or a zone change refreshes it
function P:UpdateVehicle(event, _, showVehicle)
	local inVehicle
	if (event == "UNIT_ENTERED_VEHICLE" and not issecretvalue(showVehicle)) then
		inVehicle = showVehicle
	elseif (event == "UNIT_EXITED_VEHICLE") then
		inVehicle = false
	else
		inVehicle = UnitHasVehicleUI("player")
	end

	local newUnit = inVehicle and "player" or "pet"
	if (newUnit ~= self.partyid) then
		self:SetUnit(newUnit)
	else
		self:UnitChanged()
	end
end

-- UpdateName: a pet without a name yet shows none
function P:UpdateName()
	local name = UnitName(self.partyid)
	if (not issecretvalue(name) and name == UNKNOWN) then
		name = ""
	end
	self.nameFrame.text:SetText(name)
	self:UpdateNameColour()
end

-- UpdateNameColour: the pet's name in the neutral reaction colour; while the frame shows the player (in a
-- vehicle), the hostile colour if the vehicle is not friendly, else the player's friendly colour
function P:UpdateNameColour()
	local text = self.nameFrame.text
	local c
	if (self.partyid == "pet") then
		c = conf.colour.reaction.none
	else
		local friend = UnitIsFriend("player", "pet")
		if (not issecretvalue(friend) and not friend) then
			c = conf.colour.reaction.enemy
		else
			XPerl_ColourFriendlyUnit(text, self.partyid)
			return
		end
	end
	text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
end

-- UpdateCombat: the charmed warning (not for the player while in a vehicle); a charm also changes the name colour
function P:UpdateCombat(...)
	UF.UpdateCombat(self, ...)
	if (self.partyid ~= "pet") then
		self.nameFrame.warningIcon:Hide()
	end
	self:UpdateNameColour()
end

-- UpdateThreat: the gauge jumps to the new value when the player changes target
function P:UpdateThreat(event)
	XPerl_Unit_ThreatStatus(self, nil, not event or event == "PLAYER_TARGET_CHANGED")
end

-- UpdateHappiness
function P:UpdateHappiness()
	self.happinessFrame.indicator:UpdateHappiness()
end

------------------------------------------------------------------------------
-- Auras
------------------------------------------------------------------------------

-- PlaceAuras: above the portrait (or name), or below the portrait unless it is shorter than the stats
function P:PlaceAuras()
	local c, bf = self.conf, self.buffFrame
	bf:ClearAllPoints()
	if (c.buffs.above) then
		bf:SetPoint("BOTTOMLEFT", c.portrait and self.portraitFrame or self.nameFrame, "TOPLEFT", 3, 0)
	elseif (not c.extendPortrait and (not c.portrait or not c.name)) then
		bf:SetPoint("TOPLEFT", self.statsFrame, "BOTTOMLEFT", 3, 0)
	else
		bf:SetPoint("TOPLEFT", self.portraitFrame, "BOTTOMLEFT", 3, 0)
	end
end

-- GetAuraLineWidth: wrapped rows span the stats and the portrait (the level box sits outside the frame)
function P:GetAuraLineWidth()
	if (not self.conf.buffs.wrap) then
		return nil
	end
	local w = self.statsFrame:GetWidth()
	if (self.portraitFrame:IsShown()) then
		w = w - 2 + self.portraitFrame:GetWidth()
	end
	return w
end
