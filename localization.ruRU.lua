-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

if (GetLocale() == "ruRU") then

XPerl_ProductName	    = "|cFFD00000X-Perl|r Фреймы Игроков"
XPerl_Description	    = XPerl_ProductName.." by "..XPerl_Author
XPerl_Version		    = XPerl_Description.." - "..XPerl_VersionNumber
XPerl_LongDescription	= "Фреймы Игроков заменяются на новый вид Игроков, Питомцев, Группы, Цели, Целей Цели, Фокуса, Рейда"

XPERL_MINIMAP_HELP1     = "|c00FFFFFFЛевый Клик|r для Опций  (и также |c0000FF00для перемещения фреймов|r)"
XPERL_MINIMAP_HELP2     = "|c00FFFFFFПравый клик|r двигать иконку"
XPERL_MINIMAP_HELP3     = "\rУчастники рейда: |c00FFFF80%d|r\rУчастники рейда: |c00FFFF80%d|r"
XPERL_MINIMAP_HELP4     = "\rВы лидер группы/рейда"
XPERL_MINIMAP_HELP5     = "|c00FFFFFFAlt|r для просмотра потребления памяти X-Perl'ом"
XPERL_MINIMAP_HELP6     = "|c00FFFFFF+Shift|r для просмотра потребления памяти X-Perl'ом после запуска"

XPERL_MINIMENU_OPTIONS	= "Опции"
XPERL_MINIMENU_ASSIST	= "Показ Фрейма Поддержки"
XPERL_MINIMENU_CASTMON	= "Показ Монитора каста"
XPERL_MINIMENU_RAIDAD	= "Показ Рейд Админа"
XPERL_MINIMENU_ITEMCHK	= "Показ проверку вещей"
XPERL_MINIMENU_RAIDBUFF = "Баффы Рейда"
XPERL_MINIMENU_ROSTERTEXT="Текст Список"
XPERL_MINIMENU_RAIDSORT = "сортировка рейда"
XPERL_MINIMENU_RAIDSORT_GROUP = "Сортировать по группам"
XPERL_MINIMENU_RAIDSORT_CLASS = "Сортировать по классам"

-- Class name localization is not too important. The only time these strings
-- are used is when the raid frame titles need to be shown when in class sort
-- mode AND when no players of that class have been seen. X-Perl builds an
-- internal list of WoW localised class names as they are encountered. The WoW
-- api function UnitClass returns both the localized and english class name.
XPERL_LOC_CLASS_WARRIOR = "Warrior"
XPERL_LOC_CLASS_MAGE	= "Mage"
XPERL_LOC_CLASS_ROGUE	= "Rogue"
XPERL_LOC_CLASS_DRUID	= "Druid"
XPERL_LOC_CLASS_HUNTER	= "Hunter"
XPERL_LOC_CLASS_SHAMAN	= "Shaman"
XPERL_LOC_CLASS_PRIEST	= "Priest"
XPERL_LOC_CLASS_WARLOCK = "Warlock"
XPERL_LOC_CLASS_PALADIN = "Paladin"
XPERL_LOC_CLASS_PETS	= "Pets"
XPERL_TYPE_NOT_SPECIFIED = "Not specified"
XPERL_TYPE_PET	    	= PET			-- "Pet"
XPERL_TYPE_BOSS 	    = "Boss"
XPERL_TYPE_RAREPLUS     = "Rare+"
XPERL_TYPE_ELITE	    = "Elite"
XPERL_TYPE_RARE 	    = "Rare"

-- Status
XPERL_LOC_DEAD		    = DEAD			-- "Dead"
XPERL_LOC_GHOST 	    = "Дух"
XPERL_LOC_FEIGNDEATH	= "Притворяется мертвым"
XPERL_LOC_OFFLINE	    = PLAYER_OFFLINE	-- "Офлайн"
XPERL_LOC_RESURRECTED	= "Воскрешаемый"
XPERL_LOC_SS_AVAILABLE	= "SS доступен"
XPERL_LOC_UPDATING    	= "Обновляется"
XPERL_LOC_ACCEPTEDRES	= "Принято"		-- Res accepted
XPERL_RAID_GROUP	    = "Группа %d"
XPERL_RAID_GROUPSHORT	= "Г%d"

