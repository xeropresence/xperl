-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

--Russian localization file
--Translated by StingerSoft
if (GetLocale() == "ruRU") then

XPERL_RAID_GROUP				= "Группа %d"
XPERL_RAID_TOOLTIP_NOCTRA		= "CTRA не найден"
XPERL_RAID_TOOLTIP_OFFLINE		= "В не сети: %s"
XPERL_RAID_TOOLTIP_AFK			= "Отсутствует: %s"
XPERL_RAID_TOOLTIP_DND			= "Не беспокоить: %s"
XPERL_RAID_TOOLTIP_DYING		= "Мёртв: %s"
XPERL_RAID_TOOLTIP_REBIRTH		= "Возрождение: %s"
XPERL_RAID_TOOLTIP_ANKH			= "Восстание из мертвых: %s"
XPERL_RAID_TOOLTIP_SOULSTONE	= "Камень души: %s"

XPERL_RAID_TOOLTIP_REMAINING	= " осталось"
XPERL_RAID_TOOLTIP_WITHBUFF		= "С баффом: (%s)"
XPERL_RAID_TOOLTIP_WITHOUTBUFF	= "Без баффа: (%s)"
XPERL_RAID_TOOLTIP_BUFFEXPIRING	= "%s: %s заканчивается через %s"	-- Name, buff name, time to expire

XPERL_RAID_DROPDOWN_SHOWPET		= "Показ питомцев"
XPERL_RAID_DROPDOWN_SHOWOWNER	= "Показ хозяинов"

XPERL_RAID_DROPDOWN_MAINTANKS	= "Главные Танки"
XPERL_RAID_DROPDOWN_SETMT		= "Установить ГТ #%d"
XPERL_RAID_DROPDOWN_REMOVEMT	= "Удалить ГТ #%d"

XPERL_RAID_RESSING				= " возраздается"
XPERL_RAID_AFK					= "Отсутствует"
XPERL_RAID_DND					= "Не беспокоить"
XPERL_RAID_AUTOPROMOTE			= "Авто-Повышать"
XPERL_RAID_RESSER_AVAIL			= "Доступно воскресителей: "

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
end