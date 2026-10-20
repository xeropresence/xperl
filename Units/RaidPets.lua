-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Raid pets: the pet header XPerl_Raid_GrpPets below its title XPerl_Raid_TitlePets, with compact buttons on
-- the shared framework (name, or <owner> while the owner is in a vehicle, in the owner's class colour, and
-- health). Anchor, spacing, scale and titles follow the raid settings (Units/Raid.lua); raidpet.alignToRaid
-- puts the pets beside the last raid group in use, raidpet.hunter/warlock limit them to those owners.

local _, ns = ...
local Raid = ns.Raid
local conf, pconf, rconf
XPerl_RequestConfig(function(new)
	conf = new
	pconf = new.raidpet
	rconf = new.raid
end, "$Revision$")

local previewing		-- Edit Mode or the options window's unlock shows the placeholder

local function Plain(value)
	if (issecretvalue(value)) then
		return nil
	end
	return value
end

-- Enabled: raid pets need the raid frames
local function Enabled()
	return (rconf.enable and pconf.enable) and true or false
end

-- PetFilter: pets of every owner, or (raidpet.hunter / raidpet.warlock) only of hunters or warlocks
local function PetFilter()
	if (pconf.hunter and pconf.warlock) then
		return nil
	end
	local list = {}
	if (pconf.hunter) then
		list[#list + 1] = "HUNTER"
	end
	if (pconf.warlock) then
		list[#list + 1] = "WARLOCK"
	end
	return table.concat(list, ",")
end

-- RefreshTitle: title text and placeholder. Not protected.
local function RefreshTitle()
	local title = XPerl_Raid_TitlePets
	if (not pconf) then
		return
	end
	title.text:SetText(PETS)
	local enabled = Enabled()
	local preview = previewing and enabled
	local first = XPerl_Raid_GrpPetsUnitButton1
	local used = enabled and Raid.Shown() and rconf.titles and first and first:IsShown()
	title.text:SetShown((preview or used) and true or false)
	local unlocked = XPerlLocked == 0 and not XPerl_EditMode_IsEditing()
	Raid.LayoutPlaceholder(title, 6, 30, preview, preview and unlocked and not pconf.alignToRaid)
end

-- Preview(on): the title's Edit Mode / unlock preview
local function Preview(on)
	previewing = on and true or false
	RefreshTitle()
end

-- Align: beside the last raid title in use (raidpet.alignToRaid), else where Edit Mode puts it (protected)
local function Align()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(Align)
		return
	end
	local title = XPerl_Raid_TitlePets
	if (not title.editModeRegistered) then
		return
	end
	local aligned = pconf.alignToRaid and true or false
	XPerl_EditMode_SetEnabled(title, Enabled() and not aligned)
	if (aligned) then
		local relative = Raid.LastUsedTitle()
		if (relative) then
			title:ClearAllPoints()
			title:SetPoint("TOPLEFT", relative, "TOPRIGHT", rconf.spacing or 0, 0)
		end
	end
end

-- ApplyPets: header attributes, scale, Edit Mode registration, alignment, visibility (protected)
local function ApplyPets()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ApplyPets)
		return
	end
	local title, header = XPerl_Raid_TitlePets, XPerl_Raid_GrpPets
	local enabled = Enabled()

	header:Hide()		-- one re-layout after all the attribute changes
	header:SetAttribute("groupFilter", PetFilter())
	Raid.LayoutHeader(header)

	local scale = rconf.scale or 0.8
	if (title:GetScale() ~= scale) then
		title:SetScale(scale)
		XPerl_EditMode_ApplyPosition(title)
	end

	if (enabled and not title.editModeRegistered) then
		title.editModeRegistered = true
		XPerl_EditMode_Register(title, "raidpet", {
			label = RAID.." "..PETS,
			default = {point = "TOPLEFT", x = 720, y = -465},
			preview = Preview,
		})
	end
	Align()

	title:SetShown(enabled)
	header:SetShown(enabled and Raid.Shown())
	RefreshTitle()
end

-- ShowHeader: the raid's visibility changed with the roster or the zone (protected)
local function ShowHeader()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ShowHeader)
		return
	end
	XPerl_Raid_GrpPets:SetShown(Enabled() and Raid.Shown())
end

-- Pets come and go without roster changes; the header shows them by itself, the title text follows on
-- the next video frame
local eventFrame = CreateFrame("Frame")
eventFrame:Hide()
eventFrame:SetScript("OnUpdate", function(self)
	self:Hide()
	RefreshTitle()
end)
eventFrame:SetScript("OnEvent", function(self)
	self:Show()
end)

-- ApplyModule (registered option changer)
local function ApplyModule()
	if (not pconf) then
		return
	end
	if (Enabled()) then
		eventFrame:RegisterEvent("UNIT_PET")
	else
		eventFrame:UnregisterEvent("UNIT_PET")
	end
	ApplyPets()
end
XPerl_RegisterOptionChanger(ApplyModule)

