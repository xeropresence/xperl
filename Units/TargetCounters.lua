-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Targeting counter: on the player frame the number of group members targeting you (all of them, or only
-- healers). Clicking the counter shows or hides the list in the targeting window (XPerl_TargetCounters).
-- player.targetCounter and player.targetCounterHealers are frame settings (per Edit Mode layout);
-- XPerlDB.targetCounters holds whether the window is open (targeting), its position and size.
--
-- 12.x secret values: on add-on restricted maps (instances) comparisons of compound unit tokens ("raid5target")
-- are secret. Members targeting you are still found through GUIDs: a token one step from a group member or a
-- pet has a readable GUID exactly when it is a player-controlled or grouped unit, so a secret GUID is never
-- you.

local conf
XPerl_RequestConfig(function(new) conf = new end, "$Revision$")

local PET = "*pet"				-- list "class" besides the player classes
local HEALER_CLASSES = {DRUID = true, EVOKER = true, MONK = true, PALADIN = true, PRIEST = true, SHAMAN = true}
local SCAN_DELAY, POLL_INTERVAL = 0.2, 0.5	-- after an event; without one (deaths, targets changed unseen)
local HIGHLIGHT = "Interface\\Addons\\XPerl\\Images\\XPerl_Highlight"

-- "<unit>target" tokens. Your own target is "target", not the compound "playertarget".
local targetOf = setmetatable({player = "target"}, {__index = function(t, unit)
	local token = unit.."target"
	t[unit] = token
	return token
end})
local raidUnits, raidPets, partyUnits, partyPets = {}, {}, {}, {}
for i = 1, 40 do
	raidUnits[i], raidPets[i] = "raid"..i, "raidpet"..i
end
for i = 1, 4 do
	partyUnits[i], partyPets[i] = "party"..i, "partypet"..i
end

local units, isPet = {}, {}				-- you, your pet, the other group members and their pets
local list = {n = 0}					-- members targeting you, {name =, class =, key =}, sorted
local lines = {}					-- display lines, a line per class
local counter						-- the player frame's counter button
local window
local myClass
local dirty, sinceScan = true, 0

------------------------------------------------------------------------------
-- Scanning
------------------------------------------------------------------------------

local function AddUnit(unit, pet)
	local n = #units + 1
	units[n], isPet[n] = unit, pet
end

local function BuildRoster()
	wipe(units)
	wipe(isPet)
	AddUnit("player", false)
	if (UnitExists("pet")) then
		AddUnit("pet", true)
	end
	if (IsInRaid()) then
		local me = UnitGUID("player")
		for i = 1, GetNumGroupMembers() do
			local unit = raidUnits[i]
			local guid = UnitGUID(unit)
			if (UnitExists(unit) and (issecretvalue(guid) or guid ~= me)) then
				AddUnit(unit, false)
				if (UnitExists(raidPets[i])) then
					AddUnit(raidPets[i], true)
				end
			end
		end
	else
		for i = 1, GetNumSubgroupMembers() do
			if (UnitExists(partyUnits[i])) then
				AddUnit(partyUnits[i], false)
				if (UnitExists(partyPets[i])) then
					AddUnit(partyPets[i], true)
				end
			end
		end
	end
end

local function Name(unit)
	local name = UnitName(unit)
	if (issecretvalue(name) or not name) then
		return UNKNOWN
	end
	return name
end

local function IsHealer(unit, class)
	local role = UnitGroupRolesAssigned(unit)
	if (not issecretvalue(role) and role and role ~= "NONE") then
		return role == "HEALER"
	end
	return HEALER_CLASSES[class]
end

-- Whether token (a group member's or pet's target) is you
local function IsPlayer(token, playerGUID)
	local same = UnitIsUnit(token, "player")
	if (not issecretvalue(same)) then
		return same
	end
	local guid = UnitGUID(token)
	return not issecretvalue(guid) and guid == playerGUID
end

local function Add(name, class)
	local n = list.n + 1
	list.n = n
	local entry = list[n]
	if (not entry) then
		entry = {}
		list[n] = entry
	end
	local rank = (class == PET and "3") or (class == myClass and "1") or "2"
	entry.name, entry.class, entry.key = name, class, rank..class..name
