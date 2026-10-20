-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Target's target, its target, the focus target and the pet target (XPerl_TargetTarget,
-- XPerl_TargetTargetTarget, XPerl_FocusTarget, XPerl_PetTarget). Their units ("...target") get no unit events,
-- so the frames follow the change events of the unit they hang off (KeyValue `watch`: target, focus or pet)
-- and otherwise refresh on a timer. Everything else comes from Units/UnitFrame.lua.

local UF = XPerl_UnitFrameMixin
XPerl_SetModuleRevision("$Revision$")

XPerl_TargetTargetFrameMixin = {
	elementList = {
		"highlight", "totTarget", "totFocus", "totPet", "name", "level", "power", "health", "combat",
		"statusIcons", "pvp", "range", "auras", "healPrediction", "petBattle",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "levelFrame"},
	flashFrameKeys = {"nameFrame", "levelFrame", "statsFrame"},
	baseWidth = 128,
	optionalPower = true,
	useUnitWatch = true,
	auraOrder = "reaction",
	highlightRatio = 2,
}
local TT = XPerl_TargetTargetFrameMixin

-- Events that point the frame's unit at somebody else
local Define = XPerl_UnitFrame_DefineElement
Define("totTarget",	{events = {PLAYER_TARGET_CHANGED = true, UNIT_TARGET = "target"}, method = "OnUnitChanged", full = false,
	enabled = function(self) return self.watch == "target" end})
Define("totFocus",	{events = {PLAYER_FOCUS_CHANGED = true, UNIT_TARGET = "focus"}, method = "OnUnitChanged", full = false,
	enabled = function(self) return self.watch == "focus" end})
Define("totPet",	{events = {UNIT_PET = "player", UNIT_TARGET = "pet"}, method = "OnUnitChanged", full = false,
	enabled = function(self) return self.watch == "pet" end})

-- OnUnitChanged: somebody else may be behind the frame's unit now
function TT:OnUnitChanged()
	self.lastGUID = nil
	self:UnitChanged()
end

-- UnitChanged: remembers who is shown, so the timer notices the next change
function TT:UnitChanged()
	local guid = UnitGUID(self.partyid)
	self.lastGUID = not issecretvalue(guid) and guid or nil
	UF.UnitChanged(self)
end

-- OnTick (range element: every 0.2 sec): a new unit behind the token (also a new target of the target, which
-- has no event) gets a full unit change, the same unit a refresh of everything shown (no unit events)
function TT:OnTick()
	UF.OnTick(self)
	if (not self.active or not UnitExists(self.partyid)) then
		return
	end
	local guid = UnitGUID(self.partyid)
	if (issecretvalue(guid) or guid ~= self.lastGUID) then
		self:UnitChanged()
	else
		self:UpdateDisplay()
	end
end

-- UpdateLevel: a skull for units far above the player, "Boss" for world bosses
function TT:UpdateLevel()
	UF.UpdateLevel(self)
	local lf = self.levelFrame
	local unit = self.partyid
	if (self.conf.level and UnitLevel(unit) < 0) then
		lf:Show()
		if (UnitClassification(unit) == "worldboss") then
			lf.skull:Hide()
			lf.text:SetText(XPERL_TYPE_BOSS)
			lf.text:SetTextColor(1, 0, 0)
			lf.text:Show()
			lf:SetWidth(lf.text:GetStringWidth() + 6)
		else
			lf.text:Hide()
			lf.skull:Show()
		end
	end
	self:CheckAuraWidth()
end
