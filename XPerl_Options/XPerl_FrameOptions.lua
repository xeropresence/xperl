-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

XPerl_SetModuleRevision("$Revision$")

local WoWclassCount = XPERL_RAID_CLASS_COUNT	-- Raid class columns (XPerl.lua)


function XPerl_OptionsFrame_DisableSlider(slider)
	local name = slider:GetName();
	getmetatable(slider).__index.Disable(slider);
	_G[name.."Text"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	_G[name.."Low"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
	_G[name.."High"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
end

function XPerl_OptionsFrame_EnableSlider(slider)
	local name = slider:GetName();
	getmetatable(slider).__index.Enable(slider);
	_G[name.."Text"]:SetVertexColor(NORMAL_FONT_COLOR.r , NORMAL_FONT_COLOR.g , NORMAL_FONT_COLOR.b);
	_G[name.."Low"]:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
	_G[name.."High"]:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
end


function XPerl_Options_SetupFunc(self)
	XPerl_DoGradient(self, true)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	self:SetBackdropColor(0, 0, 0, 1)
end

-- XPerl_OptionsFrame_SelectFrame
function XPerl_OptionsFrame_SelectFrame(frame)
	XPerl_Options:Show()

	if (frame == "player") then
		XPerl_Options_Player:Show()
		XPerl_Options_Party:Hide()
		XPerl_Options_Raid:Hide()

	elseif (frame == "party") then
		XPerl_Options_Player:Hide()
		XPerl_Options_Party:Show()
		XPerl_Options_Raid:Hide()

	elseif (frame == "raid") then
		XPerl_Options_Player:Hide()
		XPerl_Options_Party:Hide()
		XPerl_Options_Raid:Show()
	end
end

-- XPerl_OptionsSetMyText
-- Label and tooltip from the localization globals str and str_DESC. The globals stay: the Edit Mode
-- dialogs (XPerl_EditModeSettings.lua) use the same strings.
function XPerl_OptionsSetMyText(f, str)
	if (f and str) then
		local textFrame = _G[f:GetName().."Text"]

		if (textFrame) then
			textFrame:SetText(_G[str])
			f.tooltipText = _G[str.."_DESC"]

			if ((f.GetFrameType or f.GetObjectType)(f) == "CheckButton") then
				f:SetHitRectInsets(0, -(textFrame:GetStringWidth()), 0, 0)
			end

		elseif ((f.GetFrameType or f.GetObjectType)(f) == "Button") then
			f:SetText(_G[str])
			f.tooltipText = _G[str.."_DESC"]
		end
	end
end

-- XPerl_Options_CheckButton_OnEnter
function XPerl_Options_CheckButton_OnEnter(self)
	if (self.flashFrame and not InCombatLockdown()) then
		local array
		if (table.getn(self.flashFrame) == 0) then
			array = {self.flashFrame}
		else
			array = self.flashFrame
		end

		for i,f in pairs(array) do
			if (f and f.GetName) then
				if (f:IsShown()) then
					XPerl_FrameFlash(f)
				end
			end
		end
	end
	if ( self.tooltipText ) then
		local p = _G[self:GetName().."Text"]
		local title = p and p:GetText()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if (title) then
			GameTooltip:SetText(title, 1, 1, 1)
			GameTooltip:AddLine(self.tooltipText, nil, nil, nil, 1)
		else
			GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true);
		end
		GameTooltip:Show()
	end

	_G[self:GetName().."Text"]:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end

-- XPerl_GetCheck
function XPerl_GetCheck(f)
	if (f:GetChecked()) then
		return 1
	else
		return 0
	end
end

-- XPerl_Options_GetSibling(sibling,self)
function XPerl_Options_GetSibling(sibling,self)
	return _G[self:GetParent():GetName().."_"..sibling]
end

-- XPerl_Options_EnableSibling
function XPerl_Options_EnableSibling(self,sibling, check2nd, check3rd)

	local siblingName = self:GetParent():GetName().."_"..sibling
	local siblingFrame = _G[siblingName]
	local second = true
	local condition = "and"

	if (type(check2nd) == "string" and (check2nd == "or" or check2nd == "and")) then
		condition = check2nd
		check2nd = check3rd
	end
	if (check2nd) then
		if (type(check2nd) == "table") then
			second = check2nd:GetChecked()
		elseif (type(check2nd) == "string") then
			local sib2 = self:GetParent():GetName().."_"..check2nd
			local sibf2 = _G[sib2]
			if (sibf2) then
				second = sibf2:GetChecked()
			else
				DEFAULT_CHAT_FRAME:AddMessage("|c00FF0000X-Perl|r - No 2nd sibling called '"..sib2.."'")
			end
		else
			second = check2nd
		end
	end

	local result
	if (condition == "and") then
		result = (self:GetChecked() and second)
	elseif (condition == "or") then
		result = (self:GetChecked() or second)
	end

	if (siblingFrame) then
		if ((siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame) == "Button") then
			if (result) then
				siblingFrame:Enable()
			else
				siblingFrame:Disable()
			end
		elseif ((siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame) == "CheckButton") then
			XPerl_Options_EnableCheck(siblingFrame, result)

		elseif ((siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame) == "Slider") then
			if (result) then
				siblingFrame:EnableSlider()
			else
				siblingFrame:DisableSlider()
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|c00FF0000X-Perl|r - No code to disable '"..siblingFrame:GetName().."' type: "..(siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame))
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("|c00FF0000X-Perl|r - No sibling found called '"..siblingName.."'")
	end
end

-- XPerl_Options_EnableCheck
function XPerl_Options_EnableCheck(self, on)
	local textFrame = _G[self:GetName().."Text"]
	if (on) then
		self:Enable()
		textFrame:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		self:Disable()
		textFrame:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end

	if ((self.GetFrameType or self.GetObjectType)(self) == "Button") then
		local normalTexture = _G[self:GetName().."NormalTexture"]
		local icon = _G[self:GetName().."Icon"]
		if (normalTexture and icon) then
			if (on) then
				icon:SetVertexColor(1, 1, 1)
				normalTexture:SetVertexColor(1, 1, 1)
			else
				icon:SetVertexColor(0.5, 0.5, 0.5)
				normalTexture:SetVertexColor(0.5, 0.5, 0.5)
			end
		end
	end
end

-- XPerl_Options_IncrementSibling
function XPerl_Options_IncrementSibling(self,sibling)
	local siblingName = self:GetParent():GetName().."_"..sibling
	local siblingFrame = _G[siblingName]

	if (siblingFrame and (siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame) == "EditBox") then
		local n = tonumber(siblingFrame:GetText())
		n = n + 1
		siblingFrame:SetText(n)
		return n
	end
end

-- XPerl_Options_DecrementSibling
function XPerl_Options_DecrementSibling(self,sibling)
	local siblingName = self:GetParent():GetName().."_"..sibling
	local siblingFrame = _G[siblingName]

	if (siblingFrame and (siblingFrame.GetFrameType or siblingFrame.GetObjectType)(siblingFrame) == "EditBox") then
		local n = tonumber(siblingFrame:GetText())
		n = n - 1
		siblingFrame:SetText(n)
		return n
	end
end

-- XPerl_Options_CheckRadio
function XPerl_Options_CheckRadio(self,buttons)
	local prefix = self:GetParent():GetName().."_"

	for i,name in pairs(buttons) do
		if (prefix..name == self:GetName()) then
			_G[prefix..name]:SetChecked(true)
		else
			_G[prefix..name]:SetChecked(false)
		end
	end
end

-- XPerl_Options_GetSiblingChecked
function XPerl_Options_GetSiblingChecked(name,self)
	local prefix = self:GetParent():GetName().."_"
	return _G[prefix..name]:GetChecked()
end

-- XPerl_Options_OnUpdate
function XPerl_Options_OnUpdate(self,arg1)

	if (self.Fading) then
		local alpha = self:GetAlpha()
		if (self.Fading == "in") then
			alpha = alpha + (arg1 * 2)		-- elapsed * 2 == fade in/out in 1/2 second
			if (alpha > 1) then
				alpha = 1
			end
		elseif (self.Fading == "out") then
			alpha = alpha - (arg1 * 2)
			if (alpha < 0) then
				alpha = 0
			end
		end
		self:SetAlpha(alpha)
		if (alpha == 0) then
			self.Fading = nil
			self:Hide()
		elseif (alpha == 1) then
	                self.Fading = nil
		end
	else
		local f = GetMouseFoci()[1]
		if (f) then
			local n = f:GetName()
			if (n) then
				if (strfind(n, "XPerl_Player") or strfind(n, "XPerl_Target") or strfind(n, "XPerl_Focus")) then
					XPerl_OptionsFrame_SelectFrame("player")
				elseif (strfind(strlower(n), "xperl_party")) then
					XPerl_OptionsFrame_SelectFrame("party")
				elseif (strfind(n, "XPerl_Raid")) then
					XPerl_OptionsFrame_SelectFrame("raid")
				end
			end
		end
	end
end

-- XPerl_Options_MaxScaleSet
local Sliders = {}
function XPerl_Options_MaxScaleSet()

	for i,slider in pairs(Sliders) do
		local old = slider:GetValue()
		local min = slider.min or 50
		local max = slider.max or floor(XPerlDB.maximumScale * 100 + 0.5)

		slider:SetMinMaxValues(min, max)

		_G[slider:GetName().."Low"]:SetFormattedText("%d"..PERCENT_SYMBOL, min)
		_G[slider:GetName().."High"]:SetFormattedText("%d"..PERCENT_SYMBOL, max)

		if (old > max) then
			slider:SetValue(max)
		elseif (old < min) then
			slider:SetValue(min)
		end
	end
end

-- XPerl_SliderSetup(self)
function XPerl_SliderSetup(self, percent)
	self.xperlSliderEnabled = true

	self.IsEnabled = function(self)
		return self.xperlSliderEnabled
	end
	self.DisableSlider = function(self)
		self.xperlSliderEnabled = false
		XPerl_OptionsFrame_DisableSlider(self)
		_G[self:GetName().."Current"]:SetVertexColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
		self:EnableMouse(false)
		self:EnableMouseWheel(false)
	end
	self.EnableSlider = function(self)
		self.xperlSliderEnabled = true
		XPerl_OptionsFrame_EnableSlider(self)
		_G[self:GetName().."Current"]:SetVertexColor(0.4, 0.4, 0.80)
		self:EnableMouse(true)
		self:EnableMouseWheel(true)
	end

	local low = _G[self:GetName().."Low"]
	if (not tonumber(low:GetText())) then
		local min, max = self:GetMinMaxValues()
		if (min and max) then
			if (percent) then
				min = format("%d"..PERCENT_SYMBOL, min)
				max = format("%d"..PERCENT_SYMBOL, max)
			end
			low:SetText(min)
			_G[self:GetName().."High"]:SetText(max)
		end
	end

	self:SetScript("OnLoad", nil)
end

function XPerl_EditBoxSetup(self)
	self.xperlEditEnabled = true
	self.IsEnabled = function(self)
		return self.xperlEditEnabled
	end
	self.Enable = function(self)
		self.xperlEditEnabled = true
		self:EnableMouse(true)
	end
	self.Disable = function(self)
		self.xperlEditEnabled = false
		self:EnableMouse(false)
	end

	self:SetScript("OnLoad", nil)
end

-- GetTable(self)
local function GetTable(self)
	if (self.configIndex == nil) then
		error("No index for configBase in "..self:GetName())
	end

	local table = RunScript("XPerlTemp = "..self.configBase)
	local val = XPerlTemp
	XPerlTemp = nil

	if (type(val) == "table") then
		return val
	end
	--error(self:GetName().." needs to return a table from self.configBase")
end

-- XPerl_Options_GetIndex(self)
function XPerl_Options_GetIndex(self)
	if (type(self.configBase) == "string") then
		local val = GetTable(self)
		if (val) then
			return val[self.configIndex]
		end

	elseif (type(self.configBase) == "table") then
		if (self.configIndex == nil) then
			error("No index for configBase in "..self:GetName())
		end

		return self.configBase[self.configIndex]
	end
end

-- XPerl_Options_SetIndex
function XPerl_Options_SetIndex(self, new)
	if (type(self.configBase) == "string") then
		local val = GetTable(self)
		if val then
			val[self.configIndex] = new
		end
	elseif (type(self.configBase) == "table") then
		if (self.configIndex == nil) then
			error("No index for configBase in "..self:GetName())
		end
		self.configBase[self.configIndex] = new
	end
end

-- scalingOnShow
local function scalingOnShow(self)
	local i = XPerl_Options_GetIndex(self)
	if (i) then
		self:SetValue(floor(100 * i + 0.5))
	end
end

-- scalingOnValueChanged
local function scalingOnValueChanged(self, value)
	local i = XPerl_Options_GetIndex(self)

	if (i) then
		if (floor(100 * i + 0.5) ~= value) then
			XPerl_Options_SetIndex(self, value / 100)
			if (self.configClick) then
				self.configClick()
			end
		end
		_G[self:GetName().."Current"]:SetText(floor(value + 0.5).."%")
	end
end

-- XPerl_Options_RegisterScalingSlider
function XPerl_Options_RegisterScalingSlider(self, min, max)

	XPerl_Options_RegisterProtected(self)

	Sliders[self:GetName()] = self

	if (min) then
		self.min = min
	else
		min = 50
	end
	if (max) then
		self.max = max
	else
		max = floor(((XPerlDB and XPerlDB.maximumScale) or 1.5) * 100 + 0.5)
	end

	_G[self:GetName().."Low"]:SetFormattedText("%d"..PERCENT_SYMBOL, min)
	_G[self:GetName().."High"]:SetFormattedText("%d"..PERCENT_SYMBOL, max)

	self:SetMinMaxValues(min, max)
	self:SetValueStep(1)

	if (self.configBase) then
		self:SetScript("OnShow", scalingOnShow)
		self:SetScript("OnValueChanged", scalingOnValueChanged)
	end
end

-- XPerl_Popup
function XPerl_Popup(question, onAccept)
	XPerl_OptionsQuestionDialogText:SetText(question)
	XPerl_OptionsQuestionDialog.onAccept = onAccept
	XPerl_OptionsQuestionDialog:SetScale(1.5)
	XPerl_OptionsQuestionDialog:Show()

	XPerl_OptionsQuestionDialog:SetPoint("CENTER", 0, 0)

	local w = XPerl_OptionsQuestionDialogText:GetStringWidth() + 20

	if (w > 320) then
		XPerl_OptionsQuestionDialog:SetWidth(320)
		XPerl_OptionsQuestionDialog:SetHeight(100)
	else
		XPerl_OptionsQuestionDialog:SetWidth(w)
		XPerl_OptionsQuestionDialog:SetHeight(80)
	end

	if (XPerl_Options:IsShown()) then
		XPerl_OptionsQuestionDialog.hideMask = true
		XPerl_Options_Mask:Show()
	else
		XPerl_OptionsQuestionDialog.hideMask = nil
	end
end

-- Load settings menu
local MyIndex = 0
local function GetPlayerList()
	local ret = {}
	if (XPerlConfigNew) then
		local me = GetRealmName().." / "..UnitName("player")
		for realmName, realmConfig in pairs(XPerlConfigNew) do
			if (type(realmConfig) == "table" and not XPerl_ConfigReservedKeys[realmName]) then
				for playerName, settings in pairs(realmConfig) do
					local entry = realmName.." / "..playerName

					tinsert(ret, {name = entry, config = settings})

					if (entry == me) then
						MyIndex = #ret
					end
				end
			end
		end
	end
	return ret
end

-- XPerl_Options_LoadSettings_OnLoad
function XPerl_Options_LoadSettings_OnLoad(self)
	self.displayMode = "MENU"
	UIDropDownMenu_Initialize(self, XPerl_Options_LoadSettings_Initialize)
	UIDropDownMenu_SetWidth(self, 140)
	if (MyIndex == 0) then
		XPerl_Options_DropDown_LoadSettingsText:SetText("")
	else
		UIDropDownMenu_SetSelectedID(self, MyIndex, 1)
	end
end

-- XPerl_Options_LoadSettings_Initialize
function XPerl_Options_LoadSettings_Initialize()
	local list = GetPlayerList()

	for i,entry in pairs(list) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = entry.name
		info.func = XPerl_Options_LoadSettings_OnClick
		UIDropDownMenu_AddButton(info)
	end
end

-- XPerl_Options_Anchor_OnLoad
function XPerl_Options_Anchor_OnLoad(self)
	self.displayMode = "MENU"
	UIDropDownMenu_Initialize(self, XPerl_Options_Anchor_Initialize)
	UIDropDownMenu_SetSelectedID(self, MyIndex, 1)
	UIDropDownMenu_SetWidth(self, 100)
end

-- XPerl_Options_Anchor_OnLoad
function XPerl_Options_Anchor_Initialize()
	local info
	local current = XPerl_Options_Party_Anchor.varGet() or "TOP"

	for k,v in pairs(XPerl_AnchorList) do
		info = {}
		info.text = v
		info.func = XPerl_Options_Anchor_OnClick

		if (current == v) then
			MyIndex = k
		end

		UIDropDownMenu_AddButton(info)
	end
end

-- XPerl_Options_Anchor_OnClick
function XPerl_Options_Anchor_OnClick(self)
	local obj = UIDROPDOWNMENU_OPEN_MENU

	obj.varSet(XPerl_AnchorList[self:GetID()])
	MyIndex = self:GetID()
	UIDropDownMenu_SetSelectedID(obj, MyIndex, 1)

	XPerl_ProtectedCall(obj.setFunc)
end

-- CopySelectedSettings
-- Copies another character's account-wide settings into the settings slot in use. Frame settings follow the
-- Edit Mode layouts, so the slot keeps its own frame sections.
local CopyFrom
local function CopySelectedSettings()
	XPerl_EditMode_DetachConfig()

	local realm, name = GetRealmName(), UnitName("player")
	local current
	if (XPerlConfigSavePerCharacter) then
		current = XPerlConfigNew[realm] and XPerlConfigNew[realm][name]
	else
		current = XPerlConfigNew.global
	end

	local new = XPerl_CopyTable(CopyFrom.config)
	if (current) then
		for _, key in ipairs(XPerl_FrameConfigKeys) do
			if (current[key] ~= nil) then
				new[key] = current[key]
			end
		end
	end

	if (XPerlConfigSavePerCharacter) then
		if (not XPerlConfigNew[realm]) then
			XPerlConfigNew[realm] = {}
		end
		XPerlConfigNew[realm][name] = new
	else
		XPerlConfigNew.global = new
	end

	XPerl_GiveConfig()

	XPerl_StartupSpellRange()			-- Re-validate the spell range stuff

	XPerl_Options:Hide()
	XPerl_Options:Show()

	XPerl_OptionActions()
end

-- XPerl_Options_LoadSettings_OnClick
function XPerl_Options_LoadSettings_OnClick(self)

	local list = GetPlayerList()

	if (self:GetID() ~= MyIndex) then
		local entry = list[self:GetID()]

		if (entry) then
			CopyFrom = entry
			XPerl_Popup(format("Copy settings from %s?", entry.name), CopySelectedSettings)
		end
	end
end

-- XPerl_Options_TextureSelect_Onload
function XPerl_Options_TextureSelect_Onload(self)

	self.Setup = XPerl_Options_SetupFunc
	self.scrollBar = _G[self:GetName().."scrollBar"]
	self.list = XPerl_AllBarTextures()
	self.Selection = 1
	if (self.list) then
		self.scrollBar.bar:SetValue(max(0, min(self.Selection - 5, #self.list - 8)))
	else
		self.scrollBar.bar:SetValue(1)
	end

	self.UpdateFunction = function(self)
		self:GetParent():SetBarColours()
	end

	self.SetBarColours = function(self)
		local offset = self.scrollBar.bar:GetValue()
		for i = 0,9 do
			local r, g, b
			if (self.Selection - offset - 1 == i) then
				r, g, b = 0, 1, 0
			else
				r, g, b = 0.5, 0.5, 0.5
			end
			local f = _G[self:GetName()..i]
			if (f) then
				if (i + offset + 1 > #self.list) then
					f:Hide()
				else
					f:Show()
					f.name:SetText(self.list[i + offset + 1][1])
					f.tex:SetTexture(self.list[i + offset + 1][2])
					f.tex:SetVertexColor(r, g, b, 1)
				end
			end
		end

		if (FauxScrollFrame_Update(self.scrollBar, #self.list, 10, 1)) then
			self.scrollBar:Show()
		else
			self.scrollBar:Hide()
		end
	end

	XPerl_Options_TextureSelect_Onload = nil
end

-- XPerl_Options_SetTabColor
function XPerl_Options_SetTabColor(self, color)
	for i,y in pairs({"Enabled", "Disabled"}) do
		for j,z in pairs({"Left", "Right", "Middle"}) do
			local f = _G[self:GetName()..y..z]
			--if (XPerlDB and XPerlDB.colour.gradient.enable) then
				local c = XPerlDB.colour.gradient.s
				f:SetVertexColor(c.r, c.g, c.b, c.a)
			--else
			--	f:SetVertexColor(0.8, 0.8, 0.8, 1)
			--end
		end
	end
end

-- XPerl_Options_EnableTab
function XPerl_Options_EnableTab(self, enable)
	for i,y in pairs({"Enabled", "Disabled"}) do
		for j,z in pairs({"Left", "Right", "Middle"}) do
			local f = _G[self:GetName()..y..z]

			if ((i == 1 and enable) or (i == 2 and not enable)) then
				f:Show()
			else
				f:Hide()
			end
		end
	end
end

local protected = {}

-- XPerl_Options_InCombatChange
function XPerl_Options_InCombatChange(inCombat)

	for k,v in pairs(protected) do
		if ((k.GetFrameType or k.GetObjectType)(k) == "CheckButton") then
			local textFrame = _G[k:GetName().."Text"]

			if (inCombat) then
				k.wasChecked = k:GetChecked()
				k.combatIcon:Show()
				protected[k] = k:IsEnabled()
				k:SetChecked(false)
				k:Disable()
				k:EnableMouse(false)
				textFrame:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
			else
				k:EnableMouse(true)
				k.combatIcon:Hide()

				if (v) then
					k:Enable()
					textFrame:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				else
					k:Disable()
					textFrame:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
				end

				if (k.wasChecked) then
					k:SetChecked(true)
				end
			end

		elseif ((k.GetFrameType or k.GetObjectType)(k) == "Slider") then
			if (inCombat) then
				k.combatIcon:Show()
				k:DisableSlider()
			else
				k.combatIcon:Hide()

				if (v) then
					k:EnableSlider()
				else
					k:DisableSlider()
				end
			end

		elseif ((k.GetFrameType or k.GetObjectType)(k) == "Button") then
			if (inCombat) then
				k.combatIcon:Show()
				k:Disable()
			else
				k.combatIcon:Hide()

				if (v) then
					k:Enable()
				else
					k:Disable()
				end
			end

		elseif ((k.GetFrameType or k.GetObjectType)(k) == "EditBox") then
			if (inCombat) then
				k.combatIcon:Show()
				k:Disable()
			else
				k.combatIcon:Hide()

				if (v) then
					k:Enable()
				else
					k:Disable()
				end
			end

		end
	end
end

-- XPerl_Options_RegisterProtected
function XPerl_Options_RegisterProtected(self)

	if ((self.GetFrameType or self.GetObjectType)(self) == "Slider") then
		XPerl_SliderSetup(self)
	elseif ((self.GetFrameType or self.GetObjectType)(self) == "EditBox") then
		XPerl_EditBoxSetup(self)
	end

	protected[self] = self:IsEnabled()

	local icon = self:CreateTexture(self:GetName().."CombatIcon", "OVERLAY")
	self.combatIcon = icon

	icon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	icon:SetTexCoord(0.5, 1.0, 0.0, 0.5)

	icon:SetWidth(32)
	icon:SetHeight(32)
	icon:SetPoint("CENTER", 0, 0)
	icon:Show()

	self:SetScript("OnLoad", nil)
end

-- GetSpell
local function GetSpell()
	return XPerlDB and XPerlDB.rangeFinder[XPerl_Options.optRange].spell
end

-- XPerl_Options_GetRangeTexture
function XPerl_Options_GetRangeTexture(self)
	local spell = GetSpell()
	if (spell) then
		local tex = C_Spell.GetSpellTexture(spell)
		return tex, spell
	end

	return ""
end

-- XPerl_Options_DoRangeTooltip
function XPerl_Options_DoRangeTooltip(self)

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -15, 0)

	local spell = GetSpell()
	if (spell) then
		local link = C_Spell.GetSpellLink(spell)
		if (link) then
			GameTooltip:SetHyperlink(link)
		else
			GameTooltip:SetText(spell, 1, 1, 1)
		end

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(XPERL_CONF_CUSTOMSPELL_DESC, 0.5, 1, 0.5)
	else
		GameTooltip:SetText(XPERL_CONF_CUSTOMSPELL, 1, 1, 1)
		GameTooltip:AddLine(XPERL_CONF_CUSTOMSPELL_DESC2, 0.5, 1, 0.5)
	end
	GameTooltip:Show()
end

-- SetClassNames
local function SetClassNames(self)
	XPerl_ValidateRaidClasses(XPerlDB.raid)

	local prefix = self:GetParent():GetParent():GetName().."_"
	for i = 1,WoWclassCount do
		local f = _G[prefix.."ClassSel"..i.."_EnableText"]
		if (f) then
			local class = XPerlDB.raid.class[i].name
			f:SetText(LOCALIZED_CLASS_NAMES_MALE[class])
		end
	end
end


-- XPerl_Options_MoveRaidClassUp
function XPerl_Options_MoveRaidClassUp(self)
	local i = self:GetID()

	XPerl_ValidateRaidClasses(XPerlDB.raid)

	local save = XPerlDB.raid.class[i].name
	XPerlDB.raid.class[i].name = XPerlDB.raid.class[i - 1].name
	XPerlDB.raid.class[i - 1].name = save

	SetClassNames(self)
end

-- XPerl_Options_MoveRaidClassDown
function XPerl_Options_MoveRaidClassDown(self)
	local i = self:GetID()

	XPerl_ValidateRaidClasses(XPerlDB.raid)

	local save = XPerlDB.raid.class[i]
	XPerlDB.raid.class[i] = XPerlDB.raid.class[i + 1]
	XPerlDB.raid.class[i + 1] = save

	SetClassNames(self)
end

-- XPerl_Options_RaidSelectAll
function XPerl_Options_RaidSelectAll(self, enable)
	local prefix = self:GetParent():GetName().."_"

	for i = 1,WoWclassCount do
		local f = _G[prefix.."Grp"..i]
		if (f) then
			f:SetChecked(enable)
			--print(f:GetChecked(), enable)
			if f:GetChecked() then
				XPerlDB.raid.group[i] = 1
			else
				XPerlDB.raid.group[i] = nil
			end
		end

		f = _G[prefix.."ClassSel"..i.."_Enable"]
		if (f) then
			f:SetChecked(enable)
			--print(f:GetChecked(), enable)
			if f:GetChecked() then
				XPerlDB.raid.class[i].enable = 1
			else
				XPerlDB.raid.class[i].enable = nil
			end
		end
	end

	XPerl_Raid_OptionActions()
end

-- XPerl_Options_SetupStatsFrames
function XPerl_Options_SetupStatsFrames()

	-- Raid and raid pet buttons have their own compact bars (no mana bar / percent text by default)
	XPerl_ForEachUnitFrame(function(frame)
		local sf = frame.statsFrame
		if (sf and sf.healthBar and sf.healthBar.percent and sf.manaBar and sf.manaBar.percent) then
			XPerl_StatsFrameSetup(frame, frame:GetExtraBars(), frame.statsOffset)
		end
	end)
end




-- XPerl_Player_Reset()
-- Options refresh for the player frame (settings, then a full redraw)
function XPerl_Player_Reset()
	XPerl_Player:ApplySettings()
end

-- XPerl_Player_Pet_Reset
-- Options refresh for the pet frame
function XPerl_Player_Pet_Reset()
	XPerl_Player_Pet:ApplySettings()
end

-- XPerl_Target_Reset()
-- Options refresh for the target and focus frames
function XPerl_Target_Reset()
	XPerl_Target:ApplySettings()
	XPerl_Focus:ApplySettings()
end

-- All -> Frames panel: the frame enable flags (XPerlDB.<key>.enable, 1 or false) with the type a row
-- depends on. The flags in use when the UI loaded tell whether a reload is needed. A second column switches
-- each type's heal prediction (XPerlDB.<key>.healPrediction, 1 or false), which belongs to the active Edit Mode
-- layout like the other frame settings.
local frameToggles = {
	{"player", "XPERL_CONF_ADDON_PLAYER"},
	{"pet", "XPERL_CONF_ADDON_PET"},
	{"pettarget", "XPERL_CONF_ADDON_PETTARGET", "pet"},
	{"target", "XPERL_CONF_ADDON_TARGET"},
	{"targettarget", "XPERL_CONF_ADDON_TARGETTARGET", "target"},
	{"targettargettarget", "XPERL_CONF_ADDON_TARGETTARGETTARGET", "targettarget"},
	{"focus", "XPERL_CONF_ADDON_FOCUS"},
	{"focustarget", "XPERL_CONF_ADDON_FOCUSTARGET", "focus"},
	{"party", "XPERL_CONF_ADDON_PARTY"},
	{"partypet", "XPERL_CONF_ADDON_PARTYPET", "party"},
	{"raid", "XPERL_CONF_ADDON_RAID"},
	{"raidpet", "XPERL_CONF_ADDON_RAIDPETS", "raid"},
	{"boss", "XPERL_CONF_ADDON_BOSS"},
	{"arena", "XPERL_CONF_ADDON_ARENA"},
}

local function FrameEnabled(key)
	local section = XPerlDB[key]
	return (section and section.enable) and true or false
end

local HEAL_COLUMN = 185		-- from the left of a row's check box; the panel is at least 256 wide

local loadedFrameFlags
XPerl_RequestConfig(function()
	if (not loadedFrameFlags) then
		loadedFrameFlags = {}
		for _, row in ipairs(frameToggles) do
			loadedFrameFlags[row[1]] = FrameEnabled(row[1])
		end
	end
end, "$Revision$")

-- UpdateFrameToggles(panel)
local function UpdateFrameToggles(panel)
	local changed
	for _, row in ipairs(frameToggles) do
		local key, parent = row[1], row[3]
		local check = panel.toggles[key]
		local on = FrameEnabled(key)
		check:SetChecked(on)
		local available = not parent or FrameEnabled(parent)
		XPerl_Options_EnableCheck(check, available)
		local heal = panel.healToggles[key]
		local section = XPerlDB[key]
		heal:SetChecked(section and section.healPrediction and true or false)
		XPerl_Options_EnableCheck(heal, on and available)
		if (loadedFrameFlags and on ~= loadedFrameFlags[key]) then
			changed = true
		end
	end
	panel.reload:SetEnabled(changed and true or false)
end

-- XPerl_Options_FrameToggles_OnLoad
function XPerl_Options_FrameToggles_OnLoad(self)
	local name = self:GetName()
	self.toggles, self.healToggles = {}, {}
	self.reload = _G[name.."_Reload"]
	local prev = _G[name.."_Title"]
	for i, row in ipairs(frameToggles) do
		local key = row[1]
		local check = CreateFrame("CheckButton", name.."_"..key, self, "XPerlCheckButtonTemplate")
		check:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -3 or 6)
		XPerl_OptionsSetMyText(check, row[2])
		check:SetScript("OnShow", nil)
		check:SetScript("OnClick", function(button)
			-- One flag per settings slot, whatever the Edit Mode layout
			XPerl_EditMode_SetFrameEnabledFlag(key, button:GetChecked() and 1 or false)
			UpdateFrameToggles(self)
		end)
		self.toggles[key] = check

		local heal = CreateFrame("CheckButton", name.."_"..key.."_Heal", self, "XPerlCheckButtonTemplate")
		heal:SetPoint("LEFT", check, "LEFT", HEAL_COLUMN, 0)
		heal:SetScript("OnShow", nil)
		heal:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(XPERL_CONF_HEALPREDICTION, 1, 1, 1)
			GameTooltip:AddLine(XPERL_CONF_HEALPREDICTION_DESC, nil, nil, nil, 1)
			GameTooltip:Show()
		end)
		heal:SetScript("OnLeave", GameTooltip_Hide)
		heal:SetScript("OnClick", function(button)
			local section = XPerlDB[key]
			if (section) then
				section.healPrediction = button:GetChecked() and 1 or false
				XPerl_OptionActions()
			end
		end)
		self.healToggles[key] = heal
		if (i == 1) then
			local header = self:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			header:SetPoint("BOTTOM", heal, "TOP", 0, -4)
			header:SetTextColor(1, 1, 1)
			header:SetText(XPERL_CONF_HEALPREDICTION)
		end
		prev = check
	end
	self.reload:ClearAllPoints()
	self.reload:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 6)
	self:SetScript("OnShow", UpdateFrameToggles)
end

-- XPerl_TargetTarget_Reset()
-- Options refresh for the target's target, its target, the focus target and the pet target
function XPerl_TargetTarget_Reset()
	XPerl_TargetTarget:ApplySettings()
	XPerl_TargetTargetTarget:ApplySettings()
	XPerl_FocusTarget:ApplySettings()
	XPerl_PetTarget:ApplySettings()
end

-- XPerl_Party_Reset()
-- Options refresh for the party frames; each also applies its target, its pet and (party 1) the anchor
function XPerl_Party_Reset()
	for i = 1, 4 do
		_G["XPerl_party"..i]:ApplySettings()
	end
end

-- XPerl_PartyPet_Reset()
function XPerl_PartyPet_Reset()
	for i = 1, 4 do
		_G["XPerl_partypet"..i]:ApplySettings()
	end
end

-- XPerl_Party_GetGap / XPerl_Party_SetGap: the Party quick panel's spacing (party.spacing)
function XPerl_Party_GetGap()
	return XPerlDB.party.spacing
end

function XPerl_Party_SetGap(newGap)
	if (type(newGap) ~= "number") then
		return
	end
	XPerlDB.party.spacing = newGap
	XPerl_Party_Reset()
end




-- Moving stuff
function XPerl_Player_GetGap()
	if (XPerl_Player and XPerl_Target) then
		local pr = XPerl_Player.statsFrame:GetRight()
		local ps = XPerl_Player:GetEffectiveScale()
		if (pr and ps) then
			local playerLeft = pr * ps
			local tl = XPerl_Target:GetLeft()
			local ts = XPerl_Target:GetEffectiveScale()
			if (tl and ts) then
				local targetLeft = tl * ts
				local a = targetLeft - playerLeft
				return floor(floor((a + 0.01) * 100) / 100 + 4)
			end
		end
	end
	return 0
end

-- XPerl_Player_SetGap
function XPerl_Player_SetGap(newGap)
	if (type(newGap) == "number") then
		newGap = newGap - 4

		local function SetChildGap(self, other)
			if (self and other) then
				local top = other:GetTop()
				local left

				if (self == XPerl_Player) then
					left = ((self.statsFrame:GetRight() * self:GetEffectiveScale()) + newGap) / other:GetEffectiveScale()
				else
					left = ((self:GetRight() * self:GetEffectiveScale()) + newGap) / other:GetEffectiveScale()
				end

				if (self == XPerl_Target or self == XPerl_TargetTarget or self == XPerl_Focus) then
					if (self.levelFrame and self.levelFrame:IsShown()) then
						left = left + self.levelFrame:GetWidth()
					end
				end

				other:ClearAllPoints()
				other:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
				XPerl_SavePosition(other)
			end
		end

		SetChildGap(XPerl_Player, XPerl_Target)
		SetChildGap(XPerl_Target, XPerl_TargetTarget)
		SetChildGap(XPerl_TargetTarget, XPerl_TargetTargetTarget)
		SetChildGap(XPerl_Focus, XPerl_FocusTarget)
		SetChildGap(XPerl_Player_Pet, XPerl_PetTarget)

		if (XPerl_Player) then
			XPerl_SavePosition(XPerl_Player)
		end
	end
end

-- XPerl_Player_AlignTop
function XPerl_Player_AlignTop()

	-- We set this for 1 reason, so that all the related frames scale in the same direction should the user do that...
	if (XPerl_Player) then
		XPerl_Player:ClearAllPoints()
		XPerl_Player:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", XPerl_Player:GetLeft() or 5, XPerl_Player:GetTop() or 948)
		XPerl_SavePosition(XPerl_Player)
	end

	local function AlignChildTop(self, other)
		if (self and other) then
			local top = self:GetTop() * self:GetEffectiveScale()
			local otherLeft = other:GetLeft() or 220
			local selfLeft = self:GetLeft() or 5

			if (otherLeft == nil) then
				otherLeft = selfLeft + 200
			end

			other:ClearAllPoints()
			local newTop = top / other:GetEffectiveScale()
			other:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", otherLeft, newTop)
			XPerl_SavePosition(other)
		end
	end

	AlignChildTop(XPerl_Player, XPerl_Target)
	AlignChildTop(XPerl_Target, XPerl_TargetTarget)
	AlignChildTop(XPerl_TargetTarget, XPerl_TargetTargetTarget)
	AlignChildTop(XPerl_Focus, XPerl_FocusTarget)
	AlignChildTop(XPerl_Player_Pet, XPerl_PetTarget)
end

-- Raid group placement (quick panel). Titles are moved and their positions stored for the active Edit Mode
-- layout. Groups side by side (raid.anchor TOP/BOTTOM) are spaced horizontally, stacked groups (LEFT/RIGHT,
-- each a row of buttons below its title) vertically. The tools move all 13 titles, the ones the sort mode
-- doesn't use too, so they line up once in use.

local function RaidSideBySide()
	return XPerlDB.raid.anchor ~= "LEFT" and XPerlDB.raid.anchor ~= "RIGHT"
end

-- Height of a raid button below a stacked group's title, in the titles' scale
local function RaidButtonHeight()
	return XPerlDB.raid.mana and 43 or 38
end

-- XPerl_Raid_GetGap
function XPerl_Raid_GetGap()
	local first, second = XPerl_Raid_Title1, XPerl_Raid_Title2
	if (RaidSideBySide()) then
		local left, right = second:GetLeft(), first:GetRight()
		return (left and right) and floor(left - right + 0.5) or 0
	end
	local bottom, top = first:GetBottom(), second:GetTop()
	return (bottom and top) and floor(bottom - RaidButtonHeight() - top + 0.5) or 0
end

-- InterestingFrames: the titles the quick panel's group selector (XPerl_Options.raidAlign) picks
local function InterestingFrames()
	local interest = XPerl_Options.raidAlign
	local first, last, step = 1, WoWclassCount, 1
	if (interest == "odd") then
		step = 2
	elseif (interest == "even") then
		first, step = 2, 2
	elseif (interest == "first4") then
		last = 4
	elseif (interest == "last4") then
		first = 5
	elseif (interest ~= "all") then
		return {}
	end
	local ret = {}
	for i = first, last, step do
		tinsert(ret, _G["XPerl_Raid_Title"..i])
	end
	return ret
end

-- MoveTitle(frame, left, top): TOPLEFT at left/top (the frame's own coordinates), stored for Edit Mode; a
-- linked raid group stays linked
local function MoveTitle(frame, left, top)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	XPerl_SavePosition(frame, true)
end

-- XPerl_Raid_SetGap
function XPerl_Raid_SetGap(newGap)
	if (type(newGap) ~= "number" or InCombatLockdown()) then
		return
	end
	local framePrev
	for _, frame in ipairs(InterestingFrames()) do
		if (framePrev) then
			if (RaidSideBySide()) then
				MoveTitle(frame, framePrev:GetRight() + newGap, frame:GetTop())
			else
				MoveTitle(frame, frame:GetLeft(), framePrev:GetBottom() - RaidButtonHeight() - newGap)
			end
		end
		framePrev = frame
	end
end

-- XPerl_Raid_AlignTop
function XPerl_Raid_AlignTop()
	local frames = InterestingFrames()
	if (not frames[1] or InCombatLockdown()) then
		return
	end
	local top = frames[1]:GetTop()
	for _, frame in ipairs(frames) do
		MoveTitle(frame, frame:GetLeft(), top)
	end
end

-- XPerl_Raid_AlignLeft
function XPerl_Raid_AlignLeft()
	local frames = InterestingFrames()
	if (not frames[1] or InCombatLockdown()) then
		return
	end
	local left = frames[1]:GetLeft()
	for _, frame in ipairs(frames) do
		MoveTitle(frame, left, frame:GetTop())
	end
end

-- XPerl_Raid_ArrangeGrid(gap)
-- Puts the 13 raid groups in rows of four from group 1's spot, as many rows deep as it takes, `gap` apart (the
-- Spacing value, at least 0). Columns are as wide as the widest group and each row as tall as its tallest
-- group, measured by the groups' placeholders (five buttons; a class column as many as its class has).
local GRID_COLUMNS = 4
function XPerl_Raid_ArrangeGrid(gap)
	local left, top = XPerl_Raid_Title1:GetLeft(), XPerl_Raid_Title1:GetTop()
	if (InCombatLockdown() or not (left and top)) then
		return
	end
	gap = max(0, tonumber(gap) or 0)

	local titles, columnWidth = {}, 0
	for i = 1, WoWclassCount do
		local title = _G["XPerl_Raid_Title"..i]
		titles[i] = title
		columnWidth = max(columnWidth, title:GetWidth(), title.virtual:GetWidth())
	end
	for rowStart = 1, WoWclassCount, GRID_COLUMNS do
		local rowEnd = min(rowStart + GRID_COLUMNS - 1, WoWclassCount)
		local rowHeight = 0
		for i = rowStart, rowEnd do
			rowHeight = max(rowHeight, titles[i]:GetHeight() + titles[i].virtual:GetHeight())
		end
		for i = rowStart, rowEnd do
			if (i > 1) then
				MoveTitle(titles[i], left + (i - rowStart) * (columnWidth + gap), top)
			end
		end
		top = top - rowHeight - gap
	end
end

--------------------------------------------------------------------
-------------------------- LAYOUT STUFF ----------------------------
--------------------------------------------------------------------

-- Named frame layouts save and load the active Edit Mode layout's frame positions. The list also offers
-- the positions of the other Edit Mode layouts X-Perl knows (loading copies them into the active one).

-- XPerl_Options_LayoutGetList
-- {label =, positions =, named =} entries (XPerl_EditMode_PositionSets)
function XPerl_Options_LayoutGetList(self)
	return XPerl_EditMode_PositionSets()
end

-- XPerl_Options_GetLayout
function XPerl_Options_GetLayout(self, label)
	for _, set in ipairs(XPerl_EditMode_PositionSets()) do
		if (set.label == label) then
			return set
		end
	end
end

-- XPerl_Options_LayoutNameChanged
-- Save takes any new name or an existing named layout; Load any listed entry; Delete only named layouts
function XPerl_Options_LayoutNameChanged(editBox)
	local text = editBox:GetText()
	local set = text and text ~= "" and XPerl_Options_GetLayout(nil, text)
	local canSave = text and text ~= "" and (not set or set.named)

	XPerl_Options_GetSibling("Save", editBox):SetEnabled(canSave and true or false)
	XPerl_Options_GetSibling("Load", editBox):SetEnabled(set and true or false)
	XPerl_Options_GetSibling("Delete", editBox):SetEnabled(set and set.named and true or false)
end

-- XPerl_Options_SaveFrameLayout
function XPerl_Options_SaveFrameLayout(name)
	local set = name and name ~= "" and XPerl_Options_GetLayout(nil, name)
	if (name and name ~= "" and (not set or set.named)) then
		XPerl_EditMode_SaveNamedPositions(name)
		return true
	end
end

-- XPerl_Options_LoadFrameLayout
function XPerl_Options_LoadFrameLayout(name)
	local set = XPerl_Options_GetLayout(nil, name)
	if (set) then
		XPerl_EditMode_SetPositions(set.positions)
	end
end

-- XPerl_Options_DeleteFrameLayout
function XPerl_Options_DeleteFrameLayout(name)
	local set = XPerl_Options_GetLayout(nil, name)
	if (set and set.named) then
		XPerl_EditMode_DeleteNamedPositions(name)
		return true
	end
end

-- XPerl_Options_LayoutFill
function XPerl_Options_LayoutFill(self, setName)
	local list = XPerl_Options_LayoutGetList(self)

	self.start = self.scrollBar.bar:GetValue() + 1

	if (self.selection) then
		if (self.selection < 1) then
			self.selection = 1
		elseif (self.selection > #list) then
			self.selection = #list
		end
	end

	for i = 1,#self.line do
		self.line[i]:SetText("")
		self.line[i]:UnlockHighlight()
		self.line[i]:Hide()
	end

	local newName
	local line = 1
	for i = self.start,self.start+#self.line-1 do
		if (i > #list) then
			break
		end

		local set = list[i]
		self.line[line].raw = set.label

		if (set.named) then
			self.line[line]:SetText(set.label)
		else
			self.line[line]:SetText("|cFF6060A0"..set.label)
		end

		self.line[line]:Show()

		if (i == self.selection) then
			self.line[line]:LockHighlight()

			if (setName) then
				newName = set.label
			end
		end

		line = line + 1
	end

	if (setName) then
		if (newName) then
			XPerl_Options_Layout_Name:SetText(newName)
		else
			XPerl_Options_Layout_Name:SetText("")
		end
	end

	if (FauxScrollFrame_Update(self.scrollBar, #list, 16, 1)) then
		self.scrollBar:Show()
	else
		self.scrollBar:Hide()
	end
end

---------------------------------------------------------------------
-------------------------- CONFIG IMPORT ----------------------------
---------------------------------------------------------------------
-- Saved variables are not loaded yet while this file runs; the core's ADDON_LOADED settings setup calls the importer
-- when XPerlConfig/XPerlConfig_Global exist, then drops it
do

-- Convert		-- Convert old options (we have 1 or nil now instead of 1 or 0)
local function Convert(opt)
	if (opt == 0) then
		return nil
	end
	return opt
end

-- XPerl_Options_ImportOldConfig
function XPerl_Options_ImportOldConfig(old)

	if (not old) then
		return
	end

	local new = {
		bar = {
			texture		= old.BarTexture,
			background	= Convert(old.BackgroundTextures),
			fat		= Convert(old.FatHealthBars),
			inverse		= Convert(old.InverseBars),				-- 1.8.6
		},
		transparency = {
			frame		= old.Transparency			or 1,
			text		= old.TextTransparency			or 1,
		},
		colour = {
			frame			= old.BackColour		or {r = 0, g = 0, b = 0, a = 1},
			border			= old.BorderColour		or {r = 0.5, g = 0.5, b = 0.5, a = 1},
			class			= Convert(old.ClassColouredNames),
			guildList		= Convert(old.ApplyToGuildList),		-- 1.8.9
			classic			= Convert(old.ClassicHealthBar),
			bar = {
				healthEmpty	= old.ColourHealthEmpty		or {r = 1, g = 0, b = 0},
				healthFull	= old.ColourHealthFull		or {r = 0, g = 1, b = 0},
				mana		= old.ColourMana		or {r = 0, g = 0, b = 1},
				energy		= old.ColourEnergy		or {r = 1, g = 1, b = 0},
				rage		= old.ColourRage		or {r = 1, g = 0, b = 0},
				focus		= old.ColourFocus		or {r = 1, g = 0.5, b = 0.25},
				runic_power	= {r = PowerBarColor and PowerBarColor["RUNIC_POWER"].r or 1, g = PowerBarColor and PowerBarColor["RUNIC_POWER"].g or 1, b = PowerBarColor and PowerBarColor["RUNIC_POWER"].b or 1},
			},
			reaction = {
				enemy		= old.ColourReactionEnemy	or {r = 1, g = 0, b = 0},
				neutral		= old.ColourReactionNeutral	or {r = 1, g = 1, b = 0},
				unfriendly	= old.ColourReactionUnfriendly	or {r = 1, g = 0.5, b = 0},
				friend		= old.ColourReactionFriend	or {r = 0, g = 1, b = 0},
				none		= old.ColourReactionNone	or {r = 0.5, g = 0.5, b = 1},
				tapped		= old.ColourTapped		or {r = 0.5, g = 0.5, b = 0.5},
			},
			gradient = XPerl_DefaultGradientColours(),
		},
		highlightSelection	= Convert(old.HighlightSelection),
		minimap = {
			enable		= Convert(old.MinimapButtonShown),
			pos		= old.MinimapButtonPosition	or 186,
		},
		combatFlash		= Convert(old.PerlCombatFlash),
		tooltip = {
			enable		= Convert(old.UnitTooltips),				-- 2.0.5
			enableBuffs	= 1,							-- 2.3.4a
			fading		= Convert(old.FadingTooltip),				-- 1.8.3
			xperlInfo	= Convert(old.XPerlTooltipInfo),			-- 1.8.6
			modifier	= old.UnitTooltipsModifiers	or "all",		-- 2.0.6
		},
		maximumScale		= old.MaximumScale		or 1.5,
		optionsColour		= old.OptionsColour		or {r = 0.7, g = 0.2, b = 0.2},	-- 1.8.3
		showAFK			= Convert(old.ShowAFK),					-- 2.2.4
		buffs = {
			cooldown	= Convert(old.BuffCooldown),				-- 2.2.3
			countdown	= Convert(old.BuffCountdown),				-- 2.2.2
			countdownStart	= old.BuffCountdownStart	or 20,			-- 2.2.2
		},
		rangeFinder = old.RangeFinder or XPerl_DefaultRangeFinder(),
		highlight = {
			enable			= Convert(old.RaidHighlights),
			HOT			= Convert(old.RaidHighlightHoTs),
			AGGRO			= Convert(old.RaidHighlightAggro),
			MISSING			= Convert(old.RaidHighlightMissing),
			all			= Convert(old.RaidHighlightMissingAll),
		},
		player = {
			enable			= 1,
			castBar = {
				enable		= Convert(old.ArcaneBarPlayer),
				original	= Convert(old.OldCastBar),
				castTime	= Convert(old.CastTime),
			},
			portrait		= Convert(old.ShowPlayerPortrait),
			portrait3D		= Convert(old.ShowPlayerPortrait3D),
			hitIndicator	= Convert(old.CombatHitIndicator),
			level			= Convert(old.ShowPlayerLevel),
			classIcon		= Convert(old.ShowPlayerClassIcon),
			xpBar			= Convert(old.ShowPlayerXPBar),
			repBar			= Convert(old.ShowPlayerRepBar),
			pvpIcon			= Convert(old.ShowPlayerPVP),
			values			= Convert(old.ShowPlayerValues),
			percent			= Convert(old.ShowPlayerPercent),
			scale			= old.Scale_PlayerFrame		or 0.8,
			partyNumber		= Convert(old.ShowPartyNumber),
			withName		= Convert(old.ShowPartyNumberWithName),
			showRunes		= 1,
			dockRunes		= 1,


			fullScreen = {
				enable		= Convert(old.FullScreenStatus),
			},

			healerMode = {
				enable		= Convert(old.HealerModePlayer),
				type		= old.HealerModePlayerType	or 1,
			},

			buffs = {
				enable		= Convert(old.PlayerBuffs),
				above		= Convert(old.PlayerBuffsAbove),
				size		= old.PlayerBuffSize		or 15,
				hideBlizzard	= Convert(old.HideBlizzardBuffBar),
				count		= old.PlayerBuffMaxDisplay	or 40,
				cooldown	= Convert(old.PlayerBuffsCooldown),
				wrap		= 1,			-- 2.3.5
				rows		= 2,			-- 2.3.5
			},
			debuffs = {
				enable		= Convert(old.PlayerBuffs),
				size		= old.PlayerBuffSize		or 19,
			},
			size = {
				width		= old.PlayerWidthBonus		or 0,
			},
		},
		pet = {
			enable			= 1,
			castBar = {
				enable		= Convert(old.ArcaneBarPlayer),
			},
			portrait		= Convert(old.ShowPlayerPetPortrait),
			portrait3D		= Convert(old.ShowPlayerPetPortrait3D),
			hitIndicator		= Convert(old.PetCombatHitIndicator),
			level			= Convert(old.ShowPetLevel),
			scale			= old.Scale_PetFrame		or 0.8,
			name			= Convert(old.ShowPlayerPetName),
			buffs = {
				enable		= 1,
				size		= old.PlayerPetBuffSize		or 15,
				wrap		= 1,			-- 2.3.5
			},
			debuffs = {
				enable		= 1,
				size		= old.PlayerPetBuffSize		or 19,
			},
			healerMode = {
--				enable		= nil,
				type		= 1,
			},
			values			= Convert(old.ShowPlayerPetValues),
			size = {
				width		= old.PetWidthBonus		or 0,
			},
		},
		target = {
			enable			= 1,
			portrait		= Convert(old.ShowTargetPortrait),
			portrait3D		= Convert(old.ShowTargetPortrait3D),
			castBar = {
				enable		= Convert(old.ArcaneBarTarget),
			},
			hitIndicator		= Convert(old.TargetCombatHitIndicator),			-- 2.1.7
			classIcon		= Convert(old.ShowTargetClassIcon),
			classText		= Convert(old.ShowTargetClassText),			-- 2.0.6
			mobType			= Convert(old.ShowTargetMobType),
			level			= Convert(old.ShowTargetLevel),
			elite			= Convert(ceil((old.ShowTargetElite or 1) / 2)),
			eliteGfx		= Convert(floor((old.ShowTargetElite or 1) / 2)),
			mana			= Convert(old.ShowTargetMana),
			percent			= Convert(old.ShowTargetPercent),
			values			= Convert(old.ShowTargetValues),
			combo = {
				enable		= Convert(old.UseCPMeter),
				blizzard	= Convert(old.BlizzardCPMeter),
				pos		= old.BlizzardCPPosition	or "top",
			},
			pvpIcon			= Convert(old.ShowTargetPVP),			-- 1.8.3
			scale			= old.Scale_TargetFrame		or 0.8,
			buffs = {
				enable		= 1,
				wrap		= 1,
				above		= Convert(old.TargetBuffsAbove),
				size		= old.TargetBuffSize		or 15,
				rows		= old.TargetBuffRows		or 3,
				castable	= old.TargetCastableBuffs	or 0,
			},
			debuffs = {
				enable		= 1,
				curable		= old.TargetCurableDebuffs	or 0,
				size		= old.TargetBuffSize		or 19,
				big		= 1,						-- 2.3.6
			},
			reactionHighlight	= Convert(old.TargetReactionHighlight),			-- 1.8.6
			healerMode = {
				enable		= Convert(old.HealerModeTarget),		-- 1.9.1
				type		= old.HealerModeTargetType	or 1,		-- 1.9.1
			},
			defer			= Convert(old.TargetChangeDefer),			-- 1.9.5
			size = {
				width		= old.TargetWidthBonus		or 0,
			},
			sound			= Convert(old.TargetSounds or 1),		-- 2.2.6
		},
		focus = {
			enable			= Convert(old.ShowFocus),
			portrait		= Convert(old.ShowFocusPortrait),
			portrait3D		= Convert(old.ShowFocusPortrait3D),
			castBar = {
				enable		= Convert(old.ArcaneBarFocus),
			},
			hitIndicator		= Convert(old.FocusCombatHitIndicator),			-- 2.1.7
			classIcon		= Convert(old.ShowFocusClassIcon),
			classText		= Convert(old.ShowFocusClassText),			-- 2.0.6
			mobType			= Convert(old.ShowFocusMobType),
			level			= Convert(old.ShowFocusLevel),
			elite			= Convert(ceil((old.ShowFocusElite or 1) / 2)),
			eliteGfx		= Convert(floor((old.ShowFocusElite or 1) / 2)),
			mana			= Convert(old.ShowFocusMana),
			percent			= Convert(old.ShowFocusPercent),
			values			= Convert(old.ShowFocusValues),
			pvpIcon			= Convert(old.ShowFocusPVP),			-- 1.8.3
			scale			= old.Scale_FocusFrame		or 0.8,
			buffs = {
				enable		= 1,
				wrap		= 1,
				above		= Convert(old.FocusBuffsAbove),
				size		= old.FocusBuffSize		or 15,
				rows		= old.FocusBuffRows		or 3,
				castable	= old.FocusCastableBuffs	or 0,
				curable		= old.FocusCurableDebuffs	or 0,
			},
			debuffs = {
				enable		= 1,
				size		= old.FocusBuffSize		or 19,
				curable		= old.TargetCurableDebuffs	or 0,
			},
			reactionHighlight	= Convert(old.FocusReactionHighlight),			-- 1.8.6
			healerMode = {
				enable		= Convert(old.HealerModeFocus),				-- 1.9.1
				type		= old.HealerModeFocusType	or 1,			-- 1.9.1
			},
			defer			= Convert(old.TargetChangeDefer),			-- 1.9.5
			size = {
				width		= old.FocusWidthBonus		or 0,
			},
		},
		targettarget = {
			enable			= Convert(old.ShowTargetTarget),
			buffs = {
				enable		= Convert(old.TargetTargetBuffs),
				above		= Convert(old.TargetTargetBuffsAbove),
				size		= old.FocusBuffSize		or 15,
				rows		= old.FocusBuffRows		or 3,
				castable	= old.TargetCastableBuffs	or 0,
				curable		= old.TargetCurableDebuffs	or 0,
				wrap		= 1,			-- 2.3.5
			},
			debuffs = {
				enable		= Convert(old.TargetTargetBuffs),
				size		= old.FocusBuffSize		or 19,
			},
			scale			= old.Scale_TargetTargetFrame	or 0.8,
			percent			= Convert(old.ShowTargetTargetPercent),
			values			= Convert(old.ShowTargetTargetValues),
			level			= Convert(old.ShowTargetTargetLevel),
			mana			= Convert(old.ShowTargetTargetMana),
			size = {
				width		= old.TargetTargetWidthBonus	or 0,
			},
		},
		targettargettarget = {
			enable			= Convert(old.ShowTargetTargetTarget),
			buffs = {
				enable		= Convert(old.TargetTargetTargetBuffs),
				above		= Convert(old.TargetTargetBuffsAbove),
				size		= old.FocusBuffSize		or 15,
				rows		= old.FocusBuffRows		or 3,
				castable	= old.TargetCastableBuffs	or 0,
				curable		= old.TargetCurableDebuffs	or 0,
			},
			debuffs = {
				enable		= Convert(old.TargetTargetBuffs),
				size		= old.FocusBuffSize		or 19,
			},
			scale			= old.Scale_TargetTargetFrame	or 0.8,
			percent			= Convert(old.ShowTargetTargetPercent),
			values			= Convert(old.ShowTargetTargetValues),
			level			= Convert(old.ShowTargetTargetLevel),
			mana			= Convert(old.ShowTargetTargetMana),
			size = {
				width		= old.TargetTargetWidthBonus	or 0,
			},
		},
		focustarget = {
			enable			= Convert(old.ShowFocusTarget),
			buffs = {
				enable		= Convert(old.FocusTargetBuffs),
				above		= Convert(old.FocusTargetBuffsAbove),
				size		= old.FocusBuffSize		or 15,
				rows		= old.FocusBuffRows		or 3,
				castable	= old.TargetCastableBuffs	or 0,
				curable		= old.TargetCurableDebuffs	or 0,
				wrap		= 1,			-- 2.3.5
			},
			debuffs = {
				enable		= Convert(old.TargetTargetBuffs),
				size		= old.FocusBuffSize		or 19,
			},
			scale			= old.Scale_FocusTargetFrame	or 0.8,
			percent			= Convert(old.ShowFocusTargetPercent),
			values			= Convert(old.ShowFocusTargetValues),
			level			= Convert(old.ShowFocusTargetLevel),
			mana			= Convert(old.ShowFocusTargetMana),
			size = {
				width		= old.FocusTargetWidthBonus	or 0,
			},
		},
		pettarget = {
			enable			= Convert(old.ShowPetTarget),
			buffs = {
				enable		= Convert(old.PlayerPetTargetBuffs),
				above		= Convert(old.PlayerPetTargetBuffsAbove),
				size		= old.TargetBuffSize		or 15,
				rows		= old.TargetBuffRows		or 3,
				castable	= old.TargetCastableBuffs	or 0,
				curable		= old.TargetCurableDebuffs	or 0,
				wrap		= 1,			-- 2.3.5
			},
			debuffs = {
				enable		= Convert(old.TargetTargetBuffs),
				size		= old.TargetBuffSize		or 19,
			},
			scale			= old.Scale_PlayerPetTargetFrame or 0.8,
			percent			= Convert(old.ShowPlayerPetTargetPercent),
			values			= Convert(old.ShowPlayerPetTargetValues),
			level			= Convert(old.ShowPlayerPetTargetLevel),
			mana			= Convert(old.ShowPlayerPetTargetMana),
			size = {
				width		= old.FocusTargetWidthBonus	or 0,
			},
		},
		party = {
			enable			= 1,
			castBar = {
				enable		= Convert(old.ArcaneBarParty),
			},
			spacing			= old.PartySpacing		or 23,
			anchor			= old.PartyAnchor		or "TOP",
			portrait		= Convert(old.ShowPartyPortrait),
			portrait3D		= Convert(old.ShowPartyPortrait3D),
			target = {
				enable		= Convert(old.ShowPartyTarget),
				large		= Convert(old.PartyTargetLarge),
				size		= old.PartyTargetSize		or 120,			-- 2.0.9
			},
			level			= Convert(old.ShowPartyLevel),
			name			= Convert(old.ShowPartyNames),
			values			= Convert(old.ShowPartyValues),
			percent			= Convert(old.ShowPartyPercent),
			classIcon		= Convert(old.ShowPartyClassIcon),
			pvpIcon			= Convert(old.ShowPartyPVP),			-- 1.8.3
			inRaid			= Convert(old.ShowPartyRaid),
			buffs = {
				wrap		= 1,
				enable		= Convert(old.PartyBuffs),
				size		= old.PartyBuffSize		or 22,
				castable	= old.PartyCastableBuffs	or 0,
				rows		= 2,
			},
			debuffs = {
				enable		= Convert(old.PartyDebuffs),
				size		= old.PartyBuffSize		or 32,
				curable		= old.PartyCurableDebuffs	or 0,
				halfSize	= Convert(old.PartyDebuffsHalfSize),			-- 2.2.6
				below		= Convert(old.PartyDebuffsBelow),
			},
			scale			= old.Scale_PartyFrame		or 0.8,
			healerMode = {
				enable		= Convert(old.HealerModeParty),			-- 1.9.1
				type		= old.HealerModePartyType	or 1,			-- 1.9.1
			},
			hitIndicator		= Convert(old.PartyCombatHitIndicator),			-- 2.1.7
			size = {
				width		= old.PartyWidthBonus		or 0,
			},
			flip			= Convert(old.PartyFlip),			-- 2.2.7
		},
		partypet = {
			enable			= Convert(old.ShowPartyPets),
			scale			= old.Scale_PartyPets		or 0.7,
			name			= Convert(old.ShowPartyPetName),
			buffs = {
				enable		= Convert(old.ShowPartyPetBuffs),
				castable	= old.PartyCastableBuffs	or 0,
				size		= 12,
			},
			debuffs = {
				enable		= Convert(old.ShowPartyPetBuffs),
				curable		= old.PartyCurableDebuffs	or 0,
			},
			mana			= Convert(old.ShowPartyPetMana),			-- 1.9.1
			level			= Convert(old.ShowPartyPetLevel),			-- 1.9.1
		},
		raid = {
			enable			= Convert(old.ShowRaid),
			sortByClass		= Convert(old.SortRaidByClass),
			sortByRole		= Convert(old.sortByRole),
			sortAlpha		= Convert(old.SortRaidAlpha),
			group = {
				Convert(old.ShowGroup1),
				Convert(old.ShowGroup2),
				Convert(old.ShowGroup3),
				Convert(old.ShowGroup4),
				Convert(old.ShowGroup5),
				Convert(old.ShowGroup6),
				Convert(old.ShowGroup7),
				Convert(old.ShowGroup8),
				Convert(old.ShowGroup9),
			},
			class = {
				{enable = Convert(old.RaidClass1Enable), name = old.RaidClass1 or "WARRIOR"},
				{enable = Convert(old.RaidClass2Enable), name = old.RaidClass2 or "ROGUE"},
				{enable = Convert(old.RaidClass3Enable), name = old.RaidClass3 or "HUNTER"},
				{enable = Convert(old.RaidClass4Enable), name = old.RaidClass4 or "MAGE"},
				{enable = Convert(old.RaidClass5Enable), name = old.RaidClass5 or "WARLOCK"},
				{enable = Convert(old.RaidClass6Enable), name = old.RaidClass6 or "PRIEST"},
				{enable = Convert(old.RaidClass7Enable), name = old.RaidClass7 or "DRUID"},
				{enable = Convert(old.RaidClass8Enable), name = old.RaidClass8 or "SHAMAN"},
				{enable = Convert(old.RaidClass9Enable), name = old.RaidClass9 or "PALADIN"},
				{enable = true, name = "DEATHKNIGHT"},
				{enable = true, name = "MONK"},
			},
			titles			= Convert(old.ShowRaidTitles),
			percent			= Convert(old.ShowRaidPercents),
			scale			= old.Scale_Raid		or 0.8,
			buffs = {
				enable		= Convert(old.RaidBuffs),
				castable	= old.BuffsCastableCurable	or 0,
				right		= Convert(old.RaidBuffsRight),
				inside		= Convert(old.RaidBuffsInside),
				untilDebuffed	= Convert(old.RaidBuffsUntilDebuffed),			-- 2.1.3
			},
			debuffs = {
				enable		= old.RaidDebuffs		or 0,
			},
			mana			= Convert(old.RaidMana),
			healerMode = {
				enable		= Convert(old.HealerModeRaid),
				type		= old.HealerModeRaidType	or 1,
			},
			spacing			= old.RaidVerticalSpacing	or 0,
			anchor			= old.RaidAnchor		or "TOP",
		},
		raidpet = {
			enable			= Convert(old.ShowRaidPets),				-- 2.1.3
			hunter			= Convert(old.ShowRaidPetsHunter),			-- 2.1.3
			warlock			= Convert(old.ShowRaidPetsWarlock),			-- 2.1.3
		},
		savedPositions = XPerl_CopyTable(old.SavedPositions),
	}

	return new
end

end




-------------------------------------------------------------------------------------
---------------------------------- DEFAULT CONFIGS ----------------------------------
-------------------------------------------------------------------------------------

local defaultConfig = {}


-- XPerl_RegisterConfigDefault
local function XPerl_RegisterConfigDefault(configFunc, configSection)
	tinsert(defaultConfig, {func = configFunc, section = configSection})
end

local function XPerl_MakeDefaultConfig(new)
	for k,v in pairs(defaultConfig) do
		v.func(new, v.section)
	end
end

-- XPerl_Options_Defaults()
function XPerl_Options_Defaults(new)
	XPerl_MakeDefaultConfig(new)
end


-- XPerl_Global_ConfigDefault
local function XPerl_Global_ConfigDefault(default)
	-- Defaults for global options

	if (not default) then
		error("Usage: XPerl_Global_ConfigDefault(<table>)")
		return
	end

	default.transparency = {
		frame		= 1,
		text		= 1,
	}

	default.highlightSelection	= 1
	default.combatFlash	= 1
	default.maximumScale	= 1.5
	default.optionsColour	= {r = 0.7, g = 0.2, b = 0.2}	-- 1.8.3
	default.showAFK		= 1				-- 2.2.4
	default.xperlOldroleicons = 1

	default.minimap = {
		pos		= 186,
		enable		= 1,
	}

	default.buffs = {
		cooldown	= 1,			-- 2.2.3
		countdown	= 1,			-- 2.2.2
		countdownStart	= 20,			-- 2.2.2
	}

	default.rangeFinder = XPerl_DefaultRangeFinder()

	default.tooltip = {
		enable		= 1,			-- 2.0.5
		enableBuffs	= 1,			-- 2.3.4a
--		fading		= nil,			-- 1.8.3
--		xperlInfo	= nil,			-- 1.8.6
		modifier	= "all",		-- 2.0.6
	}

	default.colour = {
		border		= {r = 0.5, g = 0.5, b = 0.5, a = 1},
		frame		= {r = 0, g = 0, b = 0, a = 1},
		class		= 1,
		guildList	= 1,		-- 1.8.9
		classic		= 1,
		bar		= XPerl_DefaultBarColours(),
		reaction	= XPerl_DefaultReactionColours(),
		gradient	= XPerl_DefaultGradientColours(),
	}

	default.bar = {
		texture		= {"Perl v2", "Interface\\Addons\\XPerl\\Images\\XPerl_StatusBar"},
		background	= 1,
		fat		= 1,
--		inverse		= nil,		-- 1.8.6
	}

	default.highlight = {
		enable			= 1,
		HOT			= 1,
		AGGRO			= 1,
--		MISSING			= nil,
--		all			= nil,
	}

end

-- XPerl_Target_ConfigDefault
local function XPerl_Target_ConfigDefault(default, section)
	default[section] = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons(section),
		portrait		= 1,
		portrait3D		= 1,
		castBar = {
			enable		= 1,
		},
		hitIndicator	= 1,			-- 2.1.7
		threat			= 1,
		threatMode		= "portraitFrame",
		classIcon		= 1,
--		classText		= nil,			-- 2.0.6
		mobType			= 1,
		level			= 1,
		elite			= 1,
--		eliteGfx		= nil,
		mana			= 1,
		percent			= 1,
		values			= 1,
		combo = {
			enable		= 1,
			blizzard	= 1,
			pos		= "top",
		},
		pvpIcon			= 1,			-- 1.8.3
		scale			= 0.8,
		buffs = {
			enable		= 1,
			wrap		= 1,
--			above		= nil,
			size		= 22,
			rows		= 3,
			castable	= 0,
		},
		debuffs = {
			enable		= 1,
			size		= 29,
			curable		= 0,
			big		= 1,			-- 2.3.6
		},
--		reactionHighlight	= nil,			-- 1.8.6
		healerMode = {
--			enable		= nil,			-- 1.9.1
			type		= 1,			-- 1.9.1
		},
--		defer			= nil,			-- 1.9.5
		size = {
			width		= 0,
		},
		sound			= 1,			-- 2.2.6
	}
end

-- XPerl_Party_ConfigDefault
local function XPerl_Party_ConfigDefault(default)
	default.party = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("party"),
		castBar = {
			enable		= 1,
		},
		spacing			= 23,
		anchor			= "TOP",
		portrait		= 1,
		portrait3D		= 1,
		hitIndicator	= 1,			-- 2.1.7
		threat			= 1,
		threatMode		= "portraitFrame",
		target = {
			enable		= 1,
			large		= 1,
			size		= 120,			-- 2.0.9
			icons		= XPerl_DefaultStatusIcons("partytarget"),
		},
		level			= 1,
		name			= 1,
		values			= 1,
		percent			= 1,
		classIcon		= 1,
		pvpIcon			= 1,			-- 1.8.3
		inRaid			= 1,
		buffs = {
			enable		= 1,
			wrap		= 1,			-- 2.3.5
			size		= 22,
			castable	= 0,
			rows		= 2,
		},
		debuffs = {
			enable		= 1,
			size		= 32,
			curable		= 0,
			halfSize	= 1,			-- 2.2.6
			below		= 1,
		},
		scale			= 0.8,
		healerMode = {
--			enable		= nil,			-- 1.9.1
			type		= 1,			-- 1.9.1
		},
		size = {
			width		= 0,
		},
--		flip			= nil,			-- 2.2.7
	}
end

-- XPerl_PartyPet_ConfigDefault
local function XPerl_PartyPet_ConfigDefault(default)
	default.partypet = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("partypet"),
		scale			= 0.7,
		name			= 1,
		buffs = {
			enable		= 1,
			castable	= 0,
			size		= 12,
		},
		debuffs = {
			enable		= 1,
			curable		= 0,
			size		= 12,
		},
--		mana			= nil,			-- 1.9.1
--		level			= nil,			-- 1.9.1
	}
end

-- XPerl_Player_ConfigDefault
local function XPerl_Player_ConfigDefault(default)
	default.player = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("player"),
		targetCounter	= 1,
		targetCounterHealers = 1,
		castBar = {
			enable		= 1,
--			original	= nil,
--			castTime	= nil,
		},
		portrait		= 1,
		portrait3D		= 1,
		hitIndicator	= 1,
		threat			= 1,
		threatMode		= "portraitFrame",
		level			= 1,
		classIcon		= 1,
--		xpBar			= nil,
--		repBar			= nil,
		pvpIcon			= 1,
		values			= 1,
		percent			= 1,
		scale			= 0.9,
		partyNumber		= 1,
--		withName		= nil,
		showRunes		= 1,
		dockRunes		= 1,

		fullScreen = {
			enable		= 1,
		},

		healerMode = {
--			enable		= nil,
			type		= 1,
		},

		buffs = {
			enable		= 1,
--			above		= nil,
			size		= 25,
			wrap		= 1,			-- 2.3.5
			rows		= 2,			-- 2.3.5
			hideBlizzard	= 1,
			count		= 40,
			cooldown	= 1,
		},
		debuffs = {
			enable		= 1,
			size		= 25,
		},
		size = {
			width		= 0,
		},
	}
end

-- XPerl_Pet_ConfigDefault
local function XPerl_Pet_ConfigDefault(default)
	default.pet = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("pet"),
		castBar = {
			enable		= 1,
		},
		portrait		= 1,
		portrait3D		= 1,
		hitIndicator	= 1,
		threat			= 1,
		threatMode		= "portraitFrame",
		level			= 1,
		scale			= 0.7,
		name			= 1,
		buffs = {
			enable		= 1,
			size		= 18,
			rows		= 2,
		},
		debuffs = {
			enable		= 1,
			size		= 20,
		},
		values			= 1,
		healerMode = {
--			enable		= nil,
			type		= 1,
		},
		size = {
			enable		= 1,
			width		= 0,
			size		= 20,
		},
	}
end

-- XPerl_TargetTarget_ConfigDefault
local function XPerl_TargetTarget_ConfigDefault(default, section)
	local e
	if (section ~= "targettargettarget") then
		e = 1
	end

	default[section] = {
		enable			= e,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons(section),
		buffs = {
			enable		= 1,
--			above		= nil,
			size		= 22,
			rows		= 3,
			castable	= 0,
			wrap		= 1,			-- 2.3.5
		},
		debuffs = {
			size		= 29,
			enable		= 1,
			curable		= 0,
		},
		scale			= 0.7,
		pvpIcon			= 1,
		percent			= 1,
		values			= 1,
--		level			= nil,
		mana			= 1,
		size = {
			width		= 0,
		},
		healerMode = {
--			enable		= nil,			-- 1.9.1
			type		= 1,			-- 1.9.1
		},
	}
end

-- XPerl_Raid_ConfigDefault
local function XPerl_Raid_ConfigDefault(default)
	default.raid = {
		enable			= 1,
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("raid"),
--		sortByClass		= nil,
		sortByRole 		= 1,			-- 3.7.1 (stored as 0 before, which Lua counts as on too)
--		sortAlpha		= nil,
		group = {1, 1, 1, 1, 1, 1, 1, 1, 1,1},
		class = XPerl_DefaultRaidClasses(),
		titles			= 1,
		percent			= 1,
		precisionPercent = 1,
		precisionManaPercent = 1,
		scale			= 0.8,
		spacing			= 0,
		buffs = {
--			enable		= nil,
			castable	= 0,
			right		= 1,
			inside		= 1,
--			untilDebuffed	= nil,			-- 2.1.3
		},
		debuffs = {
			enable		= 1,
		},
--		mana			= nil,
		healerMode = {
--			enable		= nil,
			type		= 1,
		},
		anchor			= "TOP",
	}
end

-- XPerl_RaidPet_ConfigDefault
local function XPerl_RaidPet_ConfigDefault(default, section)
	default.raidpet = {
		enable			= 1,			-- 2.1.3
		healPrediction	= 1,
		icons			= XPerl_DefaultStatusIcons("raidpet"),
		hunter			= 1,			-- 2.1.3
		warlock			= 1,			-- 2.1.3
	}
end

-- Boss and arena frames (Units/Boss.lua, Units/Arena.lua): five frames each in a stack, spacing and growth
-- ("down" or "up") placing them below or above the first. The aura rows default to one row each so the
-- stack's spacing holds them.
local frameDefaults = {
	boss = function()
		return {
			enable			= 1,
			healPrediction	= 1,
			scale			= 0.8,
			spacing			= 46,
			growth			= "down",
			portrait		= 1,
--			portrait3D		= nil,
			castBar = {
				enable		= 1,
			},
			hitIndicator	= 1,
			level			= 1,
			elite			= 1,
--			eliteGfx		= nil,
--			mobType			= nil,
			mana			= 1,
			percent			= 1,
			values			= 1,
			icons			= XPerl_DefaultStatusIcons("boss"),
			buffs = {
				enable		= 1,
				wrap		= 1,
				size		= 18,
				rows		= 1,
				castable	= 0,
			},
			debuffs = {
				enable		= 1,
				size		= 22,
				curable		= 0,
				onlyMine	= 1,
			},
			healerMode = {
				type		= 1,
			},
			size = {
				width		= 0,
			},
		}
	end,
	arena = function()
		return {
			enable			= 1,
			healPrediction	= 1,
			icons			= XPerl_DefaultStatusIcons("arena"),
			scale			= 0.8,
			spacing			= 46,
			growth			= "down",
--			portrait		= nil,
			classIcon		= 1,			-- the specialization icon
			trinket			= 1,
			castBar = {
				enable		= 1,
			},
			hitIndicator	= 1,
			mana			= 1,
			percent			= 1,
			values			= 1,
			buffs = {
				enable		= 1,
				wrap		= 1,
				size		= 18,
				rows		= 1,
				bigStealable	= 1,
				castable	= 0,
			},
			debuffs = {
				enable		= 1,
				size		= 22,
				curable		= 0,
			},
			healerMode = {
				type		= 1,
			},
			size = {
				width		= 0,
			},
		}
	end,
}

-- XPerl_Options_FrameDefaults(key)
-- Fresh default settings of the boss or arena section (XPerl_ValidateSettings completes older sections)
function XPerl_Options_FrameDefaults(key)
	return frameDefaults[key]()
end

-- XPerl_BossArena_ConfigDefault
local function XPerl_BossArena_ConfigDefault(default)
	default.boss = frameDefaults.boss()
	default.arena = frameDefaults.arena()
end

XPerl_RegisterConfigDefault(XPerl_Global_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_Target_ConfigDefault, "target")
XPerl_RegisterConfigDefault(XPerl_Target_ConfigDefault, "focus")
XPerl_RegisterConfigDefault(XPerl_Party_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_PartyPet_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_Player_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_Pet_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_TargetTarget_ConfigDefault, "targettargettarget")
XPerl_RegisterConfigDefault(XPerl_TargetTarget_ConfigDefault, "targettarget")
XPerl_RegisterConfigDefault(XPerl_TargetTarget_ConfigDefault, "focustarget")
XPerl_RegisterConfigDefault(XPerl_TargetTarget_ConfigDefault, "pettarget")
XPerl_RegisterConfigDefault(XPerl_Raid_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_RaidPet_ConfigDefault)
XPerl_RegisterConfigDefault(XPerl_BossArena_ConfigDefault)


-- XPerl_DefaultGradientColours
function XPerl_DefaultGradientColours()
	return {
		enable		= 1,
--		horizontal	= nil,
		s		= {r = 0.25, g = 0.25, b = 0.25, a = 1},
		e		= {r = 0.1, g = 0.1, b = 0.1, a = 0}
	}
end

-- XPerl_DefaultReactionColours
function XPerl_DefaultReactionColours()
	return {
		enemy		= {r = 1, g = 0, b = 0},
		neutral		= {r = 1, g = 1, b = 0},
		unfriendly	= {r = 1, g = 0.5, b = 0},
		friend		= {r = 0, g = 1, b = 0},
		none		= {r = 0.5, g = 0.5, b = 1},
		tapped		= {r = 0.5, g = 0.5, b = 0.5},
	}
end

-- XPerl_DefaultBarColours
function XPerl_DefaultBarColours()
	return {
		healthEmpty	= {r = 1, g = 0, b = 0},
		healthFull	= {r = 0, g = 1, b = 0},
		mana		= {r = 0, g = 0, b = 1},
		energy		= {r = 1, g = 1, b = 0},
		rage		= {r = 1, g = 0, b = 0},
		focus		= {r = 1, g = 0.5, b = 0.25},
		runic_power	= {r = 0, g = 0.82, b = 1},
	}
end

-- XPerl_DefaultFrameAppearance
function XPerl_DefaultFrameAppearance()
	XPerlDB.transparency.frame	= 1
	XPerlDB.transparency.text	= 1
	XPerlDB.colour.border		= {r = 0.5, g = 0.5, b = 0.5, a = 1}
	XPerlDB.colour.frame		= {r = 0, g = 0, b = 0, a = 1}
end

-- XPerl_DefaultRangeFinder
function XPerl_DefaultRangeFinder()
	return {						-- 2.1.7
--		enabled		= e,	-- 2.3.4a Defaulting to OFF now, because of so many confused users complaining about faded frames. RTFM... (TODO: Write a manual)
		Main		= {enabled = true, FadeAmount = 0.5},
		NameFrame	= {FadeAmount = 0.5},
		StatsFrame	= {FadeAmount = 0.5},
	}
end


----------------------------------------------
-------------- UPGRADE SETTINGS --------------
----------------------------------------------

-- Run once by the core's ADDON_LOADED settings setup, which then drops XPerl_Options_UpgradeSettings
do
	local flist = {"player", "pet", "target", "targettarget", "pettarget", "focus", "focustarget", "targettargettarget", "party", "partypet"}
	-- UpgradeSettings
	-- For future upgrade of settings from old versions
	local function UpgradeSettings(old, oldVersion)
		if (not old.pet) then
			old.pet = {}
			XPerl_Pet_ConfigDefault(old)
		elseif (not old.pet.castBar) then
			old.pet.castBar = {enable = 1}
		end

		local playerClass = select(2, UnitClass("player"))

		if (type(oldVersion) == "string") then
			for k,v in pairs(flist) do
				if (old[v]) then
					if (not old[v].buffs) then
						old[v].buffs = {enable = 1, size = 20, wrap = 1}
					elseif (not old[v].buffs.size) then
						old[v].buffs.size = 20
					end
					if (not old[v].debuffs) then
						old[v].debuffs = {enable = 1, size = 20, wrap = 1}
					elseif (not old[v].debuffs.size) then
						old[v].debuffs.size = 20
					end
				end
			end

			if (not old.colour.bar.runic_power or old.colour.bar.runic_power[1]) then
				if (PowerBarColor) then
					old.colour.bar.runic_power	= {r = PowerBarColor["RUNIC_POWER"].r, g = PowerBarColor["RUNIC_POWER"].g, b = PowerBarColor["RUNIC_POWER"].b}
				else
					old.colour.bar.runic_power	= {r = 1, g = 0.25, b = 1}
				end
			end

			if (old.raid) then
				XPerl_ValidateRaidClasses(old.raid)
			end

			if (old.bar and old.bar.texture and old.bar.texture[1] == "X-Perl 2") then
				old.bar.texture[1] = "BantoBar"
			end

			if (oldVersion < "3.0.2") then
				old.focus.threat = old.target.threat
				old.focus.threatMode = old.focus.portrait and old.target.threatMode or "nameFrame"
				old.party.threat = old.target.threat
				old.party.threatMode = old.party.portait and old.target.threatMode or "nameFrame"
			end

			if (oldVersion < "3.0.0c") then
				old.target.threat = 1
				old.target.threatMode = "portraitFrame"
				old.focus.threat = 1
				old.focus.threatMode = "portraitFrame"
				old.party.threat = 1
				old.party.threatMode = "portraitFrame"
				old.pet.threat = 1
				old.pet.threatMode = "portraitFrame"
			end

			if (oldVersion < "3.0.0") then
				old.player.showRunes = 1
				old.player.dockRunes = 1
			end

			if (oldVersion < "2.4.2c") then
				old.highlight.sparkles = 1
			end

			if (oldVersion <= "2.3.9a") then
				old.player.debuffs.enable = old.player.buffs.enable
			end

			if (oldVersion <= "2.3.9") then
				old.showReadyCheck = 1
			end

			if (oldVersion <= "2.3.6a") then
				old.target.buffs.wrap = 1
				old.targettarget.buffs.wrap = 1
				old.targettargettarget.buffs.wrap = 1
				old.pettarget.buffs.wrap = 1
				old.focus.buffs.wrap = 1
				old.focustarget.buffs.wrap = 1
				old.party.buffs.wrap = 1

				-- These should have been defaulted to OFF, oops
				old.targettarget.debuffs.big = nil
				old.targettargettarget.debuffs.big = nil
				old.focustarget.debuffs.big = nil
				old.pettarget.debuffs.big = nil
			end
			if (oldVersion <= "2.3.6") then
				old.target.debuffs.big = 1
				old.focus.debuffs.big = 1
				old.player.buffs.rows = 2
				old.party.buffs.rows = 2
			end

			if (oldVersion < "2.3.5") then
				old.target.range30yard	= nil
				old.focus.range30yard	= nil
				old.raid.manaPercent = 1

				old.highlight.MISSING = nil
				if (playerClass == "PRIEST" or playerClass == "DRUID" or playerClass == "PALADIN" or playerClass == "SHAMAN") then
					old.highlight.HOTCOUNT = 1
				end
			end

			if (oldVersion < "2.3.4a") then
				old.tooltip.enableBuffs = 1
			end

			if (oldVersion < "3.1.0") then
				old.ShowTutorials = nil
				old.TutorialFlags = nil
			end

			if (oldVersion < "3.1.2") then
				old.xperlOldroleicons = 1
			end
			
			if (oldVersion < "3.7.1") then
				old.raid.sortByRole = 1
			end
			
			if (oldVersion < "3.7.3") then
				old.raid.precisionPercent = 1
				old.raid.precisionManaPercent = 1
			end
			
			if (oldVersion < "3.7.5") then
				old.targettargettarget.debuffs.enable = old.targettargettarget.buffs.enable;
				old.pettarget.debuffs.enable = old.pettarget.buffs.enable;
				old.focustarget.debuffs.enable = old.focustarget.buffs.enable;
			end
		end
	end

	-- XPerl_Options_UpgradeSettings()
	function XPerl_Options_UpgradeSettings()
		local oldVersion = XPerlConfigNew.ConfigVersion

		-- Global config upgrade checks here:
		if (type(oldVersion) == "string" and oldVersion < "2.3.2d") then
			if (XPerlConfigNew.savedPositions and XPerlConfigNew.savedPositions.current) then
				for name,settings in pairs(XPerlConfigNew.savedPositions) do
					if (name ~= "saved" and name ~= "current") then
						if (not XPerlConfigNew.savedPositions.saved) then
							XPerlConfigNew.savedPositions.saved = {}
						end
						XPerlConfigNew.savedPositions.saved[name] = settings
						XPerlConfigNew.savedPositions[name] = nil
					end
				end

				local realm, name = GetRealmName(), UnitName("player")
				if (not XPerlConfigNew.savedPositions[realm]) then
					XPerlConfigNew.savedPositions[realm] = {}
				end
				XPerlConfigNew.savedPositions[realm][name] = XPerlConfigNew.savedPositions.current
				XPerlConfigNew.savedPositions.current = nil
			end
		end

		for realmName,realmList in pairs(XPerlConfigNew) do
			if (type(realmList) == "table" and not XPerl_ConfigReservedKeys[realmName]) then
				for playerName,settings in pairs(realmList) do
					if (playerName == "global") then
						-- Fix global settings being put in with realms
						if (not XPerlConfigNew.global) then
							XPerlConfigNew.global = settings
							UpgradeSettings(settings, oldVersion)
						end
						realmList.global = nil
					else
						UpgradeSettings(settings, oldVersion)
					end
				end
			end
		end

		UpgradeSettings = nil
		XPerl_Options_UpgradeSettings = nil
		flist = nil
	end
end
