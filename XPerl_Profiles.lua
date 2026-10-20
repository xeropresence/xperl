-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Settings export / import.
--
-- Several WoW: Forever beta builds have dropped add-on SavedVariables on
-- patch day. A profile string lets people keep their setup outside the game
-- and paste it back in. The string holds the account-wide settings plus the
-- active Edit Mode layout's frame settings and frame positions, CBOR-serialised,
-- deflated and base64'd by the client's own C_EncodingUtil, behind a short
-- format tag so a future layout change can be detected instead of misread.
--
-- XPERL2: {version, flavor, config = account-wide sections, frames = frame sections
--          (XPerl_FrameConfigKeys), positions = Edit Mode layout positions}
-- XPERL1: (before Edit Mode layouts) {version, flavor, config = whole settings table,
--          positions = {[frameName] = {top, left}}}
-- An import goes into the active Edit Mode layout.

XPerl_SetModuleRevision("$Revision$")

local C_EncodingUtil = C_EncodingUtil

local FORMAT_TAG = "XPERL2:"
local OLD_FORMAT_TAG = "XPERL1:"
local SERIALIZE_OPTIONS = {ignoreSerializationErrors = true}

local function Encode()
	local config, frames = {}, {}
	for key, value in pairs(XPerlDB) do
		config[key] = value
	end
	for _, key in ipairs(XPerl_FrameConfigKeys) do
		frames[key] = config[key]
		config[key] = nil
	end

	local payload = {
		version = XPerl_VersionNumber,
		flavor = XPerlAPI.flavor,
		config = config,
		frames = frames,
		positions = XPerl_EditMode_GetPositions(),
	}
	local packed = C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(payload, SERIALIZE_OPTIONS))
	return FORMAT_TAG..C_EncodingUtil.EncodeBase64(packed)
end

-- The settings table and layout positions a payload stands for (positions nil: leave them alone)
local function Unpack(payload, old)
	if (type(payload) ~= "table" or type(payload.config) ~= "table") then
		return
	end

	local settings = XPerl_CopyTable(payload.config)
	local positions
	if (old) then
		if (type(payload.positions) == "table") then
			positions = XPerl_EditMode_ConvertLegacyPositions(payload.positions, settings)
		end
	else
		if (type(payload.frames) ~= "table") then
			return
		end
		for _, key in ipairs(XPerl_FrameConfigKeys) do
			settings[key] = XPerl_CopyTable(payload.frames[key])
		end
		if (type(payload.positions) == "table") then
			positions = payload.positions
		end
	end

	if (XPerl_IsValidConfig(settings)) then
		return settings, positions
	end
end

local function Decode(text)
	-- Pasting through chat or a forum tends to add line breaks.
	text = gsub(text or "", "%s", "")
	local old
	if (strsub(text, 1, #OLD_FORMAT_TAG) == OLD_FORMAT_TAG) then
		old = true
	elseif (strsub(text, 1, #FORMAT_TAG) ~= FORMAT_TAG) then
		return nil, XPERL_PROFILE_NOT_A_PROFILE
	end

	local ok, payload = pcall(function()
		local packed = C_EncodingUtil.DecodeBase64(strsub(text, #FORMAT_TAG + 1))
		return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(packed))
	end)
	local settings, positions
	if (ok) then
		settings, positions = Unpack(payload, old)
	end
	if (not settings) then
		return nil, XPERL_PROFILE_CORRUPT
	end
	return payload, settings, positions
end

local function Apply(settings, positions)
	XPerl_SetCurrentConfig(settings)

	if (positions) then
		XPerl_EditMode_SetPositions(positions)
	end
end

------------------------------------------------------------------------------
-- Dialog
------------------------------------------------------------------------------

local DIALOG_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileEdge = true,
	tileSize = 32,
	edgeSize = 32,
	insets = {left = 11, right = 12, top = 12, bottom = 11},
}

local dialog
local function GetDialog()
	if (dialog) then
		return dialog
	end

	local f = CreateFrame("Frame", "XPerl_ProfileDialog", UIParent, "BackdropTemplate")
	f:SetSize(460, 260)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetBackdrop(DIALOG_BACKDROP)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	tinsert(UISpecialFrames, f:GetName())		-- Escape closes it

	f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	f.title:SetPoint("TOP", 0, -18)

	local scroll = CreateFrame("ScrollFrame", "XPerl_ProfileDialogScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -42)
	scroll:SetPoint("BOTTOMRIGHT", -40, 48)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(390)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(edit)
	f.edit = edit

	f.accept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.accept:SetSize(110, 22)
	f.accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 16)

	f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.close:SetSize(110, 22)
	f.close:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 16)
	f.close:SetText(CLOSE)
	f.close:SetScript("OnClick", function() f:Hide() end)

	dialog = f
	return f
end

local function DoImport()
	local f = GetDialog()
	local payload, settings, positions = Decode(f.edit:GetText())
	if (not payload) then
		XPerl_Notice(settings)		-- the error message
		return
	end
	if (InCombatLockdown()) then
		-- Applying settings re-anchors secure unit frames.
		XPerl_Notice(XPERL_PROFILE_IN_COMBAT)
		return
	end
	if (payload.flavor and payload.flavor ~= XPerlAPI.flavor) then
		XPerl_Notice(XPERL_PROFILE_OTHER_FLAVOR, tostring(payload.flavor))
	end

	Apply(settings, positions)
	f:Hide()
	XPerl_Notice(XPERL_PROFILE_IMPORTED, tostring(payload.version or "?"), tostring(XPerl_EditMode_GetActiveLayoutName() or "?"))
end

-- XPerl_ProfileExport
function XPerl_ProfileExport()
	local f = GetDialog()
	f.title:SetText(XPERL_PROFILE_EXPORT_TITLE)
	f.edit:SetText(Encode())
	f.edit:HighlightText()
	f.edit:SetFocus()
	f.accept:Hide()
	f:Show()
end

-- XPerl_ProfileImport
function XPerl_ProfileImport()
	local f = GetDialog()
	f.title:SetText(XPERL_PROFILE_IMPORT_TITLE)
	f.edit:SetText("")
	f.edit:SetFocus()
	f.accept:SetText(XPERL_PROFILE_IMPORT_BUTTON)
	f.accept:SetScript("OnClick", DoImport)
	f.accept:Show()
	f:Show()
end
