local playerClass, playerName
local myBuffSpells
local conf
XPerl_RequestConfig(function(new) conf = new end)

local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetTime = GetTime
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitName = UnitName
local rosterUpdate
local xperlHealComms = XPERL_COMMS_PREFIX.."Heal"
local distribution

------------------------------------------------------------------------------
-- XPerl_Highlight
------------------------------------------------------------------------------

local hotSpells  = XPERL_HIGHLIGHT_SPELLS.hotSpells
local pomSpells = XPERL_HIGHLIGHT_SPELLS.pomSpells
local shieldSpells = XPERL_HIGHLIGHT_SPELLS.shieldSpells
local healSpells = XPERL_HIGHLIGHT_SPELLS.healSpells
local groupHealSpells = XPERL_HIGHLIGHT_SPELLS.groupHealSpells
local buffSpells = XPERL_HIGHLIGHT_SPELLS.buffSpells

local colours = {HOT = {r = 0.2, g = 0.4, b = 0.8, canFlash = true},
		 POM = {r = 0.8, g = 0.6, b = 0.4},
		 SHIELD = {r = 0.6, g = 0.1, b = 0.6, canFlash = true},
		 AGGRO = {r = 0.8, g = 0, b = 0},
		 HEAL = {r = 0.2, g = 0.8, b = 0.2},
		 SEL = {r = 0.86, g = 0.82, b = 0.41},
		 TARGET = {r = 0.7167, g = 0.6833, b = 0.31467}			-- Coloured so that colour * 1.2 == SEL colour
}

-- XPerl_Highlight(name, highlightType, duration)
local xpHigh = CreateFrame("Frame", "XPerl_Highlight")
xpHigh.list = {}
xpHigh.callbacks = {}
xpHigh.lastExpireCheck = 0
xpHigh.flashers = {}

-- xpHigh:CreateHotCount(frame)
function xpHigh:CreateHotCount(frame)

	local f = frame.highlight:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	frame.highlight.hot = f

	f:SetTextColor(0, 1, 0)
	f:Hide()

	local sf = getglobal(frame:GetName().."statsFrame")
	if (sf) then
		if (strfind(frame:GetName(), "XPerl_Raid_Grp")) then
			f:SetTextHeight(15)
			f:SetPoint("TOPLEFT", sf, "TOPLEFT", 3, -3)
		else
			f:SetPoint("TOPLEFT", sf, "TOPLEFT", 5, -6)
		end
	else
		f:SetPoint("CENTER", 0, 0)
	end
end

-- XPerl_Highlight:Add
function xpHigh:Add(name, highlightType, duration, source)
--ChatFrame2:AddMessage("xpHigh:Add("..tostring(name)..", "..tostring(highlightType)..", "..tostring(duration)..")")

	if (not UnitInRaid(name) and not UnitInParty(name)) then
		return
	end
	if (not self.list[name]) then
		self.list[name] = XPerl_GetReusableTable()
	end
	local a = self.list[name]

	if (not duration) then
		a[highlightType] = nil
		self:Send(name)
	else
		if (duration == 0) then
			a[highlightType] = 0
			self:Send(name)
		else
			if (highlightType == "HOTCOUNT") then
				a[highlightType] = duration
				self:Send(name)
			else
				local newEndTime = GetTime() + duration
				if (highlightType == "HEAL" and source and (UnitInRaid(source) or UnitInParty(source))) then
					-- We'll query their cast bar and get accurate highlight time info
					local spellName, rank, spellNameAlso, iconTexture, startTime, endTime, isTradeSkill = UnitCastingInfo(source)
					if (spellName and rank and rank ~= "") then
						newEndTime = endTime / 1000
					end

					newEndTime = newEndTime + 0.8		-- Add some because other highlights expire 1 sec early
				end
