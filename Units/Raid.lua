-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Raid frames: the group headers XPerl_Raid_Grp1-13 below their titles XPerl_Raid_Title1-13 show raid
-- groups, class columns or role-sorted slices of five. Their buttons are compact unit frames on the shared
-- framework (Units/UnitFrame.lua) with their own layout: health text modes, a mana bar made on demand,
-- buffs or debuffs beside or below, role and raid target icons, status texts. The XPerl_Roster cache keeps
-- AFK/DND/offline times, resurrections and CTRA versions for the tooltip and the status texts.
-- Raid pets (Units/RaidPets.lua) share the titles, scale, anchor and spacing.

local _, ns = ...
local UF = XPerl_UnitFrameMixin
local conf, rconf

local WoWclassCount = XPERL_RAID_CLASS_COUNT	-- class columns, one title/header pair each (XPerl.lua)
local MAX_GROUPS = 8				-- raid groups, and role-sorted slices of five for 40 members

local titles = {}		-- XPerl_Raid_Title1-13 by id
local groupCounts = {}		-- members each header shows, from the roster
local myGroup = 0
local ResArray = {}		-- [resser's name] = name of the unit being resurrected
local auraOpts			-- aura row settings shared by every raid button, see RaidAuraOptions
local previewing		-- Edit Mode or the options window's unlock shows the placeholders
local blizzRaidHidden
local rosterChecked		-- the saved roster was checked against the group after login

local percF = "%.1f"..PERCENT_SYMBOL
local percD = "%d"..PERCENT_SYMBOL

-- Restricted (secret) health and power percentages, 0 to 100, from the client (raid.precisionPercent)
local percentCurve = C_CurveUtil.CreateCurve()
percentCurve:AddPoint(0, 0)
percentCurve:AddPoint(1, 100)

local UnitIsAFK = XPerlAPI.UnitIsAFK			-- secret-safe unit flags, see XPerl_Api.lua
local UnitIsDND = XPerlAPI.UnitIsDND

-- Shared with Units/RaidPets.lua
local Raid = {titles = titles}
ns.Raid = Raid

-- Raid roster information (AFK, DND, offline times, resurrections, CTRA versions), saved per character so
-- the timers survive a reload
XPerl_Roster = {}

C_ChatInfo.RegisterAddonMessagePrefix("CTRA")

-- Plain(value): nil for a restricted (secret) value, which can't even be tested
local function Plain(value)
	if (issecretvalue(value)) then
		return nil
	end
	return value
end

-- RosterName(unit): the unit's name as the raid roster has it ("Name-Realm" for other realms)
local function RosterName(unit)
	return Plain(GetUnitName(unit, true))
end

XPerl_RequestConfig(function(new)
	conf = new
	rconf = new.raid
	if (rconf) then
		XPerl_ValidateRaidClasses(rconf)	-- settings saved before Demon Hunters/Evokers lack their class columns

		-- Blizzard's raid frames (CompactRaidFrameContainer) go while ours are enabled; the
		-- CompactRaidFrameManager (raid tools, markers) stays usable. XPerl_BlizzFrameDisable is gone after
		-- PLAYER_LOGIN, so this only follows the settings in use at login.
		if (rconf.enable and not blizzRaidHidden and XPerl_BlizzFrameDisable and CompactRaidFrameContainer) then
			blizzRaidHidden = true
			if (CompactUnitFrameProfiles) then
				CompactUnitFrameProfiles:UnregisterAllEvents()	-- profile changes would rebuild the Blizzard raid frames
			end
			XPerl_BlizzFrameDisable(CompactRaidFrameContainer)
		end
	end
end, "$Revision$")

------------------------------------------------------------------------------
-- Sorting, visibility
------------------------------------------------------------------------------

-- SortMode: class columns win over role slices (the options window greys out one while the other is on)
local function SortMode()
	if (rconf.sortByClass) then
		return "class"
	elseif (rconf.sortByRole) then
		return "role"
	end
	return "group"
end

-- HeaderCount: headers in use, a column per class or one per group / role slice
local function HeaderCount()
	return rconf.sortByClass and WoWclassCount or MAX_GROUPS
end

-- Raid.Shown(): raid frames are enabled, not hidden in battlegrounds and not left to the party frames
-- (party frames switched on with party.smallRaid while the whole raid is in group 1)
function Raid.Shown()
	if (not rconf.enable) then
		return false
	end
	if (rconf.notInBG and select(2, IsInInstance()) == "pvp") then
		return false
	end
	if (conf.party.enable and conf.party.smallRaid and XPerl_Party_SingleGroup()) then
		return false
	end
	return true
end

-- HeaderUsed(i): whether header i shows anybody with the current settings
local function HeaderUsed(i, mode)
	return i <= HeaderCount() and (mode ~= "group" or rconf.group[i]) and true or false
end

-- CountMembers: members per header, for the titles and the raid pets' alignment
local function CountMembers()
	for i = 1, WoWclassCount do
		groupCounts[i] = 0
	end
	myGroup = 0
	if (not IsInRaid()) then
		return
	end

	local mode = SortMode()
	local total = GetNumGroupMembers()
	for i = 1, total do
		local name, _, group, _, _, class = GetRaidRosterInfo(i)
		if (name) then
			if (Plain(UnitIsUnit("raid"..i, "player"))) then
				myGroup = group
			end
			if (mode == "class") then
				for j = 1, WoWclassCount do
					local column = rconf.class[j]
					if (column.name == class) then
						if (column.enable) then
							groupCounts[j] = groupCounts[j] + 1
						end
						break
					end
				end
			elseif (mode == "group" and groupCounts[group]) then
				groupCounts[group] = groupCounts[group] + 1
			end
		end
	end
	if (mode == "role") then
		for i = 1, MAX_GROUPS do
			groupCounts[i] = max(0, min(5, total - (i - 1) * 5))
		end
	end
end

-- Raid.LastUsedTitle(): the right-most title showing anybody (the raid pets line up beside it)
function Raid.LastUsedTitle()
	if (not Raid.Shown()) then
		return
	end
	local mode = SortMode()
	for i = HeaderCount(), 1, -1 do
		if (groupCounts[i] > 0 and HeaderUsed(i, mode)) then
			return titles[i]
		end
	end
end

------------------------------------------------------------------------------
-- Headers and titles
------------------------------------------------------------------------------

-- Header point, title point, x and y spacing direction per raid.anchor
local anchors = {
	TOP	= {"TOPLEFT", "BOTTOMLEFT", 0, -1},
	LEFT	= {"TOPLEFT", "BOTTOMLEFT", 1, 0},
	BOTTOM	= {"BOTTOMLEFT", "TOPLEFT", 0, 1},
	RIGHT	= {"TOPRIGHT", "BOTTOMRIGHT", -1, 0},
}

local function Anchor()
	return anchors[rconf.anchor] and rconf.anchor or "TOP"
end

-- Raid.LayoutHeader(header): growth direction and spacing from raid.anchor/spacing, below or above its title
function Raid.LayoutHeader(header)
	local anchor = Anchor()
	local a = anchors[anchor]
	local spacing = rconf.spacing or 0
	header:SetAttribute("point", anchor)
	header:SetAttribute("xOffset", a[3] * spacing)
	header:SetAttribute("yOffset", a[4] * spacing)
	header:ClearAllPoints()
	header:SetPoint(a[1], header:GetParent(), a[2], 0, 0)
end

-- GroupFilter(i): a group header shows its group, limited to the enabled classes; a class column its class
local function GroupFilter(i, mode)
	if (mode == "class") then
		local column = rconf.class[i]
		return column.enable and column.name or ""
	end
	if (not rconf.group[i]) then
		return ""
	end
	local list = {tostring(i)}
	for j = 1, WoWclassCount do
		local column = rconf.class[j]
		if (column.enable) then
			list[#list + 1] = column.name
		end
	end
	return table.concat(list, ",")
end

-- ConfigureHeader(header, i, mode)
local function ConfigureHeader(header, i, mode)
	header:SetAttribute("sortMethod", rconf.sortAlpha and "NAME" or nil)
	if (mode == "role") then
		header:SetAttribute("groupBy", "ASSIGNEDROLE")
		header:SetAttribute("groupingOrder", "TANK,HEALER,DAMAGER,NONE")
		header:SetAttribute("startingIndex", (i - 1) * 5 + 1)
		header:SetAttribute("unitsPerColumn", 5)
		header:SetAttribute("strictFiltering", nil)
		header:SetAttribute("groupFilter", nil)
	else
		header:SetAttribute("groupBy", nil)
		header:SetAttribute("groupingOrder", nil)
		header:SetAttribute("startingIndex", 1)
		header:SetAttribute("unitsPerColumn", nil)
		header:SetAttribute("strictFiltering", mode == "group")
		header:SetAttribute("groupFilter", GroupFilter(i, mode))
	end
	Raid.LayoutHeader(header)
end

-- PlaceSelection(title, anchor)
-- The Edit Mode selection covers the title and its group (the placeholder), wherever the group grows
local LEM = LibStub("LibEditMode")
local function PlaceSelection(title, anchor)
	local selection = LEM.frameSelections[title]
	if (not selection) then
		return
	end
	local v = title.virtual
	selection:ClearAllPoints()
	if (anchor == "BOTTOM") then
		selection:SetPoint("TOPLEFT", v, "TOPLEFT")
		selection:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT")
	elseif (anchor == "RIGHT") then
		selection:SetPoint("TOPRIGHT", title, "TOPRIGHT")
		selection:SetPoint("BOTTOMLEFT", v, "BOTTOMLEFT")
	else
		selection:SetPoint("TOPLEFT", title, "TOPLEFT")
		selection:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT")
	end
	selection:SetFrameLevel(title:GetFrameLevel() + 10)	-- above the group's buttons
end

-- Raid.LayoutPlaceholder(title, rows, buttonHeight, show, mouse)
-- Sizes a title's placeholder to `rows` buttons of 80 x buttonHeight laid out as the header does it, shows it
-- (Edit Mode, unlocked frames) and lets it drag the title (unlocked frames only). Not protected.
function Raid.LayoutPlaceholder(title, rows, buttonHeight, show, mouse)
	local v = title.virtual
	local anchor = Anchor()
	local a = anchors[anchor]
	local spacing = rconf.spacing or 0
	v:ClearAllPoints()
	v:SetPoint(a[1], title, a[2], 0, 0)
	if (a[3] == 0) then
		v:SetSize(80, max(1, rows * buttonHeight + spacing * (rows - 1)))
	else
		v:SetSize(max(1, rows * 80 + spacing * (rows - 1)), buttonHeight)
	end
	local c, b = conf.colour.frame, conf.colour.border
	v:SetBackdropColor(c.r, c.g, c.b, c.a)
	v:SetBackdropBorderColor(b.r, b.g, b.b, 1)
	v:SetShown(show and true or false)
	v:EnableMouse(mouse and true or false)
	title.titleFrame:EnableMouse(mouse and true or false)
	PlaceSelection(title, anchor)
end

-- RefreshTitles: texts, colours and placeholders. The Edit Mode / unlocked preview shows all 13 titles, the ones
-- the sort mode doesn't use too, so they can be placed before a sort mode with more columns uses them (as the
-- unlocked frames always did). Not protected.
local function RefreshTitles()
	if (not rconf) then
		return
	end
	local mode = SortMode()
	local shown = Raid.Shown()
	local unlocked = XPerlLocked == 0 and not XPerl_EditMode_IsEditing()
	local buttonHeight = rconf.mana and 43 or 38
	for i = 1, WoWclassCount do
		local title = titles[i]
		local text = title.text
		if (mode == "class") then
			local class = rconf.class[i].name
			text:SetText(LOCALIZED_CLASS_NAMES_MALE[class] or class)
		else
			text:SetFormattedText(XPERL_RAID_GROUP, i)
		end
		local c = (mode == "group" and myGroup == i) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
		text:SetTextColor(c.r, c.g, c.b)

		local preview = previewing and rconf.enable
		text:SetShown(preview or (shown and rconf.titles and groupCounts[i] > 0 and HeaderUsed(i, mode)) or false)

		local rows = mode == "class" and max(5, groupCounts[i]) or 5
		Raid.LayoutPlaceholder(title, rows, buttonHeight, preview, preview and unlocked)
	end
end
Raid.RefreshTitles = RefreshTitles

-- Raid.Preview(on): the titles' Edit Mode / unlock preview (one call per title; idempotent)
local function Preview(on)
	on = on and true or false
	if (on ~= (previewing or false)) then
		previewing = on
		RefreshTitles()
	end
end
function Raid.Previewing()
	return previewing
end

-- RegisterTitles: every title is a selectable Edit Mode frame while the raid frames are enabled. Groups 2-13
-- follow group 1 while linked (XPerl_EditMode.lua).
local function RegisterTitles()
	for i = 1, WoWclassCount do
		local title = titles[i]
		if (rconf.enable and not title.editModeRegistered) then
			title.editModeRegistered = true
			XPerl_EditMode_Register(title, "raid", {
				label = RAID.." "..format(XPERL_RAID_GROUP, i),
				index = i,
				default = {point = "TOPLEFT", x = 76 * (i - 1), y = -465},
				preview = Preview,
				leader = i > 1 and titles[1] or nil,
			})
		end
		if (title.editModeRegistered) then
			XPerl_EditMode_SetEnabled(title, rconf.enable)
		end
	end
end

-- ShowHeaders: which headers are shown (protected)
local function ShowHeaders()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ShowHeaders)
		return
	end
	local mode = SortMode()
	local shown = Raid.Shown()
	for i = 1, WoWclassCount do
		titles[i].header:SetShown(shown and HeaderUsed(i, mode))
	end
