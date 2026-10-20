-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Status highlights on unit frames: your HoTs (border or timer bar), HoT count, aggro and your target. Heal
-- prediction and absorbs on the health bar are the unit frames' own (Units/UnitFrame.lua).
--
-- Unit code tells this module about its frames through XPerl_Highlight:UnitFrameChanged(frame) whenever a
-- frame's unit (frame.partyid) changes or the frame is shown; XPerl_ForEachUnitFrame finds every frame when
-- options change. Visuals go on frame.highlight (the XPerl_HighlightTemplate child) and the health bar.
--
-- 12.x secret values: while add-on restrictions are active (combat, encounters, ...) the client keeps most
-- auras secret, and since 12.1 any read of a secret aura from add-on code is an error ("Auras cannot be
-- accessed when secret while tainted"), lists (C_UnitAuras.GetUnitAuraInstanceIDs) and durations included.
-- Every aura read here goes through XPerl_Api.lua, which asks C_Secrets first and hands back
-- XPerlAPI.SECRET_AURA for a secret aura. What still works then:
--   * Counting: secret auras keep their place in the list. A secret one in the RAID_IN_COMBAT list (with
--     HELPFUL|PLAYER: "your HoTs", see Blizzard_FrameXMLUtil/AuraUtil.lua) counts as your HoT.
--   * UnitThreatSituation(unit) for a single unit is not secret.
-- What needs readable auras (normally out of combat only): the HoT timer and its expiry flashing. Unreadable
-- data never matches, so nothing goes stale. Highlights that can't work in combat (telling shields or Prayer
-- of Mending apart from HoTs, incoming heal amounts) are left out on purpose.

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local C_UnitAuras = C_UnitAuras
local GetTime = GetTime
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitThreatSituation = UnitThreatSituation
local UnitPlayerOrPetInParty = UnitPlayerOrPetInParty
local UnitPlayerOrPetInRaid = UnitPlayerOrPetInRaid
local issecretvalue = issecretvalue
local cos, sin = math.cos, math.sin
local GetAuraDataByIndex = XPerlAPI.GetAuraDataByIndex					-- secret-safe, see XPerl_Api.lua
local SECRET_AURA = XPerlAPI.SECRET_AURA
local GetAuraDuration = C_UnitAuras.GetAuraDuration

local hotSpells = XPERL_HIGHLIGHT_SPELLS.hotSpells

-- Clients without the RAID_IN_COMBAT aura filter (WoW: Forever) recognise HoTs by name from hotSpells instead.
local RAID_IN_COMBAT = AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.RaidInCombat
local MY_FILTER = RAID_IN_COMBAT and ("HELPFUL|PLAYER|"..RAID_IN_COMBAT) or "HELPFUL|PLAYER"
local ALL_FILTER = RAID_IN_COMBAT and ("HELPFUL|"..RAID_IN_COMBAT) or "HELPFUL"

local colours = {
	HOT = {r = 0.2, g = 0.4, b = 0.8},
	AGGRO = {r = 0.8, g = 0, b = 0},
	TARGET = {r = 0.7167, g = 0.6833, b = 0.31467},		-- colour * 1.2 == selection colour
}
local SELECTION = {r = 0.86, g = 0.82, b = 0.41}
local borderOrder = {"AGGRO", "HOT", "TARGET"}	-- first two shown, as a gradient
local tooltipOrder = {"HOT", "AGGRO"}
local FLASH_TIME = 5							-- HoT borders flash for their last seconds

local xpHigh = CreateFrame("Frame", "XPerl_Highlight")

local frameUnit = {}		-- frame -> unit token it shows
local unitFrames = {}		-- unit token -> {frame = true}
local unitState = {}		-- unit token -> state table (keys HOT, AGGRO, TARGET, ...)
local pendingAura = {}
local pendingAll, pendingThreat, pendingTarget
local targetGUID

---------------------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------------------

-- rotate: texture coordinates for a clockwise rotation by angle
local function rotate(angle)
	local hcos = 0.5 * cos(angle)
	local mhcos = -hcos
	local hsin = 0.5 * sin(angle)
	local mhsin = -hsin
	local ULx, ULy, LLx, LLy = hcos - mhsin, mhsin + hcos, hcos - hsin, mhsin + mhcos
	local URx, URy, LRx, LRy = mhcos - mhsin, hsin + hcos, mhcos - hsin, hsin + mhcos
	return ULx+0.5, ULy+0.5, LLx+0.5, LLy+0.5, URx+0.5, URy+0.5, LRx+0.5, LRy+0.5