ns.RaidPets = {
	Apply = ApplyModule,
	-- Called by Units/Raid.lua on the video frame after roster changes
	RosterChanged = function()
		if (pconf) then
			ShowHeader()
			Align()
			RefreshTitle()
		end
	end,
}

------------------------------------------------------------------------------
-- Raid pet buttons
------------------------------------------------------------------------------

local Define = XPerl_UnitFrame_DefineElement
Define("petOwnerVehicle", {events = {UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true}, method = "UpdateName", full = false})

local RaidMixin = XPerl_RaidFrameMixin
XPerl_RaidPetFrameMixin = {
	elementList = {"name", "health", "petOwnerVehicle", "statusIcons", "range", "highlight", "healPrediction", "groupRoster"},
	flashFrameKeys = {"nameFrame"},
	highlightRatio = 2,
	statusIconSize = RaidMixin.statusIconSize,
	edgeFile = RaidMixin.edgeFile,
	edgeSize = RaidMixin.edgeSize,
	edgeInsets = RaidMixin.edgeInsets,
	-- Shared with the raid buttons: no dragging (the title moves the group), roster changes, range
	OnDragStart = RaidMixin.OnDragStart,
	OnDragStop = RaidMixin.OnDragStop,
	OnRosterChanged = RaidMixin.OnRosterChanged,
	UpdateRange = RaidMixin.UpdateRange,
}
local P = XPerl_RaidPetFrameMixin

-- InitType: the name sits above the health bar
function P:InitType()
	local text = self.nameFrame.text
	text:SetFontObject(GameFontNormalSmall)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", 2, -3)
	text:SetPoint("BOTTOMRIGHT", self.nameFrame, "TOPRIGHT", -2, -9)
end

-- SetEnabled: only with the raid frames (also when XPerl_UnitFrames_ApplyEnableFlags switches them)
function P:SetEnabled(on)
	XPerl_UnitFrameMixin.SetEnabled(self, on and rconf and rconf.enable)
end

-- ApplySettings: header children have nothing protected to apply
function P:ApplySettings()
	local c = self.conf
	if (not c) then
		return
	end
	self:SetEnabled(c.enable)
	if (not self.active) then
		return
	end
	self:ApplyElements()
	XPerl_ApplyFrameBackdrop(self)
	if (self:IsShown()) then
		self:UpdateDisplay()
	end
end

-- UnitChanged: the owner's unit ("raid5" for "raidpet5")
function P:UnitChanged()
	local unit = self.partyid
	self.ownerUnit = unit and (gsub(unit, "^(%a+)pet(%d+)$", "%1%2"))
	self.unitGUID = unit and Plain(UnitGUID(unit))
	XPerl_UnitFrameMixin.UnitChanged(self)
end

-- UpdateName: the pet's name, or <owner> while the owner is in a vehicle; owner's class colour
function P:UpdateName()
	local owner, text = self.ownerUnit, self.nameFrame.text
	if (not self.partyid) then
		return
	end
	local ownerName
	if (owner and ((UnitInVehicle and Plain(UnitInVehicle(owner))) or (UnitHasVehicleUI and Plain(UnitHasVehicleUI(owner))))) then
		ownerName = Plain(UnitName(owner))
	end
	if (ownerName) then
		text:SetFormattedText("<%s>", ownerName)
	else
		text:SetText(UnitName(self.partyid))
	end

	local c = XPerl_GetClassColour(owner and Plain(select(2, UnitClass(owner))))
	text:SetTextColor(c.r, c.g, c.b, conf.transparency.text)
end

-- UpdateHealth: bar in the health colour, percentage or "dead"
function P:UpdateHealth()
	local unit = self.partyid
	local bar = self.statsFrame.healthBar
	local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
	-- Restricted (secret) health can't be compared or divided: the client colours the bar and formats the text
	local secret = issecretvalue(health) or issecretvalue(healthMax)
	if (not secret and health > healthMax) then
		health = UnitIsDeadOrGhost(unit) and 0 or healthMax
	end

	bar:SetMinMaxValues(0, healthMax)
	if (not conf.bar.inverse) then
		bar:SetValue(health)
	elseif (secret) then
		bar:SetValue(UnitHealthMissing(unit))
	else
		bar:SetValue(healthMax - health)
	end
	self:UpdateHealPrediction()

	local fraction
	if (secret) then
		XPerl_SetSmoothBarColorFromUnit(bar, unit)
	else
		fraction = healthMax == 0 and 0 or health / healthMax
		XPerl_SetSmoothBarColor(bar, fraction)
	end

	if (UnitIsDead(unit)) then
		bar.text:SetText(XPERL_LOC_DEAD)
	elseif (secret) then
		bar.text:SetText(XPerl_UnitHealthPercentText(unit))
	elseif (healthMax == 0) then
		bar.text:SetText("")
	else
		bar.text:SetFormattedText("%.0f%%", fraction * 100)
	end
end