end

-- ApplyHeaders: scale, header attributes, Edit Mode registration, visibility (protected)
local function ApplyHeaders()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ApplyHeaders)
		return
	end
	XPerl_ValidateRaidClasses(rconf)		-- class columns can be out of date after a settings swap

	local mode = SortMode()
	local scale = rconf.scale or 0.8
	for i = 1, WoWclassCount do
		local title = titles[i]
		local header = title.header
		header:Hide()		-- one re-layout after all the attribute changes, instead of one per attribute
		ConfigureHeader(header, i, mode)
		if (title:GetScale() ~= scale) then
			title:SetScale(scale)
			XPerl_EditMode_ApplyPosition(title)
		end
	end
	RegisterTitles()
	ShowHeaders()
end

------------------------------------------------------------------------------
-- Raid roster
------------------------------------------------------------------------------

-- ForRaidButtons(func): func(frame) for every active raid button that has a unit
local function ForRaidButtons(func)
	XPerl_ForEachUnitFrame(function(frame)
		if (frame.frameKey == "raid" and frame.active and frame.partyid) then
			func(frame)
		end
	end)
end

-- UpdateRoster: XPerl_Roster follows the raid (keeping the entries of those still in it)
local function UpdateRoster()
	if (not IsInRaid()) then
		wipe(ResArray)
		wipe(XPerl_Roster)
		return
	end

	local now = GetTime()
	local newRoster = {}
	for i = 1, GetNumGroupMembers() do
		local name = GetRaidRosterInfo(i)
		if (name) then
			local unit = "raid"..i
			local entry = XPerl_Roster[name] or {}
			entry.afk = UnitIsAFK(unit) and (entry.afk or now) or nil
			entry.dnd = UnitIsDND(unit) and (entry.dnd or now) or nil
			newRoster[name] = entry
		end
	end
	wipe(XPerl_Roster)
	for name, entry in pairs(newRoster) do
		XPerl_Roster[name] = entry
	end
