-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Cast bar element (replaces XPerl_ArcaneBar). A StatusBar from XPerl_CastBarTemplate covers the unit
-- frame's name frame while the unit casts.
--
-- Cast information of units other than the player and their pet is secret while spell casts are
-- restricted: no comparisons or arithmetic on names, times, spell IDs or the interruptible flag. The bar
-- therefore runs on the client's duration objects (UnitCastingDuration/UnitChannelDuration ->
-- StatusBar:SetTimerDuration), the cast time text on a DurationTextBinding, the spark on the bar texture's
-- edge and the "can't interrupt" shield on SetAlphaFromBoolean. Names go straight to SetText. Only the
-- player's own casts (never secret) are used for the latency (precast) mark. Clients without duration
-- objects fall back to plain timing, where values are never secret.
--
-- Blizzard's CastingBarMixin isn't reused: it does arithmetic on the cast times, which only untainted code
-- may do with secret values.

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local GetTime = GetTime
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local useDurations = UnitCastingDuration and UnitChannelDuration and C_DurationUtil and true

local HOLD_TIME = 1			-- seconds a failed or interrupted bar stays before it fades
local FLASH_STEP = 3			-- flash alpha per second after a cast ends
local FADE_STEP = 2			-- bar alpha per second while fading

local barColours = {
	main = {r = 1.0, g = 0.7, b = 0.0},
	channel = {r = 0.0, g = 1.0, b = 0.0},
	success = {r = 0.0, g = 1.0, b = 0.0},
	failure = {r = 1.0, g = 0.0, b = 0.0},
}

local castEvents = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
	"UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local IsEventValid = C_EventUtils and C_EventUtils.IsEventValid

-- Remaining seconds with one decimal ("1.5s")
local timeFormatter
if (useDurations and C_StringUtil and C_StringUtil.CreateSecondsFormatter) then
	timeFormatter = C_StringUtil.CreateSecondsFormatter()
	timeFormatter:SetMillisecondsThreshold(60)
	timeFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	timeFormatter:SetMaxInterval(Enum.SecondsFormatterInterval.Seconds)
	timeFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
end

-- Blizzard's player cast bar is switched off by clearing its unit, which unregisters its events and hides it
local blizzardBarOff
local function ShowBlizzardPlayerBar(show)
	if (not PlayerCastingBarFrame) then
		return
	end
	if (show) then
		if (blizzardBarOff) then
			blizzardBarOff = nil
			PlayerCastingBarFrame:SetUnit("player", true, false)
		end
	elseif (not blizzardBarOff) then
		blizzardBarOff = true
		PlayerCastingBarFrame:SetUnit(nil)
	end
end

XPerl_CastBarMixin = {}
local CB = XPerl_CastBarMixin

-- XPerl_CastBar_Create(owner)
-- Element init: the bar is named <nameFrame>CastBar and covers the name frame
function XPerl_CastBar_Create(owner)
	local nameFrame = owner.nameFrame
	local bar = CreateFrame("StatusBar", nameFrame:GetName().."CastBar", nameFrame, "XPerl_CastBarTemplate")
	Mixin(bar, CB)
	owner.castBar = bar

	bar.owner = owner
	bar.unit = owner.partyid
	bar.nameText = nameFrame.text
	bar:SetPoint("TOPLEFT", 4, -4)
	bar:SetPoint("BOTTOMRIGHT", -4, 4)
	bar:SetFrameLevel(nameFrame:GetFrameLevel() + 2)

	bar.tex = bar:GetStatusBarTexture()
	bar.tex:SetTexture("Interface\\AddOns\\XPerl\\Images\\XPerl_StatusBar")
	bar.tex:SetHorizTile(false)
	bar.tex:SetVertTile(false)
	bar.spark:SetPoint("CENTER", bar.tex, "RIGHT", 0, 1)
	XPerl_RegisterBar(bar)

	if (owner.frameKey == "player") then
		local tex = XPerl_GetBarTexture()
		bar.precast = bar:CreateTexture(nil, "ARTWORK")
		bar.precast:SetTexture(tex)
		bar.precast:SetBlendMode("ADD")
		bar.precast:SetGradient("HORIZONTAL", CreateColor(0, 0, 1, 1), CreateColor(1, 0, 0, 1))
		bar.precast:Hide()
	end

	if (useDurations) then
		bar.timeBinding = C_DurationUtil.CreateDurationTextBinding()
		if (timeFormatter) then
			bar.timeBinding:SetFormatter(timeFormatter)
		end
		bar.timeBinding:SetFontString(bar.castTimeText)
		bar.timeBinding:SetEnabled(false)
	end

	bar:SetScript("OnEvent", bar.OnEvent)
	bar:SetScript("OnUpdate", bar.OnUpdate)
	return bar
end

