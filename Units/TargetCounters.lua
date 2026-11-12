-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Targeting counters. On the player frame the number of group members targeting you (all of them, or only
-- healers); on the target frame the number of group members, you and pets included, targeting your target.
-- Clicking a counter shows or hides its list in the targeting window (XPerl_TargetCounters).
-- player.targetCounter, player.targetCounterHealers and target.assistCounter are frame settings;
-- XPerlDB.targetCounters holds which lists the window shows (targeting, assisting), its position and size.
--
-- 12.x secret values: on add-on restricted maps (instances) comparisons of compound unit tokens ("raid5target")
-- are secret. A token one step from a group member or a pet has a readable GUID exactly when it is a
-- player-controlled or grouped unit, so a secret GUID is never you, nor a player-controlled target. Whether a
-- member targets the same mob as you stays hidden there; the target frame's counter shows "?" then.

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
-- The counted members, {name =, class =, key =} sorted, n of them, and their display lines (a line per class).
-- key: the window setting that shows the list; hidden: the game hides whether some members count.
local targeting = {n = 0, lines = {}, key = "targeting"}	-- targeting you
local assisting = {n = 0, lines = {}, key = "assisting"}	-- targeting your target
local counter, assistCounter			-- the player frame's and the target frame's counter buttons
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
	local name = XPerlAPI.UnitDisplayName(unit)
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

-- Whether token (a group member's or pet's target) is your target; nil when the game hides it.
-- targetGUID: your target's GUID (may be secret); targetControlled: your target is player-controlled
local function IsYourTarget(token, targetGUID, targetControlled)
	if (token == "target") then
		return true
	end
	local same = UnitIsUnit(token, "target")
	if (not issecretvalue(same)) then
		return same
	end
	local guid = UnitGUID(token)
	if (not issecretvalue(guid)) then
		-- A player-controlled or grouped unit; a secret target GUID is neither
		return not issecretvalue(targetGUID) and guid == targetGUID
	end
	if (targetControlled) then
		return false
	end
	return nil
end

local function Add(list, name, class)
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
local function Finish(list)
	for i = list.n + 1, #list do
		list[i] = nil
	end
	sort(list, ByKey)
	local lines = list.lines
	wipe(lines)
	if (list.hidden) then
		return
	end
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
	local hasTarget = UnitExists("target")
	local targetGUID, targetControlled
	if (hasTarget) then
		targetGUID = UnitGUID("target")
		targetControlled = UnitPlayerControlled("target")
		targetControlled = not issecretvalue(targetControlled) and targetControlled
	end
	targeting.n, assisting.n, assisting.hidden = 0, 0, nil

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
				Add(targeting, Name(unit), class)
			end
			if (hasTarget) then
				local same = IsYourTarget(token, targetGUID, targetControlled)
				if (same == nil) then
					assisting.hidden = true
				elseif (same) then
					Add(assisting, Name(unit), class)
				end
			end
		end
	end

	Finish(targeting)
	Finish(assisting)
end

------------------------------------------------------------------------------
-- Display
------------------------------------------------------------------------------

local function Title(list)
	if (list == assisting) then
		return format("%s: %s", XPERL_TARGETCOUNTER_ASSISTING, list.hidden and "?" or list.n)
	end
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

