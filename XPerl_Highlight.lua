-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Status highlights on unit frames: aggro and your target, as a border colour, and debuffs, as a glow of the
-- same shape in the debuff type's colour. Heal prediction and absorbs on the health bar are the unit frames' own
-- (Units/UnitFrame.lua).
--
-- Unit code tells this module about its frames through XPerl_Highlight:UnitFrameChanged(frame) whenever a
-- frame's unit (frame.partyid) changes or the frame is shown; XPerl_ForEachUnitFrame finds every frame when
-- options change. Visuals go on frame.highlight (the XPerl_HighlightTemplate child).
--
-- 12.x secret values: UnitThreatSituation(unit) for a single unit is not secret, and a secret GUID simply
-- doesn't match your target. Add-on code can't tell auras apart while add-on restrictions are active (every
-- aura index reads as secret, filled or not), so the HoT highlights are gone and the client draws the debuff
-- glow (see "Debuff glow" below).

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitThreatSituation = UnitThreatSituation
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local UnitPlayerOrPetInRaid = UnitPlayerOrPetInRaid
local issecretvalue = issecretvalue

local colours = {
	AGGRO = {r = 0.8, g = 0, b = 0},
	TARGET = {r = 0.7167, g = 0.6833, b = 0.31467},		-- colour * 1.2 == selection colour
}
local SELECTION = {r = 0.86, g = 0.82, b = 0.41}
local borderOrder = {"AGGRO", "TARGET"}		-- both shown as a gradient when both apply
local tooltipOrder = {"AGGRO"}

local xpHigh = CreateFrame("Frame", "XPerl_Highlight")

local frameUnit = {}		-- frame -> unit token it shows
local unitFrames = {}		-- unit token -> {frame = true}
local unitState = {}		-- unit token -> state table (keys AGGRO, TARGET)
local pendingUnits = {}
local pendingAll, pendingThreat, pendingTarget
local targetGUID

---------------------------------------------------------------------------------------------------------------
-- Frame decorations
---------------------------------------------------------------------------------------------------------------

-- Border colour on frame.highlight.tex; without highlights it keeps the plain selection look
local function ShowBorder(frame, st)
	local h = frame.highlight
	local tex = h.tex
	local c1, c2
	if (st) then
		local hc = conf.highlight
		for _, key in ipairs(borderOrder) do
			if (st[key] and hc[key]) then
				if (not c1) then
					c1 = colours[key]
				else
					c2 = colours[key]
					break
				end
			end
		end
	end

	if (c1) then
		local m = h.sel and 1.2 or 1
		if (c2) then
			tex:SetGradient("HORIZONTAL", CreateColor(min(c1.r * m, 1), min(c1.g * m, 1), min(c1.b * m, 1), 1),
							CreateColor(min(c2.r * m, 1), min(c2.g * m, 1), min(c2.b * m, 1), 1))
		else
			tex:SetVertexColor(min(c1.r * m, 1), min(c1.g * m, 1), min(c1.b * m, 1))
		end
		tex:Show()
		tex:SetAlpha(1)
	else
		tex:SetVertexColor(SELECTION.r, SELECTION.g, SELECTION.b)
		if (h.sel and conf and conf.highlightSelection) then
			tex:Show()
			tex:SetAlpha(1)
		else
			tex:Hide()
		end
	end
end

local function RenderUnit(unit)
	local st = unitState[unit]
	local set = unitFrames[unit]
	if (set) then
		for frame in pairs(set) do
			ShowBorder(frame, st)
		end
	end
end

-- Debuff glow (conf.highlight.DEBUFF)
-- A unit with a Magic, Curse, Disease or Poison debuff (with conf.highlight.curable, only one the player can
-- cure) gets a second copy of the border art in that debuff type's colour. Each frame gets a custom aura
-- container with a single aura slot: the client puts the unit's first such debuff in the slot and colours the
-- glow on the slot's button by its type, or hides the button when there is none. Nothing tells add-on code the
-- glow is showing, so it adds to the aggro and target colours instead of taking a side of their gradient.
-- Container and button sit on frame.highlight at its frame level. Units get one while they get status
-- highlights (they exist and the player can assist them). /xperl debuffs shows a preview of it.
local DEBUFF_SLOT = "debuff"
local DebuffTypes = {"Magic", "Curse", "Disease", "Poison"}
local DebuffCandidates = {includeDispelTypes = {Magic = true, Curse = true, Disease = true, Poison = true}}
local debuffGlows = {}		-- frame -> aura container drawing its glow, made the first time it's needed
local debuffPreviews = {}	-- frame -> X-Perl's own copy of the glow, for /xperl debuffs
local debuffPreviewType		-- dispel type /xperl debuffs shows, nil when it's off

