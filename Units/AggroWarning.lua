-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Aggro warning (once part of the Raid Helper): "- AGGRO -" in the middle of the screen while a mob is
-- attacking you, "- PET AGGRO -" below it while one is attacking your pet. Only in a group: alone you know
-- who is being hit. Red while it lasts, then it fades out in green. player.aggroWarning.enable is a player
-- frame setting (per Edit Mode layout). Edit Mode places the warning (XPerl_AggroWarning) as a third "player"
-- frame whose default stays in the middle of the screen in every layout.
--
-- 12.x secret values: on restricted maps it is secret whom a group member's target is targeting, so the old
-- scan of the group's targets can't find the mobs on you. UnitThreatSituation for a single unit is not
-- secret: 2 or more means the unit tops the threat of a mob it is in combat with, so that mob attacks it.

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local UnitThreatSituation = UnitThreatSituation
local issecretvalue = issecretvalue
local GetTime = GetTime

local FADE_TIME = 1		-- seconds an ended warning takes to fade out
local EVENTS = {"GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED"}

local warning			-- XPerl_AggroWarning
local texts = {}		-- the player's line and the pet's line; text.unit is whose aggro it shows
local previewing		-- shown for placing (Edit Mode, unlocked frames)

local function Enabled()
	local setting = conf.player.aggroWarning
	return setting and setting.enable
end

-- A mob is attacking unit: it is tanking (status 2, insecurely, or 3). nil without the unit or out of combat.
local function HasAggro(unit)
	local status = UnitThreatSituation(unit)
	return not issecretvalue(status) and status ~= nil and status >= 2
end

local function AnyShown()
	return texts[1]:IsShown() or texts[2]:IsShown()
end

local function OnUpdate(self)
	local now, fading = GetTime()
	for _, text in ipairs(texts) do
		if (text.fadeStart) then
			local elapsed = now - text.fadeStart
			if (elapsed < FADE_TIME) then
				text:SetAlpha(1 - elapsed / FADE_TIME)
				fading = true
			else
				text.fadeStart = nil
				text:Hide()
			end
		end
	end
	if (not fading) then
		self:SetScript("OnUpdate", nil)
		self:SetShown(AnyShown())
	end
end

local function Update()
	if (previewing) then
		return
	end
	local enabled = Enabled()
	local grouped = enabled and IsInGroup()
	for _, text in ipairs(texts) do
		if (grouped and HasAggro(text.unit)) then
			text.fadeStart = nil
			text:SetTextColor(1, 0, 0)
			text:SetAlpha(1)
			text:Show()
		elseif (not enabled) then
			text.fadeStart = nil
			text:Hide()
		elseif (text:IsShown() and not text.fadeStart) then
			text.fadeStart = GetTime()
			text:SetTextColor(0, 1, 0)
		end
	end
	warning:SetScript("OnUpdate", (texts[1].fadeStart or texts[2].fadeStart) and OnUpdate or nil)
	warning:SetShown(AnyShown())
end

-- Edit Mode and the options window's unlocked frames show the warning for placing, in blue as it used to be
-- while dragged, unless it is switched off. In Edit Mode LibEditMode's child selection owns the mouse; the
-- warning's own drag handler only works in the options window's unlocked mode and would intercept that drag.
local function Preview(on)
	local was = previewing
	previewing = (on and Enabled()) and true or nil
	warning:EnableMouse(previewing == true and not XPerl_EditMode_IsEditing())
	if (previewing) then
		warning:SetScript("OnUpdate", nil)
		for _, text in ipairs(texts) do
			text.fadeStart = nil
			text:SetTextColor(0.4, 0.6, 1)
			text:SetAlpha(1)
			text:Show()
		end
		warning:Show()
		return
	end
	if (was) then
		for _, text in ipairs(texts) do
			text:Hide()
		end
	end
	Update()
end

local function AddLine(unit, label, size)
	local text = warning:CreateFontString(nil, "OVERLAY")
	text:SetFont((GameFontNormal:GetFont()), size, "THICKOUTLINE")
	text:SetText(label)
	text:Hide()
	text.unit = unit
	texts[#texts + 1] = text
	return text
end

local function Create()
	warning = CreateFrame("Frame", "XPerl_AggroWarning", UIParent)
	warning:SetSize(320, 72)
	warning:SetPoint("CENTER")
	warning:SetFrameStrata("HIGH")
	warning:SetClampedToScreen(true)
	warning:SetMovable(true)
	warning:EnableMouse(false)
	warning:RegisterForDrag("LeftButton")
	warning:SetScript("OnDragStart", XPerl_UnitFrameMixin.OnDragStart)		-- the options window's unlocked drag
	warning:SetScript("OnDragStop", XPerl_UnitFrameMixin.OnDragStop)
	warning:SetScript("OnEvent", Update)
	warning:Hide()

	local player = AddLine("player", XPERL_AGGRO_PLAYER, 42)
	player:SetPoint("TOP")
	local pet = AddLine("pet", XPERL_AGGRO_PET, 16)
	pet:SetPoint("TOP", player, "BOTTOM", 0, -2)
end

local function SetEvents(on)
	warning:UnregisterAllEvents()
	if (not on) then
		return
	end
	for _, event in ipairs(EVENTS) do
		if (not C_EventUtils or C_EventUtils.IsEventValid(event)) then
			warning:RegisterEvent(event)
		end
	end
	warning:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player", "pet")
	warning:RegisterUnitEvent("UNIT_PET", "player")
end

-- Apply: the setting changed (options window, Edit Mode dialog, layout switch, login)
local function Apply()
	if (not warning) then
		Create()
		XPerl_EditMode_Register(warning, "player", {
			label = XPERL_CONF_PLAYER_AGGROWARNING,
			default = {point = "CENTER", x = 0, y = 0},
			index = 3,
			fixed = true,
			preview = Preview,
		})
	end
	local enabled = Enabled() and true or false
	SetEvents(enabled)
	XPerl_EditMode_SetEnabled(warning, enabled)
	Preview(XPerlLocked == 0 or XPerl_EditMode_IsEditing())
end

XPerl_RegisterOptionChanger(Apply)
