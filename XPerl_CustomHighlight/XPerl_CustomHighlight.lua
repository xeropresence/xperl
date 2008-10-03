-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

if (not XPerl_RequestConfig) then
	return
end

local conf
XPerl_RequestConfig(function(new) conf = new.custom end, "$Revision$")

local ch = CreateFrame("Frame", "XPerl_Custom")
ch.active = {}
ch:RegisterEvent("PLAYER_ENTERING_WORLD")
ch:RegisterEvent("UNIT_AURA")
ch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ch:RegisterEvent("MINIMAP_ZONE_CHANGED")

ch.RaidFrameArray = XPerl_Raid_GetFrameArray()

-- ch:OnEvent(event, a, b, c)
function ch:OnEvent(event, a, b, c)
	self[event](self, a, b, c)
end

-- ch:AddDebuff
function ch:AddDebuff(debuffName)
	local zoneName = GetRealZoneText()
end

-- ch:AddDebuff
function ch:AddBuff(buffName)
	local zoneName = GetRealZoneText()
end

-- DefaultZoneData
function ch:DefaultZoneData()
	return {
		["Serpentshrine Caverns"]=
			{
				[38132] = true								-- Paralyze - Picked up Tainted Core
			},
		["Black Temple"] =
			{
				[38132] = true,								-- Paralyze - Target of Illidan's Demons
				[40932] = true,								-- Agonizing Flames (Illidan)
				[41917] = true,								-- Parasitic Shadowfiend (Illidan)
				[46787] = true,								-- Fel Rage (Gurtogg Bloodboil)
				[39837] = true,								-- Impaling Spine (Najentus)
				[41001] = true,								-- Fatal Attraction (Mother Shahrazz)
				[40251] = true,								-- Shadow of Death (Terron Gorefiend)
				[43581] = true,								-- Deadly Poison (Illidari Council)
				[40585] = true,								-- Dark Barrage (Illidan)
			},
		["Hyjal Summit"] =
			{
				[39941] = true,								-- Inferno
				[31347] = true,								-- Doom
			},
		["Karazhan"] =
			{
				[34661] = true,								-- Sacrifice (Illhoof)
				[30753] = true,								-- Red Riding Hood (Big Bad Wolf)
			},
		["Sunwell Plateau"] =
			{
				[45141] = true,								-- Burn (Brutallus)
			},
		}
end

-- SetDefaultZoneData
function ch:SetDefaultZoneData()
	if (conf) then
		conf.zones = self:DefaultZoneData()
		self:PLAYER_ENTERING_WORLD()
	end
end

-- SetDefaultZoneData
function ch:SetDefaults()
	if (conf) then
		conf.alpha = 0.5
		conf.blend = "ADD"
		self:SetDefaultZoneData()
	end
end

-- ch:PLAYER_ENTERING_WORLD
function ch:PLAYER_ENTERING_WORLD()
	if (conf and conf.enable) then
		if (not conf.zones) then
			conf.zones = self:DefaultZoneData()
		end
		local zoneName = GetRealZoneText()
		self.zoneDataRaw = conf and conf.zones[zoneName]

		if (self.zoneDataRaw) then
			self.zoneData = {}
			for spellid in pairs(self.zoneDataRaw) do
				local spellName, rank, icon = GetSpellInfo(spellid)
				if (spellName) then
					self.zoneData[spellName] = icon
				end
			end
		else
			self.zoneData = nil
		end
	else
		self.zoneData = nil
	end
end

ch.ZONE_CHANGED_NEW_AREA = ch.PLAYER_ENTERING_WORLD
ch.MINIMAP_ZONE_CHANGED = ch.PLAYER_ENTERING_WORLD

-- UpdateRoster
function ch:UpdateUnits()
	for unit,frame in pairs(self.RaidFrameArray) do
		if (frame:IsShown()) then
			self:Check(frame, unit)
		end
	end
end

-- IconAcquire
function ch:IconAcquire()
	if (not self.icons) then
		self.icons = {}
	end
	if (not self.usedIcons) then
		self.usedIcons = {}
	end

	local icon = self.icons[1]
	if (not icon) then
		icon = CreateFrame("Frame", nil)
		icon:SetFrameStrata("MEDIUM")
		icon.tex = icon:CreateTexture(nil, "OVERLAY")
		icon.tex:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		icon.tex:SetAllPoints(true)
		icon.tex:SetBlendMode(conf.blend or "ADD")
	else
		tremove(self.icons, 1)
	end

	self.usedIcons[icon] = true
	return icon
end

-- IconFree
function ch:IconFree(icon)
	icon:Hide()
	tinsert(self.icons, icon)
	self.usedIcons[icon] = nil
end

-- ch:Highlight
function ch:Highlight(frame, mode, unit, debuff, buffIcon)
	if (not self.active[frame]) then
		self.active[frame] = buffIcon
		local c = frame.customHighlight
		if (not c) then
			c = {}
			frame.customHighlight = c
		end
		c.type = mode
		local icon = self:IconAcquire()
		c.icon = icon

		icon:ClearAllPoints()
		icon:SetPoint("CENTER", frame, "CENTER")
		local size = frame:GetHeight() * frame:GetEffectiveScale()
		icon:SetWidth(size)
		icon:SetHeight(size)
		icon:SetAlpha(conf.alpha or 0.5)
		icon.tex:SetBlendMode(conf.blend or "ADD")

		icon.tex:SetTexture(buffIcon)
		icon:Show()
	end
end

-- Clear
function ch:Clear(frame)
	if (self.active[frame]) then
		self.active[frame] = nil
		local c = frame.customHighlight
		if (c) then
			self:IconFree(c.icon)
			c.icon = nil
		end
	end
end

-- Clear
function ch:ClearAll()
	for frame in pairs(self.usedIcons) do
		local icon = self.usedIcons[frame]
		self.usedIcons[frame] = true
		tinsert(self.icons, icon)
		self.active[frame] = nil
		icon:Hide()
	end
end

-- UNIT_AURA
function ch:UNIT_AURA(unit)
	local frame = XPerl_Raid_GetUnitFrameByUnit(unit)
	if (frame) then
		self:Check(frame, unit)
	end
end

-- ch:Check
function ch:Check(frame, unit)
	if (not conf.enable) then
		return
	end

	local z = self.zoneData
	if (z) then
		if (not unit) then
			unit = frame:GetAttribute("unit")
			if (not unit) then
				unit = SecureButton_GetUnit(frame)
				if (not unit) then
					return
				end
			end
		end

		for i = 1,40 do
			local name, rank, buffIcon = UnitDebuff(unit, i)
			if (not name) then
				break
			end
			if (z[name]) then
				self:Highlight(frame, "debuff", unit, name, buffIcon)
				return
			end
		end
	end

	self:Clear(frame)
end

if (not conf) then
	conf = {
		enable = true,
		zones = ch:DefaultZoneData(),
	}
end

ch:SetScript("OnEvent", ch.OnEvent)

ch:PLAYER_ENTERING_WORLD()