-- CreateGlow(parent, frame): a copy of frame's border art, on parent
local function CreateGlow(parent, frame)
	local h = frame.highlight
	local glow = parent:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Addons\\XPerl\\images\\XPerl_Highlight")
	glow:SetTexCoord(XPerl_GetHighlightTexCoords(h))
	glow:SetBlendMode("ADD")
	glow:SetAllPoints(h)
	return glow
end

-- InitGlowButton
-- Runs once as the container creates the slot's button, before the client locks it away from add-on code
local function InitGlowButton(button, frame)
	button:SetUsingParentLevel(true)
	button:EnableMouse(false)		-- clicks and tooltips stay the unit frame's
	button:SetAllPoints(frame.highlight)
	button:AddDispelTypeTexture(CreateGlow(button, frame), {
		showWhenHarmful = true,
		style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
	})
end

-- UpdateDebuffGlow(frame, unit): points frame's glow at unit (nil: none) and refreshes it. Frames can show before
-- the settings arrive; no glow exists then.
local function UpdateDebuffGlow(frame, unit)
	local hc = conf and conf.highlight
	local on = unit and hc and hc.enable and hc.DEBUFF and true or false
	local container = debuffGlows[frame]
	if (not container) then
		if (not on) then
			return
		end
		local h = frame.highlight
		container = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
		container:SetUsingParentLevel(true)
		container:SetAllPoints(h)
		container:AddAuraSlot(DEBUFF_SLOT, "HARMFUL", {
			candidateFilters = DebuffCandidates,
			initializeFrame = function(button) InitGlowButton(button, frame) end,
		})
		debuffGlows[frame] = container
	end
	container:SetAuraSlotFilterString(DEBUFF_SLOT, hc.curable and "HARMFUL|RAID" or "HARMFUL")
	container:SetUnit(unit or "none")
	container:SetEnabled(on)
	container:UpdateAllAuras()		-- the unit behind the token may have changed
end

-- ShowDebuffPreview(frame)
-- X-Perl's own copy of the glow, in the colour the client gives debuffPreviewType, on every frame with status
-- highlights whatever its unit
local function ShowDebuffPreview(frame)
	local hc = conf.highlight
	local colour = debuffPreviewType and frame.active and hc.enable and hc.DEBUFF and AuraUtil.GetAuraBorderColor(debuffPreviewType)
	local preview = debuffPreviews[frame]
	if (colour) then
		if (not preview) then
			preview = CreateFrame("Frame", nil, frame.highlight)
			preview:SetUsingParentLevel(true)
			preview:SetAllPoints(frame.highlight)
			preview.glow = CreateGlow(preview, frame)
			debuffPreviews[frame] = preview
		end
		preview.glow:SetVertexColor(colour:GetRGBA())
		preview:Show()
	elseif (preview) then
		preview:Hide()
	end
end