-- ApplySettings: owner's conf.castBar.enable and .inside; the cast time text and precast mark follow the
-- player's settings (conf.player.castBar), as they always did, and the player frame owns Blizzard's bar
function CB:ApplySettings()
	local c = self.owner.conf.castBar
	local pc = conf.player.castBar

	self.castTimeText:ClearAllPoints()
	if (c and c.inside) then
		self.castTimeText:SetPoint("RIGHT", self, "RIGHT", -2, 0)
		self.castTimeText:SetJustifyH("RIGHT")
	else
		self.castTimeText:SetPoint("LEFT", self, "RIGHT", 2, 0)
		self.castTimeText:SetJustifyH("LEFT")
	end
	self.showCastTime = pc.castTime
	self.showPrecast = pc.precast

	if (self.owner.frameKey == "player") then
		ShowBlizzardPlayerBar(pc.original)
	end

	self:SetActive(c and c.enable and self.owner.active)
end

-- SetActive(on): event registration
function CB:SetActive(on)
	on = on and true or false
	if (on == (self.active or false)) then
		if (on) then
			self:Refresh()
		end
		return
	end
	self.active = on
	if (on) then
		self:RegisterBarEvents()
		self:Refresh()
	else
		self:UnregisterAllEvents()
		self:Clear()
	end
end

-- RegisterBarEvents
function CB:RegisterBarEvents()
	self:UnregisterAllEvents()
	if (not self.active or not self.unit) then
		return
	end
	for i = 1, #castEvents do
		local event = castEvents[i]
		if (not IsEventValid or IsEventValid(event)) then
			self:RegisterUnitEvent(event, self.unit)
		end
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- SetBarUnit(unit): the owner's unit (or the unit behind it) changed
function CB:SetBarUnit(unit)
	if (unit ~= self.unit) then
		self.unit = unit
		if (self.active) then
			self:RegisterBarEvents()
		end
	end
	if (self.active) then
		self:Refresh()
	end
end

-- Clear: no cast; the name shows again
function CB:Clear()
	self.casting, self.channeling, self.fadeOut, self.castID = nil, nil, nil, nil
	self.flashFrame.active = nil
	self.holdTime = 0
	if (self.timeBinding) then
		self.timeBinding:SetEnabled(false)
	end
	self:Hide()
	self.castTimeText:Hide()
	self.nameText:SetAlpha(conf.transparency.text)
	self.nameText:Show()
end

-- Refresh: shows whatever the unit is casting now
function CB:Refresh()
	if (not self.unit or not self:Start()) then
		self:Clear()
	end
end

-- GetCast: the unit's current cast or channel. Returns kind ("cast", "channel" or "empower"), display name,
-- duration object (nil without the client support), start and end times (ms; secret for other units),
-- castID and the not-interruptible flag (both may be secret).
local function GetCast(unit)
	local name, text, _, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
	if (name) then
		return "cast", text, useDurations and UnitCastingDuration(unit), startTime, endTime, castID, notInterruptible
	end
	local isEmpowered
	name, text, _, startTime, endTime, _, notInterruptible, _, isEmpowered = UnitChannelInfo(unit)
	if (name) then
		if (isEmpowered) then
			return "empower", text, useDurations and (UnitEmpoweredChannelDuration or UnitChannelDuration)(unit), startTime, endTime, nil, notInterruptible
		end
		return "channel", text, useDurations and UnitChannelDuration(unit), startTime, endTime, nil, notInterruptible
	end
end

-- SetShield(notInterruptible)
function CB:SetShield(notInterruptible)
	if (issecretvalue(notInterruptible)) then
		self.shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
	else
		self.shield:SetAlpha(notInterruptible and 1 or 0)
	end
end

-- SetTiming(kind, duration, startTime, endTime)
function CB:SetTiming(kind, duration, startTime, endTime)
	self.endTime = nil
	if (duration) then
		local direction = kind == "channel" and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
		self:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
		self.timeBinding:SetDuration(duration)
		self.timeBinding:SetEnabled(self.showCastTime and true or false)
	elseif (not issecretvalue(startTime) and not issecretvalue(endTime)) then
		-- No duration objects on this client: plain times, run by OnUpdate
		self.startTime = startTime / 1000
		self.endTime = endTime / 1000
		self:SetMinMaxValues(self.startTime, self.endTime)
	else
		-- Secret times and no duration object: a full bar, so the cast still shows
		self:SetMinMaxValues(0, 1)
		self:SetValue(1)
	end
end