end

-- fluctuate: random brightness flicker for sparkles
local function fluctuate(self, elapsed)
	if (self.fluctuate) then
		if (self.fluctuate == "dim" or self.fluctuate == "notbright") then
			self.fluctuatingBrightness = self.fluctuatingBrightness - elapsed
			if (self.fluctuatingBrightness < 0.5) then
				if (self.fluctuate == "dim") then
					self.fluctuatingBrightness = 0.5
					self.fluctuate = "notdim"
				else
					self.fluctuatingBrightness = nil
					self.fluctuate = nil
				end
			end
		else
			self.fluctuatingBrightness = self.fluctuatingBrightness + elapsed
			if (self.fluctuatingBrightness >= 1) then
				if (self.fluctuate == "notdim") then
					self.fluctuatingBrightness = nil
					self.fluctuate = nil
				else
					self.fluctuatingBrightness = 1
					self.fluctuate = "notbright"
				end
			end
		end
	elseif (random(10) == 1) then
		self.fluctuate = random(3) == 2 and "dim" or "bright"
		self.fluctuatingBrightness = 1
	end
	return self.fluctuatingBrightness or 1
end

local function CreateShine(parent)
	local shine = parent:CreateTexture(nil, "OVERLAY")
	shine:SetTexture("Spells\\SparkleBlue")
	shine:SetBlendMode("ADD")
	shine:SetWidth(12)
	shine:SetHeight(12)
	return shine
end

local function HealthBar(frame)
	return frame.healthBar or (frame.statsFrame and frame.statsFrame.healthBar)
end

-- Raid-sized frames get smaller decorations
local function IsSmall(frame)
	return frame:GetHeight() < 45
end

-- Remaining seconds of a duration object, or nil while it is secret
local function Remaining(duration)
	local r = duration:GetRemainingDuration()
	if (not issecretvalue(r)) then
		return r
	end
end

---------------------------------------------------------------------------------------------------------------
-- Sparkle areas (extra sparkles burst over a health bar)
---------------------------------------------------------------------------------------------------------------
local sparkleAreas = {}
local inactiveSparks = {}

local function SparkOnShow(self)
	self.angle = 0
	self.alpha = 0
	self.begin = GetTime()
	self.state = "new"
end

local function SparkOnUpdate(self, elapsed)
	self.angle = self.angle + elapsed
	if (self.angle > 360) then
		self.angle = self.angle - 360
	end
	self.tex:SetTexCoord(rotate(self.angle))

	local x, y = self:GetCenter()
	if (x) then
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + elapsed * self.speed)
	end

	if (self.state == "new") then
		self.alpha = self.alpha + elapsed * 6
		if (self.alpha >= 1) then
			self.alpha = 1
			self.state = GetTime() > self.begin + self.ttl and "fade" or "cycle"
		end
	elseif (self.state == "cycle") then
		if (GetTime() > self.begin + self.ttl) then
			self.state = "fade"
		end
	else
		self.alpha = self.alpha - elapsed
		if (self.alpha <= 0) then
			self:Hide()
			self.area.sparks = self.area.sparks - 1
			self.area = nil
			tinsert(inactiveSparks, self)
			return
		end
	end

	self.tex:SetVertexColor(1, 1, 0.5, self.alpha * fluctuate(self, elapsed))
end

local function AddSpark(area, bias)
	local spark = tremove(inactiveSparks)
	if (not spark) then
		spark = CreateFrame("Frame", nil, xpHigh)
		spark.tex = CreateShine(spark)
		spark.tex:SetAllPoints()
		spark:SetScript("OnShow", SparkOnShow)
		spark:SetScript("OnUpdate", SparkOnUpdate)
		spark:Hide()
	end

	spark.area = area
	spark.ttl = 0.1
	area.sparks = area.sparks + 1

	local size = 8 + random(6)
	spark:SetWidth(size)
	spark:SetHeight(size)
	spark.speed = size

	local w = area.right - area.left
	local x
	if (bias == "left") then
		x = area.left + random(w) / 3
	elseif (bias == "right") then
		x = area.right - random(w) / 3
	else
		x = area.left + (w / 3) + (random(w) / 3)
	end
	local y = area.bottom + random(area.top - area.bottom) / 2
	spark:ClearAllPoints()
	spark:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	spark:Show()