end

-- RosterChanged: many roster updates can come in one video frame, so they're handled once, on the next one
local eventFrame = CreateFrame("Frame")
eventFrame:Hide()
eventFrame:SetScript("OnUpdate", function(self)
	self:Hide()
	UpdateRoster()
	CountMembers()
	RefreshTitles()
	ShowHeaders()
	if (ns.RaidPets) then
		ns.RaidPets.RosterChanged()
	end
end)

-- UpdateUnitByName(name): redraws the status of the raid button showing that member
local function UpdateUnitByName(name)
	ForRaidButtons(function(frame)
		if (RosterName(frame.partyid) == name) then
			frame:UpdateHealth()
		end
	end)
end

local resSpells = XPerlAPI.SpellNameMap({
	[2006] = true,			-- Resurrection
	[2008] = true,			-- Ancestral Spirit
	[20484] = true,			-- Rebirth
	[7328] = true,			-- Redemption
	[50769] = true,			-- Revive
	[83968] = true,			-- Mass Resurrection
})

-- SetResStatus(resser, target, ignoreCounter)
-- With a target: resser started resurrecting target. Without: resser's cast ended (counted as a
-- resurrection unless ignoreCounter, for failed or interrupted casts).
local function SetResStatus(resser, target, ignoreCounter)
	local ended
	if (target) then
		ResArray[resser] = target
	else
		ended = true
		target = ResArray[resser]
		ResArray[resser] = nil
	end

	local entry = target and XPerl_Roster[target]
	if (entry) then
		if (ended and not ignoreCounter) then
			entry.ressed = 1
			entry.resCount = (entry.resCount or 0) + 1
		end
		UpdateUnitByName(target)
	end