local function AddSection(text, list)
	if (text) then
		text = text.."\n\n"
	end
	text = (text or "").."|cffffffff"..Title(list).."|r"
	if (list.hidden) then
		text = text.."\n"..XPERL_TARGETCOUNTER_HIDDEN
	elseif (#list.lines > 0) then
		text = text.."\n"..table.concat(list.lines, "\n")
	end
	return text
end

local function RenderWindow()
	if (not (window and window:IsShown())) then
		return
	end
	local db = WindowSettings()
	local text
	if (db.targeting) then
		text = AddSection(text, targeting)
	end
	if (db.assisting) then
		text = AddSection(text, assisting)
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
	local db = WindowSettings()
	db.targeting, db.assisting = nil, nil
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

-- Shows the window while one of its lists is open
function LayoutWindow()
	local db = WindowSettings()
	if (not (db.targeting or db.assisting)) then
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
	local list = self.list
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(Title(list), 1, 1, 1)
	if (list.hidden) then
		GameTooltip:AddLine(XPERL_TARGETCOUNTER_HIDDEN, 1, 1, 1, true)
	end
	for _, line in ipairs(list.lines) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:AddLine(XPERL_TARGETCOUNTER_CLICK, 0.62, 0.38, 0)
	GameTooltip:Show()
end

local function CounterOnClick(self)
	local db = WindowSettings()
	local key = self.list.key
	db[key] = not db[key] or nil
	LayoutWindow()
end

-- RenderCounter(button, low, high): red below low members, green above high, blue between; grey while hidden
local function RenderCounter(button, low, high)
	local list = button.list
	local alpha = conf.transparency.text
	local text = button.text
	local n = list.n
	if (list.hidden) then
		text:SetText("?")
		text:SetTextColor(0.6, 0.6, 0.6, alpha)
	else
		text:SetText(n)
		if (n < low) then
			text:SetTextColor(1, 0.5, 0.5, alpha)
		elseif (n > high) then
			text:SetTextColor(0.5, 1, 0.5, alpha)
		else
			text:SetTextColor(0.5, 0.5, 1, alpha)
		end
	end
	if (GameTooltip:IsOwned(button)) then
		CounterOnEnter(button)
	end
end

-- Shows button while its frame is active and its setting is on
local function ShowCounter(button)
	if (not button) then
		return false
	end
	local frame = button:GetParent()
	local c = frame.conf
	local on = (frame.active and c and c[button.setting]) and true or false
	button:SetShown(on)
	return on
end

local function Update()
	if (not myClass) then
		myClass = select(2, UnitClass("player"))
		LayoutWindow()		-- the lists left open last time
	end

	local playerOn = ShowCounter(counter)
	local targetOn = ShowCounter(assistCounter)
	if (not (playerOn or targetOn or (window and window:IsShown()))) then
		return
	end

	Scan()
	if (playerOn) then
		RenderCounter(counter, 1, 5)		-- targeting you: nobody is bad, more than five is plenty
	end
	if (targetOn and UnitExists("target")) then
		RenderCounter(assistCounter, 2, #units / 2)	-- only you is bad, half the group is plenty
	end
	RenderWindow()
end

------------------------------------------------------------------------------
-- Unit frame elements and driver
------------------------------------------------------------------------------

local function CreateCounter(frame, list, setting)
	local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
	button.backdropInfo = XPERL_BACKDROP_FRAME
	button:ApplyBackdrop()
	button:SetSize(27, 20)
	button:SetFrameLevel(frame.levelFrame:GetFrameLevel() + 1)

	local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetAllPoints()
	XPerl_RegisterUnitText(text)
	button.text = text
	button.list, button.setting = list, setting

	button:SetHighlightTexture(HIGHLIGHT, "ADD")
	button:GetHighlightTexture():SetTexCoord(0, 0.25, 0, 0.5)
	button:SetScript("OnClick", CounterOnClick)
	button:SetScript("OnEnter", CounterOnEnter)
	button:SetScript("OnLeave", XPerl_PlayerTipHide)
	button:Hide()
	return button
end

local function MarkDirty()
	dirty = true
end

-- The player frame's counter, left of the portrait (below the level)
XPerl_UnitFrame_DefineElement("targetCounter", {
	init = function(frame)
		counter = CreateCounter(frame, targeting, "targetCounter")
		counter:SetPoint("TOPRIGHT", frame.portraitFrame, "TOPLEFT", 2, -19)
		frame.targetCounter = counter
	end,
	apply = MarkDirty,
})

-- The target frame's counter, right of the portrait (below the level; Units/Target.lua moves it into the
-- portrait while the elite graphic takes that side). The focus frame shares the target's elements and has none.
XPerl_UnitFrame_DefineElement("assistCounter", {
	init = function(frame)
		if (frame.frameKey == "target") then
			assistCounter = CreateCounter(frame, assisting, "assistCounter")
			assistCounter:SetPoint("TOPLEFT", frame.portraitFrame, "TOPRIGHT", -2, -19)
			frame.assistCounter = assistCounter
		end
	end,
	apply = MarkDirty,
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