--if (highlightType == "HEAL") then
--ChatFrame2:AddMessage("HEAL "..name..", current = "..tostring(current)..", newEndTime = "..tostring(newEndTime))
--end
				local current = a[highlightType]
				if (not current or current < newEndTime) then
					a[highlightType] = newEndTime
					self:Send(name)
				end
			end
		end
	end
end

-- xpHigh:TooltipInfo
function xpHigh:TooltipInfo(name)
	local effects = self.list[name]
	if (effects) then
		local str = ""
		local prefix = XPERL_LOC_STATUSTIP
		for k,v in pairs(effects) do
			local desc = XPERL_LOC_STATUSTIPLIST[k]
			local c = colours[k]
			if (desc and c) then
				str = str..prefix..format("|c00%02X%02X%02X", 255 * c.r, 255 * c.g, 255 * c.b)..desc.."|r"
				prefix = ", "
			end
		end

		if (prefix == ", ") then
			GameTooltip:AddLine("\r"..str)
			GameTooltip:Show()
		end
	end
end

-- xpHigh:Remove
function xpHigh:Remove(name, highlightType)
	local a = self.list[name]
	if (a) then
--ChatFrame2:AddMessage("xpHigh:Remove("..tostring(name)..", "..tostring(highlightType)..")")
		a[highlightType] = nil
		self:Send(name)
	end
end

-- xpHigh:HasEffect
function xpHigh:HasEffect(name, effect)
	local list = self.list[name]
	if (list) then
		return list[effect]
	end
end

-- xpHigh:OnUpdate
function xpHigh:OnUpdate(elapsed)
	if (rosterUpdate) then
		rosterUpdate = nil
		local instance, pvpType = IsInInstance()
		if (pvpType == "pvp") then
			distribution = "BATTLEGROUND"
		elseif (GetNumRaidMembers() > 0) then
			distribution = "RAID"
		else
			distribution = "PARTY"
		end

		self:RefreshAllAuras()			-- New roster, get all
		if (not (conf.highlight.enable and (conf.highlight.HOT or conf.highlight.SHIELD or conf.highlight.HEAL))) then
			self:SetScript("OnUpdate", nil)
			return
		end
	end

	self.lastExpireCheck = self.lastExpireCheck + elapsed
	if (self.lastExpireCheck > 0.2) then
		self.lastExpireCheck = 0
	else
		return
	end

	-- We expire things 1 second early so people can cast in time for buff to expire
	local now = GetTime() + 1

	for playerName,list in pairs(self.list) do
		local any
		for k,v in pairs(list) do
			any = true
			if (k ~= "HOTCOUNT") then
				if (v > 0) then
					if (v <= now) then
						self.flashers[playerName] = nil
						list[k] = nil
						self:Send(playerName)

					elseif (v <= now + 5 and colours[k].canFlash) then
						if (not self.flashers[playerName]) then
							self.flashers[playerName] = k
							self:Send(playerName)
						end
					end
				end
			end
		end

		if (not any) then
			self.list[playerName] = nil
			self.flashers[playerName] = nil
		end
	end
end