end

-- RaidCaster(unit): the roster name of the caster behind a spellcast event's unit, for raid members only.
-- Event units can be secret in restricted content, and those can't be matched.
local function RaidCaster(unit)
	if (not issecretvalue(unit) and strmatch(unit, "^raid%d+$")) then
		return RosterName(unit)
	end
end

-- DurabilityCheck(author)
-- Answers a CTRA durability check for those without CTRA
local DurabilityCheck
do
	local tip
	function DurabilityCheck(author)
		local durPattern = gsub(DURABILITY_TEMPLATE, "(%%%d-$-d)", "(%%d+)")
		local cur, maxDur, broken = 0, 0, 0
		if (not tip) then
			tip = CreateFrame("GameTooltip", "XPerlDurCheckTooltip", nil, "GameTooltipTemplate")
		end

		tip:SetOwner(UIParent, "ANCHOR_NONE")
		for i = 1, 18 do
			if (GetInventoryItemBroken("player", i)) then
				broken = broken + 1
			end

			tip:ClearLines()
			tip:SetInventoryItem("player", i)
			for j = 1, tip:NumLines() do
				local line = _G[tip:GetName().."TextLeft"..j]
				local text = line and line:GetText()
				if (text and not issecretvalue(text)) then
					local imin, imax = strmatch(text, durPattern)
					if (imin and imax) then
						cur = cur + tonumber(imin)
						maxDur = maxDur + tonumber(imax)
						break
					end
				end
			end
		end
		tip:Hide()

		C_ChatInfo.SendAddonMessage("CTRA", format("DUR %s %s %s %s", cur, maxDur, broken, author), "RAID")
	end
end

-- ItemCheckCount(itemName, author): answers a CTRA item count check
local function ItemCheckCount(itemName, author)
	local count = C_Item.GetItemCount(itemName)
	if (count and count > 0) then
		C_ChatInfo.SendAddonMessage("CTRA", "ITM "..count.." "..itemName.." "..author, "RAID")
	end
end

-- ProcessCTRAMessage(name, msg)
local function ProcessCTRAMessage(name, msg)
	local entry = XPerl_Roster[name]
	if (not entry) then
		return
	end

	local update = true
	if (msg == "RESNO") then
		SetResStatus(name)
	elseif (strsub(msg, 1, 4) == "RES ") then
		SetResStatus(name, strsub(msg, 5))
		return
	elseif (strsub(msg, 1, 2) == "V ") then
		entry.version = strsub(msg, 3)
		update = nil
	elseif (msg == "DURC") then
		if (not CT_RA_VersionNumber) then
			DurabilityCheck(name)
		end
	elseif (strsub(msg, 1, 4) == "ITMC") then
		if (not CT_RA_VersionNumber) then
			local itemName = strmatch(msg, "^ITMC (.+)$")
			if (itemName) then
				ItemCheckCount(itemName, name)
			end
		end
	else
		update = nil
	end

	if (update) then
		UpdateUnitByName(name)
	end
end

-- Event handlers of the raid module (registered while the raid frames are enabled)
local events = {}

function events:GROUP_ROSTER_UPDATE()
	self:Show()
end

function events:PLAYER_ENTERING_WORLD()
	if (not rosterChecked) then
		rosterChecked = true
		if (IsInRaid()) then
			local entry = XPerl_Roster[RosterName("player")]
			if (entry) then
				entry.afk, entry.dnd, entry.ressed, entry.resCount = nil, nil, nil, nil
			end
		end
	end
	-- Battlegrounds (raid.notInBG) and events missed while zoning
	self:Show()
	ForRaidButtons(UF.UpdateDisplay)
end

function events:PLAYER_FLAGS_CHANGED(unit)
	local entry = unit and XPerl_Roster[RosterName(unit)]
	if (entry) then
		if (UnitIsAFK(unit)) then
			entry.afk = entry.afk or GetTime()
			entry.dnd = nil
		elseif (UnitIsDND(unit)) then
			entry.dnd = entry.dnd or GetTime()
			entry.afk = nil
		else
			entry.afk, entry.dnd = nil, nil
		end
	end
end

function events:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if (prefix == "CTRA" and channel == "RAID" and not issecretvalue(msg) and not issecretvalue(sender)) then
		local name = Ambiguate(sender, "none")
		for subMsg in gmatch(msg, "[^#]+") do
			ProcessCTRAMessage(name, subMsg)
		end
	end
end

function events:UNIT_SPELLCAST_START(unit)
	local caster = RaidCaster(unit)
	if (not caster) then
		return
	end
	if (ResArray[caster]) then
		SetResStatus(caster)		-- flagged as ressing: that cast is over
	end

	local spell = UnitCastingInfo(unit)
	if (spell and not issecretvalue(spell) and resSpells[spell]) then
		local target = unit.."target"
		if (UnitExists(target) and UnitIsDead(target)) then
			local targetName = RosterName(target)
			if (targetName) then
				SetResStatus(caster, targetName)
			end
		end
	end
end

function events:UNIT_SPELLCAST_STOP(unit)
	local caster = RaidCaster(unit)
	if (caster and ResArray[caster]) then
		SetResStatus(caster)
	end
end

function events:UNIT_SPELLCAST_FAILED(unit)
	local caster = RaidCaster(unit)
	if (caster and ResArray[caster]) then
		SetResStatus(caster, nil, true)
	end
