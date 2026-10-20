-- X-Perl UnitFrames
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Arena enemy frames XPerl_Arena1..5 (arena1-5) in the stack XPerl_Arena_Anchor (Units/UnitStack.lua): name,
-- health, power, optional portrait, the opponent's specialization icon, the PvP trinket (crowd control
-- removal) with its cooldown, cast bar and auras. Before the gates open, placeholders show the opponents'
-- specializations (XPerl_Arena<n>Prep).
--
-- PvP matches restrict a lot to secret values: names, health, casts, auras, and (depending on the client) the
-- opponent specializations and the trinket spell. Secret values only go to widget calls that accept them
-- (SetText, SetTexture, SetVertexColor, SetAlphaFromBoolean, duration objects); nothing compares them.
--
-- Only clients with Blizzard's arena frames (CompactArenaFrame_Generate; WoW: Forever has none) have arenas,
-- so only they get these frames.

if (not CompactArenaFrame_Generate) then
	return
end

local SF = XPerl_UnitStackFrameMixin
local C_PvP = C_PvP

local TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

-- Plain(value): nil for a secret value, which can't even be tested
local function Plain(value)
	if (issecretvalue(value)) then
		return nil
	end
	return value
end

XPerl_ArenaFrameMixin = CreateFromMixins(SF, {
	elementList = {
		"highlight", "arenaChanged", "name", "arenaSpec", "power", "health", "statusIcons", "portrait", "range",
		"auras", "healPrediction", "combatFeedback", "castBar", "trinket",
	},
	perlFrameKeys = {"nameFrame", "statsFrame", "portraitFrame", "specFrame", "trinketFrame"},
	flashFrameKeys = {"nameFrame", "statsFrame", "portraitFrame"},
	portraitWidth = 60,
	portraitHiddenWidth = 2,
	optionalPower = true,
	useUnitWatch = true,
	auraOrder = "reaction",
	unitPrefix = "arena",
	labelFormat = XPERL_EDITMODE_UNIT_ARENA,
})
local A = XPerl_ArenaFrameMixin

local Define = XPerl_UnitFrame_DefineElement
local function TrinketEnabled(self)
	return self.conf.trinket and true or false
end
-- ARENA_OPPONENT_UPDATE: (token, "seen" / "unseen" / "destroyed" / "cleared"); the token isn't a unit event
-- argument the client can filter on, so the method does
Define("arenaChanged",	{events = {ARENA_OPPONENT_UPDATE = true}, method = "OnOpponentUpdate", full = false})
Define("arenaSpec",	{events = {ARENA_PREP_OPPONENT_SPECIALIZATIONS = true}, method = "UpdateSpec"})
Define("trinket",	{events = {ARENA_CROWD_CONTROL_SPELL_UPDATE = "unit", ARENA_COOLDOWNS_UPDATE = true}, method = "UpdateTrinket",
	enabled = TrinketEnabled,
	apply = function(self) self.trinketFrame:SetShown(TrinketEnabled(self)) end})

local stack = XPerl_UnitStack_Create("XPerl_Arena_Anchor", "arena", XPERL_EDITMODE_FRAME_ARENA, {point = "TOPRIGHT", x = -480, y = -300})
A.stack = stack

------------------------------------------------------------------------------
-- Specializations
------------------------------------------------------------------------------

-- SpecInfo(index) -> hasSpec, specName, className, specIcon, r, g, b
-- What is known of opponent <index>'s specialization. Plain values on clients that give them out (class
-- colours as everywhere in X-Perl); where GetArenaOpponentSpec is secret, Blizzard's secure helper
-- (UnitFrameUtil.GetArenaOpponentSpecDisplayInfo, newer clients) hands out its possibly secret display values
-- (bar colour per the pvpFramesDisplayClassColor setting). hasSpec is false (plain) when nothing is known.
local function SpecInfo(index)
	local specID, gender = GetArenaOpponentSpec(index)
	if (not issecretvalue(specID)) then
		if (specID and specID > 0) then
			local _, specName, _, specIcon, _, class, className = GetSpecializationInfoByID(specID, gender)
			local c = XPerl_GetClassColour(class)
			return true, specName, className, specIcon, c.r, c.g, c.b
		end
		return false
	end
	local GetDisplayInfo = UnitFrameUtil and UnitFrameUtil.GetArenaOpponentSpecDisplayInfo
	if (GetDisplayInfo) then
		local info = GetDisplayInfo(index)
		return info.hasSpec, info.specName, info.className, info.specIcon, info.barColorR, info.barColorG, info.barColorB
	end
	return false
