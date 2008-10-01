-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

if (CT_RA_BuffTextures) then
	XPerl_CTBuffTextures = CT_RA_BuffTextures
else
	local function spellIcon(id)
		local name, rank, icon = GetSpellInfo(id)
		if (icon) then
			return icon:sub(17)
		end
		return ""
	end

	XPerl_CTBuffTextures = {
		[CT_RA_POWERWORDFORTITUDE[1]]	= { spellIcon(25389), 30*60 },		-- Spell_Holy_WordFortitude
		[CT_RA_POWERWORDFORTITUDE[2]]	= { spellIcon(39231), 60*60 },		-- Spell_Holy_PrayerOfFortitude
		[CT_RA_MARKOFTHEWILD[1]]		= { spellIcon(39233), 30*60 },		-- Spell_Nature_Regeneration
		[CT_RA_MARKOFTHEWILD[2]]		= { spellIcon(26991), 60*60 },		-- Spell_Nature_Regeneration
		[CT_RA_ARCANEINTELLECT[1]]		= { spellIcon(39235), 30*60 },		-- Spell_Holy_MagicalSentry
		[CT_RA_ARCANEINTELLECT[2]]		= { spellIcon(27127), 60*60 },		-- Spell_Holy_ArcaneIntellect
		[CT_RA_SHADOWPROTECTION[1]]		= { spellIcon(25433), 10*60 },		-- Spell_Shadow_AntiShadow
		[CT_RA_SHADOWPROTECTION[2]]		= { spellIcon(39374), 20*60 },		-- Spell_Holy_PrayerofShadowProtection
		[CT_RA_POWERWORDSHIELD]			= { spellIcon(46193), 30 },			-- Spell_Holy_PowerWordShield
		[CT_RA_SOULSTONERESURRECTION]	= { spellIcon(27239), 30*60 },		-- Spell_Shadow_SoulGem
		[CT_RA_DIVINESPIRIT[1]]			= { spellIcon(25312), 30*60 },		-- Spell_Holy_DivineSpirit
		[CT_RA_DIVINESPIRIT[2]]			= { spellIcon(32999), 60*60 },		-- Spell_Holy_PrayerofSpirit
		[CT_RA_THORNS]					= { spellIcon(26992), 10*60 },		-- Spell_Nature_Thorns
		[CT_RA_FEARWARD]				= { spellIcon(6346), 10*60 },		-- Spell_Holy_Excorcism
		[CT_RA_BLESSINGOFMIGHT[1]]		= { spellIcon(27140), 5*60},		-- Spell_Holy_FistOfJustice
		[CT_RA_BLESSINGOFMIGHT[2]]		= { spellIcon(27141), 5*60},		-- Spell_Holy_GreaterBlessingofKings
		[CT_RA_BLESSINGOFWISDOM[1]]		= { spellIcon(27142), 5*60},		-- Spell_Holy_SealOfWisdom
		[CT_RA_BLESSINGOFWISDOM[2]]		= { spellIcon(27143), 5*60},		-- Spell_Holy_GreaterBlessingofWisdom
		[CT_RA_BLESSINGOFKINGS[1]]		= { spellIcon(20217), 5*60},		-- Spell_Magic_MageArmor
		[CT_RA_BLESSINGOFKINGS[2]]		= { spellIcon(25898), 5*60},		-- Spell_Magic_GreaterBlessingofKings
		[CT_RA_BLESSINGOFSALVATION[1]]	= { spellIcon(1038), 5*60},			-- Spell_Holy_SealOfSalvation
		[CT_RA_BLESSINGOFSALVATION[2]]	= { spellIcon(25895), 5*60},		-- Spell_Holy_GreaterBlessingofSalvation
		[CT_RA_BLESSINGOFLIGHT[1]]		= { spellIcon(27144), 5*60},		-- Spell_Holy_PrayerOfHealing02
		[CT_RA_BLESSINGOFLIGHT[2]]		= { spellIcon(27145), 5*60},		-- Spell_Holy_GreaterBlessingofLight
		[CT_RA_BLESSINGOFSANCTUARY[1]]	= { spellIcon(27168), 5*60},		-- Spell_Nature_LightningShield
		[CT_RA_BLESSINGOFSANCTUARY[2]]	= { spellIcon(27169), 5*60},		-- Spell_Holy_GreaterBlessingofSanctuary
		[CT_RA_RENEW]					= { spellIcon(47079), 15 },			-- Spell_Holy_Renew
		[CT_RA_REJUVENATION]			= { spellIcon(38657), 12 },			-- Spell_Nature_Rejuvenation
		[CT_RA_REGROWTH]				= { spellIcon(39125), 21 },			-- Spell_Nature_ResistNature
		[CT_RA_AMPLIFYMAGIC]			= { spellIcon(33946), 10*60 },		-- Spell_Holy_FlashHeal
		[CT_RA_DAMPENMAGIC]				= { spellIcon(33944), 10*60 },		-- Spell_Nature_AbolishMagic
	}
end

if (CT_RAMenu_Options and CT_RAMenu_Options.temp.BuffArray) then
	XPerl_CTBuffArray = CT_RAMenu_Options.temp.BuffArray
else
	XPerl_CTBuffArray = {
		{ show = 1, name = CT_RA_POWERWORDFORTITUDE, index = 1 },
		{ show = 1, name = CT_RA_MARKOFTHEWILD, index = 2 },
		{ show = 1, name = CT_RA_ARCANEINTELLECT, index = 3 },
		{ show = 1, name = CT_RA_SHADOWPROTECTION, index = 5 },
		{ show = 1, name = CT_RA_POWERWORDSHIELD, index = 6 },
		{ show = 1, name = CT_RA_SOULSTONERESURRECTION, index = 7 },
		{ show = 1, name = CT_RA_DIVINESPIRIT, index = 8 },
		{ show = 1, name = CT_RA_THORNS, index = 9 },
		{ show = 1, name = CT_RA_FEARWARD, index = 10 },
		{ show = 1, name = CT_RA_BLESSINGOFMIGHT, index = 11 },
		{ show = 1, name = CT_RA_BLESSINGOFWISDOM, index = 12 },
		{ show = 1, name = CT_RA_BLESSINGOFKINGS, index = 13 },
		{ show = 1, name = CT_RA_BLESSINGOFSALVATION, index = 14 },
		{ show = 1, name = CT_RA_BLESSINGOFLIGHT, index = 15 },
		{ show = 1, name = CT_RA_BLESSINGOFSANCTUARY, index = 16 },
		{ show = 1, name = CT_RA_RENEW, index = 17 },
		{ show = 1, name = CT_RA_REJUVENATION, index = 18 },
		{ show = 1, name = CT_RA_REGROWTH, index = 19 }
	}
end