end

local function ByKey(a, b)
	return a.key < b.key
end

local function Colour(class)
	if (class == PET) then
		return "|cff8080ff"
	end
	return XPerlColourTable[class]
end

-- Sorts the list (dropping entries left from a longer one) and makes its display lines
local function Finish()
	for i = list.n + 1, #list do
		list[i] = nil
	end
	sort(list, ByKey)
	wipe(lines)
	local line, lastClass
	for i = 1, list.n do
		local entry = list[i]
		if (entry.class ~= lastClass) then
			if (line) then
				lines[#lines + 1] = line
			end
			line, lastClass = Colour(entry.class)..entry.name, entry.class
		else
			line = line.." "..entry.name
		end
	end
	if (line) then
		lines[#lines + 1] = line
	end
end

local function Scan()
	BuildRoster()
	local pconf = conf.player
	local healersOnly = pconf and pconf.targetCounterHealers
	local playerGUID = UnitGUID("player")
	list.n = 0

	for i = 1, #units do
		local unit, pet = units[i], isPet[i]
		local token = targetOf[unit]
		if (UnitExists(token) and not UnitIsDeadOrGhost(unit)) then
			local class = PET
			if (not pet) then
				local _, playerClass = UnitClass(unit)
				class = (not issecretvalue(playerClass) and playerClass) or ""
			end

			if ((not healersOnly or (not pet and IsHealer(unit, class))) and IsPlayer(token, playerGUID)) then
				Add(Name(unit), class)
			end
		end
	end

	Finish()
end

------------------------------------------------------------------------------
-- Display
------------------------------------------------------------------------------

local function Title()
	local pconf = conf.player
	local label = (pconf and pconf.targetCounterHealers) and XPERL_TARGETCOUNTER_HEALERS or XPERL_TARGETCOUNTER_TARGETING
	return format("%s: %d", label, list.n)
end

local function WindowSettings()
	local db = conf.targetCounters
	if (type(db) ~= "table") then
		db = {}
		conf.targetCounters = db
	end
	return db
end

local function RenderWindow()
	if (not (window and window:IsShown())) then
		return
	end
	local text = "|cffffffff"..Title().."|r"
	if (#lines > 0) then
		text = text.."\n"..table.concat(lines, "\n")
	end
	window.pane.text:SetText(text)
end

local function SaveWindow(self)
	self:StopMovingOrSizing()
	local db = WindowSettings()
	db.left, db.top, db.width, db.height = self:GetLeft(), self:GetTop(), self:GetWidth(), self:GetHeight()
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.left, db.top)
	if (self:IsUserPlaced()) then
		self:SetUserPlaced(false)
	end
end

local LayoutWindow

local function CloseWindow()
	WindowSettings().targeting = nil
	LayoutWindow()
end

local function CreateWindow()
	local db = WindowSettings()
	local w = CreateFrame("Frame", "XPerl_TargetCounters", UIParent, "BackdropTemplate")
	w.backdropInfo = XPERL_BACKDROP_FRAME
	w:ApplyBackdrop()
	w:SetFrameStrata("LOW")
	w:SetClampedToScreen(true)
	w:SetMovable(true)
	w:SetResizable(true)
	w:SetResizeBounds(140, 60, 800, 600)
	w:EnableMouse(true)
	w:RegisterForDrag("LeftButton")
	if (w.SetDontSavePosition) then
		w:SetDontSavePosition(true)
	end
	w:SetSize(db.width or 160, db.height or 120)
	if (db.left and db.top) then
		w:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.left, db.top)
	else
		w:SetPoint("CENTER")
	end
	w:SetScript("OnDragStart", w.StartMoving)
	w:SetScript("OnDragStop", SaveWindow)

	local title = w:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", 8, -8)
	title:SetText(XPERL_TARGETCOUNTER_WINDOW)

	local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
	close:SetSize(20, 20)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", CloseWindow)

	local grip = CreateFrame("Button", nil, w)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function() w:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function() SaveWindow(w) end)

	local pane = CreateFrame("Frame", nil, w)
	pane:SetClipsChildren(true)
	pane:SetPoint("TOPLEFT", 8, -24)
	pane:SetPoint("BOTTOMRIGHT", -8, 8)
	local text = pane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	text:SetPoint("TOPLEFT")
	text:SetPoint("TOPRIGHT")
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	pane.text = text
	w.pane = pane

	XPerl_RegisterPerlFrames(w)
	window = w