end

-- SparkleArea: a short burst of rising sparks over region
local function SparkleArea(region)
	local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	if (not left) then
		return
	end
	-- Sparks are parented to xpHigh (no parent, scale 1): work in screen units
	local s = region:GetEffectiveScale()
	local area = {left = floor(left * s), right = floor(right * s), top = floor(top * s), bottom = floor(bottom * s)}
	if (area.right - area.left < 3 or area.top - area.bottom < 2) then
		return
	end
	area.endTime = GetTime() + 0.4
	area.sparkTime = 0
	area.sparks = 0
	tinsert(sparkleAreas, area)
end

local function SparkleAreasOnUpdate(elapsed)
	local now = GetTime()
	for i = #sparkleAreas, 1, -1 do
		local area = sparkleAreas[i]
		if (now < area.endTime) then
			area.sparkTime = area.sparkTime + elapsed
			if (area.sparkTime > 0.1) then
				area.sparkTime = 0
				AddSpark(area, "left")
				AddSpark(area, "middle")
				AddSpark(area, "right")
			end
		elseif (area.sparks == 0) then
			tremove(sparkleAreas, i)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- Frame decorations
---------------------------------------------------------------------------------------------------------------

-- Bars along the top (HoT timer) or bottom (absorbs) edge of the health bar, with a rotating sparkle
local function BarOnShow(self)
	self.angle = 0
	self.alpha = 1
	self.alphaPulse = "out"
end

local function BarOnUpdate(self, elapsed)
	local remaining
	if (self.duration) then
		remaining = Remaining(self.duration)
	elseif (self.expiration) then
		remaining = self.expiration - GetTime()
		if (remaining <= 0) then
			self:Hide()
			return
		end
		self:SetValue(remaining)
	end

	self.angle = self.angle + elapsed
	if (self.angle > 360) then
		self.angle = self.angle - 360
	end
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = rotate(self.angle)
	self.spark:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
	self.shine:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)

	-- Pulse for the last seconds, when the remaining time is readable
	local a = 1
	if (remaining and remaining < FLASH_TIME) then
		if (self.alphaPulse == "in") then
			a = self.alpha + elapsed * 2
			if (a >= 1) then
				a = 1
				self.alphaPulse = "out"
			end
		else
			a = self.alpha - elapsed * 2
			if (a < 0.3) then
				a = 0.3
				self.alphaPulse = "in"
			end
		end
	else
		self.alphaPulse = "out"
	end
	self.alpha = a

	self.spark:SetVertexColor(1, 1, 1, a * fluctuate(self.spark, elapsed))
	self.shine:SetVertexColor(1, 1, 1, a * fluctuate(self.shine, elapsed))
end

-- Timer bar along the top edge of the health bar
local function CreateEdgeBar(frame)
	local parent = HealthBar(frame)
	local f = CreateFrame("StatusBar", nil, parent)
	f:SetPoint("TOPLEFT")
	f:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, -4)
	f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	local tex = f:GetStatusBarTexture()
	tex:SetHorizTile(false)
	tex:SetVertTile(false)
	f:SetMinMaxValues(0, 1)
	f:SetValue(0)
	f:Hide()

	-- The sparkle follows the end of the fill, so its position needs no maths on (possibly secret) values
	f.spark = CreateShine(f)
	f.spark:SetPoint("CENTER", tex, "RIGHT")
	f.shine = CreateShine(f)
	f.shine:SetPoint("CENTER", f, "LEFT")

	f:SetScript("OnShow", BarOnShow)
	f:SetScript("OnUpdate", BarOnUpdate)
	return f
end

