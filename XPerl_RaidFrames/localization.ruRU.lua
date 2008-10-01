-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

if (GetLocale() == "ruRU") then
	
XPERL_RAID_GROUP		= "Группа %d"
XPERL_RAID_TOOLTIP_NOCTRA	= "CTRA не найден"
XPERL_RAID_TOOLTIP_OFFLINE	= "в не сети %s"
XPERL_RAID_TOOLTIP_AFK		= "AFK %s"
XPERL_RAID_TOOLTIP_DND		= "DND %s"
XPERL_RAID_TOOLTIP_DYING	= "Мёртв %s"
XPERL_RAID_TOOLTIP_REBIRTH	= "Возрождаются : %s"
XPERL_RAID_TOOLTIP_ANKH		= "Заголовки : %s"
XPERL_RAID_TOOLTIP_SOULSTONE	= "Соулкамень : %s"

XPERL_RAID_TOOLTIP_REMAINING	= " осталось"
XPERL_RAID_TOOLTIP_WITHBUFF	= "С баффом: (%s)"
XPERL_RAID_TOOLTIP_WITHOUTBUFF	= "Без баффа: (%s)"
XPERL_RAID_TOOLTIP_BUFFEXPIRING	= "%s's %s заканчивается через %s"	-- Name, buff name, time to expire

XPERL_RAID_DROPDOWN_SHOWPET	= "Показ петов"
XPERL_RAID_DROPDOWN_SHOWOWNER	= "Показ хозяинов"

XPERL_RAID_DROPDOWN_MAINTANKS	= "Основное Танки"
XPERL_RAID_DROPDOWN_SETMT	= "Установить MT #%d"
XPERL_RAID_DROPDOWN_REMOVEMT	= "Удалить MT #%d"

XPERL_RAID_RESSING		= " возраздается"
XPERL_RAID_AFK			= "AFK"
XPERL_RAID_DND			= "DND"
XPERL_RAID_AUTOPROMOTE		= "Авто-Повышать"
XPERL_RAID_RESSER_AVAIL		= "Доступно воскресителей: "

if (not CT_RA_POWERWORDFORTITUDE) then

	CT_RA_POWERWORDFORTITUDE	= { (GetSpellInfo(25389)), (GetSpellInfo(39231)) }		-- Power Word: Fortitude, Prayer of Fortitude
	CT_RA_MARKOFTHEWILD			= { (GetSpellInfo(39233)), (GetSpellInfo(26991)) }		-- Mark of the Wild, Gift of the Wild
	CT_RA_ARCANEINTELLECT		= { (GetSpellInfo(39235)), (GetSpellInfo(27127)) }		-- Arcane Intellect, Arcane Brilliance
	CT_RA_ADMIRALSHAT			= GetSpellInfo(12022)									-- Admiral's Hat
	CT_RA_POWERWORDSHIELD		= GetSpellInfo(46193)									-- Power Word: Shield
	CT_RA_SOULSTONERESURRECTION	= GetSpellInfo(27239)									-- Soulstone Resurrection
	CT_RA_DIVINESPIRIT			= { (GetSpellInfo(25312)), (GetSpellInfo(32999)) }		-- Divine Spirit, Prayer of Spirit
	CT_RA_THORNS				= GetSpellInfo(26992)									-- Thorns
	CT_RA_FEARWARD				= GetSpellInfo(6346)									-- Fear Ward
	CT_RA_SHADOWPROTECTION		= { (GetSpellInfo(25433)), (GetSpellInfo(39374)) }		-- Shadow Protection, Prayer of Shadow Protection
	CT_RA_BLESSINGOFMIGHT		= { (GetSpellInfo(27140)), (GetSpellInfo(27141)) }		-- Blessing of Might, Greater Blessing of Might
	CT_RA_BLESSINGOFWISDOM		= { (GetSpellInfo(27142)), (GetSpellInfo(27143)) }		-- Blessing of Wisdom, Greater Blessing of Wisdom
	CT_RA_BLESSINGOFKINGS		= { (GetSpellInfo(20217)), (GetSpellInfo(25898)) }		-- Blessing of Kings, Greater Blessing of Kings
	CT_RA_BLESSINGOFSALVATION	= { (GetSpellInfo(1038)), (GetSpellInfo(25895)) }		-- Blessing of Salvation, Greater Blessing of Salvation
	CT_RA_BLESSINGOFLIGHT		= { (GetSpellInfo(27144)), (GetSpellInfo(27145)) }		-- Blessing of Light, Greater Blessing of Light
	CT_RA_BLESSINGOFSANCTUARY	= { (GetSpellInfo(27168)), (GetSpellInfo(27169)) }		-- Blessing of Sanctuary, Greater Blessing of Sanctuary
	CT_RA_RENEW					= GetSpellInfo(47079)									-- Renew
	CT_RA_REGROWTH				= GetSpellInfo(39125)									-- Regrwth
	CT_RA_REJUVENATION			= GetSpellInfo(38657)									-- Rejuvenation
	CT_RA_FEIGNDEATH			= { ["en"] = GetSpellInfo(5384) }						-- Feign Death
	CT_RA_FIRESHIELD			= GetSpellInfo(27489)									-- Fire Shield
	CT_RA_DAMPENMAGIC			= GetSpellInfo(33946)									-- Dampen Magic
	CT_RA_AMPLIFYMAGIC			= GetSpellInfo(33944)									-- Amplify Magic
end

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

end
