-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- X-Perl in the game's Settings panel (Options → AddOns): a main page with the global settings and the frame
-- switches, and a page per frame type with the settings of its Edit Mode dialog. The pages are vertical lists
-- of the definitions in XPerl_EditModeSettings.lua, which is what lets the panel's search box find them.
-- Colours, bar textures, layouts and the other pickers stay in the options window, which the main page opens.

XPerl_SetModuleRevision("$Revision$")

local _, ns = ...
local SettingType = LibStub("LibEditMode").SettingType

local function FormatNumber(value)
	return format("%d", value)
end

local function FormatPercent(value)
	return format("%d%%", value)
end

local function OpenOptionsWindow()
	HideUIPanel(SettingsPanel)
	XPerl_UnlockFrames()
end

-- A scale slider's maximum follows XPerlDB.maximumScale, so it is looked up each time the slider shows
local function SliderOptions(entry)
	local options = Settings.CreateSliderOptions(entry.minValue, entry.maxValue, entry.valueStep)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, entry.percent and FormatPercent or FormatNumber)
	if (entry.scale) then
		options.maxValue, options.steps = nil, nil
		setmetatable(options, {__index = function(_, key)
			if (key == "maxValue") then
				return ns.EditModeSettings.MaxScalePercent(entry.minValue)
			elseif (key == "steps") then
				return (ns.EditModeSettings.MaxScalePercent(entry.minValue) - entry.minValue) / entry.valueStep
			end
		end})
	end
	return options
end

local function DropdownOptions(entry)
	return function()
		local container = Settings.CreateControlTextContainer()
		for _, option in ipairs(entry.values) do
			container:Add(option.value, option.text)
		end
		return container:GetData()
	end
end

-- Adds a settings list to a page. Its groups become section headings: the panel shows every row, and its search
-- lists matches under their page's name.
local function AddList(category, layout, prefix, list)
	for i, entry in ipairs(list) do
		local kind = entry.kind
		if (kind == SettingType.Expander) then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(entry.name))
		elseif (kind == "button") then
			layout:AddInitializer(CreateSettingsButtonInitializer(entry.name, entry.name, entry.func, entry.desc, true))
		else
			local varType
			if (kind == SettingType.Checkbox) then
				varType = Settings.VarType.Boolean
			elseif (kind == SettingType.Slider) then
				varType = Settings.VarType.Number
			else
				varType = type(entry.default)
			end
			local setting = Settings.RegisterProxySetting(category, prefix..i, varType, entry.name, entry.default, entry.get,
				function(value) entry.set(nil, value) end)

			if (kind == SettingType.Checkbox) then
				Settings.CreateCheckbox(category, setting, entry.desc)
			elseif (kind == SettingType.Slider) then
				Settings.CreateSlider(category, setting, SliderOptions(entry), entry.desc)
			else
				Settings.CreateDropdown(category, setting, DropdownOptions(entry), entry.desc)
			end
		end
	end
end

-- XPerl_SettingsPanel_OnLogin
-- Called once after XPerl_Init, when the settings and every localization file are loaded
function XPerl_SettingsPanel_OnLogin()
	local main, mainLayout = Settings.RegisterVerticalLayoutCategory(XPERL_SETTINGS_CATEGORY)
	mainLayout:AddInitializer(CreateSettingsButtonInitializer(XPERL_SETTINGS_OPTIONS, XPERL_SETTINGS_OPTIONS_BUTTON,
		OpenOptionsWindow, XPERL_SETTINGS_OPTIONS_DESC, true))
	AddList(main, mainLayout, "XPERL_GLOBAL_", ns.EditModeSettings.Get("global"))

	-- Pages in the order of the frame switches; party pets are on the party page
	for _, row in ipairs(XPerl_FrameToggles) do
		local key = row[1]
		local list = ns.EditModeSettings.Get(key)
		if (list) then
			local category, layout = Settings.RegisterVerticalLayoutSubcategory(main, _G[row[2]])
			AddList(category, layout, "XPERL_"..strupper(key).."_", list)
		end
	end

	Settings.RegisterAddOnCategory(main)

	XPerl_SettingsPanel_OnLogin = nil
end