end
events.UNIT_SPELLCAST_INTERRUPTED = events.UNIT_SPELLCAST_FAILED

eventFrame:SetScript("OnEvent", function(self, event, ...)
	events[event](self, ...)
end)

-- SetModuleEvents(on)
local function SetModuleEvents(on)
	for event in pairs(events) do
		if (on) then
			eventFrame:RegisterEvent(event)
		else
			eventFrame:UnregisterEvent(event)
		end
	end
end

------------------------------------------------------------------------------
-- Applying settings
------------------------------------------------------------------------------

-- ApplyRaid: everything outside the buttons (registered option changer). The titles follow the headers, so
-- in combat all of it waits for the headers' attributes to change; the buttons' shared aura rows don't.
local function ApplyRaid()
	if (not rconf) then
		return
	end
	auraOpts = nil
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ApplyRaid)
		return
	end
	SetModuleEvents(rconf.enable)
	CountMembers()
	ApplyHeaders()
	RefreshTitles()
end
XPerl_RegisterOptionChanger(ApplyRaid)

-- XPerl_Raid_OptionActions
-- Applies the raid and raid pet settings (options window, key bindings, minimap menu)
function XPerl_Raid_OptionActions()
	ApplyRaid()
	if (ns.RaidPets) then
		ns.RaidPets.Apply()
	end
	XPerl_ForEachUnitFrame(function(frame)
		if (frame.frameKey == "raid" or frame.frameKey == "raidpet") then
			frame:ApplySettings()
		end
	end)
end

-- XPerl_Raid_TitleOnLoad: OnLoad of the raid and raid pet titles (XPerl_Raid_TitleTemplate)
local function TitleDragStart(self)
	local title = self.title or self
	if (XPerlLocked == 0 and not InCombatLockdown()) then
		title.xperlMoving = true
		title:StartMoving()
	end
end

local function TitleDragStop(self)
	local title = self.title or self
	if (title.xperlMoving) then
		title.xperlMoving = nil
		title:StopMovingOrSizing()
		XPerl_SavePosition(title)
	end
end

function XPerl_Raid_TitleOnLoad(self)
	self.text = self.titleFrame.text
	XPerl_RegisterUnitText(self.text)
	-- The title text and the placeholder drag the title while the frames are unlocked in the options window
	for _, handle in ipairs({self.titleFrame, self.virtual}) do
		handle.title = self
		handle:RegisterForDrag("LeftButton")
		handle:SetScript("OnDragStart", TitleDragStart)
		handle:SetScript("OnDragStop", TitleDragStop)
		handle:EnableMouse(false)
	end
	if (self:GetID() <= WoWclassCount) then
		titles[self:GetID()] = self
	end
end

------------------------------------------------------------------------------
-- Raid buttons
------------------------------------------------------------------------------

local Define = XPerl_UnitFrame_DefineElement

local function ManaEnabled(self)
	return self.conf.mana
end

local function RoleIconsEnabled(self)
	return self.conf.role_icons
end

Define("raidPower",	{events = {UNIT_POWER_FREQUENT = "unit", UNIT_MAXPOWER = "unit", UNIT_DISPLAYPOWER = "unit"}, method = "UpdatePower", enabled = ManaEnabled})
Define("raidRole",	{events = {GROUP_ROSTER_UPDATE = true, PLAYER_ROLES_ASSIGNED = true}, method = "UpdateRole", enabled = RoleIconsEnabled})
-- Shared with the raid pets: a roster change can put somebody else behind the same unit token
Define("groupRoster",	{events = {GROUP_ROSTER_UPDATE = true}, method = "OnRosterChanged", full = false})

XPerl_RaidFrameMixin = {
	elementList = {"raidPower", "raidRole", "health", "name", "combat", "readyCheck", "statusIcons", "auras",
		"range", "highlight", "healPrediction", "combatFeedback", "groupRoster"},
	flashFrameKeys = {"nameFrame", "statsFrame"},
	auraSetup = {single = true, raid = true, crop = true},
	statusIconSize = 12,
	highlightRatio = 2,
	edgeFile = "Interface\\Addons\\XPerl\\images\\XPerl_ThinEdge",
	edgeSize = 10,
	edgeInsets = 2,
}
local R = XPerl_RaidFrameMixin

-- InitType: the name frame's text and icons in the compact layout
function R:InitType()
	local nf = self.nameFrame
	nf.text:SetFontObject(GameFontNormalSmall)
	nf.text:ClearAllPoints()
	nf.text:SetPoint("TOPLEFT")
	nf.text:SetPoint("BOTTOMRIGHT", 0, 2)
	nf.warningIcon:SetSize(24, 24)
	nf.warningIcon:ClearAllPoints()
	nf.warningIcon:SetPoint("TOP", 0, 2)
	nf.roleIcon:SetSize(16, 16)
	nf.roleIcon:ClearAllPoints()
	nf.roleIcon:SetPoint("RIGHT", 7, 7)
	self.layoutDeferred = function() self:ApplyLayout() end
end

-- CreateManaBar: raid buttons get their mana bar when raid.mana is first switched on
local function CreateManaBar(self)
	local sf = self.statsFrame
	local mb = CreateFrame("StatusBar", sf:GetName().."manaBar", sf, "XPerlRaidStatusBar")
	sf.manaBar = mb
	mb:SetScale(0.7)
	mb:SetWidth(70)
	mb:SetPoint("TOPLEFT", sf.healthBar, "BOTTOMLEFT", 0, 0)
	mb:SetPoint("BOTTOMRIGHT", sf.healthBar, "BOTTOMRIGHT", 0, -7)
	mb:SetStatusBarColor(0, 0, 1)
end

