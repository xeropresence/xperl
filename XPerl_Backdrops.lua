-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

-- Backdrop definitions for frames inheriting BackdropTemplate.
-- XML frames reference these through <KeyValue key="backdropInfo" type="global"/>,
-- so this file must load before any XML that uses them.

-- Unit frame sections (name, level, portrait, stats)
XPERL_BACKDROP_FRAME = {
	bgFile = "Interface\\Addons\\XPerl\\Images\\XPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
}

-- Party level frame
XPERL_BACKDROP_PARTY_LEVEL = {
	bgFile = "Interface\\Addons\\XPerl\\Images\\XPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 8,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
}

-- Party placeholder shown while positioning
XPERL_BACKDROP_PARTY_VIRTUAL = {
	bgFile = "Interface\\AddOns\\XPerl\\images\\XPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 16,
	edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
}

-- Player raid group indicator
XPERL_BACKDROP_PLAYER_GROUP = {
	bgFile = "Interface\\Addons\\XPerl\\Images\\XPerl_FrameBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 12,
	insets = {left = 2, right = 2, top = 2, bottom = 2},
}

-- Raid and raid pet frames
XPERL_BACKDROP_RAID = {
	bgFile = "Interface\\AddOns\\XPerl\\images\\XPerl_FrameBack",
	edgeFile = "Interface\\Addons\\XPerl\\Images\\XPerl_ThinEdge",
	tile = true,
	tileEdge = true,
	tileSize = 256,
	edgeSize = 10,
	insets = {left = 2, right = 2, top = 2, bottom = 2},
}

-- Options windows
XPERL_BACKDROP_FANCY = {
	bgFile = "Interface\\AddOns\\XPerl\\XPerl_Options\\Images\\XPerl_FancyBack",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	tileSize = 256,
	edgeSize = 16,
	insets = {left = 5, right = 5, top = 5, bottom = 5},
}

-- Options page group borders
XPERL_BACKDROP_OPTIONS_AREA = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	edgeSize = 6,
}

-- List borders
XPERL_BACKDROP_LIST_BORDER = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileEdge = true,
	edgeSize = 9,
}

-- Options sliders
XPERL_BACKDROP_SLIDER = {
	bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
	edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
	tile = true,
	tileEdge = true,
	tileSize = 8,
	edgeSize = 8,
	insets = {left = 3, right = 3, top = 6, bottom = 6},
}