-- Start: begins showing the current cast; false if there is none
function CB:Start()
	local kind, text, duration, startTime, endTime, castID, notInterruptible = GetCast(self.unit)
	if (not kind) then
		return false
	end

	self.casting = kind ~= "channel"
	self.channeling = kind == "channel"
	self.castID = castID
	self.fadeOut = nil
	self.flashFrame.active = nil
	self.holdTime = 0

	local colour = self.channeling and barColours.channel or barColours.main
	self:SetStatusBarColor(colour.r, colour.g, colour.b, conf.transparency.frame)
	self.spellText:SetText(text)
	self:SetShield(notInterruptible)
	self:SetTiming(kind, duration, startTime, endTime)
	self:ShowPrecast(startTime, endTime)

	self.flashFrame:Hide()
	self.spark:Show()
	self:SetAlpha(1)
	self.castTimeText:SetShown(self.showCastTime and true or false)
	self.nameText:Hide()
	self:Show()
	return true
end

-- ShowPrecast(startTime, endTime): the share of the cast that is network latency (player only)
function CB:ShowPrecast(startTime, endTime)
	local precast = self.precast
	if (not precast) then
		return
	end
	local lag = min(1000, select(4, GetNetStats()))
	if (not self.showPrecast or lag < 10 or issecretvalue(startTime) or issecretvalue(endTime) or endTime <= startTime) then
		precast:Hide()
		return
	end
	precast:ClearAllPoints()
	precast:SetPoint(self.channeling and "LEFT" or "RIGHT")
	precast:SetSize(min(1, lag / (endTime - startTime)) * self:GetWidth(), self:GetHeight())
	precast:Show()
end

-- SameCast(castID): castIDs that can't be compared (secret) count as the current one
function CB:SameCast(castID)
	return issecretvalue(castID) or issecretvalue(self.castID) or castID == self.castID
end

-- Finish(failText): fills the bar (red with failText, green otherwise) and lets it flash and fade
function CB:Finish(failText)
	if (self.timeBinding) then
		self.timeBinding:SetEnabled(false)
	end
	self.castTimeText:Hide()
	self:SetMinMaxValues(0, 1)
	self:SetValue(1)
	self.spark:Hide()
	if (self.precast) then
		self.precast:Hide()
	end
	local colour = failText and barColours.failure or barColours.success
	self:SetStatusBarColor(colour.r, colour.g, colour.b, conf.transparency.frame)
	if (failText) then
		self.spellText:SetText(failText)
		self.holdTime = GetTime() + HOLD_TIME
	else
		self.flashFrame:SetAlpha(0)
		self.flashFrame:Show()
		self.holdTime = 0
	end
	self.casting, self.channeling = nil, nil
	self.flashFrame.active = not self.fadeOut
	self.fadeOut = true
end

-- OnEvent
function CB:OnEvent(event, unit, castID, spellID, extra)
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Refresh()
		return
	end
	if (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START") then
		if (not self:Start()) then
			self:Clear()
		end

	elseif (event == "UNIT_SPELLCAST_STOP") then
		if (self.casting and self:SameCast(castID)) then
			self:Finish()
		end

	elseif (event == "UNIT_SPELLCAST_CHANNEL_STOP") then
		-- extra is the interrupter's GUID (a string, so testing it is fine even when it is secret)
		if (self.channeling) then
			self:Finish(extra and SPELL_FAILED_INTERRUPTED or nil)
		end

	elseif (event == "UNIT_SPELLCAST_EMPOWER_STOP") then
		if (self.casting) then
			self:Finish()
		end

	elseif (event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED") then
		if (self:IsShown() and self.casting and not self.fadeOut and self:SameCast(castID)) then
			self:Finish(event == "UNIT_SPELLCAST_FAILED" and FAILED or SPELL_FAILED_INTERRUPTED)
		end

	elseif (event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE") then
		if (self:IsShown() and (self.casting or self.channeling)) then
			local kind, _, duration, startTime, endTime = GetCast(self.unit)
			if (kind) then
				self:SetTiming(kind, duration, startTime, endTime)
			else
				self:Clear()
			end
		end

	elseif (event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE") then
		self:SetShield(event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
	end
end

-- OnUpdate: plain-time progress (no duration objects), the end flash and the fade out
function CB:OnUpdate(elapsed)
	local now = GetTime()
	if (self.casting or self.channeling) then
		if (self.endTime) then
			local remaining = max(0, self.endTime - now)
			if (self.channeling) then
				self:SetValue(self.startTime + remaining)
			else
				self:SetValue(min(self.endTime, now))
			end
			self.castTimeText:SetFormattedText("%.1f", remaining)
		end
		return
	end

	if (now < self.holdTime) then
		return
	end

	local flash = self.flashFrame
	if (flash.active) then
		local alpha = flash:GetAlpha() + elapsed * FLASH_STEP
		if (alpha < 1) then
			flash:SetAlpha(alpha)
		else
			flash.active = nil
		end
	elseif (self.fadeOut) then
		local alpha = self:GetAlpha() - elapsed * FADE_STEP
		if (alpha > 0) then
			self:SetAlpha(alpha)
			self.nameText:SetAlpha((1 - alpha) * conf.transparency.text)
			self.nameText:Show()
		else
			self:Clear()
		end
	end
end