-- ApplyLayout: heights with or without the mana bar, value texts. The button's own height is protected.
function R:ApplyLayout()
	local c, sf = self.conf, self.statsFrame
	if (c.mana) then
		if (not sf.manaBar) then
			CreateManaBar(self)
		end
		sf:SetHeight(26)
		sf.manaBar:Show()
	else
		sf:SetHeight(21)
		if (sf.manaBar) then
			sf.manaBar:Hide()
		end
	end
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(self.layoutDeferred)
	else
		self:SetHeight(c.mana and 43 or 38)
	end

	local text = c.percent and true or false
	sf.healthBar.text:SetShown(text)
	if (sf.manaBar) then
		sf.manaBar.text:SetShown(text)
	end
end

-- ApplySettings
-- Raid buttons are laid out by their header, and their scale is their title's, so this replaces the
-- framework's size/scale handling. Nothing but the height is protected, so it applies in combat too.
function R:ApplySettings()
	local c = self.conf
	if (not c) then
		return
	end
	self:SetEnabled(c.enable)
	if (not self.active) then
		return
	end
	self:ApplyLayout()
	if (not c.role_icons) then
		self.nameFrame.roleIcon:Hide()
	end
	self:ApplyElements()
	self:PlaceAuras()
	self:ConfigureAuras()
	XPerl_ApplyFrameBackdrop(self)
	if (self:IsShown()) then
		self:UpdateDisplay()
	end
end

-- No dragging raid buttons: their titles move the groups
function R:OnDragStart()
end
function R:OnDragStop()
end

-- UnitChanged: remembers who is behind the token, see OnRosterChanged
function R:UnitChanged()
	local unit = self.partyid
	self.unitGUID = unit and Plain(UnitGUID(unit))
	UF.UnitChanged(self)
end

-- OnRosterChanged: a full refresh when somebody else is now behind the same token
function R:OnRosterChanged()
	local guid = Plain(UnitGUID(self.partyid))
	if (not guid or guid ~= self.unitGUID) then
		self:UnitChanged()
	end
end

-- UpdateName: class coloured (reaction coloured when duelling)
function R:UpdateName()
	local unit, text = self.partyid, self.nameFrame.text
	text:SetText(UnitName(unit))
	XPerl_ColourFriendlyUnit(text, unit)
end

-- UpdateRole: assigned role icon (raid.role_icons)
function R:UpdateRole()
	local icon = self.nameFrame.roleIcon
	local texture = XPerl_UnitFrame_RoleTexture(UnitGroupRolesAssigned(self.partyid))
	if (texture) then
		icon:SetTexture(texture)
		icon:Show()
	else
		icon:Hide()
	end
end

-- UpdateRange: spell range fade with the raid frame rules (rangeFinder.raidOnly)
function R:UpdateRange()
	local unit = self.partyid
	if (unit and UnitExists(unit)) then
		XPerl_UpdateSpellRange(self, unit, true)
	end
end

-- GetFlags(unit, name)
-- Text shown instead of the health (being resurrected, resurrected, AFK) and its background colour
local function GetFlags(unit, name)
	for resser, target in pairs(ResArray) do
		if (target == name) then
			if (UnitIsDeadOrGhost(unit)) then
				return resser..XPERL_RAID_RESSING, 0, 0.5, 1
			end
			ResArray[resser] = nil
			break
		end
	end

	local entry = XPerl_Roster[name]
	if (entry and entry.ressed) then
		if (UnitIsDead(unit)) then
			return XPERL_LOC_RESURRECTED, 0, 0.5, 1
		end
		entry.ressed = nil
	end

	if (conf.showAFK and UnitIsAFK(unit)) then
		return XPERL_RAID_AFK
	end
end

-- ShowStatus(text, r, g, b): a status text on greyed (or tinted) bars
function R:ShowStatus(text, r, g, b)
	local sf = self.statsFrame
	local hbt = sf.healthBar.text
	sf:SetGrey(r, g, b)
	hbt:SetText(text)
	hbt:SetTextColor(1, 1, 1)
	hbt:Show()
end

-- UpdateHealth: health bar and text (raid.percent shows it: health deficit with healer mode, values or a
-- percentage), or the member's status (offline, resurrection, AFK, dead, ghost, feigning death)
function R:UpdateHealth()
	local unit, c = self.partyid, self.conf
	local sf = self.statsFrame
	local hb = sf.healthBar
	local hbt = hb.text

	local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
	-- Restricted (secret) health can't be compared or divided: the client colours the bar and formats the text
	local secret = issecretvalue(health) or issecretvalue(healthMax)
	if (not secret and health > healthMax) then
		health = UnitIsDeadOrGhost(unit) and 0 or healthMax
	end

	hb:SetMinMaxValues(0, healthMax)
	if (not conf.bar.inverse) then
		hb:SetValue(health)
	elseif (secret) then
		hb:SetValue(UnitHealthMissing(unit))
	else
		hb:SetValue(healthMax - health)
	end
	hbt:SetShown(c.percent and true or false)
	self:UpdateHealPrediction()

	local name = RosterName(unit)
	local entry = name and XPerl_Roster[name]
	if (not UnitIsConnected(unit)) then
		self:ShowStatus(XPERL_LOC_OFFLINE)
		if (entry and not entry.offline) then
			entry.offline = GetTime()
			entry.afk, entry.dnd = nil, nil
		end
		return
	end
	if (entry) then
		entry.offline = nil
	end

	local flag, r, g, b
	if (name) then
		flag, r, g, b = GetFlags(unit, name)
	end
	if (flag) then
		self:ShowStatus(flag, r, g, b)
		return
	end

	if (self.feigning and conf.showFD) then
		self:ShowStatus(XPERL_LOC_FEIGNDEATH)
		return
	elseif (UnitIsGhost(unit)) then
		self:ShowStatus(XPERL_LOC_GHOST)
		return
	elseif (UnitIsDead(unit)) then
		self:ShowStatus(XPERL_LOC_DEAD)
		return
	end

	local fraction			-- stays nil for restricted health: XPerl_ColourHealthBar then colours from the unit
	if (not secret) then
		if (healthMax == 0) then
			fraction = health > 0 and 1 or 0
		else
			fraction = health / healthMax
		end
	end

	if (c.healerMode and c.healerMode.enable) then
		if (secret) then
			hbt:SetText(XPerl_UnitHealthDeficitText(unit))
		else
			hbt:SetText(health - healthMax)
		end
	elseif (c.values) then
		if (secret) then
			hbt:SetText(health.."/"..healthMax)
		else
			hbt:SetFormattedText("%d/%d", health, healthMax)
		end
	elseif (secret) then
		if (c.precisionPercent) then
			hbt:SetFormattedText(percF, UnitHealthPercent(unit, true, percentCurve))
		else
			hbt:SetText(XPerl_UnitHealthPercentText(unit))
		end
	else
		hbt:SetFormattedText(c.precisionPercent and percF or percD, fraction * 100)
	end

	if (sf.greyMana) then
		-- Back from a status: the bars get their colours again
		sf.greyMana = nil
		if (entry) then
			entry.ressed, entry.resCount = nil, nil
		end
		XPerl_SetManaBarType(self)
	end
	XPerl_ColourHealthBar(self, fraction, unit)