end

-- Shows the window while its list is open
function LayoutWindow()
	if (not WindowSettings().targeting) then
		if (window) then
			window:Hide()
		end
		return
	end
	if (not window) then
		CreateWindow()
	end
	window:Show()
	dirty = true
end

local function CounterOnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(Title(), 1, 1, 1)
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:AddLine(XPERL_TARGETCOUNTER_CLICK, 0.62, 0.38, 0)
	GameTooltip:Show()
end

local function CounterOnClick()
	local db = WindowSettings()
	db.targeting = not db.targeting or nil
	LayoutWindow()
end

local function RenderCounter()
	local n = list.n
	local alpha = conf.transparency.text
	local text = counter.text
	text:SetText(n)
	if (n < 1) then				-- targeting you: nobody is bad, more than five is plenty
		text:SetTextColor(1, 0.5, 0.5, alpha)
	elseif (n > 5) then
		text:SetTextColor(0.5, 1, 0.5, alpha)
	else
		text:SetTextColor(0.5, 0.5, 1, alpha)
	end
	if (GameTooltip:IsOwned(counter)) then
		CounterOnEnter(counter)
	end
end

local function Update()
	if (not myClass) then
		myClass = select(2, UnitClass("player"))
		LayoutWindow()		-- the list left open last time
	end

	local needed = window and window:IsShown()
	if (counter) then
		local frame = counter:GetParent()
		local c = frame.conf
		local on = (frame.active and c and c.targetCounter) and true or false
		counter:SetShown(on)
		needed = needed or on
	end
	if (not needed) then
		return
	end

	Scan()
	if (counter and counter:IsShown()) then
		RenderCounter()
	end
	RenderWindow()
end

------------------------------------------------------------------------------
-- Unit frame element and driver
------------------------------------------------------------------------------

-- The player frame's counter, left of the portrait (below the level)
local function CreateCounter(frame)
	local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
	button.backdropInfo = XPERL_BACKDROP_FRAME
	button:ApplyBackdrop()
	button:SetSize(27, 20)
	button:SetFrameLevel(frame.levelFrame:GetFrameLevel() + 1)
	button:SetPoint("TOPRIGHT", frame.portraitFrame, "TOPLEFT", 2, -19)

	local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetAllPoints()
	XPerl_RegisterUnitText(text)
	button.text = text

	button:SetHighlightTexture(HIGHLIGHT, "ADD")
	button:GetHighlightTexture():SetTexCoord(0, 0.25, 0, 0.5)
	button:SetScript("OnClick", CounterOnClick)
	button:SetScript("OnEnter", CounterOnEnter)
	button:SetScript("OnLeave", XPerl_PlayerTipHide)
	button:Hide()

	frame.targetCounter = button
	counter = button
end

XPerl_UnitFrame_DefineElement("targetCounter", {
	init = CreateCounter,
	apply = function()
		dirty = true
	end,
})

local driver = CreateFrame("Frame")
for _, event in ipairs({"GROUP_ROSTER_UPDATE", "UNIT_TARGET", "UNIT_PET", "PLAYER_TARGET_CHANGED",
		"PLAYER_ENTERING_WORLD", "PLAYER_ROLES_ASSIGNED"}) do
	if (not C_EventUtils or C_EventUtils.IsEventValid(event)) then
		driver:RegisterEvent(event)
	end
end
driver:SetScript("OnEvent", function()
	dirty = true
end)
driver:SetScript("OnUpdate", function(_, elapsed)
	sinceScan = sinceScan + elapsed
	if ((dirty and sinceScan >= SCAN_DELAY) or sinceScan >= POLL_INTERVAL) then
		sinceScan, dirty = 0, nil
		if (conf) then
			Update()
		end
	end
end)