-- xpHigh:Query
function xpHigh:SetHighlight(frame, unitName)
--if (strfind(frame:GetName(), "^XPerl_Raid")) then ChatFrame7:AddMessage("XPerl_Highlight:SetHighlight("..tostring(frame:GetName())..", "..tostring(unitName)) end
	if (not frame.highlight) then
		XPerl_Notice("No .highlight region for "..frame:GetName()..", unit: "..unitName)
		return
	end

	if (not unitName) then
		local id = frame.partyid
		if (not id) then
			id = SecureButton_GetUnit(frame)
		end
		if (id) then
			unitName = UnitName(id)
		end
	end

	self:OnUpdate(0)

	local hotCount
	if (unitName and conf.highlight.enable) then
		local r = self.list[unitName]
		if (r) then
			local r1, g1, b1, r2, g2, b2, t1
			for k,v in pairs(r) do
				if (k == "HOTCOUNT") then
					hotCount = v
				else
					if (not r1 or t1 == "TARGET") then
						t1 = k
						r1, g1, b1 = colours[k].r, colours[k].g, colours[k].b
					else
						r2, g2, b2 = colours[k].r, colours[k].g, colours[k].b
						break
					end
				end
			end

			if (r1) then
				frame.highlight.tex:Show()
				frame.highlight.tex:SetAlpha(1)

				if (frame.highlight.sel) then
					r1 = min(r1 * 1.2, 1)
					g1 = min(g1 * 1.2, 1)
					b1 = min(b1 * 1.2, 1)
				end

				if (r2) then
					if (frame.highlight.sel) then
						r2 = min(r2 * 1.2, 1)
						g2 = min(g2 * 1.2, 1)
						b2 = min(b2 * 1.2, 1)
					end
					frame.highlight.tex:SetGradient("HORIZONTAL", r1, g1, b1, r2, g2, b2)
				else
					frame.highlight.tex:SetVertexColor(r1, g1, b1)
				end

				if (self.flashers[unitName]) then
					XPerl_FrameFlash(frame.highlight.tex)
				else
					XPerl_FrameFlashStop(frame.highlight.tex)
				end
				self:ShowHotCount(frame, hotCount)
				return
			end
		end
	end

	self:RemoveHighlight(frame)
	self:ShowHotCount(frame, hotCount)
end

-- ShowHotCount
function xpHigh:ShowHotCount(frame, hotCount)

	if (conf.highlight.HOTCOUNT) then
		if (hotCount and hotCount > 0) then
			if (not frame.highlight.hot) then
				self:CreateHotCount(frame)
			end

			frame.highlight.hot:SetText(hotCount)
			frame.highlight.hot:Show()
		else
			if (frame.highlight.hot) then
				frame.highlight.hot:Hide()
			end
		end
	else
		if (frame.highlight.hot) then
			frame.highlight.hot:Hide()
		end
	end
end

-- xpHigh:RemoveHighlight
function xpHigh:RemoveHighlight(frame)
	XPerl_FrameFlashStop(frame.highlight.tex)

	frame.highlight.tex:SetVertexColor(0.86, 0.82, 0.41)	-- Default selection colour

	if (frame.highlight.sel and conf.highlightSelection) then
		frame.highlight.tex:Show()
		frame.highlight.tex:SetAlpha(1)
	else
		frame.highlight.tex:Hide()
	end
end

-- xpHigh:ClearAll
function xpHigh:ClearAll(clearType)
	for k,v in pairs(self.list) do
		if (v[clearType]) then
			v[clearType] = nil
			self:Send(k)
		end
	end
end

-- xpHigh:Send
function xpHigh:Send(name)
	for k,v in pairs(self.callbacks) do
		v[1](v[2], name)
	end
end

-- XPerl_RegisterFrameHighlighter
function xpHigh:Register(callback, slf)
	tinsert(self.callbacks, {callback, slf})
end

-- xpHigh:OnEvent
function xpHigh:OnEvent(event, a, b, c, d)
	self[event](self, a, b, c, d)
end

