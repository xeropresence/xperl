-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local addonName = ...		-- folder name; ADDON_LOADED reports this, not the TOC title

XPerlLocked		= 1
local conf
local ConfigRequesters = {}
XPerl_OutOfCombatQueue	= {}
local realmKey, playerName		-- XPerlAPI.SettingsOwner()
local iFixed1
local totalBlocked = 0
local xperlBlocked = 0
local lastConfigMode
local maxRevision

function XPerl_GetRevision()
	return (maxRevision and "r"..maxRevision) or ""
end
function XPerl_SetModuleRevision(rev)
	if (rev) then
		rev = strmatch(rev, "Revision: (%d+)")
		if (rev) then
			rev = tonumber(rev)
			if (not maxRevision or rev > maxRevision) then
				maxRevision = rev
			end
		end
	end
end
local AddRevision = XPerl_SetModuleRevision

XPerl_SetModuleRevision("$Revision$")

function XPerl_Notice(...)
	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage(XPerl_ProductName.." - |c00FFFF80"..format(...))
	end
end

do
	local function DisableOther(modName, issues)
		if (C_AddOns.DoesAddOnExist(modName) and XPerlAPI.IsAddOnEnabled(modName)) then
			C_AddOns.DisableAddOn(modName)
			local notice = "Disabled '"..modName.."' addon. It is not compatible or needed with X-Perl"
			if (issues) then
				notice = notice..", and creates display issues."
			end
			XPerl_Notice(notice)
		end
	end

	DisableOther("PerlButton")		-- PerlButton was made for Nymbia's Perl UnitFrames. We have our own minimap button
	DisableOther("WT_ZoningTimeFix", true)

	DisableOther("CT_PartyBuffs", true)

	if (XPerlAPI.IsAddOnEnabled("XPerl_GrimReaper")) then
		C_AddOns.DisableAddOn("XPerl_GrimReaper")
		XPerl_Notice("Disabled XPerl_GrimReaper. This has been replaced by a standalone version 'GrimReaper' available on the WoW Ace Updater or from files.wowace.com")
	end
end

-- Settings sections that belong to a unit frame type (frame settings). Edit Mode dialogs edit these
-- (XPerl_EditModeSettings.lua); they used to be kept per Edit Mode layout (XPerl_EditMode.lua).
XPerl_FrameConfigKeys = {"player", "pet", "target", "focus", "targettarget", "focustarget", "targettargettarget",
	"pettarget", "party", "partypet", "raid", "raidpet", "boss", "arena"}

-- Top-level XPerlConfigNew keys that are not realm tables of per-character settings slots
XPerl_ConfigReservedKeys = {global = true, savedPositions = true, editMode = true}

-- XPerl_RequestConfig
-- Setup a callback to give config around to local variables
function XPerl_RequestConfig(getConfig, rev)
	tinsert(ConfigRequesters, getConfig)
	if (XPerlDB) then
		getConfig(XPerlDB)
	end
	AddRevision(rev)
end

-- XPerl_NotifyConfig
-- Hands XPerlDB to every XPerl_RequestConfig callback again, e.g. after its frame sections were switched to
-- another Edit Mode layout. Changes no settings.
function XPerl_NotifyConfig()
	for k,v in pairs(ConfigRequesters) do
		v(XPerlDB)
	end
end

-- XPerl_IsValidConfig
-- Cheap structural check that a settings table has every top-level section.
function XPerl_IsValidConfig(set)
	return type(set) == "table" and set.player and set.pet and set.colour and set.target and set.targettarget and set.focus and set.party and set.partypet and set.raid and set.rangeFinder and set.highlight and set.buffs and set.bar and true
end
local QuickValidate = XPerl_IsValidConfig