end

-- UpdateSpec: the specialization icon, or the class icon while the specialization isn't known
function A:UpdateSpec()
	local sf = self.specFrame
	if (not self.conf.classIcon) then
		sf:Hide()
		return
	end
	sf:Show()

	local icon = sf.icon
	local hasSpec, _, _, specIcon = SpecInfo(self.index)
	if (issecretvalue(hasSpec)) then
		icon:SetTexture(specIcon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetAlphaFromBoolean(hasSpec)
		return
	end

	icon:SetAlpha(1)
	if (hasSpec) then
		icon:SetTexture(specIcon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		return
	end
	local class = Plain(select(2, UnitClass(self.partyid)))
	if (class) then
		icon:SetTexture(CLASS_ICONS)
		icon:SetTexCoord(XPerl_ClassPos(class))
	else
		icon:SetTexture(UNKNOWN_ICON)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
end

------------------------------------------------------------------------------
-- PvP trinket
------------------------------------------------------------------------------

-- SetTrinketSpell(spellID): the opponent's crowd control removal. The spell is secret while loss of control
-- information is restricted; its texture then goes to the icon as it is.
function A:SetTrinketSpell(spellID)
	local icon = self.trinketFrame.icon
	if (issecretvalue(spellID)) then
		icon:SetTexture(C_Spell.GetSpellTexture(spellID))
	elseif (spellID and spellID > 0) then
		icon:SetTexture(C_Spell.GetSpellTexture(spellID) or TRINKET_ICON)
	else
		icon:SetTexture(TRINKET_ICON)
	end
end

-- UpdateTrinketCooldown: from the client's duration object (secret-safe), or the plain times on clients
-- without it
function A:UpdateTrinketCooldown()
	local cd = self.trinketFrame.cooldown
	local unit = self.partyid
	if (C_PvP.GetArenaCrowdControlDuration and cd.SetCooldownFromDurationObject) then
		cd:SetCooldownFromDurationObject(C_PvP.GetArenaCrowdControlDuration(unit))
		return
	end
	local _, startTime, duration = C_PvP.GetArenaCrowdControlInfo(unit)
	startTime, duration = Plain(startTime), Plain(duration)
	if (startTime and duration and duration > 0) then
		cd:SetCooldown(startTime / 1000, duration / 1000)
	else
		cd:Clear()
	end
end

-- UpdateTrinket(event, unit, spellID)
-- A new opponent asks the server for its trinket, which answers with ARENA_CROWD_CONTROL_SPELL_UPDATE
function A:UpdateTrinket(event, _, spellID)
	if (event == "ARENA_CROWD_CONTROL_SPELL_UPDATE") then
		self:SetTrinketSpell(spellID)
	elseif (not event) then
		local token = self.partyid
		self:SetTrinketSpell(C_PvP.GetArenaCrowdControlInfo(token))
		if (C_PvP.RequestCrowdControlSpell) then
			C_PvP.RequestCrowdControlSpell(token)
		end
	end
	self:UpdateTrinketCooldown()
end

------------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------------

-- InitType: the stack's setup, neutral icons until there is an opponent
function A:InitType()
	SF.InitType(self)
	self.specFrame.icon:SetTexture(UNKNOWN_ICON)
	self.specFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	self.trinketFrame.icon:SetTexture(TRINKET_ICON)
end

-- OnOpponentUpdate(event, token): the opponent behind our token was seen (again) or went away
function A:OnOpponentUpdate(_, token)
	if (token == self.partyid) then
		self:UnitChanged()
	end
end

-- ApplySize(width): name and stats bars, the portrait beside them and the icon column
function A:ApplySize(width)
	local c = self.conf
	local barWidth = (c.percent and 160 or 128) + width
	self.nameFrame:SetWidth(barWidth)
	self.statsFrame:SetWidth(barWidth)
	self:SetWidth(barWidth + (c.portrait and (self.portraitWidth - 2) or 0) + ((c.classIcon or c.trinket) and 32 or 0))
end

-- ApplyTypeSettings: the specialization icon, the stack's layout and the preparation placeholders
function A:ApplyTypeSettings()
	self.specFrame:SetShown(self.conf.classIcon and true or false)
	SF.ApplyTypeSettings(self)
	stack:UpdatePrep()
end

------------------------------------------------------------------------------
-- Arena preparation placeholders and Blizzard's arena frame
------------------------------------------------------------------------------

local IsEventValid = C_EventUtils and C_EventUtils.IsEventValid
local stackEvents = {"ARENA_PREP_OPPONENT_SPECIALIZATIONS", "ARENA_OPPONENT_UPDATE", "PVP_MATCH_STATE_CHANGED", "PLAYER_ENTERING_WORLD"}

-- Blizzard's arena frame is created on demand, maybe long after login, so the core's (login only) disable
-- function is kept for it. Whether it is hidden is decided by the settings in use at login, not by the
-- frames' activation (which waits for combat to end after a /reload in combat): then and whenever it gets
-- created.
local BlizzFrameDisable = XPerl_BlizzFrameDisable
local function DisableBlizzardArena()
	if (CompactArenaFrame and not CompactArenaFrame.XPerlDisabled) then
		BlizzFrameDisable(CompactArenaFrame)
	end
end

local blizzardHidden
XPerl_RequestConfig(function(new)
	if (XPerl_BlizzFrameDisable and not blizzardHidden and new.arena and new.arena.enable) then
		blizzardHidden = true
		DisableBlizzardArena()
		hooksecurefunc("CompactArenaFrame_Generate", DisableBlizzardArena)
	end
end, "$Revision$")

-- InPrepPhase: in an arena match whose gates haven't opened yet (as Blizzard's pre-match frames decide it)
local function InPrepPhase()
	if (not (C_PvP.IsMatchConsideredArena and C_PvP.GetActiveMatchState and Enum.PvPMatchState)) then
		return false
	end
	return C_PvP.IsMatchConsideredArena() and C_PvP.IsMatchActive() and not C_PvP.IsMatchComplete()
		and C_PvP.GetActiveMatchState() ~= Enum.PvPMatchState.Engaged
end

-- UpdatePrep
-- A placeholder covers each opponent's (hidden) frame while the match is being prepared and the opponent
-- isn't a unit yet. When the opponent count is secret, every placeholder is laid out and only those with a
-- specialization are visible (SetAlphaFromBoolean).
function stack:UpdatePrep()
	local prep = self.active and not self.previewing and InPrepPhase()
	local count = prep and GetNumArenaOpponentSpecs and GetNumArenaOpponentSpecs()
	local secretCount = issecretvalue(count)
	for i, frame in ipairs(self.frames) do
		local placeholder = frame.prep
		local show = prep and (secretCount or i <= (count or 0)) and not Plain(UnitExists(frame.partyid))
		if (show) then
			local hasSpec, specName, className, specIcon, r, g, b = SpecInfo(i)
			local secret = issecretvalue(hasSpec)
			if (secret or hasSpec) then
				placeholder.specName:SetText(specName)
				placeholder.className:SetText(className)
				placeholder.specIcon:SetTexture(specIcon)
				placeholder.bar:SetVertexColor(r, g, b)
				if (secret) then
					placeholder:SetAlphaFromBoolean(hasSpec)
				else
					placeholder:SetAlpha(1)
				end
			else
				show = false
			end
		end
		placeholder:SetShown(show and true or false)
	end
end

stack:SetScript("OnEvent", stack.UpdatePrep)

-- OnActiveChanged(on): the placeholder events
function stack:OnActiveChanged(on)
	self:UnregisterAllEvents()
	if (on) then
		for _, event in ipairs(stackEvents) do
			if (not IsEventValid or IsEventValid(event)) then
				self:RegisterEvent(event)
			end
		end
	end
	self:UpdatePrep()
end

-- OnPreviewChanged: Edit Mode shows the frames themselves
function stack:OnPreviewChanged()
	self:UpdatePrep()
end

for _, frame in ipairs(XPerl_UnitStack_CreateFrames(stack, "XPerl_ArenaFrameTemplate", "XPerl_Arena", 5)) do
	local placeholder = CreateFrame("Frame", frame:GetName().."Prep", stack, "XPerl_ArenaPrepTemplate")
	placeholder:SetFrameStrata(frame:GetFrameStrata())
	placeholder:SetAllPoints(frame)
	XPerl_RegisterPerlFrames(placeholder)
	frame.prep = placeholder
end