end

-- UpdatePower: mana bar (raid.mana) and its text (raid.manaPercent, mana users only)
function R:UpdatePower(event)
	local mb = self.statsFrame.manaBar
	local unit = self.partyid
	local powerType = XPerl_GetDisplayedPowerType(unit)
	if (not mb or not powerType) then
		return
	end
	if (event ~= "UNIT_POWER_FREQUENT" and event ~= "UNIT_MAXPOWER") then
		XPerl_SetManaBarType(self)
	end

	local power, powerMax = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
	-- Restricted (secret) power can't be compared or divided, so the client formats the percentage
	local secret = issecretvalue(power) or issecretvalue(powerMax)
	local c, text = self.conf, mb.text
	if (c.manaPercent and powerType == Enum.PowerType.Mana) then
		if (c.values) then
			if (secret) then
				text:SetText(power.."/"..powerMax)
			else
				text:SetFormattedText("%d/%d", power, powerMax)
			end
		elseif (secret) then
			if (c.precisionManaPercent) then
				text:SetFormattedText(percF, UnitPowerPercent(unit, powerType, false, percentCurve))
			else
				text:SetText(XPerl_UnitPowerPercentText(unit, powerType))
			end
		else
			local fraction
			if (powerMax == 0) then
				fraction = power > 0 and 1 or 0
			else
				fraction = power / powerMax
			end
			text:SetFormattedText(c.precisionManaPercent and percF or percD, fraction * 100)
		end
	else
		text:SetText("")
	end

	mb:SetMinMaxValues(0, powerMax)
	mb:SetValue(power)
end

-- UpdateAuras: also when a hunter started feigning death (for the tooltip)
function R:UpdateAuras(event)
	UF.UpdateAuras(self, event)
	local unit = self.partyid

	local entry = XPerl_Roster[RosterName(unit) or ""]
	if (entry) then
		if (self.feigning) then
			entry.fd = entry.fd or GetTime()
		else
			entry.fd = nil
		end
	end
end

-- RaidAuraOptions
-- One shared set of aura row settings for every raid button: 10px icons, buffs or debuffs as raid.buffs
-- picks. raid.buffs.untilDebuffed used to swap the buffs for debuffs once the unit had any, but whether it has
-- any is secret in combat, so debuffs lead and buffs follow beside them, splitting the old icon limit.
local function RaidAuraOptions()
	-- The column beside a frame without a mana bar is shorter, so it holds fewer icons
	local maxIcons = (rconf.buffs.right and not rconf.mana) and 6 or 8
	local buffs = {size = 10, max = maxIcons, castable = rconf.buffs.castable}
	local debuffs = {size = 10, max = maxIcons, curable = rconf.buffs.castable}
	local opts = {buffs = buffs, debuffs = debuffs}

	if (rconf.buffs.enable) then
		buffs.enable = true
		if (rconf.buffs.untilDebuffed) then
			debuffs.enable = true
			buffs.max = maxIcons / 2
			debuffs.max = maxIcons / 2
			opts.order = "debuffs"
			opts.across = true
		end
	elseif (rconf.debuffs.enable) then
		debuffs.enable = true
	end

	if (rconf.buffs.right) then
		opts.vertical = true
		opts.above = true
		-- Column height: 3 or 4 icons of 10px, the spare pixel per icon covers the spacing between them
		opts.lineWidth = (rconf.mana and 4 or 3) * 11
	end
	return opts
end

-- PlaceAuras: a column beside the stats (raid.buffs.right, inside the frame's width with .inside) or a row below
function R:PlaceAuras()
	local sf, bf = self.statsFrame, self.buffFrame
	bf:ClearAllPoints()
	if (rconf.buffs.right) then
		bf:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", -1, 1)
		-- How many columns are showing is secret, so "inside" always leaves room for one column
		sf:SetWidth(rconf.buffs.inside and 70 or 80)
	else
		bf:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, 1)
		sf:SetWidth(80)
	end
end

-- ConfigureAuras
function R:ConfigureAuras()
	if (not auraOpts) then
		auraOpts = RaidAuraOptions()
	end
	XPerl_Auras_Configure(self, auraOpts)
end

-- CheckAuraWidth: the raid aura rows don't depend on the unit
function R:CheckAuraWidth()
end

