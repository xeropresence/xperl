-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

if (GetLocale() == "zhCN") then

	XPERL_RAID_GROUP		= "小队 %d"
	XPERL_RAID_TOOLTIP_NOCTRA	= "没有发现CTRA"
	XPERL_RAID_TOOLTIP_OFFLINE	= "离线计时： %s"
	XPERL_RAID_TOOLTIP_AFK		= "暂离计时： %s"
	XPERL_RAID_TOOLTIP_DND		= "勿扰计时： %s"
	XPERL_RAID_TOOLTIP_DYING	= "死亡倒计时： %s"
	XPERL_RAID_TOOLTIP_REBIRTH	= "重生倒计时： %s"
	XPERL_RAID_TOOLTIP_ANKH		= "十字章失效： %s"
	XPERL_RAID_TOOLTIP_SOULSTONE	= "灵魂石失效： %s"

	XPERL_RAID_TOOLTIP_REMAINING	= "后消失"
	XPERL_RAID_TOOLTIP_WITHBUFF	= "有该buff的成员： (%s)"
	XPERL_RAID_TOOLTIP_WITHOUTBUFF	= "无该buff的成员： (%s)"
	XPERL_RAID_TOOLTIP_BUFFEXPIRING	= "%s的%s将在%s后过期"	-- Name, buff name, time to expire

	XPERL_RAID_DROPDOWN_SHOWPET	= "显示宠物"
	XPERL_RAID_DROPDOWN_SHOWOWNER	= "显示主人"

	XPERL_RAID_DROPDOWN_MAINTANKS	= "主坦克"
	XPERL_RAID_DROPDOWN_SETMT	= "设置 MT #%d"
	XPERL_RAID_DROPDOWN_REMOVEMT	= "移除 MT #%d"

	XPERL_RAID_RESSING		= "正在复活"
	XPERL_RAID_AFK			= "暂离"
	XPERL_RAID_DND			= "勿扰"
	XPERL_RAID_AUTOPROMOTE		= "自动提升"
	XPERL_RAID_RESSER_AVAIL		= "可以复活者: "	
	
	--[[if (not CT_RA_POWERWORDFORTITUDE) then

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
	end]]
end