-- CurrentConfig()
-- The settings slot in use. "Save per character" is account-wide, so a character can find itself in a mode
-- it has no slot for yet; it then starts from a copy of the other mode's settings (or defaults).
local function CurrentConfig()
	local realm = realmKey
	local mine = XPerlConfigNew[realm] and XPerlConfigNew[realm][playerName]
	local global = XPerlConfigNew.global

	if (XPerlConfigSavePerCharacter) then
		if (not mine or not QuickValidate(mine)) then
			if (QuickValidate(global)) then
				mine = XPerl_CopyTable(global)
			else
				mine = {}
				XPerl_Options_Defaults(mine)
			end
			if (not XPerlConfigNew[realm]) then
				XPerlConfigNew[realm] = {}
			end
			XPerlConfigNew[realm][playerName] = mine
		end
		return mine
	end

	if (not global or not QuickValidate(global)) then
		if (QuickValidate(mine)) then
			global = XPerl_CopyTable(mine)
		else
			global = {}
			XPerl_Options_Defaults(global)
		end
		XPerlConfigNew.global = global
	end
	return global
end

-- GiveConfig
-- (Re)selects the settings slot, validates it and hands it to every module
local function GiveConfig()
	conf = CurrentConfig()
	XPerlDB = conf
	XPerl_EditMode_AttachConfig(conf)
	XPerl_pcall(XPerl_ValidateSettings)
	XPerl_NotifyConfig()
end

XPerl_GiveConfig = GiveConfig

-- XPerl_SetCurrentConfig
-- Replace the active settings (per-character or global, whichever is in use) with `new`, and push them to
-- every module.
function XPerl_SetCurrentConfig(new)
	if (XPerlConfigSavePerCharacter) then
		XPerlConfigNew[realmKey] = XPerlConfigNew[realmKey] or {}
		XPerlConfigNew[realmKey][playerName] = new
	else
		XPerlConfigNew.global = new
	end

	GiveConfig()

	XPerl_OptionActions()

	if (XPerl_Options and XPerl_Options:IsShown()) then
		XPerl_Options:Hide()
		XPerl_Options:Show()
	end
end

-- XPerl_ResetDefaults
function XPerl_ResetDefaults()
	local conf = {}
	XPerl_Options_Defaults(conf)
	XPerl_SetCurrentConfig(conf)
end

-- CopyTable
function XPerl_CopyTable(old)
	if (not old) then
		return
	end

	local new = XPerl_GetReusableTable()

	for k,v in pairs(old) do
		if (type(v) == "table") then
			new[k] = XPerl_CopyTable(v)
		else
			new[k] = v
		end
	end

	return new
end

-- ImportOldConfigs()
local function ImportOldConfigs()
	if (XPerlConfig_Global) then
		-- Convert old global configs
		XPerlConfigNew = {}

		for realm,realmList in pairs(XPerlConfig_Global) do
			XPerlConfigNew[realm] = {}
			for player,settings in pairs(realmList) do
				XPerlConfigNew[realm][player] = XPerl_Options_ImportOldConfig(settings)
			end
		end

		XPerlConfig_Global = nil
	end
	if (XPerlConfig) then
		-- Convert old config
		if (not XPerlConfigNew) then
			XPerlConfigNew = {}
		end

		if (XPerlConfig) then
			XPerlConfigNew.global = XPerl_Options_ImportOldConfig(XPerlConfig)
			XPerlConfig = nil
		end
	end
end

--[[
-- XPerl_GuildStatusUpdate()
function XPerl_GuildRoster_Update()
	if (conf.colour.class and conf.colour.guildList) then
		local col = _G.GuildRosterColumnButton4
		if (_G.GuildFrame.selectedTab ~= 2 or not col or col.sortType ~= "zone") then
			return
		end

		local myZone = GetRealZoneText()

		local scrollFrame = GuildRosterContainer
		local offset = HybridScrollFrame_GetOffset(scrollFrame)
		local buttons = scrollFrame.buttons
		local numButtons = #buttons
		local button, index, class
		local totalMembers, onlineMembers = GetNumGuildMembers()
		local selectedGuildMember = GetGuildRosterSelection()

		for i = 1, numButtons do
			button = buttons[i]
			index = offset + i
			local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(index)

			local color = GetQuestDifficultyColor(level)
			if (online) then
				_G["GuildRosterContainerButton"..i.."String1"]:SetTextColor(color.r, color.g, color.b)
			else
				_G["GuildRosterContainerButton"..i.."String1"]:SetTextColor(color.r / 2, color.g / 2, color.b / 2)
			end

			if (zone == myZone) then
				if (online) then
					_G["GuildRosterContainerButton"..i.."String3"]:SetTextColor(0, 1, 0)
				else
					_G["GuildRosterContainerButton"..i.."String3"]:SetTextColor(0, 0.5, 0)
				end
			end

		end
	end
end

if (_G.GuildRoster_Update) then
	hooksecurefunc("GuildRoster_Update", XPerl_GuildRoster_Update)
end ]]

