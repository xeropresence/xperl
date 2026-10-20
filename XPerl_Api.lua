-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Client API adapters and client identification.
--
-- The 12.0 engine moved most of the flat global API into C_* namespaces and
-- deleted the old spellings. Straight renames are done at the call site - a
-- rename is not worth an indirection. This file exists for the calls whose
-- *shape* changed, so the add-on unpacks the new layout in one place instead
-- of in forty files, and for the one question several modules need answered:
-- which game are we running in.

XPerlAPI = {}
local API = XPerlAPI

local C_AddOns = C_AddOns

------------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------------

-- WoW: Forever (codename Camelot) is a Classic+ game on the 12.0 engine,
-- shipped as its own product next to Mainline and Classic. It numbers its
-- patches 1.60.x and reports interface 16001 for 1.60.1, which keeps it clear
-- of Classic Era (115xx) and Mainline (12xxxx). Code that has to care asks
-- API.isForever instead of sniffing for frames or functions.
local clientVersion, clientBuild, _, interfaceVersion = GetBuildInfo()

API.clientVersion = clientVersion
API.clientBuild = clientBuild
API.interfaceVersion = interfaceVersion
API.isForever = interfaceVersion >= 16000 and interfaceVersion < 20000
API.flavor = API.isForever and "Camelot" or "Mainline"
API.flavorName = API.isForever and "WoW: Forever" or "Retail"

------------------------------------------------------------------------------
-- Add-on manager
------------------------------------------------------------------------------

-- C_AddOns.GetAddOnInfo dropped the enabled flag that used to sit in slot 4;
-- enable state is its own call now and answers with Enum.AddOnEnableState
-- (None = 0, Some = 1, All = 2). Compared numerically so this still works if
-- the enum table is not populated yet during early load.
function API.IsAddOnEnabled(addon)
	local state = C_AddOns.GetAddOnEnableState(addon)
	return type(state) == "number" and state > 0
end

------------------------------------------------------------------------------
-- Spell names
------------------------------------------------------------------------------

local C_Spell = C_Spell

-- Buff/debuff lists are matched against aura names, so they are written as
-- spell IDs and translated to the client's localised names at load. The
-- Classic+ spell database lacks many later-expansion IDs; C_Spell.GetSpellName
-- returns nil for those, so unknown IDs are skipped instead of becoming a nil
-- table key that aborts the whole file.
function API.SpellNameMap(spells)
	local map = {}
	for spellID, value in pairs(spells) do
		local name = C_Spell.GetSpellName(spellID)
		if (name) then
			map[name] = value
		end
	end
	return map
end

-- Localised spell name for display strings, or fallback when the client does
-- not know the spell.
function API.SpellName(spellID, fallback)
	return C_Spell.GetSpellName(spellID) or fallback
end

------------------------------------------------------------------------------
-- Restricted (secret) data
------------------------------------------------------------------------------

local C_UnitAuras = C_UnitAuras
local C_Secrets = C_Secrets
local issecretvalue = issecretvalue

-- While auras are restricted (e.g. in combat in instances) the client keeps some of them secret, and
-- asking for one of those from add-on code is an error ("Auras cannot be accessed when secret while
-- tainted"). These ask first. A secret aura comes back as API.SECRET_AURA, an empty table, so loops over a
-- unit's auras skip it instead of stopping there: every field (name, icon, auraInstanceID, ...) reads nil.
local SECRET_AURA = setmetatable({}, {__newindex = function() end})
API.SECRET_AURA = SECRET_AURA

local function auraIndexSecret(unit, index, filter)
	return C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret(unit, index, filter)
end

local function typedFilter(auraType, filter)
	if (filter and filter ~= "") then
		return auraType.."|"..filter
	end
	return auraType
end

function API.GetAuraDataByIndex(unit, index, filter)
	if (auraIndexSecret(unit, index, filter)) then
		return SECRET_AURA
	end
	return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
end

function API.GetBuffDataByIndex(unit, index, filter)
	if (auraIndexSecret(unit, index, typedFilter("HELPFUL", filter))) then
		return SECRET_AURA
	end
	return C_UnitAuras.GetBuffDataByIndex(unit, index, filter)
end

function API.GetDebuffDataByIndex(unit, index, filter)
	if (auraIndexSecret(unit, index, typedFilter("HARMFUL", filter))) then
		return SECRET_AURA
	end
	return C_UnitAuras.GetDebuffDataByIndex(unit, index, filter)
end

function API.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
	if (C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret(unit, auraInstanceID)) then
		return SECRET_AURA
	end
	return C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
end

-- Some unit flags come back as secret booleans in restricted situations, and add-on code can't even test
-- those. These return nil (not set) instead.
local function Plain(func)
	return function(...)
		local value = func(...)
		if (issecretvalue(value)) then
			return nil
		end
		return value
	end
end
API.UnitIsPVP = Plain(UnitIsPVP)
API.UnitIsAFK = Plain(UnitIsAFK)
API.UnitIsDND = Plain(UnitIsDND)