-- HoT timer bar: the longest of your HoTs
local function ShowHotBar(frame, st)
	local h = frame.highlight
	local show = st and st.HOT and conf.highlight.HOT and conf.highlight.sparkles and HealthBar(frame)
	local bar = h.hotBar
	if (show) then
		if (not bar) then
			bar = CreateEdgeBar(frame)
			bar:SetStatusBarColor(1, 1, 0)
			h.hotBar = bar
		end
		bar.duration, bar.expiration = nil, nil
		if (st.hotDuration and bar.SetTimerDuration) then
			bar.duration = st.hotDuration
			bar:SetTimerDuration(st.hotDuration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
		elseif (st.hotExpire and st.hotLength) then
			bar.expiration = st.hotExpire
			bar:SetMinMaxValues(0, st.hotLength)
			bar:SetValue(st.hotExpire - GetTime())
		else
			-- No timing information: a full bar marks the HoT
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
		end
		bar:Show()
	elseif (bar) then
		bar:Hide()
		bar.duration, bar.expiration = nil, nil
	end
end

-- HoT count: number of HoT-type buffs on the unit from anyone; green when one of them is yours
local function ShowHotCount(frame, st)
	local h = frame.highlight
	local count = st and conf.highlight.HOTCOUNT and st.count
	if (count and count > 0) then
		local f = h.hot
		if (not f) then
			f = h:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
			h.hot = f
			local small = IsSmall(frame)
			if (small) then
				f:SetTextHeight(15)
			end
			if (frame.statsFrame) then
				f:SetPoint("TOPLEFT", frame.statsFrame, "TOPLEFT", small and 3 or 5, small and -3 or -8)
			elseif (small) then
				f:SetPoint("TOPLEFT", 3, -3)
			else
				f:SetPoint("CENTER", 0, 0)
			end
		end
		f:SetText(count)
		if (st.mine > 0) then
			f:SetTextColor(0, 1, 0)
		else
			f:SetTextColor(0.8, 0, 0)
		end
		f:Show()
	elseif (h.hot) then
		h.hot:Hide()
	end
end

-- Border colour on frame.highlight.tex; without highlights it keeps the plain selection look
local function ShowBorder(frame, st)
	local h = frame.highlight
	local tex = h.tex
	local c1, c2, flash
	if (st) then
		local hc = conf.highlight
		local sparkles = hc.sparkles
		local now = GetTime()
		for _, key in ipairs(borderOrder) do
			-- With sparkles the HoT is the timer bar instead of a border
			if (st[key] and hc[key] and not (sparkles and key == "HOT")) then
				if (key == "HOT" and st.hotExpire and st.hotExpire - now <= FLASH_TIME) then
					flash = true
				end
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
		if (flash) then
			tex:Show()
			XPerl_FrameFlash(tex)
		else
			XPerl_FrameFlashStop(tex)
			tex:Show()
			tex:SetAlpha(1)
		end
	else
		XPerl_FrameFlashStop(tex)
		tex:SetVertexColor(SELECTION.r, SELECTION.g, SELECTION.b)
		if (h.sel and conf and conf.highlightSelection) then
			tex:Show()
			tex:SetAlpha(1)
		else
			tex:Hide()
		end
	end
end

-- Render: st is nil when highlights are off or the frame shows no unit
local function Render(frame, st)
	if (st and st.burst and frame:IsVisible()) then
		local bar = HealthBar(frame)
		if (bar) then
			SparkleArea(bar)
		end
	end
	ShowBorder(frame, st)
	ShowHotCount(frame, st)
	ShowHotBar(frame, st)
end

local function RenderUnit(unit)
	local st = unitState[unit]
	local set = unitFrames[unit]
	if (set) then
		for frame in pairs(set) do
			Render(frame, st)
		end
	end
	if (st) then
		st.burst = nil
	end
end

---------------------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------------------
local auraScratch = {}

-- Auras(unit, filter): the unit's auras for filter in the client's order, SECRET_AURA for each one add-on code
-- may not read (a shared list, valid until the next call)
local function Auras(unit, filter)
	wipe(auraScratch)
	for i = 1, 40 do
		local aura = GetAuraDataByIndex(unit, i, filter)
		if (not aura) then
			break
		end
		auraScratch[i] = aura
	end
	return auraScratch
end

-- One of your auras as a HoT: true plus its readable expiration time and length, or nil. On clients with the
-- RAID_IN_COMBAT list every aura of yours in it counts, readable or secret: that list is what Blizzard's raid
-- frames show as your HoTs in combat. Elsewhere (WoW: Forever) readable auras are matched by name.
local function AsHot(aura)
	local name = aura.name
	if (issecretvalue(name) or not name) then
		return RAID_IN_COMBAT and true
	end
	if (not RAID_IN_COMBAT and not hotSpells[name]) then
		return
	end

	local expire, length = aura.expirationTime, aura.duration
	if (issecretvalue(expire) or issecretvalue(length) or expire == 0) then
		expire, length = nil, nil
	end
	return true, expire, length
end

-- A duration object that actually runs (not a permanent aura) for a readable aura, or nil
local function RunningDuration(unit, aura)
	local id = aura.auraInstanceID
	if (GetAuraDuration and aura ~= SECRET_AURA and id and not issecretvalue(id)) then
		local duration = GetAuraDuration(unit, id)
		if (duration) then
			local zero = duration:IsZero()
			if (issecretvalue(zero) or not zero) then
				return duration
			end
		end
	end
end

local function ScanAuras(unit, st, fromEvent)
	local mineBefore = st.mine
	st.HOT, st.hotExpire, st.hotLength, st.hotDuration = nil, nil, nil, nil
	st.count, st.mine, st.flashing = 0, 0, nil

	if (not UnitIsDeadOrGhost(unit)) then
		local mine = Auras(unit, MY_FILTER)
		for i = 1, #mine do
			local aura = mine[i]
			local hot, expire, length = AsHot(aura)
			if (hot) then
				st.mine = st.mine + 1
				-- The latest-ending readable HoT times the bar
				if (not st.HOT or (expire and (not st.hotExpire or expire > st.hotExpire))) then
					st.HOT = true
					st.hotDuration = RunningDuration(unit, aura)
					st.hotExpire, st.hotLength = expire, length
				end
			end
		end

		if (RAID_IN_COMBAT) then
			st.count = #Auras(unit, ALL_FILTER)
		else
			local all = Auras(unit, ALL_FILTER)
			for i = 1, #all do
				local name = all[i].name
				if (name and not issecretvalue(name) and hotSpells[name]) then
					st.count = st.count + 1
				end
			end
		end
	end

	-- Extra sparkles when you put a new HoT on the unit
	if (fromEvent and mineBefore and st.mine > mineBefore and conf.highlight.extraSparkles and conf.highlight.HOT) then
		st.burst = true
	end
end

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

-- RefreshUnit: rebuild unit's whole state and redraw its frames. Like before, only units you can assist get
-- status highlights (a hostile target or target-of-target shows none).
local function RefreshUnit(unit, fromEvent)
	if (not UnitExists(unit) or not UnitCanAssist("player", unit)) then
		unitState[unit] = nil
	else
		local st = unitState[unit]
		if (not st) then
			st = {}
			unitState[unit] = st
			fromEvent = nil
		end
		ScanAuras(unit, st, fromEvent)
		ScanThreat(unit, st)
		ScanTarget(unit, st)
	end
	RenderUnit(unit)
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
		wipe(pendingAura)
		for unit in pairs(unitFrames) do
			RefreshUnit(unit)
		end
		return
	end

	for unit in pairs(pendingAura) do
		pendingAura[unit] = nil
		if (unitFrames[unit]) then
			RefreshUnit(unit, true)
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

-- Poll: units without events, and borders reaching their flashing time
local function Poll()
	local now = GetTime()
	for unit, st in pairs(unitState) do
		if (IsPolled(unit)) then
			RefreshUnit(unit)
		elseif (not st.flashing) then
			local hot = st.hotExpire
			if (hot and hot - now <= FLASH_TIME) then
				st.flashing = true
				RenderUnit(unit)
			end
		end
	end
end

local function OnUpdate(self, elapsed)
	if (sparkleAreas[1]) then
		SparkleAreasOnUpdate(elapsed)
	end

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

-- Unit tokens normally arrive plain; if one were secret it could not be a table key, so refresh everything.
local function UnitPending(list, unit)
	if (issecretvalue(unit)) then
		pendingAll = true
	elseif (unitFrames[unit]) then
		list[unit] = true
	end
end

function events.UNIT_AURA(unit)
	UnitPending(pendingAura, unit)
end

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
			pendingAura[unit] = true
		end
	end
end

function events.PLAYER_FOCUS_CHANGED()
	for unit in pairs(unitFrames) do
		if (strfind(unit, "^focus")) then
			pendingAura[unit] = true
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
		Render(frame, nil)
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

-- OptionChange: (re)apply XPerlDB.highlight
local function OptionChange()
	local enabled = conf.highlight.enable

	wipe(unitState)
	wipe(pendingAura)
	pendingAll, pendingThreat, pendingTarget = nil, nil, nil

	SetEvents(enabled)
	if (enabled) then
		UpdateTargetGUID()
		xpHigh:SetScript("OnUpdate", OnUpdate)
	else
		xpHigh:SetScript("OnUpdate", nil)
		wipe(sparkleAreas)
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
end

XPerl_RegisterOptionChanger(OptionChange)