-- onEventPostSetup
local function onEventPostSetup(self, event, unit, ...)
	--print(event)
	--if (event == "PLAYER_REGEN_ENABLED") then
		--print("something useful")
		if (not XPerlDB) then
			return
		end
		--print("dsadasd")
		if (XPerl_OutOfCombatOptionSet) then
			XPerl_OutOfCombatOptionSet = nil
			XPerl_OptionActions()
		end
		for func,arg in pairs(XPerl_OutOfCombatQueue) do
			assert(type(func) == "function")
			func(arg or nil)
			--print("out of combat magiczzz:" .. tostring(arg))
			--if (type(v) == "function") then
			--	v()
			--elseif (type(v) == "table") then
			--	v[1](v[2])
			--elseif (type(v) == "string") then
			--	RunScript(v)
			--end
			XPerl_OutOfCombatQueue[func] = nil
		end
	--end
end

-- XPerl_RegisterLDB
local function XPerl_RegisterLDB()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
	if (LDB) then
		local ldbSource = LDB:NewDataObject("X-Perl UnitFrames", {
			type = "launcher",
			text = XPerl_ShortProductName,
			icon = XPerl_ModMenuIcon,
		})

		if (ldbSource) then
			function ldbSource:Update()
				self.text = XPerl_Version
			end
			ldbSource.OnClick = XPerl_MinimapButton_OnClick
			ldbSource.OnTooltipShow = function(tooltip) XPerl_MinimapButton_Details(tooltip, true) end
		end
	end
	XPerl_RegisterLDB = nil
end


-- WoW: Forever settings from before the ruleset keys (XPerlAPI.SettingsOwner) sit under the server name and the
-- first name. This character's move to its own keys when it logs in, unless it has data there already.
local function MoveServerKeyedSettings()
	local oldRealm, oldName = GetRealmName(), UnitName("player")
	local list = XPerlConfigNew[oldRealm]
	if (type(list) == "table" and not XPerl_ConfigReservedKeys[oldRealm] and list[oldName] ~= nil) then
		XPerlConfigNew[realmKey] = XPerlConfigNew[realmKey] or {}
		if (XPerlConfigNew[realmKey][playerName] == nil) then
			XPerlConfigNew[realmKey][playerName] = list[oldName]
			list[oldName] = nil
			if (next(list) == nil) then
				XPerlConfigNew[oldRealm] = nil
			end
		end
	end
	XPerl_EditMode_MoveCharacter(oldRealm, oldName, realmKey, playerName)
end

local function settingspart1(self,event)
	realmKey, playerName = XPerlAPI.SettingsOwner()
	self:UnregisterEvent(event)

	if (not XPerlConfigNew) then
		if (XPerlConfig_Global or XPerlConfig) then
			XPerl_pcall(ImportOldConfigs)
		else
			XPerlConfigNew = {}
		end
	end

	if (XPerlAPI.isForever) then
		MoveServerKeyedSettings()
	end

	-- Variable checking only occurs for new install and version number change. Runs on the stored slots,
	-- before XPerl_EditMode_AttachConfig moves the old position data into the Edit Mode store.
	if (not XPerlConfigNew.ConfigVersion or XPerlConfigNew.ConfigVersion ~= XPerl_VersionNumber) then
		XPerl_pcall(XPerl_Options_UpgradeSettings)
		XPerlConfigNew.ConfigVersion = XPerl_VersionNumber
	end

	-- One-shot setup code; nothing calls these after the settings are in place
	ImportOldConfigs = nil
	XPerl_Options_ImportOldConfig = nil
	XPerl_Options_UpgradeSettings = nil

	-- Also validates the settings (XPerl_ValidateSettings)
	GiveConfig()
end
	


