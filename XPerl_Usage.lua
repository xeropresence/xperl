-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

XPerl_Usage = {}

local GetNumSubgroupMembers = GetNumSubgroupMembers

local new, del, copy = XPerl_GetReusableTable, XPerl_FreeTable, XPerl_CopyTable

local mod = CreateFrame("Frame", "XPerl_UsageFrame")
mod:RegisterEvent("PLAYER_ENTERING_WORLD")
mod:RegisterEvent("CHAT_MSG_ADDON")
mod:RegisterEvent("GROUP_ROSTER_UPDATE")

C_ChatInfo.RegisterAddonMessagePrefix(XPERL_COMMS_PREFIX)

local function modOnEvent(self, event, ...)
	local f = mod[event]
	if (f) then
		f(mod, ...)
	end
end

mod:SetScript("OnEvent", modOnEvent)
mod.notifiedVersion = nil

-- OnTooltipSetUnit is gone since 10.0.2; unit tooltips are post-processed through TooltipDataProcessor
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,
	function(self)
		if (self ~= GameTooltip) then
			return
		end
		local name, unitid = self:GetUnit()
		if (not unitid) then
			unitid = "mouseover"
		end
		mod:TooltipInfo(self, unitid)
	end)


-- Players are keyed by the name their add-on messages arrive under, less our own realm. On Retail that's
-- "Name-Realm" with the realm normalized, as UnitFullName returns it. WoW: Forever names are unique across the
-- region: a sender is "First Surname" (with a realm that tells nothing apart there), and UnitName returns the
-- surname where Retail returns the realm.
local SURNAME_SEPARATOR = XPerlAPI.isForever and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
local SENDER_CONTEXT = SURNAME_SEPARATOR and "short" or "none"

local function SenderKey(sender)
	return Ambiguate(sender, SENDER_CONTEXT)
end

-- The key for a unit, nil while its name is secret
local function UnitKey(unit)
	local name, second
	if (SURNAME_SEPARATOR) then
		name, second = UnitName(unit)
	else
		name, second = UnitFullName(unit)
	end
	if (issecretvalue(name) or issecretvalue(second)) then
		return
	end
	if (not second or second == "") then
		return name
	elseif (SURNAME_SEPARATOR) then
		return name..SURNAME_SEPARATOR..second
	end
	return Ambiguate(name.."-"..second, "none")
end

-- GetUsage(unitName, unitID): what that player's X-Perl announced, asking for it by whisper when it isn't known
local function GetUsage(unitName, unitID)
	local ver = XPerl_Usage[unitName]
	if (not ver) then
		if (unitID and unitName ~= UNKNOWN and (UnitIsPlayer(unitID) and UnitFactionGroup("player") == UnitFactionGroup(unitID) and UnitIsConnected(unitID))) then
			if (not mod.directQueries) then
				mod.directQueries = {}
			end
			if (not mod.directQueries[unitName]) then
				mod.directQueries[unitName] = true
				-- A whispered VER gets no reply (replies are whispers too), so ask for one
				C_ChatInfo.SendAddonMessage(XPERL_COMMS_PREFIX, mod:MakePacket(nil, true).."#ASK", "WHISPER", unitName)
			end
		end
	end

	return ver
end

function mod:TooltipInfo(tooltip, unitid)
	-- The tooltip's unit token is secret for identity-restricted units, and add-on code can't pass that to UnitIsPlayer
	if (issecretvalue(unitid)) then
		return
	end
	if (unitid and conf and conf.tooltip.xperlInfo and UnitIsPlayer(unitid) and UnitIsFriend(unitid, "player")) then
		local isPlayer = UnitIsUnit(unitid, "player")
		local xpUsage
		if (isPlayer) then
			xpUsage = self.ownUsage			-- known here, without waiting for our own announcement to come back
		else
			local key = UnitKey(unitid)
			xpUsage = key and GetUsage(key, unitid)
		end
		if (xpUsage) then
			local xp = "|cFFD00000X-Perl|r "..(xpUsage.version or XPerl_VersionNumber)

			if (xpUsage.revision) then
				local r = "r"..xpUsage.revision
				xp = format("%s |cFF%s%s", xp, r == XPerl_GetRevision() and "80FF80" or "FF8080", r)
			elseif (isPlayer) then
				xp = xp.." |cFF80FF80"..XPerl_GetRevision()
			end

			if (xpUsage.mods and IsShiftKeyDown()) then
				local modList = self:DecodeModuleList(xpUsage.mods)
				if (modList) then
					xp = xp.." : |c00909090"..modList
				end
			end

			GameTooltip:AddLine(xp, 1, 1, 1, 1)
			GameTooltip:Show()
		end
	end