XPERL_LOC_NONEWATCHED	= "не наблюдался"

XPERL_LOC_STATUSTIP = "Статус подсвечивания: " 	-- Tooltip explanation of status highlight on unit
XPERL_LOC_STATUSTIPLIST = {
	HOT = "Исцеления за Время",
	AGGRO = "Аггро",
	MISSING = "Отсутствие классового' баффа",
	HEAL = "Излечен",
	SHIELD = "Защищенный"
}

XPERL_OK		= "OK"
XPERL_CANCEL		= "Отмена"

XPERL_LOC_LARGENUMDIV	= 1000
XPERL_LOC_LARGENUMTAG	= "K"

BINDING_HEADER_XPERL = XPerl_ProductName
BINDING_NAME_TOGGLERAID = "Окна рейда"
BINDING_NAME_TOGGLERAIDSORT = "Сорт рейда по классам/группам"
BINDING_NAME_TOGGLERAIDPETS = "Питомцы рейда"
BINDING_NAME_TOGGLEOPTIONS = "Окно опций"
BINDING_NAME_TOGGLEBUFFTYPE = "Баффы/Дебаффы/пусто"
BINDING_NAME_TOGGLEBUFFCASTABLE = "Касты/Лечение"
BINDING_NAME_TEAMSPEAKMONITOR = "Монитор Teamspeak'a"
BINDING_NAME_TOGGLERANGEFINDER = "Определитель досягаемости"

XPERL_KEY_NOTICE_RAID_BUFFANY = "Показ всех баффов/дебаффов"
XPERL_KEY_NOTICE_RAID_BUFFCURECAST = "Показ только кастуемые/излечивающие баффы или дебаффы"
XPERL_KEY_NOTICE_RAID_BUFFS = "Показ баффов рейда"
XPERL_KEY_NOTICE_RAID_DEBUFFS = "Показ дебаффов рейда"
XPERL_KEY_NOTICE_RAID_NOBUFFS = "Не показ баффов рейда"

XPERL_DRAGHINT1		= "|c00FFFFFFКлик|r для масштабирования окна"
XPERL_DRAGHINT2		= "|c00FFFFFFShift+Клик|r для изменения размера окна"

-- Usage
XPerlUsageNameList	= {XPerl = "Core", XPerl_Player = "Player", XPerl_PlayerPet = "Pet", XPerl_Target = "Target", XPerl_TargetTarget = "Target's Target", XPerl_Party = "Party", XPerl_PartyPet = "Party Pets", XPerl_RaidFrames = "Raid Frames", XPerl_RaidHelper = "Raid Helper", XPerl_RaidAdmin = "Raid Admin", XPerl_TeamSpeak = "TS Monitor", XPerl_RaidMonitor = "Raid Monitor", XPerl_RaidPets = "Raid Pets", XPerl_ArcaneBar = "Arcane Bar", XPerl_PlayerBuffs = "Player Buffs", XPerl_GrimReaper = "Grim Reaper"}
XPERL_USAGE_MEMMAX	= "UI Макс Пам: %d"
XPERL_USAGE_MODULES = "Модули: "
XPERL_USAGE_NEWVERSION	= "*Новейшая версия"
XPERL_USAGE_AVAILABLE	= "%s |c00FFFFFF%s|r доступно для скачивания"

XPERL_CMD_HELP		= "|c00FFFF80Usage: |c00FFFFFF/xperl menu | lock | unlock | config list | config delete <realm> <name>"
XPERL_CANNOT_DELETE_CURRENT = "Невозможна удалить ваши текущие настройки"
XPERL_CONFIG_DELETED		= "Настройки для %s/%s удалены"
XPERL_CANNOT_FIND_DELETE_TARGET = "Нету настроек для удаления (%s/%s)"
XPERL_CANNOT_DELETE_BADARGS = "Введите реалм и ник игрока"
XPERL_CONFIG_LIST		= "Список настроек:"
XPERL_CONFIG_CURRENT		= " (текущий)"

end

XPERL_LOC_CLASS_PETSHUNTER	= XPERL_LOC_CLASS_HUNTER.." "..XPERL_LOC_CLASS_PETS
XPERL_LOC_CLASS_PETSWARLOCK = XPERL_LOC_CLASS_WARLOCK.." "..XPERL_LOC_CLASS_PETS