-- xpHigh:UNIT_SPELLCAST_SENT
function xpHigh:UNIT_SPELLCAST_SENT(unit, spell, rank, targetName)
--ChatFrame2:AddMessage("UNIT_SPELLCAST_SENT("..tostring(unit)..", "..tostring(spell)..", "..tostring(rank)..", "..tostring(targetName)..")")
	if (hotSpells[spell] or shieldSpells[spell] or pomSpells[spell]) then
		self.castSpell = spell
		self.castTarget = targetName

	elseif (unit == "player") then
		local t = healSpells[spell]
		if (t) then
			self.castSpell = spell
			self.castTarget = targetName
			if (conf.highlight.HEAL) then
				self:Add(targetName, "HEAL", max(2, t), "player")
			end
			SendAddonMessage(xperlHealComms, "HEAL "..targetName, nil, distribution)
		else
			t = groupHealSpells[spell]
			if (t) then
				local playerName = UnitName(unit)
				local targetGroup
				self.castSpell = spell
				self.castTarget = targetName

				for unit, unitName, unitClass, group in XPerl_NextMember do
					if (unitName == playerName) then
						targetGroup = group
						break
					end
				end
				if (targetGroup) then
					for unit, unitName, unitClass, group in XPerl_NextMember do
						if (group == targetGroup) then
							if (conf.highlight.HEAL) then
								self:Add(unitName, "HEAL", max(2, t), "player")
							end
							SendAddonMessage(xperlHealComms, "HEAL "..unitName, nil, distribution)
						end
					end
				end
			end
		end
	else
		self.castTarget, self.castSpell = nil, nil
	end
end

-- xpHigh:UNIT_SPELLCAST_FAILED
function xpHigh:UNIT_SPELLCAST_FAILED(unit)
	if (unit == "player" and self.castTarget) then
		if (conf.highlight.HEAL) then
			self:Remove(self.castTarget, "HEAL")
		end
		SendAddonMessage(xperlHealComms, "FAIL "..self.castTarget, nil, distribution)
		self.castTarget = nil
		self.castSpell = nil
	end
end

xpHigh.UNIT_SPELLCAST_INTERRUPTED = xpHigh.UNIT_SPELLCAST_FAILED

-- xpHigh:UNIT_SPELLCAST_SUCCEEDED
function xpHigh:UNIT_SPELLCAST_SUCCEEDED(unit, spell, rank)
	if (spell == self.castSpell) then
		if (hotSpells[spell]) then
			if (conf.highlight.HOT) then
				self:Add(self.castTarget, "HOT", hotSpells[spell])
			end
		elseif (shieldSpells[spell]) then
			if (conf.highlight.SHIELD) then
				self:Add(self.castTarget, "SHIELD", shieldSpells[spell])
			end
		elseif (pomSpells[spell]) then
			if (conf.highlight.HOT) then
				self:Add(self.castTarget, "POM", pomSpells[spell])
			end
		end
	end
	self.castSpell = nil
	self.castTarget = nil
end

-- xpHigh:CHAT_MSG_ADDON
function xpHigh:CHAT_MSG_ADDON(source, msg, channel, player)
--if (source == xperlHealComms) then
--ChatFrame2:AddMessage("CHAT_MSG_ADDON("..tostring(source)..", msg="..tostring(msg)..", channel="..tostring(channel)..", player="..tostring(player)..")")
--end
	if (player ~= playerName and conf.highlight.HEAL) then
		if (source == "HealComm") then
			local name, healSize = strmatch(msg, "^(.+):(.+)$")
			if (name) then
				self:Add(name, "HEAL", 2, source)
			end
		elseif (source == xperlHealComms) then
			local msgType, name = strmatch(msg, "^(%a+) (%a+)$")
			if (name) then
				if (msgType == "HEAL") then
					self:Add(name, "HEAL", 2, source)
				elseif (msgType == "FAIL") then
					self:Remove(name, "HEAL")
				end
			end
		end
	end
end

-- xpHigh:CommLibCallback()
function xpHigh:CommLibCallback(sender, senderUnit, action, target, channel, spell, rank, displayName, icon, startTime, endTime, isTradeSkill)
	if (not channel and healSpells[spell]) then
		self:Add(target, "HEAL", healSpells[spell], senderUnit)
	end
end