end

-- CheckForNewerVersion
function mod:CheckForNewerVersion(ver)
	--if (not strfind(strlower(ver), "beta")) then
		if (ver > XPerl_VersionNumber) then
			if (not self.notifiedVersion or self.notifiedVersion < ver) then
				self.notifiedVersion = ver

				--if (not conf or conf.tooltip.xperlInfo) then
					DEFAULT_CHAT_FRAME:AddMessage(format(XPERL_USAGE_AVAILABLE, XPerl_ProductName, ver))
				--end
			end
			return true
		end
	--end
end

-- ProcessXPerlMessage
function mod:ProcessXPerlMessage(sender, msg, channel)
	sender = SenderKey(sender)
	local myUsage = XPerl_Usage[sender]

	if (strsub(msg, 1, 4) == "VER ") then
		if (not myUsage) then
			myUsage = {}
			XPerl_Usage[sender] = myUsage
		end

		myUsage.old = nil
		local ver = strsub(msg, 5)

		if (ver == XPerl_VersionNumber) then
			myUsage.version = nil
		else
			myUsage.version = ver
			self:CheckForNewerVersion(ver) -- Won't do a per revision check
		end

		if (channel ~= "WHISPER" and sender and sender ~= UnitKey("player")) then
			self:SendModules("WHISPER", sender)
		end

	elseif (strsub(msg, 1, 4) == "REV ") then
		if (myUsage) then
			local temp = strmatch(strsub(msg, 5), "(%d+)")
			if (temp) then
				myUsage.revision = tonumber(temp)
			end
		end

	elseif (strsub(msg, 1, 7) == "MAXVER ") then
		local ver = strsub(msg, 8)
		if (ver >= XPerl_VersionNumber) then
			self:CheckForNewerVersion(ver)
		end

	elseif (msg == "S") then
		if (channel == "WHISPER") then
			-- Version only sent, so ask for rest
			C_ChatInfo.SendAddonMessage(XPERL_COMMS_PREFIX, "ASK", channel, sender)
		end

	elseif (msg == "ASK") then
		if (channel == "WHISPER") then
			-- Details asked for
			self:SendModules("WHISPER", sender)
		end

	elseif (strsub(msg, 1, 4) == "MOD ") then
		if (myUsage) then
			myUsage.mods = strsub(msg, 5)
		end

	elseif (strsub(msg, 1, 4) == "LOC ") then
		if (myUsage) then
			local loc = strsub(msg, 5)
			if (loc ~= GetLocale()) then
				myUsage.locale = loc
			end
		end

	elseif (strsub(msg, 1, 3) == "GC ") then
		if (myUsage) then
			myUsage.gc = tonumber(strsub(msg, 4))
		end
	end
end

-- XPerl_UsageStartup
function mod:PLAYER_ENTERING_WORLD()
	if (conf.tooltip.xperlInfo) then			-- FOR TESTING
		-- Let other X-Perl users know which version we're running
		self:SendModules()			-- No channel given will detect BG, RAID, PARTY
		if (IsInGuild()) then
			self:SendModules("GUILD")
		end
	end
end

