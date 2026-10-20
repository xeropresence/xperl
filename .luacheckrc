-- luacheck configuration for X-Perl UnitFrames.
--
-- Run with:  luacheck .
--
-- The add-on predates module scoping, so almost every entry point is a true
-- global named XPerl_* / XPERL_*. Those are intentional and are filtered out
-- below rather than being annotated one by one in 80-odd files.

std = "lua51"
max_line_length = false
codes = true
cache = true

-- Generated art, translation blobs and vendored libraries: nothing to lint,
-- and the big option locale tables blow the line/complexity limits for no
-- benefit.
exclude_files = {
	".release/",
	"Libs/",
	"**/localization*.lua",
	"**/Localization*.lua",
}

ignore = {
	"11./^XPerl.*",  -- add-on entry points are deliberate globals
	"11./^XPERL.*",  -- localisation + constant tables, likewise
	"212/self",      -- widget handlers get self whether they use it or not
	"213",           -- unused loop variables are common in roster scans
	"542",           -- empty if branches are used as explicit no-ops
}

-- Globals the add-on itself owns.
globals = {
	"XPerlConfig", "XPerlConfig_Global", "XPerlConfigNew", "XPerlConfigSavePerCharacter",
	"XPerlColourTable", "XPerlUsageNameList",
	-- Shared client tables the add-on registers into or moves (Blizzard and click-cast add-ons read them)
	"ClickCastFrames", "SlashCmdList", "SLASH_XPERL1", "TotemFrame",
	-- Key binding labels (set by the localization files, read back by the minimap menu)
	"BINDING_NAME_TOGGLEBUFFCASTABLE", "BINDING_NAME_TOGGLEBUFFTYPE",
	-- Other add-ons' settings X-Perl switches off when both are loaded
	"DHUD_Config", "HealBot_Options_EnablePlayerFrame", "myAddOnsList",
}