-- xpHigh:UNIT_SPELLCAST_START
--function xpHigh:UNIT_SPELLCAST_START(unit, spell, rank)
--	if (unit == "player") then
--		if (healSpells[spell]) then
--			self:Add(targetName, "HEAL", healSpells[name])
--			SendAddonMessage("X-PerlHeal",
--		end
--	end
--end

-- xpHigh:UNIT_SPELLCAST_START
-- Removed for now since we can't determine the heal target
--function xpHigh:UNIT_SPELLCAST_START(unit)
--	local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(unit)
--	if (healSpells[name] and not UnitIsUnit(unit, "player")) then
--		if (UnitName(unit.."target") and not UnitIsDead(unit.."target") and UnitIsFriend("player", unit.."target")) then
--			self:Add(targetName, "HEAL", healSpells[name])
--		end
--	end
--end

-- xpHigh:HasMyPomPom(unit)
function xpHigh:HasMyPomPom(unit)
	for i = 1,20 do
		local name, rank, tex, dur, maxDur = UnitBuff(unit, i)
		if (not name or not dur) then
			break
		end

		if (pomSpells[name]) then
			return dur
		end
	end
end

-- xpHigh:HasMyShield(unit)
function xpHigh:HasMyShield(unit)
	for i = 1,20 do
		local name, rank, tex, dur, maxDur = UnitBuff(unit, i)
		if (not name or not dur) then
			break
		end

		if (shieldSpells[name]) then
			return dur
		end
	end
end

-- xpHigh:FindMyPomPom()
function xpHigh:FindMyPomPom()
	for unit, unitName, unitClass, group in XPerl_NextMember do
		local timeLeft = self:HasMyPomPom(unit)
		if (timeLeft) then
			return unit, timeLeft
		end
	end
end

-- xpHigh:UNIT_AURA
function xpHigh:UNIT_AURA(unit)
	--if (not UnitInRaid(unit)) then
	--	return
	--elseif (GetNumRaidMembers() > 0 and not strfind(unit, "^raid")) then
	--	return
	--elseif (GetNumPartyMembers() > 0 and (not strfind(unit, "^party") and not unit == "player")) then
	--	return
	--end

	local name = UnitName(unit)

	-- Check pom movement (Needs testing)
	if (playerClass == "PRIEST") then
		if (self:HasEffect(name, "POM")) then
			if (not self:HasMyPomPom(unit)) then
				self:Remove(name, "POM")
				local unit, timeLeft = self:FindMyPomPom()
				if (unit) then
					self:Add(UnitName(unit), "POM", timeLeft)
				end
			end
		end
	end

	-- Check for pre-mature end of shield buff (Power Word: Shield, Earth Shield)
	if (playerClass == "SHAMAN" or playerClass == "PRIEST") then
		if (self:HasEffect(name, "SHIELD")) then
			if (not self:HasMyShield(unit)) then
				self:Remove(name, "SHIELD")
			end
		end
	end

	if (conf.highlight.HOTCOUNT) then
		local hotCount = 0
		for i = 1,40 do
			local buffName, rank, buffTexture, count, duration, maxDuration = UnitBuff(unit, i)
			if (not buffName) then
				break
			end
			if (hotSpells[buffName]) then
				hotCount = hotCount + 1
			end
		end

		if (hotCount == 0) then
			self:Remove(name, "HOTCOUNT")
		else
			self:Add(name, "HOTCOUNT", hotCount)
		end
	end
end

-- xpHigh:RAID_ROSTER_UPDATE
function xpHigh:RAID_ROSTER_UPDATE()
	rosterUpdate = true
	self:SetScript("OnUpdate", self.OnUpdate)
end

-- PLAYER_TARGET_CHANGED
function xpHigh:PLAYER_TARGET_CHANGED()
	self:ClearAll("TARGET")
	if (UnitExists("target") and UnitInRaid("target") or UnitInParty("target")) then
		self:Add(UnitName("target"), "TARGET", 0)
	end
end

-- xpHigh:GetBuffClasses
function xpHigh:GetBuffClasses()
	local oldBuffClasses = self.buffClasses
	self.buffClasses = XPerl_FreeTable(self.buffClasses)

	local raid = GetNumRaidMembers() > 0

	self.roster = XPerl_FreeTable(self.roster)

	if (raid) then
		self.roster = XPerl_GetReusableTable()
	end

	for unitid, unitName, unitClass in XPerl_NextMember do
		if (raid) then
			self.roster[unitName] = u
		end
		if (buffSpells[unitClass]) then
			if (not self.buffClasses) then
				self.buffClasses = XPerl_GetReusableTable()
			end
			self.buffClasses[unitClass] = true
		end
	end

	if (oldBuffClasses) then
		if (not self.buffClasses or not oldBuffClasses) then
			return (self.buffClasses == nil) ~= (oldBuffClasses == nil)
		end

		return self.buffClasses.PRIEST ~= oldBuffClasses.PRIEST or
			self.buffClasses.DRUID ~= oldBuffClasses.DRUID or
			self.buffClasses.MAGE ~= oldBuffClasses.MAGE
	end

	return self.buffClasses
end

-- xpHigh:RefreshAllAuras
function xpHigh:RefreshAllAuras()
	for unitid in XPerl_NextMember do
		self:UNIT_AURA(unitid)
	end
end

local hcTried

-- xpHigh:OptionChange
function xpHigh:OptionChange()
	local events

	local _
	_, playerClass = UnitClass("player")
	playerName = UnitName("player")
	myBuffSpells = buffSpells[playerClass]

	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")

	if (conf.highlight.enable and (conf.highlight.HOT or conf.highlight.SHIELD or conf.highlight.HEAL)) then
		events = true
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	else
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	end

	if (not conf.highlight.enable or not conf.highlight.HOT) then
		self:ClearAll("HOT")
		self:ClearAll("POM")
	end
	if (not conf.highlight.enable or not conf.highlight.SHIELD) then
		self:ClearAll("SHIELD")
	end

	if (conf.highlight.enable and conf.highlight.HEAL) then
		events = true
		self:RegisterEvent("CHAT_MSG_ADDON")
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

		if (not hcTried) then
			hcTried = true
			if (playerClass == "SHAMAN" or playerClass == "PRIEST" or playerClass == "DRUID" or playerClass == "PALADIN") then
				if (not IsAddOnLoaded("LibHealComm-3.0")) then
					if (not LoadAddOn("LibHealComm-3.0")) then
						LoadAddOn("HealCommLib")		-- Will load if it's enabled and load on demand
					end
				end
			end

			LoadAddOn("CastCommLib")
			local cc = AceLibrary and AceLibrary:HasInstance("CastCommLib") and AceLibrary("CastCommLib")
			if (cc) then
				cc:RegisterCallBack(xpHigh, "CommLibCallback")
			end
		end
	else
		self:UnregisterEvent("CHAT_MSG_ADDON")
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		self:ClearAll("HEAL")
	end

	if (conf.highlight.enable and conf.highlight.HOTCOUNT) then
		events = true
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("RAID_ROSTER_UPDATE")
		self:RefreshAllAuras()
	else
		self:UnregisterEvent("UNIT_AURA")
		self:UnregisterEvent("RAID_ROSTER_UPDATE")
		self:ClearAll("HOTCOUNT")
	end

	if (conf.highlight.TARGET) then
		events = true
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:PLAYER_TARGET_CHANGED()
	else
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:ClearAll("TARGET")
	end

	if (not conf.highlight.AGGRO) then
		XPerl_Highlight:ClearAll("AGGRO")
	end

	if (conf.highlight.enable and events) then
		self:SetScript("OnEvent", self.OnEvent)
	else
		self:SetScript("OnEvent", nil)
	end

	if (conf.highlight.enable and (conf.highlight.HOT or conf.highlight.SHIELD or conf.highlight.HEAL)) then
		self:SetScript("OnUpdate", self.OnUpdate)
	else
		self:SetScript("OnUpdate", nil)
	end
end

XPerl_RegisterOptionChanger(xpHigh.OptionChange, xpHigh)