-- GROUP_ROSTER_UPDATE
function mod:GROUP_ROSTER_UPDATE()
	if (IsInRaid()) then
		if (not self.inRaid) then
			self.inRaid = true
			self:SendModules()
		end
	else
		self.inRaid = nil
	end
	
	if (UnitInParty("player")) then
		if (not self.inParty and not self.inRaid) then
			self.inParty = true
			self:SendModules("PARTY")			-- Let other X-Perl users know which version we're running
		end
	else
		self.inParty = nil
	end
	
end

-- CHAT_MSG_ADDON
function mod:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if (prefix == XPERL_COMMS_PREFIX) then
		self:ParseCTRA(sender, msg, channel)
	end
end

-- XPerl_ParseCTRA
function mod:ParseCTRA(sender, msg, channel)
	local arr = new(strsplit("#", msg))
	for i,subMsg in pairs(arr) do
		self:ProcessXPerlMessage(sender, subMsg, channel)
	end
	del(arr)
end

-- !!!!! Don't change the order of this list - EVER!!!!!
-- The position of each entry is its bit in the "MOD" field other clients decode. Every listed module is part of
-- this addon now, so all named slots are always loaded. false marks the slots of retired modules and of separate
-- addons that X-Perl disables at load; they are always sent as not loaded and skipped when decoding.
local xpModList = {"XPerl", "XPerl_Player", "XPerl_PlayerPet", "XPerl_Target", "XPerl_TargetTarget", "XPerl_Party", "XPerl_PartyPet", "XPerl_RaidFrames", false, false, false, false, "XPerl_RaidPets", "XPerl_ArcaneBar", "XPerl_PlayerBuffs", false}

-- The MOD field
local ownModules = ""
for k,v in ipairs(xpModList) do
	ownModules = ownModules..(v and "1" or "0")
end

-- Our own entry, for our own tooltip. version and revision stay nil, as they do for a sender matching ours.
mod.ownUsage = {mods = ownModules}
--------------------------------------------------------

-- XPerl_SendModules
mod.throttle = {}
function mod:SendModules(chan, target)
	if (not chan) then
		if (IsInRaid()) then
			if (select(2, IsInInstance()) == "pvp") then
				chan = "INSTANCE_CHAT"
			else
				chan = "RAID"
			end
		elseif (UnitInParty("player")) then
			chan = "PARTY"
		end
	end

	if (chan) then
		if (chan == "PARTY" or chan == "RAID") then
			-- Cope with WoW 3.2 bug which says party members exist, when in BGs in fake raid
			local instance, pvp = IsInInstance()
			if (pvp == "arena" or pvp == "pvp") then
				return
			end
		end

		if (chan == "WHISPER") then
			local t = self.throttle[target]
			if (t and time() < t + 15) then
				return
			end
			self.throttle[target] = time()
		end

		local packet = self:MakePacket(chan == "WHISPER")
		C_ChatInfo.SendAddonMessage(XPERL_COMMS_PREFIX, packet, chan, target)
	end
end

-- MakePacket
function mod:MakePacket(response, versionOnly)
	local resp
	if (response) then resp = "R#S#" else resp = "" end

	if (versionOnly) then
		return format("%sVER %s#REV %s", resp, XPerl_VersionNumber, XPerl_GetRevision())
	else
		local gc = floor(collectgarbage("count"))

		local s = format("%sVER %s#REV %s#GC %d#LOC %s#MOD %s", resp, XPerl_VersionNumber, XPerl_GetRevision(), gc, GetLocale(), ownModules)
		if (self.notifiedVersion and self.notifiedVersion > XPerl_VersionNumber) then
			s = format("%s#MAXVER %s", s, self.notifiedVersion)
		end
		return s
	end
end

-- XPerl_DecodeModuleList
function mod:DecodeModuleList(modList)
	local ret = new()
	for k,v in ipairs(xpModList) do
		if (v and strsub(modList, k, k) == "1") then
			if (XPerlUsageNameList[v]) then
				tinsert(ret, XPerlUsageNameList[v])
			else
				tinsert(ret, v)
			end
		end
	end
	local tmp = table.concat(ret, ", ")
	del(ret)
	return tmp
end