------------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------------

-- GetCombatRezzerList()
-- Who can resurrect now: everybody (normal resurrection) unless the priests, shamans and paladins are busy
-- in combat, then the out-of-combat ones
local normalRezzers = {PRIEST = true, SHAMAN = true, PALADIN = true}
local function GetCombatRezzerList()
	local anyCombat, anyAlive = 0, 0
	local num = GetNumGroupMembers()
	for i = 1, num do
		local unit = "raid"..i
		if (normalRezzers[Plain(select(2, UnitClass(unit))) or ""]) then
			if (UnitAffectingCombat(unit)) then
				anyCombat = anyCombat + 1
			end
			if (not UnitIsDeadOrGhost(unit) and UnitIsConnected(unit)) then
				anyAlive = anyAlive + 1
			end
		end
	end

	-- Only the out-of-combat resurrectors matter while the others are in combat
	if (anyCombat > 0 or anyAlive < 3) then
		local text
		for i = 1, num do
			local unit = "raid"..i
			if (not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) and not UnitAffectingCombat(unit)) then
				local name, _, _, _, _, class = GetRaidRosterInfo(i)
				if (normalRezzers[class]) then
					name = XPerlColourTable[class]..name.."|r"
					text = text and (text..", "..name) or name
				end
			end
		end
		return text or "|c00FF0000"..NONE.."|r"
	end

	if (anyAlive == 0) then
		return "|c00FF0000"..NONE.."|r"
	elseif (anyCombat == 0) then
		return "|c00FFFFFF"..ALL.."|r"
	end
end

-- XPerl_RaidTipExtra(unit)
-- Unit tooltip lines from the raid roster: CTRA version, offline/AFK/DND times, feign death, resurrections
-- and who can resurrect
function XPerl_RaidTipExtra(unit)
	if (not UnitInRaid(unit)) then
		return
	end
	local stats = XPerl_Roster[RosterName(unit) or ""]
	if (not stats) then
		return
	end

	local now = GetTime()
	if (stats.version) then
		GameTooltip:AddLine("CTRA "..stats.version, 1, 1, 1)
	end

	if (stats.offline and UnitIsConnected(unit)) then
		stats.offline = nil
	end
	if (stats.afk and not UnitIsAFK(unit)) then
		stats.afk = nil
	end
	if (stats.dnd and not UnitIsDND(unit)) then
		stats.dnd = nil
	end

	if (stats.offline) then
		GameTooltip:AddLine(format(XPERL_RAID_TOOLTIP_OFFLINE, SecondsToTime(now - stats.offline)))
	elseif (stats.afk) then
		GameTooltip:AddLine(format(XPERL_RAID_TOOLTIP_AFK, SecondsToTime(now - stats.afk)))
	elseif (stats.dnd) then
		GameTooltip:AddLine(format(XPERL_RAID_TOOLTIP_DND, SecondsToTime(now - stats.dnd)))
	elseif (stats.fd) then
		if (not UnitIsDead(unit)) then
			stats.fd = nil
		else
			local left = stats.fd + 360 - now
			if (left > 0) then
				GameTooltip:AddLine(format(XPERL_RAID_TOOLTIP_DYING, SecondsToTime(left)))
			end
		end
	end

	if (UnitIsDeadOrGhost(unit) and not Plain(UnitIsFeignDeath(unit))) then
		if (stats.resCount) then
			GameTooltip:AddLine(XPERL_LOC_RESURRECTED.." x"..stats.resCount)
		end
		local rezzers = GetCombatRezzerList()
		if (rezzers) then
			GameTooltip:AddLine(XPERL_RAID_RESSER_AVAIL..rezzers, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
		end
	end

	GameTooltip:Show()
end

------------------------------------------------------------------------------
-- Key bindings and the minimap menu
------------------------------------------------------------------------------

-- XPerl_ToggleRaidBuffs(castable)
-- castable: toggles buffs you can cast / debuffs you can cure versus all of them. Otherwise steps through
-- buffs, debuffs, none.
function XPerl_ToggleRaidBuffs(castable)
	if (castable) then
		if (rconf.buffs.castable == 1) then
			rconf.buffs.castable = 0
			XPerl_Notice(XPERL_KEY_NOTICE_RAID_BUFFANY)
		else
			rconf.buffs.castable = 1
			XPerl_Notice(XPERL_KEY_NOTICE_RAID_BUFFCURECAST)
		end
	else
		if (rconf.buffs.enable) then
			rconf.buffs.enable = nil
			rconf.debuffs.enable = 1
			XPerl_Notice(XPERL_KEY_NOTICE_RAID_DEBUFFS)
		elseif (rconf.debuffs.enable) then
			rconf.buffs.enable = nil
			rconf.debuffs.enable = nil
			XPerl_Notice(XPERL_KEY_NOTICE_RAID_NOBUFFS)
		else
			rconf.buffs.enable = 1
			rconf.debuffs.enable = nil
			XPerl_Notice(XPERL_KEY_NOTICE_RAID_BUFFS)
		end
	end

	auraOpts = nil
	XPerl_ForEachUnitFrame(function(frame)
		if (frame.frameKey == "raid" and frame.active) then
			frame:ConfigureAuras()
		end
	end)
end

-- XPerl_ToggleRaidSort(mode)
-- mode "class" or "group" sorts the raid frames that way; nil switches between the two
function XPerl_ToggleRaidSort(mode)
	if (XPerl_Options and XPerl_Options:IsShown()) then
		return
	end
	local byClass
	if (mode) then
		byClass = mode == "class"
	else
		byClass = not rconf.sortByClass
	end
	rconf.sortByClass = byClass and 1 or nil
	XPerl_Raid_OptionActions()
end
