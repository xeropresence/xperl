-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

XPERL_RAID_GROUP		= "Group %d"
XPERL_RAID_TOOLTIP_NOCTRA	= "No CTRA Found"
XPERL_RAID_TOOLTIP_OFFLINE	= "Offline for %s"
XPERL_RAID_TOOLTIP_AFK		= "AFK for %s"
XPERL_RAID_TOOLTIP_DND		= "DND for %s"
XPERL_RAID_TOOLTIP_DYING	= "Dying in %s"
XPERL_RAID_TOOLTIP_REBIRTH	= "Rebirth up in: %s"
XPERL_RAID_TOOLTIP_ANKH		= "Ankh up in: %s"
XPERL_RAID_TOOLTIP_SOULSTONE	= "Soulstone up in: %s"

XPERL_RAID_TOOLTIP_REMAINING	= " remaining"
XPERL_RAID_TOOLTIP_WITHBUFF	= "With buff: (%s)"
XPERL_RAID_TOOLTIP_WITHOUTBUFF	= "Without buff: (%s)"
XPERL_RAID_TOOLTIP_BUFFEXPIRING	= "%s's %s expires in %s"	-- Name, buff name, time to expire

XPERL_RAID_DROPDOWN_SHOWPET	= "Show Pets"
XPERL_RAID_DROPDOWN_SHOWOWNER	= "Show Owners"

XPERL_RAID_DROPDOWN_MAINTANKS	= "Main Tanks"
XPERL_RAID_DROPDOWN_SETMT	= "Set MT #%d"
XPERL_RAID_DROPDOWN_REMOVEMT	= "Remove MT #%d"

XPERL_RAID_RESSING		= " ressing"
XPERL_RAID_AFK			= "AFK"
XPERL_RAID_DND			= "DND"
XPERL_RAID_AUTOPROMOTE		= "Auto-Promote"
XPERL_RAID_RESSER_AVAIL		= "Rezzers Available: "

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