-- Client API surface actually referenced by this add-on, checked against the
-- live 12.0 global table (plus the C_* namespaces the port is moving to).
-- Anything missing from here that the client no longer exports is a porting
-- bug, not a lint nit.
read_globals = {
	"AbbreviateNumbers", "Ambiguate", "AnchorUtil", "AuraContainerItemEnchantmentSlot", "AuraUtil", "BackdropTemplateMixin",
	"CLASS_ICON_TCOORDS", "C_AddOns", "C_CVar", "C_EditMode",
	"C_ChatInfo", "C_CurveUtil", "C_DurationUtil", "C_EncodingUtil", "C_EventUtils", "C_FriendList", "C_Item", "C_PaperDollInfo",
	"C_PartyInfo", "C_Reputation", "C_Secrets", "C_SpecializationInfo", "C_Spell", "C_SpellBook", "C_StringUtil", "C_Timer", "C_XMLUtil",
	"C_UnitAuras", "CanInspect", "CheckInteractDistance", "ClearCursor", "ClearFocus",
	"CloseMenus", "CombatFeedback_Initialize", "CombatFeedback_OnCombatEvent", "CombatFeedback_OnUpdate",
	"CooldownFrame_Set", "CopyTable",
	"CreateColor", "CreateFrame", "DEFAULT_CHAT_FRAME", "Enum",
	"FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
	"FauxScrollFrame_Update", "GameTooltip_Hide", "GameTooltip_SetDefaultAnchor", "GetAddOnCPUUsage",
	"GetAddOnMemoryUsage", "GetBuildInfo", "GetCVarBool",
	"GetComboPoints", "GetCreatureDifficultyColor", "GetCursorInfo", "GetCursorPosition",
	"GetGuildInfo", "GetGuildRosterInfo", "GetGuildRosterSelection", "GROUP",
	"GetInventoryItemBroken", "GetInventoryItemTexture", "GetLocale", "GetMouseFoci",
	"GetNetStats", "GetNumGroupMembers", "GetNumGuildMembers", "GetNumSpecializations", "GetNumSubgroupMembers",
	"GetPVPTimer", "GetQuestDifficultyColor", "GetRaidRosterInfo", "GetRaidTargetIndex",
	"GetReadyCheckStatus", "GetRealZoneText", "GetRealmName", "GetRuneCooldown",
	"GetShapeshiftFormID", "GetSpecializationInfoByID", "GetText", "GetTime",
	"GetUnitPowerBarInfo", "GetXPExhaustion", "HideDropDownMenu",
	"HybridScrollFrame_GetOffset", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND", "InCombatLockdown", "IsAltKeyDown",
	"IsControlKeyDown", "IsInGroup", "IsInGuild", "IsInInstance", "IsInRaid", "IsPVPTimerRunning",
	"IsResting", "IsShiftKeyDown", "LAYOUT_STYLE_CLASSIC", "LAYOUT_STYLE_GAMEPAD", "LAYOUT_STYLE_MODERN", "LibStub", "Mixin", "NotifyInspect", "PlaySound", "RegisterAttributeDriver",
	"RegisterUnitWatch", "ReloadUI", "RunScript", "SOUNDKIT", "SecondsToTime", "SecureActionButton_OnClick",
	"SecureButton_GetUnit", "SecureUnitButton_OnLoad", "SetCursor",
	"SetPortraitTexture", "SetRaidTargetIconTexture", "SpellCanTargetUnit",
	"SpellIsTargeting", "ToggleDropDownMenu", "TooltipDataProcessor", "UIDropDownMenu_AddButton",
	"UIDropDownMenu_CreateInfo", "UIDropDownMenu_GetSelectedID", "UIDropDownMenu_Initialize",
	"UIDropDownMenu_SetSelectedID", "UIDropDownMenu_SetWidth",
	"UnitAffectingCombat", "UnitBattlePetType",
	"UnitCanAssist", "UnitCanAttack", "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitClassBase",
	"UnitClassification", "UnitCreatureType", "UnitDetailedThreatSituation", "UnitExists", "UnitFactionGroup",
	"UnitCastingDuration", "UnitChannelDuration", "UnitEmpoweredChannelDuration",
	"UnitFullName", "UnitGUID", "UnitGetDetailedHealPrediction", "UnitGetIncomingHeals", "UnitGroupRolesAssigned",
	"UnitHasVehicleUI", "CreateUnitHealPredictionCalculator",
	"UnitHealth", "UnitHealthMax", "UnitHealthMissing", "UnitHealthPercent", "UnitInParty", "UnitInRaid",
	"UnitInRange", "UnitInVehicle", "UnitIsAFK", "UnitIsBattlePetCompanion", "UnitIsCharmed", "UnitIsConnected",
	"UnitIsDND", "UnitIsDead", "UnitIsDeadOrGhost", "UnitIsEnemy", "UnitIsFeignDeath", "UnitIsFriend",
	"UnitIsGhost", "UnitIsGroupAssistant", "UnitIsGroupLeader", "UnitIsPVP", "UnitIsPVPFreeForAll",
	"UnitIsPlayer", "UnitIsTapDenied", "UnitIsUnit", "UnitIsVisible", "UnitIsWildBattlePet", "UnitLevel",
	"UnitName", "UnitOnTaxi", "UnitPhaseReason", "UnitPlayerControlled", "UnitPlayerOrPetInParty",
	"UnitPlayerOrPetInRaid", "UnitPopup_OpenMenu", "UnitPower", "UnitPowerMax", "UnitPowerPercent",
	"UnitPowerType", "UnitRace", "UnitReaction", "UnitUsingVehicle", "UnitXP", "UnitXPMax",
	"UnregisterUnitWatch", "UpdateAddOnCPUUsage", "UpdateAddOnMemoryUsage", "abs", "atan2", "ceil", "cos", "date",
	"debugstack", "deg", "floor", "format", "geterrorhandler", "getn", "gmatch", "gsub",
	"hooksecurefunc", "issecretvalue", "issecure", "log", "max", "min", "mod", "random", "securecall",
	"sin", "sort", "strfind", "strjoin", "strlen", "strlower", "strmatch", "strsplit", "strsub",
	"strtrim", "strupper", "time", "tinsert", "tremove", "wipe",
	-- XPerl_Highlight.lua (checked against the 12.1 API documentation / FrameXML)
	"C_EventUtils", "GameTooltip", "UIParent", "UnitThreatSituation",
	-- Units/Pet.lua
	"GameFontNormalSmall", "UNKNOWN",
	"FOM_FeedButton", "Set_FOM_FeedButton",	-- Feed-O-Matic (optional)
	-- Units/Party.lua
	"GameFontNormal", "PARTY",
	-- Units/Boss.lua, Units/Arena.lua (checked against the 12.1 FrameXML / API documentation)
	"Boss1TargetFrame", "BossTargetFrameContainer", "CompactArenaFrame", "CompactArenaFrame_Generate",
	"CreateFromMixins", "C_PvP", "GetArenaOpponentSpec", "GetNumArenaOpponentSpecs", "UnitFrameUtil",
	-- Units/Raid.lua, Units/RaidPets.lua (checked against the 12.1 FrameXML / API documentation)
	"ALL", "CompactRaidFrameContainer", "CompactUnitFrameProfiles", "CT_RA_VersionNumber", "DURABILITY_TEMPLATE",
	"GetUnitName", "HIGHLIGHT_FONT_COLOR", "LOCALIZED_CLASS_NAMES_MALE", "NONE", "NORMAL_FONT_COLOR",
	"PERCENT_SYMBOL", "PETS", "RAID",
	-- FrameXML frames and tables (12.1 FrameXML) and GlobalStrings
	"BuffFrame", "CHAT_MSG_AFK", "CLOSE",
	"ChatFontNormal", "ChatFrame2", "ComboFrame", "DebuffFrame", "DropDownList1", "FACTION_BAR_COLORS", "FAILED",
	"GRAY_FONT_COLOR", "Minimap", "PET_TYPE_SUFFIX", "PartyFrame", "PetFrame", "PlayerCastingBarFrame", "PlayerFrame",
	"PowerBarColor", "RAID_CLASS_COLORS", "RAID_TARGET_ICON", "READY_CHECK_NOT_READY_TEXTURE",
	"READY_CHECK_READY_TEXTURE", "READY_CHECK_WAITING_TEXTURE", "RuneFrame", "SPELL_FAILED_INTERRUPTED",
	"UIDROPDOWNMENU_MENU_VALUE", "UIDROPDOWNMENU_OPEN_MENU", "UISpecialFrames", "WarlockPowerFrame",
	-- Other add-ons X-Perl integrates with when they are loaded
	"BCastBar", "BCastBarDragButton", "BCastingBar", "CT_PartyBuffFrame1", "CT_PartyBuffFrame2",
	"CT_PartyBuffFrame3", "CT_PartyBuffFrame4", "CT_PetBuffFrame", "CT_RAGroup1", "CT_RAMTGroup", "CT_RAMTTGroup",
	"CT_RAPTGroup", "CT_RAPTTGroup", "CT_RegisterMod", "CUSTOM_CLASS_COLORS", "EarthFeature_AddButton",
	"MYADDONS_CATEGORY_OTHERS", "eCastingBar_Player", "eCastingBar_Saved", "myAddOnsFrame",
}