local function startupCheckSettings(self,event)


	XPerl_Init()
	XPerl_EditMode_OnLogin()
	XPerl_BlizzFrameDisable = nil
	XPerl_RegisterLDB()

	lastConfigMode = XPerlConfigSavePerCharacter
end

-- XPerl_Globals_OnEvent
function XPerl_Globals_OnEvent(self, event, arg1, ...)

	--if (event == "VARIABLES_LOADED") then
	if (event == "ADDON_LOADED" and arg1 == addonName) then
		self:UnregisterEvent(event)
		settingspart1(self,event)
		-- Tell DHUD to hide Blizzard default Player and Target frames
		if (type(DHUD_Config) == "table") then
			if (XPerl_Player) then
				DHUD_Config["bplayer"] = 0
			end
			if (XPerl_Target) then
				DHUD_Config["btarget"] = 0
			end
		end

--	elseif (event == "ADDON_LOADED") then
--		if (arg1 == "Blizzard_GuildUI") then
--			hooksecurefunc("GuildRoster_Update", XPerl_GuildRoster_Update)
--		end

	elseif (event == "PLAYER_LOGIN") then
		self:UnregisterEvent(event)
		startupCheckSettings(self,event)
		XPerl_MinimapButton_Init(XPerl_MinimapButton_Frame)

	elseif (event == "PLAYER_ENTERING_WORLD") then
		self:UnregisterEvent(event)
		self:UnregisterAllEvents();
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		self:SetScript("OnEvent", onEventPostSetup)
		XPerl_Globals_OnEvent = nil
	end
end

-- XPerl_SetMyGlobal
function XPerl_SetMyGlobal()
	local realm = realmKey

	if (not lastConfigMode and XPerlConfigSavePerCharacter) then
		if (not XPerlConfigNew[realm]) then
			XPerlConfigNew[realm] = {}
		end
		if (XPerlConfigNew.global) then
			XPerlConfigNew[realm][playerName] = XPerl_CopyTable(XPerlConfigNew.global)
		else
			XPerlConfigNew[realm][playerName] = {}
			XPerl_Options_Defaults(XPerlConfigNew[realm][playerName])
		end

	elseif (lastConfigMode and not XPerlConfigSavePerCharacter) then
		if (XPerlConfigNew[realm] and XPerlConfigNew[realm][playerName]) then
			XPerlConfigNew.global = XPerl_CopyTable(XPerlConfigNew[realm][playerName])
		else
			XPerlConfigNew.global = {}
			XPerl_Options_Defaults(XPerlConfigNew.global)
		end
	end

	lastConfigMode = XPerlConfigSavePerCharacter

	GiveConfig()
end

