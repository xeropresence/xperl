-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Shared unit frame framework. Every unit button inherits XPerl_UnitButtonTemplate (Units/Templates.xml) and
-- gets XPerl_UnitFrameMixin plus its type's mixin. A type lists the elements it shows (elementList); each
-- element names the events it needs and the mixin method that draws it. The framework registers those
-- events per frame (RegisterUnitEvent for the frame's own unit), dispatches them, runs every element for a
-- full refresh (UpdateDisplay) and applies the settings every type has in common (ApplySettings).

local conf
local unitFrames = {}		-- every X-Perl unit button, in creation order
local Elements = {}		-- element name -> definition

-- Plain(value): nil for a restricted (secret) value, which can't even be tested
local function Plain(value)
	if (issecretvalue(value)) then
		return nil
	end
	return value
end

local UnitIsAFK = XPerlAPI.UnitIsAFK			-- secret-safe unit flags, see XPerl_Api.lua
local UnitIsPVP = XPerlAPI.UnitIsPVP
local GetDifficultyColor = GetCreatureDifficultyColor or GetQuestDifficultyColor		-- by level (GetDifficultyColor takes a difficulty enum)
local IsEventValid = C_EventUtils and C_EventUtils.IsEventValid

XPerl_UnitFrameMixin = {}
local UF = XPerl_UnitFrameMixin

------------------------------------------------------------------------------
-- Registry and settings plumbing
------------------------------------------------------------------------------

-- XPerl_ForEachUnitFrame(func)
-- Calls func(frame) for every X-Perl unit button, group header children included
function XPerl_ForEachUnitFrame(func)
	for i = 1, #unitFrames do
		func(unitFrames[i])
	end
end

XPerl_RequestConfig(function(new)
	conf = new
	for i = 1, #unitFrames do
		local frame = unitFrames[i]
		frame.conf = new[frame.frameKey]
	end
end, "$Revision$")

-- KeepBlizzardPetFrame
-- Blizzard's PetFrame is a child of PlayerFrame (12.1), so hiding PlayerFrame would take it along; with X-Perl's
-- pet frame off it moves to UIParent first (its anchor keeps it in place)
local function KeepBlizzardPetFrame()
	if (PetFrame and PlayerFrame and PetFrame:GetParent() == PlayerFrame) then
		PetFrame:SetParent(UIParent)
	end
end

-- XPerl_UnitFrames_ApplyEnableFlags
-- Activates the enabled frames and deactivates the others. Units/Startup.lua registers it as the last config
-- callback of the unit code, so every unit type has its settings by then. Settings are validated before
-- the callbacks run (login and every Edit Mode layout switch). While XPerl_BlizzFrameDisable exists (until
-- PLAYER_LOGIN) the Blizzard frames of the enabled types are hidden; enabling a type later shows the X-Perl
-- frame next to Blizzard's until the UI is reloaded.
function XPerl_UnitFrames_ApplyEnableFlags()
	for i = 1, #unitFrames do
		local frame = unitFrames[i]
		local c = frame.conf
		if (c) then
			if (c.enable and not frame.blizzardHidden and XPerl_BlizzFrameDisable) then
				frame.blizzardHidden = true
				if (frame.blizzardFrame == "PlayerFrame" and not (conf.pet and conf.pet.enable)) then
					-- Out of combat first; XPerl_BlizzFrameDisable defers the same way in combat
					XPerl_ProtectedCall(KeepBlizzardPetFrame)
				end
				if (frame.blizzardFrame) then
					XPerl_BlizzFrameDisable(_G[frame.blizzardFrame])
				end
			end
			frame:SetEnabled(c.enable)
		end
	end
end

------------------------------------------------------------------------------
-- Elements
------------------------------------------------------------------------------

-- XPerl_UnitFrame_DefineElement(name, def)
-- def fields (all optional):
--	events		{EVENT = spec}: spec "unit" = the frame's current unit, a unit token = that unit only,
--			true = any unit / not a unit event
--	method		mixin method called as self:method(event, ...) on those events, and as self:method()
--			on a full refresh
--	full		false: not part of the full refresh (event-only)
--	deferrable	skipped by a full refresh while self.deferring is set (target "defer" option)
--	enabled		function(self) -> whether the element is active now (events and refresh); re-checked by
--			ApplySettings
--	init		function(self) run once from the frame's OnLoad
--	apply		function(self) run by ApplySettings
function XPerl_UnitFrame_DefineElement(name, def)
	Elements[name] = def
end
local Define = XPerl_UnitFrame_DefineElement

Define("portrait",	{events = {UNIT_PORTRAIT_UPDATE = "unit", UNIT_MODEL_CHANGED = "unit"}, method = "UpdatePortrait", deferrable = true})
Define("name",		{events = {UNIT_NAME_UPDATE = "unit"}, method = "UpdateName"})
Define("level",		{events = {UNIT_LEVEL = "unit"}, method = "UpdateLevel"})
Define("classIcon",	{method = "UpdateClassIcon"})
Define("power",		{events = {UNIT_POWER_FREQUENT = "unit", UNIT_MAXPOWER = "unit", UNIT_DISPLAYPOWER = "unit"}, method = "UpdatePower"})
Define("health",	{events = {UNIT_HEALTH = "unit", UNIT_MAXHEALTH = "unit", UNIT_CONNECTION = "unit", PLAYER_FLAGS_CHANGED = true}, method = "UpdateHealth"})
-- Raid target, leader, assistant, master looter, main assist, main tank and combat icons (conf.icons spots)
Define("statusIcons",	{events = {RAID_TARGET_UPDATE = true, PARTY_LEADER_CHANGED = true, PARTY_LOOT_METHOD_CHANGED = true,
		GROUP_ROSTER_UPDATE = true, UNIT_FLAGS = "unit", PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true},
	method = "UpdateStatusIcons",
	init = function(self) self:CreateStatusIcons() end,
	apply = function(self) self.statusIcons.dirty = true end})
Define("role",		{events = {GROUP_ROSTER_UPDATE = true, PLAYER_ROLES_ASSIGNED = true}, method = "UpdateRole", deferrable = true})
Define("pvp",		{events = {UNIT_FACTION = "unit", UNIT_FLAGS = "unit", PLAYER_FLAGS_CHANGED = true}, method = "UpdatePvP"})
Define("combat",	{events = {UNIT_FLAGS = "unit", PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true}, method = "UpdateCombat"})
Define("threat",	{events = {UNIT_THREAT_LIST_UPDATE = "unit", UNIT_THREAT_SITUATION_UPDATE = "unit", PLAYER_REGEN_ENABLED = true, PLAYER_REGEN_DISABLED = true}, method = "UpdateThreat"})
Define("range",		{method = "UpdateRange", init = function(self) self.rangeFade = true self.tickInterval = 0.2 end})
Define("readyCheck",	{events = {READY_CHECK = true, READY_CHECK_CONFIRM = true, READY_CHECK_FINISHED = true}, method = "UpdateReadyCheck"})
Define("healPrediction", {events = {UNIT_HEAL_PREDICTION = "unit", UNIT_ABSORB_AMOUNT_CHANGED = "unit", UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "unit"},
	method = "UpdateHealPrediction", full = false,		-- health updates refresh it too (XPerl_SetHealthBar)
	enabled = function(self) return self.conf.healPrediction end,
	init = function(self) self:CreateHealPrediction() end,
	apply = function(self) self:ApplyHealPrediction() end})
Define("combatFeedback", {events = {UNIT_COMBAT = "unit"}, method = "OnUnitCombat", full = false,
	init = function(self)
		if (self.hitIndicator) then
			CombatFeedback_Initialize(self, self.hitIndicator.text, 30)
			self.hitIndicator.text:SetPoint("CENTER", self.portraitFrame or self, "CENTER", 0, 0)
		end
	end})
Define("auras",		{events = {UNIT_AURA = "unit", UNIT_FACTION = "unit"}, method = "UpdateAuras",
	init = function(self) XPerl_Auras_Init(self, self.auraSetup) end})
Define("petBattle",	{events = {PET_BATTLE_OPENING_START = true, PET_BATTLE_CLOSE = true}, method = "OnPetBattle", full = false})
Define("highlight",	{init = function(self) if (self.highlight) then XPerl_RegisterHighlight(self.highlight, self.highlightRatio or 3) end end})
Define("castBar",	{init = function(self) XPerl_CastBar_Create(self) end, apply = function(self) self.castBar:ApplySettings() end})

------------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------------

-- SecureSetup: click registration and the secure click attributes of the button and its name frame.
-- Header children get no unit attribute: the header owns the button's unit, and the name frame inherits it
-- (useparent-unit); a pinned unit would outlive the header's later reassignments.
local function SecureSetup(self)
	local unit = not self.headerChild and self.partyid or nil
	self:RegisterForClicks("AnyUp")
	self:RegisterForDrag("LeftButton")
	XPerl_SecureUnitButton_OnLoad(self, unit, nil, nil, XPerl_ShowGenericMenu)
	local nf = self.nameFrame
	if (nf) then
		nf:RegisterForClicks("AnyUp")
		nf:RegisterForDrag("LeftButton")
		XPerl_SecureUnitButton_OnLoad(nf, unit, nil, nil, XPerl_ShowGenericMenu)
	end
end

-- XPerl_UnitFrame_OnLoad
-- OnLoad of XPerl_UnitButtonTemplate; reads the KeyValues documented there
function XPerl_UnitFrame_OnLoad(self)
	Mixin(self, UF, self.typeMixin)
	unitFrames[#unitFrames + 1] = self

	self.partyid = self.initialUnit
	self.eventHandlers = {}
	self.tick = 0
	self.applySettingsDeferred = function() self:ApplySettings() end
	if (XPerlDB) then
		self.conf = XPerlDB[self.frameKey]
	end

	-- Today's XML anchor (relative to UIParent) is the Edit Mode default; header children have none
	local point, relativeTo, relativePoint, x, y = self:GetPoint(1)
	if (point and (not relativeTo or relativeTo == UIParent) and point == relativePoint) then
		self.defaultPosition = {point = point, x = x, y = y}
		self.editModePreview = function(on) self:EditModePreview(on) end
	end

	-- Group headers create buttons mid-combat when the roster grows, and their protected setup has to wait.
	-- Header child templates declare their clicks and click attributes in XML for the meantime.
	if (self.headerChild and InCombatLockdown()) then
		self.secureSetupDeferred = function() SecureSetup(self) end
		XPerl_ProtectedCall(self.secureSetupDeferred)
	else
		SecureSetup(self)
	end

	self:SetScript("OnEvent", self.OnEvent)
	self:SetScript("OnUpdate", self.OnUpdate)
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)
	self:SetScript("OnEnter", XPerl_Unit_OnEnter)
	self:SetScript("OnLeave", XPerl_Unit_OnLeave)
	self:SetScript("OnDragStart", self.OnDragStart)
	self:SetScript("OnDragStop", self.OnDragStop)
	if (self.headerChild) then
		self:SetScript("OnAttributeChanged", self.OnAttributeChanged)
	end

	local list = self.elementList
	for i = 1, #list do
		local el = Elements[list[i]]
		if (not el) then
			error("X-Perl: unknown unit frame element "..tostring(list[i]))
		end
		if (el.init) then
			el.init(self)
		end
	end

	self:InitType()
	XPerl_RegisterOptionChanger(self.ApplySettings, self)

	-- Frames that get the configured backdrop colours, and those whose border flashes
	local perl, flash = {}, {}
	for _, key in ipairs(self.perlFrameKeys or self.flashFrameKeys) do
		if (self[key]) then
			perl[#perl + 1] = self[key]
		end
	end
	for _, key in ipairs(self.flashFrameKeys) do
		if (self[key]) then
			flash[#flash + 1] = self[key]
		end
	end
	self.FlashFrames = flash
	XPerl_RegisterPerlFrames(self, perl)

	-- Group headers create buttons whenever their group grows; those made after login get their settings
	-- now (XPerl_UnitFrames_ApplyEnableFlags only saw the ones that existed then)
	if (self.headerChild and self.conf) then
		self:ApplySettings()
	end
end

-- XPerl_UnitNameFrame_OnLoad
-- The name frame clicks (registered with its unit frame's secure setup), drags and shows the tooltip for
-- its unit frame
function XPerl_UnitNameFrame_OnLoad(self)
	XPerl_RegisterUnitText(self.text)
	self:SetScript("OnEnter", function(nameFrame) XPerl_Unit_OnEnter(nameFrame:GetParent()) end)
	self:SetScript("OnLeave", function(nameFrame) XPerl_Unit_OnLeave(nameFrame:GetParent()) end)
	self:SetScript("OnDragStart", function(nameFrame) nameFrame:GetParent():OnDragStart() end)
	self:SetScript("OnDragStop", function(nameFrame) nameFrame:GetParent():OnDragStop() end)
end

-- Overridable hooks
function UF:InitType() end
function UF:ApplyTypeSettings() end
function UF:OnActivate() end
function UF:TypePreview() end

------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------

-- RegisterElementEvents
-- (Re)registers the events of the active elements. Called on activation, unit changes and ApplySettings.
-- A frame without a unit (a group header's spare button) listens to nothing.
function UF:RegisterElementEvents()
	self:UnregisterAllEvents()
	local handlers = self.eventHandlers
	for _, list in pairs(handlers) do
		wipe(list)
	end
	if (not self.active or not self.partyid) then
		return
	end

	-- handlers[event] = {method1, filter1, method2, filter2, ...}; filter false = any unit
	local unit = self.partyid
	local elementList = self.elementList
	for i = 1, #elementList do
		local el = Elements[elementList[i]]
		if (el.events and (not el.enabled or el.enabled(self))) then
			for event, spec in pairs(el.events) do
				local filter
				if (spec == true) then
					filter = false
				elseif (spec == "unit") then
					filter = unit
				else
					filter = spec
				end
				if (filter ~= nil and (not IsEventValid or IsEventValid(event))) then
					local list = handlers[event]
					if (not list) then
						list = {}
						handlers[event] = list
					end
					list[#list + 1] = el.method
					list[#list + 1] = filter
				end
			end
		end
	end

	for event, list in pairs(handlers) do
		if (#list > 0) then
			local u1, u2, any
			for i = 2, #list, 2 do
				local filter = list[i]
				if (not filter) then
					any = true
				elseif (not u1 or u1 == filter) then
					u1 = filter
				elseif (not u2 or u2 == filter) then
					u2 = filter
				else
					any = true
				end
			end
			if (any) then
				self:RegisterEvent(event)
			else
				self:RegisterUnitEvent(event, u1, u2)
			end
		end
	end
end

-- OnEvent
function UF:OnEvent(event, arg1, ...)
	local list = self.eventHandlers[event]
	if (list) then
		for i = 1, #list, 2 do
			local filter = list[i + 1]
			if (not filter or filter == arg1) then
				self[list[i]](self, event, arg1, ...)
			end
		end
	end
end

-- OnUpdate
function UF:OnUpdate(elapsed)
	if (self.feedbackText) then
		CombatFeedback_OnUpdate(self, elapsed)
	end
	if (self.PlayerFlash and XPerl_CombatFlashSet(self, elapsed)) then
		XPerl_CombatFlashSetFrames(self)
	end
	local interval = self.tickInterval
	if (interval) then
		local tick = self.tick + elapsed
		if (tick >= interval) then
			tick = 0
			self:OnTick()
		end
		self.tick = tick
	end
end

-- OnTick (every tickInterval seconds)
function UF:OnTick()
	if (self.rangeFade) then
		self:UpdateRange()
	end
end

-- OnShow
function UF:OnShow()
	self:UpdatePortrait()
	XPerl_Highlight:UnitFrameChanged(self)
end

function UF:OnHide()
end

-- OnAttributeChanged (group header children)
function UF:OnAttributeChanged(name, value)
	if (name == "unit") then
		self:SetUnit(value)
	end
end

------------------------------------------------------------------------------
-- Unit, refresh, activation
------------------------------------------------------------------------------

-- SetUnit(unit)
-- Points the frame at another unit token (nil for none). The secure "unit" attribute is the caller's
-- business (group headers set it themselves).
function UF:SetUnit(unit)
	if (unit == self.partyid) then
		return
	end
	self.partyid = unit
	if (self.active) then
		self:RegisterElementEvents()
	end
	self:UnitChanged()
end

-- UnitChanged
-- The unit behind the frame changed (new token, or a new target behind "target")
function UF:UnitChanged()
	self.feigning = nil
	if (self.PlayerFlash) then
		self.PlayerFlash = 0
		XPerl_CombatFlashSetFrames(self)
	end
	if (self.castBar) then
		self.castBar:SetBarUnit(self.partyid)
	end
	XPerl_Highlight:UnitFrameChanged(self)
	self:UpdateDisplay()
end

-- UpdateDisplay
-- Full refresh: runs every active element in elementList order
function UF:UpdateDisplay()
	local unit = self.partyid
	if (not self.active or not unit or not UnitExists(unit)) then
		return
	end
	local list = self.elementList
	for i = 1, #list do
		local el = Elements[list[i]]
		if (el.method and el.full ~= false and (not el.deferrable or not self.deferring) and (not el.enabled or el.enabled(self))) then
			self[el.method](self)
		end
	end
end

-- SetEnabled(on)
-- A disabled type has no events, is hidden and has no Edit Mode selection. Group header children leave
-- showing and hiding to their header, so nothing here is protected for them.
function UF:SetEnabled(on)
	on = on and true or false
	if (on == (self.active or false)) then
		return
	end
	if (InCombatLockdown() and not self.headerChild) then
		XPerl_ProtectedCall(self.applySettingsDeferred)
		return
	end

	self.active = on
	if (on) then
		if (self.defaultPosition and not self.editModeRegistered) then
			self.editModeRegistered = true
			XPerl_EditMode_Register(self, self.frameKey, {label = self.editModeLabel, default = self.defaultPosition, preview = self.editModePreview})
		end
		if (not self.headerChild) then
			if (self.useUnitWatch) then
				RegisterUnitWatch(self)
			else
				self:Show()
			end
		end
	else
		if (not self.headerChild) then
			if (self.useUnitWatch) then
				UnregisterUnitWatch(self)
			end
			self:Hide()
		end
	end
	self:ApplyElements()		-- cast bar, combo point events: none of it is protected
	if (self.editModeRegistered) then
		XPerl_EditMode_SetEnabled(self, on)
	end
	self:OnActivate(on)
	-- Switched on while frames are unlocked (options window or Edit Mode): show it for placing, after the
	-- unit watch above would have hidden it again
	if (on and self.editModePreview and (XPerlLocked == 0 or XPerl_EditMode_IsEditing())) then
		self:EditModePreview(true)
	end
	XPerl_Highlight:UnitFrameChanged(self)
end

-- ApplyElements: the elements' apply steps, then their events
function UF:ApplyElements()
	local list = self.elementList
	for i = 1, #list do
		local el = Elements[list[i]]
		if (el.apply) then
			el.apply(self)
		end
	end
	self:RegisterElementEvents()
end

-- EditModePreview(on)
-- Edit Mode (and the options window unlock) shows frames that are normally hidden without a unit
function UF:EditModePreview(on)
	if (InCombatLockdown() or not self.active) then
		return
	end
	if (self.useUnitWatch) then
		if (on) then
			UnregisterUnitWatch(self)
			self:Show()
			if (UnitExists(self.partyid)) then
				self:UpdateDisplay()
			else
				self.nameFrame.text:SetText(self.editModeLabel)
			end
		else
			RegisterUnitWatch(self)
		end
	end
	self:TypePreview(on)
end

-- OnDragStart / OnDragStop: the options window's unlocked drag; positions belong to Edit Mode
function UF:OnDragStart()
	if (XPerlLocked == 0 and not InCombatLockdown()) then
		self.xperlMoving = true
		self:StartMoving()
	end
end

function UF:OnDragStop()
	if (self.xperlMoving) then
		self.xperlMoving = nil
		self:StopMovingOrSizing()
		XPerl_SavePosition(self)
	end
end

------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------

-- GetStatsBars
-- Bars of the stats frame whose value/percent texts follow the frame's settings
function UF:GetStatsBars()
	local sf = self.statsFrame
	return {sf.healthBar, sf.manaBar}
end

-- GetExtraBars: bars stacked below the mana bar (XPerl_StatsFrameSetup)
function UF:GetExtraBars()
end

-- ApplyScale(scale): the frame's own scale, then Edit Mode re-places it. Types whose container carries the
-- scale (party header children) override this with a no-op.
function UF:ApplyScale(scale)
	if (scale) then
		self:SetScale(scale)
		XPerl_EditMode_ApplyPosition(self)
	end
end

-- ApplySize(width): bar and frame widths
function UF:ApplySize(width)
	local c = self.conf
	local barWidth = (c.percent and 160 or 128) + width
	self.nameFrame:SetWidth(barWidth)
	self.statsFrame:SetWidth(barWidth)
	self:SetWidth(self.baseWidth + (c.portrait and self.portraitWidth or 0) + (c.percent and 32 or 0) + width)
end

-- ApplySettings
-- Applies the frame's settings (registered with XPerl_RegisterOptionChanger, so XPerl_OptionActions runs it).
-- Protected frames can't be resized in combat, so it waits for combat to end.
function UF:ApplySettings()
	local c = self.conf
	if (not c) then
		return
	end
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(self.applySettingsDeferred)
		return
	end

	self:SetEnabled(c.enable)
	if (not self.active) then
		return
	end

	local width = max(0, (c.size and c.size.width) or 0)

	if (self.portraitFrame) then
		self.portraitFrame:SetShown(c.portrait and true or false)
		self.portraitFrame:SetWidth(c.portrait and 60 or self.portraitHiddenWidth or 2)
	end
	if (self.levelFrame) then
		self.levelFrame:SetShown(c.level and true or false)
	end

	local values, percent = c.values and true or false, c.percent and true or false
	for _, bar in pairs(self:GetStatsBars()) do
		if (bar.text) then
			bar.text:SetShown(values)
		end
		if (bar.percent) then
			bar.percent:SetShown(percent)
		end
	end

	self:ApplySize(width)

	self:ApplyScale(c.scale)

	self:ApplyElements()

	self:ApplyTypeSettings()

	XPerl_StatsFrameSetup(self, self:GetExtraBars(), self.statsOffset)
	if (self.auras) then
		self:PlaceAuras()
		self:ConfigureAuras()
	end
	if (not self.rangeFade) then
		self:SetAlpha(conf.transparency.frame)
	end

	XPerl_ApplyFrameBackdrop(self)
	if (self:IsShown()) then
		self:UpdateDisplay()			-- also refreshes the reaction-highlight name colour the backdrop reset
	end
end

------------------------------------------------------------------------------
-- Element methods. All take (event, unit, ...) from events and nothing from a full refresh.
------------------------------------------------------------------------------

-- UpdatePortrait
function UF:UpdatePortrait()
	if (self.portraitFrame and self.partyid) then
		XPerl_Unit_UpdatePortrait(self)
	end
end

-- UpdateName
function UF:UpdateName()
	self.nameFrame.text:SetText(UnitName(self.partyid))
	self:UpdateNameColour()
end

-- UpdateNameColour
-- With conf.reactionHighlight the name frame backdrop shows the reaction and the name its class colour
function UF:UpdateNameColour()
	local unit, nf = self.partyid, self.nameFrame
	if (self.conf.reactionHighlight) then
		local c = XPerl_ReactionColour(unit)
		nf:SetBackdropColor(c.r, c.g, c.b)
		if (conf.colour.class and UnitPlayerControlled(unit)) then
			XPerl_SetUnitNameColor(nf.text, unit)
		else
			nf.text:SetTextColor(1, 1, 1, conf.transparency.text)
		end
	else
		XPerl_SetUnitNameColor(nf.text, unit)
	end
end

-- UpdateLevel
-- Difficulty coloured level; a skull for units too far above the player, "+" for elites when the frame
-- doesn't show elite status itself (conf.elite)
function UF:UpdateLevel()
	local lf = self.levelFrame
	if (not lf or not self.conf.level) then
		return
	end
	local unit = self.partyid
	local level = UnitLevel(unit)
	local classification = UnitClassification(unit)
	lf:Show()
	lf:SetWidth(27)
	lf.skull:Hide()
	lf.text:SetText(level)
	if (level < 0) then
		if (classification == "normal") then
			lf.text:Hide()
			lf.skull:Show()
		else
			lf:Hide()		-- bosses: the type's classification display says so
		end
	else
		local color = GetDifficultyColor(level)
		lf.text:SetTextColor(color.r, color.g, color.b)
		lf.text:Show()
		if (not self.conf.elite and (classification == "elite" or classification == "worldboss")) then
			lf.text:SetFormattedText("%d+", level)
			lf:SetWidth(33)
		end
	end
end

-- UpdateClassIcon
function UF:UpdateClassIcon()
	local icon = self.classFrame
	if (icon) then
		if (self.conf.classIcon) then
			icon.classTexture:SetTexCoord(XPerl_ClassPos(Plain(select(2, UnitClass(self.partyid)))))
			icon:Show()
		else
			icon:Hide()
		end
	end
end

-- GetHealthStatus
-- Text shown instead of health values (dead, ghost, feigning, offline, AFK), or nil
function UF:GetHealthStatus()
	local unit = self.partyid
	if (UnitIsGhost(unit)) then
		return XPERL_LOC_GHOST
	elseif (UnitIsDead(unit)) then
		return (conf.showFD and UnitIsFeignDeath(unit)) and XPERL_LOC_FEIGNDEATH or XPERL_LOC_DEAD
	elseif (self.feigning and conf.showFD) then
		return XPERL_LOC_FEIGNDEATH
	elseif (not UnitIsConnected(unit)) then
		return XPERL_LOC_OFFLINE
	elseif (conf.showAFK and UnitIsAFK(unit)) then
		return CHAT_MSG_AFK
	end
end

-- UpdateHealth
function UF:UpdateHealth()
	local sf = self.statsFrame
	local hb = sf.healthBar
	local hp, hpMax = XPerl_Unit_GetHealth(self)
	XPerl_SetHealthBar(self, hp, hpMax)

	local status = self:GetHealthStatus()
	if (status) then
		if (self.conf.percent) then
			hb.percent:SetText(status)
			hb.percent:Show()
			sf.manaBar.percent:Hide()
		else
			hb.text:SetText(status)
			hb.text:Show()
		end
		sf:SetGrey()
	elseif (sf.greyMana) then
		sf.greyMana = nil
		hb.text:SetShown(self.conf.values and true or false)
		self:UpdatePower()
	end
	return hp, hpMax
end

-- UpdatePowerVisibility
-- Types with optionalPower hide the mana bar for units without power, or when conf.mana is off
function UF:UpdatePowerVisibility()
	local mb = self.statsFrame.manaBar
	local maxPower = UnitPowerMax(self.partyid)
	local show = self.conf.mana and (issecretvalue(maxPower) or maxPower > 0) and true or false
	if (show ~= mb:IsShown()) then
		mb:SetShown(show)
		self.statsFrame:SetHeight(show and 40 or 28 + ((conf.bar.fat or 0) * 2))
		XPerl_StatsFrameSetup(self, self:GetExtraBars(), self.statsOffset)
	end
	return show
end

-- UpdatePower
function UF:UpdatePower()
	if (self.optionalPower and not self:UpdatePowerVisibility()) then
		return
	end
	local unit = self.partyid
	local powerType = XPerl_GetDisplayedPowerType(unit)
	if (not powerType) then
		-- The client has no power data before PLAYER_ENTERING_WORLD on login; that event redraws the bar
		return
	end
	XPerl_SetManaBarType(self)
	XPerl_SetPowerBar(self, UnitPower(unit, powerType), UnitPowerMax(unit, powerType), powerType, self.exactPowerText)

	local sf = self.statsFrame
	if (not sf.greyMana) then
		sf.manaBar.text:SetShown(self.conf.values and true or false)
		sf.manaBar.percent:SetShown(self.conf.percent and true or false)
	end
end

------------------------------------------------------------------------------
-- Status icons
------------------------------------------------------------------------------
-- The raid target, group leader, raid assistant, master looter, main assist, main tank and combat icons sit
-- on a layer above the frame's parts, each on the spot its setting names (conf.icons, XPerl_StatusIconSpots;
-- "NONE" hides it). Icons sharing a spot line up left to right in XPerl_StatusIcons order: from the frame's
-- left or right side, or centred on the spot. The top and bottom rows straddle the frame's edge, the middle
-- row is centred on the frame's middle.

local statusOrder = XPerl_StatusIcons
local statusTextures = {
	raidTarget	= "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
	leader		= "Interface\\GroupFrame\\UI-Group-LeaderIcon",
	assistant	= "Interface\\GroupFrame\\UI-Group-AssistantIcon",
	masterLooter	= "Interface\\GroupFrame\\UI-Group-MasterLooter",
	mainAssist	= "Interface\\GroupFrame\\UI-Group-MainAssistIcon",
	mainTank	= "Interface\\GroupFrame\\UI-Group-MainTankIcon",
	combat		= "Interface\\CharacterFrame\\UI-StateIcon",
}
-- Spot -> the icons' point that lines up on it, which sets the way a row runs
local spotAlign = {
	TOPLEFT = "LEFT", LEFT = "LEFT", BOTTOMLEFT = "LEFT",
	TOP = "CENTER", CENTER = "CENTER", BOTTOM = "CENTER",
	TOPRIGHT = "RIGHT", RIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT",
}
local STATUS_ICON_GAP = 1		-- between the icons of a row
local STATUS_ICON_INSET = 2		-- between a row and the frame's side

-- CreateStatusIcons: the layer and its icons, statusIconSize square (16 unless the type sets it)
function UF:CreateStatusIcons()
	local layer = CreateFrame("Frame", nil, self)
	layer:SetAllPoints()
	layer:SetFrameLevel(self:GetFrameLevel() + 10)		-- above the name, stats and portrait frames
	local size = self.statusIconSize or 16
	local icons = {}
	for _, key in ipairs(statusOrder) do
		local icon = layer:CreateTexture(nil, "OVERLAY")
		icon:SetTexture(statusTextures[key])
		icon:SetSize(size, size)
		icon:Hide()
		icons[key] = icon
	end
	icons.combat:SetTexCoord(0.5, 1, 0, 0.5)
	self.statusIcons = {layer = layer, icons = icons, want = {}, shown = {}, combatState = "combat", dirty = true}
end

-- StatusIconSpots: the frame's status icon settings, {[icon key] = spot}
function UF:StatusIconSpots()
	return self.conf.icons
end

-- IsMasterLooter(unit)
local function IsMasterLooter(unit)
	local method, partyIndex, raidIndex = C_PartyInfo.GetLootMethod()
	if (method ~= Enum.LootMethod.Masterlooter) then
		return false
	elseif (raidIndex) then
		return Plain(UnitIsUnit("raid"..raidIndex, unit))
	elseif (partyIndex == 0) then
		return Plain(UnitIsUnit("player", unit))
	elseif (partyIndex) then
		return Plain(UnitIsUnit("party"..partyIndex, unit))
	end
end

-- RaidRole(unit): "MAINTANK" or "MAINASSIST" for a raid member the raid gave that role, else nil
local function RaidRole(unit)
	local index = IsInRaid() and Plain(UnitInRaid(unit))
	if (index) then
		return Plain((select(10, GetRaidRosterInfo(index))))
	end
end

-- UpdateStatusIcons: which icons show, and their rows when that changed (or the settings did)
function UF:UpdateStatusIcons()
	local si, spots, unit = self.statusIcons, self:StatusIconSpots(), self.partyid
	if (not spots or not unit) then
		return
	end
	local icons, want = si.icons, si.want
	local exists = UnitExists(unit)

	-- The raid target index is secret in restricted content, but a secret number still tests as true
	local index = exists and spotAlign[spots.raidTarget] and GetRaidTargetIndex(unit)
	if (index) then
		SetRaidTargetIconTexture(icons.raidTarget, index)
	end
	want.raidTarget = index and true or false

	local group = exists and IsInGroup()
	local leader = (group and Plain(UnitIsGroupLeader(unit))) and true or false
	want.leader = leader
	want.assistant = (group and not leader and Plain(UnitIsGroupAssistant(unit))) and true or false
	want.masterLooter = (group and IsMasterLooter(unit)) and true or false
	local raidRole = group and RaidRole(unit)
	want.mainAssist = raidRole == "MAINASSIST"
	want.mainTank = raidRole == "MAINTANK"

	-- Out of combat the player frame (showResting) shows whether the player is resting
	local combat = exists and Plain(UnitAffectingCombat(unit))
	local resting = not combat and self.showResting and IsResting()
	if (combat or resting) then
		local state = combat and "combat" or "resting"
		if (si.combatState ~= state) then
			si.combatState = state
			if (combat) then
				icons.combat:SetTexCoord(0.5, 1, 0, 0.5)
			else
				icons.combat:SetTexCoord(0, 0.5, 0, 0.5)
			end
		end
	end
	want.combat = (combat or resting) and true or false

	local shown, changed = si.shown, si.dirty
	for i = 1, #statusOrder do
		local key = statusOrder[i]
		local on = (want[key] and spotAlign[spots[key]]) and true or false
		if (on ~= (shown[key] or false)) then
			shown[key] = on
			icons[key]:SetShown(on)
			changed = true
		end
	end
	if (changed) then
		si.dirty = nil
		self:PlaceStatusIcons()
	end
end

-- PlaceStatusIcons: lines up the shown icons on their spots
function UF:PlaceStatusIcons()
	local si, spots = self.statusIcons, self:StatusIconSpots()
	local layer, icons, shown = si.layer, si.icons, si.shown
	local step = (self.statusIconSize or 16) + STATUS_ICON_GAP
	for _, spot in ipairs(XPerl_StatusIconSpots) do
		local count = 0
		for i = 1, #statusOrder do
			local key = statusOrder[i]
			if (shown[key] and spots[key] == spot) then
				count = count + 1
			end
		end
		if (count > 0) then
			local align = spotAlign[spot]
			local x
			if (align == "LEFT") then
				x = STATUS_ICON_INSET
			elseif (align == "RIGHT") then
				x = -STATUS_ICON_INSET - (count - 1) * step
			else
				x = (1 - count) * step / 2
			end
			for i = 1, #statusOrder do
				local key = statusOrder[i]
				if (shown[key] and spots[key] == spot) then
					local icon = icons[key]
					icon:ClearAllPoints()
					icon:SetPoint(align, layer, spot, x, 0)
					x = x + step
				end
			end
		end
	end
end

local roleTextures = {
	TANK = "Interface\\Addons\\XPerl\\Images\\XPerl_RoleTank",
	HEALER = "Interface\\Addons\\XPerl\\Images\\XPerl_RoleHealer",
	DAMAGER = "Interface\\Addons\\XPerl\\Images\\XPerl_RoleDamage",
}
local oldRoleTextures = {
	TANK = "Interface\\GroupFrame\\UI-Group-MainTankIcon",
	HEALER = "Interface\\Addons\\XPerl\\Images\\XPerl_RoleHealer_old",
	DAMAGER = "Interface\\GroupFrame\\UI-Group-MainAssistIcon",
}

-- XPerl_UnitFrame_RoleTexture(role)
-- Icon texture for an assigned role (TANK/HEALER/DAMAGER, conf.xperlOldroleicons style), or nil for none
-- or a restricted (secret) role
function XPerl_UnitFrame_RoleTexture(role)
	role = Plain(role)
	return role and (conf.xperlOldroleicons and oldRoleTextures or roleTextures)[role]
end

-- UpdateRole: the assigned role icon, in dungeons only (elsewhere roles can be left over from the last one)
function UF:UpdateRole()
	local icon = self.nameFrame.roleIcon
	local texture = select(2, IsInInstance()) == "party" and XPerl_UnitFrame_RoleTexture(UnitGroupRolesAssigned(self.partyid))
	if (texture) then
		icon:SetTexture(texture)
		icon:Show()
	else
		icon:Hide()
	end
end

-- XPerl_UnitPvPIcon(unit)
-- "FFA", the unit's faction for a PvP flagged unit, or nil
function XPerl_UnitPvPIcon(unit)
	if (Plain(UnitIsPVPFreeForAll(unit))) then
		return "FFA"
	elseif (UnitIsPVP(unit)) then
		local faction = Plain(UnitFactionGroup(unit))
		if (faction and faction ~= "Neutral") then
			return faction
		end
	end
end

-- UpdatePvP
function UF:UpdatePvP()
	local icon = self.nameFrame.pvpIcon
	local pvp = self.conf.pvpIcon and XPerl_UnitPvPIcon(self.pvpUnit or self.partyid)
	if (pvp) then
		icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..pvp)
		icon:Show()
	else
		icon:Hide()
	end
	self:UpdateNameColour()
end

-- UpdateCombat: the charmed warning (on the combat element's unit flag changes). Whether the unit is charmed
-- can be secret, so the client shows or clears the icon through its alpha.
function UF:UpdateCombat()
	local unit, icon = self.partyid, self.nameFrame.warningIcon
	if (UnitIsVisible(unit)) then
		icon:SetAlphaFromBoolean(UnitIsCharmed(unit), 1, 0)
		icon:Show()
	else
		icon:Hide()
	end
end

-- UpdateThreat
function UF:UpdateThreat(event)
	local relative = self.threatRelative
	if (relative and not UnitCanAttack(relative, self.partyid)) then
		relative = nil
	end
	XPerl_Unit_ThreatStatus(self, relative, not event)
end

-- UpdateRange: spell range fade, and the 30 yard icon (conf.range30yard; target, boss and arena)
function UF:UpdateRange()
	local unit = self.partyid
	if (not unit or not UnitExists(unit)) then
		return
	end
	XPerl_UpdateSpellRange(self, unit)

	local icon = self.nameFrame.rangeIcon
	if (icon) then
		local near = not self.conf.range30yard or not UnitIsConnected(unit) or CheckInteractDistance(unit, 1)
		if (issecretvalue(near) or near) then
			icon:Hide()
		else
			icon:Show()
			icon:SetAlpha(1)
		end
	end
end

------------------------------------------------------------------------------
-- Heal prediction (conf.healPrediction)
------------------------------------------------------------------------------
-- Incoming heals (yours, then everyone else's) and damage absorbs extend the health fill, heal absorbs cover
-- its end, and glows mark absorbs that don't fit. UnitGetDetailedHealPrediction fills a calculator whose
-- values may be secret: StatusBars take them as they are, and each segment hangs off the end of the fill
-- before it, so nothing is measured here. The calculator keeps heals and absorbs within the missing health
-- and heal absorbs within the current health, so every segment stays inside the health bar. Segments share
-- the health bar's frame level and sit one draw sublevel above its fill, below its texts.
-- With conf.bar.inverse the health bar fills with the missing health, so every segment runs the other way.

local predictionCalculator = CreateUnitHealPredictionCalculator()		-- filled and read within one update
predictionCalculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
predictionCalculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
predictionCalculator:SetIncomingHealOverflowPercent(1)
predictionCalculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
predictionCalculator:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.CurrentHealth)
predictionCalculator:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)

local GLOW_WIDTH = 12

-- PredictionSegment: a StatusBar drawn with the health bar, in X-Perl's bar texture. Hidden until
-- ApplyHealPrediction.
local function PredictionSegment(hb, layer, sublevel, r, g, b, a)
	local seg = CreateFrame("StatusBar", nil, hb)
	seg:SetUsingParentLevel(true)
	seg:SetStatusBarTexture(XPerl_GetBarTexture())
	seg.tex = seg:GetStatusBarTexture()
	seg.tex:SetDrawLayer(layer, sublevel)
	seg:SetStatusBarColor(r, g, b, a)
	seg:SetMinMaxValues(0, 1)
	seg:SetValue(0)
	seg:Hide()
	XPerl_RegisterBar(seg)
	return seg
end

-- PredictionGlow: an additive glow centred on one end of the health bar, invisible until a prediction update
-- shows it
local function PredictionGlow(hb, file, layer, sublevel)
	local glow = hb:CreateTexture(nil, layer, nil, sublevel)
	glow:SetTexture(file)
	glow:SetBlendMode("ADD")
	glow:SetWidth(GLOW_WIDTH)
	glow:SetAlpha(0)
	glow:Hide()
	return glow
end

-- Attach: the segment starts at the given edge of relative and fills towards the right, or with reverse
-- towards the left
local function Attach(seg, relative, relativeSide, reverse)
	local side = reverse and "RIGHT" or "LEFT"
	seg:ClearAllPoints()
	seg:SetPoint("TOP"..side, relative, "TOP"..relativeSide)
	seg:SetPoint("BOTTOM"..side, relative, "BOTTOM"..relativeSide)
	seg:SetReverseFill(reverse)
end

local function PlaceGlow(glow, hb, side, mirrored)
	glow:ClearAllPoints()
	glow:SetPoint("TOP", hb, "TOP"..side)
	glow:SetPoint("BOTTOM", hb, "BOTTOM"..side)
	if (mirrored) then
		glow:SetTexCoord(1, 0, 0, 1)
	else
		glow:SetTexCoord(0, 1, 0, 1)
	end
end

-- CreateHealPrediction (element init)
function UF:CreateHealPrediction()
	local hb = self.statsFrame.healthBar
	local layer, sublevel = hb:GetStatusBarTexture():GetDrawLayer()
	local above = min(sublevel + 1, 7)
	local top = min(sublevel + 2, 7)

	local absorbs = PredictionSegment(hb, layer, above, 0.9, 0.95, 1, 0.6)
	local stripes = absorbs:CreateTexture(nil, layer, nil, top)
	stripes:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
	stripes:SetHorizTile(true)
	stripes:SetVertTile(true)
	stripes:SetAllPoints(absorbs.tex)

	local p = {
		myHeals = PredictionSegment(hb, layer, above, 0, 1, 1, 0.65),
		otherHeals = PredictionSegment(hb, layer, above, 0, 0.6, 0.65, 0.65),
		absorbs = absorbs,
		healAbsorbs = PredictionSegment(hb, layer, above, 0.55, 0.05, 0.2, 0.8),
		overAbsorb = PredictionGlow(hb, "Interface\\RaidFrame\\Shield-Overshield", layer, top),
		overHealAbsorb = PredictionGlow(hb, "Interface\\RaidFrame\\Absorb-Overabsorb", layer, top),
	}
	p.segments = {p.myHeals, p.otherHeals, p.absorbs, p.healAbsorbs}
	self.prediction = p

	-- Segments are as wide as the health bar, so a full one reaches its far end
	hb:HookScript("OnSizeChanged", function(_, width)
		for i = 1, #p.segments do
			p.segments[i]:SetWidth(width)
		end
	end)
end

-- ApplyHealPrediction (element apply): on or off, and the direction the health bar fills
function UF:ApplyHealPrediction()
	local p = self.prediction
	local on = self.conf.healPrediction and true or false
	p.on = on
	for i = 1, #p.segments do
		p.segments[i]:SetShown(on)
	end
	p.overAbsorb:SetShown(on)
	p.overHealAbsorb:SetShown(on)
	if (not on) then
		return
	end

	local hb = self.statsFrame.healthBar
	local fill = hb:GetStatusBarTexture()
	local width = hb:GetWidth()
	for i = 1, #p.segments do
		p.segments[i]:SetWidth(width)
	end
	if (conf.bar.inverse) then
		Attach(p.myHeals, fill, "RIGHT", true)
		Attach(p.otherHeals, p.myHeals.tex, "LEFT", true)
		Attach(p.absorbs, p.otherHeals.tex, "LEFT", true)
		Attach(p.healAbsorbs, fill, "RIGHT", false)
		PlaceGlow(p.overAbsorb, hb, "LEFT", true)
		PlaceGlow(p.overHealAbsorb, hb, "RIGHT", true)
	else
		Attach(p.myHeals, fill, "RIGHT", false)
		Attach(p.otherHeals, p.myHeals.tex, "RIGHT", false)
		Attach(p.absorbs, p.otherHeals.tex, "RIGHT", false)
		Attach(p.healAbsorbs, fill, "RIGHT", true)
		PlaceGlow(p.overAbsorb, hb, "RIGHT", false)
		PlaceGlow(p.overHealAbsorb, hb, "LEFT", false)
	end
end

-- UpdateHealPrediction: called on the element's events and by every health bar update. Frames without the
-- element (party targets) have no segments.
function UF:UpdateHealPrediction()
	local p = self.prediction
	if (not p or not p.on) then
		return
	end

	local calc = predictionCalculator
	UnitGetDetailedHealPrediction(self.partyid, "player", calc)
	local healthMax = calc:GetMaximumHealth()
	local _, mine, others = calc:GetIncomingHeals()
	local absorbs, overAbsorb = calc:GetDamageAbsorbs()
	local healAbsorbs, overHealAbsorb = calc:GetHealAbsorbs()

	p.myHeals:SetMinMaxValues(0, healthMax)
	p.myHeals:SetValue(mine)
	p.otherHeals:SetMinMaxValues(0, healthMax)
	p.otherHeals:SetValue(others)
	p.absorbs:SetMinMaxValues(0, healthMax)
	p.absorbs:SetValue(absorbs)
	p.healAbsorbs:SetMinMaxValues(0, healthMax)
	p.healAbsorbs:SetValue(healAbsorbs)
	p.overAbsorb:SetAlphaFromBoolean(overAbsorb, 1, 0)
	p.overHealAbsorb:SetAlphaFromBoolean(overHealAbsorb, 1, 0)
end

-- UpdateReadyCheck
function UF:UpdateReadyCheck()
	XPerl_Unit_UpdateReadyState(self)
end

-- OnUnitCombat: hit indicator over the portrait (conf.hitIndicator), and the combat flash of the borders
function UF:OnUnitCombat(event, unit, action, descriptor, damage, damageType)
	if (issecretvalue(action) or issecretvalue(damage) or issecretvalue(descriptor) or issecretvalue(damageType)) then
		return
	end
	if (self.feedbackText and self.conf.hitIndicator and self.conf.portrait) then
		CombatFeedback_OnCombatEvent(self, action, descriptor, damage, damageType)
	end

	if (action == "HEAL") then
		if (XPerl_CombatFlashSet(self, 0, true, true)) then
			XPerl_CombatFlashSetFrames(self)
		end
	elseif (damage and damage > 0) then
		if (XPerl_CombatFlashSet(self, 0, true)) then
			XPerl_CombatFlashSetFrames(self)
		end
	end
end

-- OnPetBattle
function UF:OnPetBattle(event)
	if (InCombatLockdown() or self.headerChild) then
		return
	end
	if (event == "PET_BATTLE_OPENING_START") then
		self:Hide()
	elseif (self.active and (not self.useUnitWatch or UnitExists(self.partyid))) then
		self:Show()
	end
end

------------------------------------------------------------------------------
-- Auras
------------------------------------------------------------------------------

-- UpdateAuras
-- The aura containers follow UNIT_AURA themselves; this does feign death and, on a full refresh or a faction
-- change, points the containers at the unit again.
function UF:UpdateAuras(event)
	local unit = self.partyid
	if (event ~= "UNIT_AURA") then
		if (not event) then
			self:CheckAuraWidth()
		end
		XPerl_Auras_SetUnit(self, unit)
		if (event) then
			return
		end
	end

	local feigning = Plain(UnitIsFeignDeath(unit))
	if (feigning ~= self.feigning) then
		self.feigning = feigning
		self:UpdateHealth()
	end
end

-- PlaceAuras: the aura holder sits above the frame or below the stats
function UF:PlaceAuras()
	local bf = self.buffFrame
	bf:ClearAllPoints()
	if (self.conf.buffs.above) then
		bf:SetPoint("BOTTOMLEFT", self, "TOPLEFT", self.auraInset or 2, 0)
	else
		bf:SetPoint("TOPLEFT", self.statsFrame, "BOTTOMLEFT", self.auraInset or 2, 0)
	end
end

-- GetAuraLineWidth
-- Wrapped rows span the stats frame and the portrait and level frames beside it; the container sizes are
-- secret once they show auras, so nothing below the frame can be stepped around
function UF:GetAuraLineWidth()
	if (not self.conf.buffs.wrap) then
		return nil
	end
	local w = self.statsFrame:GetWidth()
	if (self.portraitFrame and self.portraitFrame:IsShown()) then
		w = w - 2 + self.portraitFrame:GetWidth()
	end
	if (self.levelFrame and self.levelFrame:IsShown()) then
		w = w - 2 + self.levelFrame:GetWidth()
	end
	return w
end

-- ConfigureAuras
function UF:ConfigureAuras()
	XPerl_Auras_Configure(self, XPerl_Auras_UnitOptions(self, {
		above = self.conf.buffs.above,
		order = self.auraOrder,
		lineWidth = self:GetAuraLineWidth(),
	}))
end

-- CheckAuraWidth: re-wraps the rows when the frames beside the stats changed with the unit
function UF:CheckAuraWidth()
	local opts = self.auras and self.auras.opts
	if (opts and opts.lineWidth ~= self:GetAuraLineWidth()) then
		self:ConfigureAuras()
	end
end