local function ShowDebuffPreviews()
	XPerl_ForEachUnitFrame(function(frame)
		if (frame.highlight) then
			ShowDebuffPreview(frame)
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------------------

local function ScanThreat(unit, st)
	local status = UnitThreatSituation(unit)
	st.AGGRO = not issecretvalue(status) and status and status >= 2 or nil
end

local function UpdateTargetGUID()
	targetGUID = nil
	if (UnitExists("target") and (UnitPlayerOrPetInParty("target") or UnitPlayerOrPetInRaid("target"))) then
		local guid = UnitGUID("target")
		if (not issecretvalue(guid)) then
			targetGUID = guid
		end
	end
end

-- Your target, on frames other than the target frame itself
local function ScanTarget(unit, st)
	st.TARGET = nil
	if (targetGUID and unit ~= "target") then
		local guid = UnitGUID(unit)
		if (not issecretvalue(guid) and guid == targetGUID) then
			st.TARGET = true
		end
	end
end

-- RefreshUnit: rebuild unit's whole state and redraw its frames. Only units you can assist get status
-- highlights (a hostile target or target-of-target shows none).
local function RefreshUnit(unit)
	if (not UnitExists(unit) or not UnitCanAssist("player", unit)) then
		unitState[unit] = nil
	else
		local st = unitState[unit]
		if (not st) then
			st = {}
			unitState[unit] = st
		end
		ScanThreat(unit, st)
		ScanTarget(unit, st)
	end
	RenderUnit(unit)

	local set = unitFrames[unit]
	if (set) then
		local glowUnit = unitState[unit] and unit
		for frame in pairs(set) do
			UpdateDebuffGlow(frame, glowUnit)
		end
	end
end

-- Units without events of their own (targettarget, party1target, ...) are polled
local function IsPolled(unit)
	return unit ~= "target" and strfind(unit, "target$") ~= nil
end

---------------------------------------------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------------------------------------------
local PROCESS_INTERVAL, POLL_INTERVAL = 0.1, 0.5
local sinceProcess, sincePoll = 0, 0

local function Process()
	if (pendingAll) then
		pendingAll, pendingThreat, pendingTarget = nil, nil, nil
		wipe(pendingUnits)
		for unit in pairs(unitFrames) do
			RefreshUnit(unit)
		end
		return
	end

	for unit in pairs(pendingUnits) do
		pendingUnits[unit] = nil
		if (unitFrames[unit]) then
			RefreshUnit(unit)
		end
	end

	if (pendingThreat or pendingTarget) then
		local threat, target = pendingThreat, pendingTarget
		pendingThreat, pendingTarget = nil, nil
		for unit, st in pairs(unitState) do
			local aggro, isTarget = st.AGGRO, st.TARGET
			if (threat) then
				ScanThreat(unit, st)
			end
			if (target) then
				ScanTarget(unit, st)
			end
			if (st.AGGRO ~= aggro or st.TARGET ~= isTarget) then
				RenderUnit(unit)
			end
		end
	end
end

-- Poll: units without events
local function Poll()
	for unit in pairs(unitFrames) do
		if (IsPolled(unit)) then
			RefreshUnit(unit)
		end
	end
end

local function OnUpdate(self, elapsed)
	sinceProcess = sinceProcess + elapsed
	if (sinceProcess >= PROCESS_INTERVAL) then
		sinceProcess = 0
		Process()
	end

	sincePoll = sincePoll + elapsed
	if (sincePoll >= POLL_INTERVAL) then
		sincePoll = 0
		Poll()
	end
end

---------------------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------------------
local events = {}

-- UNIT_THREAT_SITUATION_UPDATE fires once per unit (not for every token showing it)
function events.UNIT_THREAT_SITUATION_UPDATE()
	pendingThreat = true
end

function events.PLAYER_TARGET_CHANGED()
	UpdateTargetGUID()
	pendingTarget = true
	-- The target frame keeps its unit token while the unit behind it changes
	for unit in pairs(unitFrames) do
		if (strfind(unit, "^target")) then
			pendingUnits[unit] = true
		end
	end
end

function events.PLAYER_FOCUS_CHANGED()
	for unit in pairs(unitFrames) do
		if (strfind(unit, "^focus")) then
			pendingUnits[unit] = true
		end
	end
end

-- Roster, pets, zoning, and every change of the add-on restrictions that make data secret
local function RefreshAll()
	pendingAll = true
end
events.GROUP_ROSTER_UPDATE = RefreshAll
events.UNIT_PET = RefreshAll
events.PLAYER_ENTERING_WORLD = RefreshAll
events.PLAYER_REGEN_DISABLED = RefreshAll
events.PLAYER_REGEN_ENABLED = RefreshAll
events.ADDON_RESTRICTION_STATE_CHANGED = RefreshAll

xpHigh:SetScript("OnEvent", function(self, event, ...)
	events[event](...)
end)

local function SetEvents(on)
	for event in pairs(events) do
		if (not on) then
			xpHigh:UnregisterEvent(event)
		elseif (not C_EventUtils or C_EventUtils.IsEventValid(event)) then
			xpHigh:RegisterEvent(event)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------------------

-- XPerl_Highlight:UnitFrameChanged(frame)
-- Unit code calls this whenever frame.partyid changes, the frame is shown, or its selection changes
function xpHigh:UnitFrameChanged(frame)
	if (not frame.highlight) then
		return
	end

	local unit = frame.active and frame.partyid or nil		-- frames of disabled types are not tracked
	local old = frameUnit[frame]
	if (old ~= unit) then
		if (old) then
			local set = unitFrames[old]
			set[frame] = nil
			if (not next(set)) then
				unitFrames[old] = nil
				unitState[old] = nil
			end
		end
		frameUnit[frame] = unit
		if (unit) then
			local set = unitFrames[unit]
			if (not set) then
				set = {}
				unitFrames[unit] = set
			end
			set[frame] = true
		end
	end

	if (conf and conf.highlight.enable and unit) then
		RefreshUnit(unit)
	else
		ShowBorder(frame, nil)
		UpdateDebuffGlow(frame, nil)
	end
end

-- XPerl_Highlight:TooltipInfo(unit)
-- Adds the unit's active status highlights to GameTooltip
function xpHigh:TooltipInfo(unit)
	local st = unit and conf and conf.highlight.enable and not issecretvalue(unit) and unitState[unit]
	if (not st) then
		return
	end

	local str
	for _, key in ipairs(tooltipOrder) do
		local desc = XPERL_LOC_STATUSTIPLIST[key]
		if (st[key] and conf.highlight[key] and desc) then
			local c = colours[key]
			local entry = format("|cFF%02X%02X%02X%s|r", 255 * c.r, 255 * c.g, 255 * c.b, desc)
			str = str and (str..", "..entry) or (XPERL_LOC_STATUSTIP..entry)
		end
	end

	if (str) then
		GameTooltip:AddLine(str)
		GameTooltip:Show()
	end
end

-- DebuffTypeName(dispelType): the type's name in its colour
local function DebuffTypeName(dispelType)
	return AuraUtil.GetAuraBorderColor(dispelType):WrapTextInColorCode(dispelType)
end

-- XPerl_DebuffHighlightPreview(which)
-- /xperl debuffs: the debuff glow's four colours in turn, two seconds each; with a type ("magic", ...) that one
-- alone. Run again without a type to stop.
local previewTicker
function XPerl_DebuffHighlightPreview(which)
	if (not (conf.highlight.enable and conf.highlight.DEBUFF)) then
		XPerl_Notice(XPERL_DEBUFFS_PREVIEW_OFF)
		return
	end
	local fixed
	if (which) then
		for _, dispelType in ipairs(DebuffTypes) do
			if (strlower(dispelType) == which) then
				fixed = dispelType
			end
		end
		if (not fixed) then
			XPerl_Notice(XPERL_DEBUFFS_PREVIEW_USAGE)
			return
		end
	end

	if (previewTicker) then
		previewTicker:Cancel()
		previewTicker = nil
	end
	if (fixed) then
		debuffPreviewType = fixed
		XPerl_Notice(XPERL_DEBUFFS_PREVIEW_ONE, DebuffTypeName(fixed))
	elseif (debuffPreviewType) then
		debuffPreviewType = nil
		XPerl_Notice(XPERL_DEBUFFS_PREVIEW_STOPPED)
	else
		local names = {}
		for i, dispelType in ipairs(DebuffTypes) do
			names[i] = DebuffTypeName(dispelType)
		end
		local index = 1
		debuffPreviewType = DebuffTypes[index]
		previewTicker = C_Timer.NewTicker(2, function()
			index = index % #DebuffTypes + 1
			debuffPreviewType = DebuffTypes[index]
			ShowDebuffPreviews()
		end)
		XPerl_Notice(XPERL_DEBUFFS_PREVIEW_CYCLE, table.concat(names, ", "))
	end
	ShowDebuffPreviews()
end

-- OptionChange: (re)apply XPerlDB.highlight
local function OptionChange()
	local enabled = conf.highlight.enable

	wipe(unitState)
	wipe(pendingUnits)
	pendingAll, pendingThreat, pendingTarget = nil, nil, nil

	SetEvents(enabled)
	if (enabled) then
		UpdateTargetGUID()
		xpHigh:SetScript("OnUpdate", OnUpdate)
	else
		xpHigh:SetScript("OnUpdate", nil)
	end

	local done = {}
	XPerl_ForEachUnitFrame(function(frame)
		done[frame] = true
		xpHigh:UnitFrameChanged(frame)
	end)
	for frame in pairs(frameUnit) do
		if (not done[frame]) then
			xpHigh:UnitFrameChanged(frame)
		end
	end
	ShowDebuffPreviews()
end

XPerl_RegisterOptionChanger(OptionChange)