-- XPerl_ValidateSettings()
-- Runs whenever a settings slot is selected (GiveConfig) and after the one-time move of frame settings out of
-- the Edit Mode layouts (XPerl_EditMode.lua), before the XPerl_RequestConfig callbacks.
function XPerl_ValidateSettings()

	local function validate(set)
		if (set) then
			if (not set.buffs) then
				set.buffs = {enable = 1, size = 20, maxrows = 2}
			else
				if (not set.buffs.size) then
					set.buffs.size = 20
				end
				if (not set.buffs.maxrows) then
					set.buffs.maxrows = 2
				end
			end
			if (not set.debuffs) then
				set.debuffs = {enable = 1, size = 20}
			elseif (not set.debuffs.size) then
				set.debuffs.size = set.buffs.size
			end

			if (not set.healerMode) then
				set.healerMode = {type = 1}
			end
			if (not set.size) then
				set.size = {width = 0}
			end
		end
	end

	-- Boss and arena sections from before those frames existed hold no more than their enable flag; they get
	-- every missing default (a section with its size table is complete: the options keep "off" flags as nil)
	for _, key in ipairs({"boss", "arena"}) do
		local set = conf[key]
		if (not set or not set.size) then
			set = set or {}
			for k, v in pairs(XPerl_Options_FrameDefaults(key)) do
				if (set[k] == nil) then
					set[k] = v
				end
			end
			conf[key] = set
		end
	end

	local list = {"player", "pet", "party", "partypet", "target", "focus", "targettarget", "targettargettarget", "focustarget", "pettarget", "raid", "boss", "arena"}

	for k,v in pairs(list) do
		validate(conf[v])
	end

	if (not conf.pet) then
		conf.pet = {enable = 1}
	end
	if (not conf.pet.castBar) then
		conf.pet.castBar = {enable = 1}
	end

	-- Frame enable flags that older settings don't have yet; a disabled type stores false, so only a
	-- missing flag becomes 1 (the other types' flags already existed, with nil meaning off)
	for _, key in ipairs({"player", "pet", "party", "boss", "arena"}) do
		if (not conf[key]) then
			conf[key] = {}
		end
		if (conf[key].enable == nil) then
			conf[key].enable = 1
		end
	end

	-- Settings from before heal prediction get it switched on; switching it off stores false
	for _, key in ipairs({"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "raid", "raidpet", "boss", "arena"}) do
		local set = conf[key]
		if (set and set.healPrediction == nil) then
			set.healPrediction = 1
		end
	end

	-- The player frame's targeting counter came back on by default; switching it off stores false
	if (conf.player) then
		if (conf.player.targetCounter == nil) then
			conf.player.targetCounter = 1
		end
		if (conf.player.targetCounterHealers == nil) then
			conf.player.targetCounterHealers = 1
		end
		-- The aggro warning came back on by default; its table marks settings that have it, so switching it
		-- off (enable = nil) stays off
		if (type(conf.player.aggroWarning) ~= "table") then
			conf.player.aggroWarning = {enable = 1}
		end
	end

	-- The target frame's assist counter came back on by default; switching it off stores false
	if (conf.target and conf.target.assistCounter == nil) then
		conf.target.assistCounter = 1
	end

	-- The target's combo points got a switch of their own, on for settings from before it; switching it off
	-- stores false
	if (conf.target and conf.target.combo and conf.target.combo.show == nil) then
		conf.target.combo.show = 1
	end

	-- The debuff status highlight came back, on by default with "Only Curable"; switching either off stores false
	local highlight = conf.highlight
	if (highlight) then
		if (highlight.DEBUFF == nil) then
			highlight.DEBUFF = 1
		end
		if (highlight.curable == nil) then
			highlight.curable = 1
		end
	end

	-- Status icon spots that older settings don't have come from the defaults; the alternate raid icon
	-- placement they replace goes
	local function completeIcons(set, section)
		if (type(set.icons) ~= "table") then
			set.icons = {}
		end
		for key, spot in pairs(XPerl_DefaultStatusIcons(section)) do
			if (set.icons[key] == nil) then
				set.icons[key] = spot
			end
		end
	end
	for _, key in ipairs(XPerl_StatusIconSections) do
		local set = conf[key]
		if (set) then
			completeIcons(set, key)
			set.raidIconAlternate = nil
		end
	end
	if (conf.party and type(conf.party.target) == "table") then
		completeIcons(conf.party.target, "partytarget")
	end

	-- The party frames' raid target icon moved from the top left, where it covered the role icon, to the right
	-- end of the name bar. Settings from before hold the old default and follow once; the mark keeps a later
	-- choice of the top left.
	local party = conf.party
	if (party and not party.raidTargetMoved) then
		party.raidTargetMoved = 1
		if (party.icons.raidTarget == "TOPLEFT") then
			party.icons.raidTarget = "RIGHT"
		end
	end

	-- Raid role sorting was stored as 0 (3.7.1), on for Lua but off for anything comparing with 1
	if (conf.raid and conf.raid.sortByRole == 0) then
		conf.raid.sortByRole = 1
	end

	if (conf.colour and not conf.colour.gradient) then
		conf.colour.gradient = {
			enable	= 1,
			s	= {r = 0.25, g = 0.25, b = 0.25, a = 1},
			e	= {r = 0.1, g = 0.1, b = 0.1, a = 0}
		}
	end

	conf.custom = nil		-- settings of the removed custom highlight module
	conf.highlightDebuffs = nil	-- the old debuff highlighting's settings (now conf.highlight.DEBUFF)
	conf.buffHelper = nil		-- removed tooltip buff helper
end
