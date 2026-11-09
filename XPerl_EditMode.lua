-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Edit Mode integration (LibEditMode). Frame positions follow the active Edit Mode layout; the frame settings
-- (XPerl_FrameConfigKeys sections of XPerlDB) are the same in every layout, like the rest of XPerlDB.
--
-- Saved data, account-wide, in XPerlConfigNew.editMode:
--   layouts[layoutKey]       = {name = <layout name>, positions = {[posKey] = <position>},
--                               unlinked = {[leader frameKey] = true}}
--   lastLayout[realm][char]  = layoutKey in use when that character last played (used at login until the client
--                              reports the layout, so frames don't jump)
--   legacy[realm][char]      = {[frameName] = {top =, left =}}: positions from before Edit Mode support; they seed
--                              layouts that have no data yet
--   named[name]              = {[posKey] = <position>}: the options window's saved frame layouts
-- layoutKey: "preset:<n>", "account:<name>" or "character:<realm>/<character>/<name>" (character layouts of
-- different characters can share a name; realm and character from XPerlAPI.SettingsOwner). posKey: the frame
-- key, plus the index for several frames of one key.
-- <position> = {point =, relativePoint = (defaults to point), x =, y =}, relative to UIParent, in the frame's
-- own (scaled) units like SetPoint offsets. A frame its layout stores no position for sits at its default: the
-- XML anchor, moved along with the Blizzard frame it replaces where the layout moves that one (see MIRRORED).
--
-- Linked frames (raid groups 2-13, following group 1): a frame registered with info.leader moves with its leader
-- while the layout doesn't list the leader's key as unlinked. It is anchored to the leader, so a drag, nudge or
-- position reset of the leader (in Edit Mode or the options window's unlocked mode) takes it along, and its
-- stored position moves with the leader's. Moving a follower itself unlinks all of them; the "Link Raid Groups"
-- button of their dialogs (and the options window's, XPerl_EditMode_Link) links them again.

XPerl_SetModuleRevision("$Revision$")

local _, ns = ...
local LEM = LibStub("LibEditMode")
local FRAME_KEYS = XPerl_FrameConfigKeys

local frameKeySet = {}
for _, key in ipairs(FRAME_KEYS) do
	frameKeySet[key] = true
end

local registered = {}		-- frame -> {frameKey =, posKey =, info =, disabled =, leader =, followers =}
local order = {}			-- registered frames in registration order
local store					-- XPerlConfigNew.editMode
local activeKey, activeData	-- active layout; nil until the client reports it (and no last layout is stored)
local pendingPositions		-- positions in use while no layout is active
local pendingUnlinked		-- unlinked leaders while no layout is active
local realm, character
local loggedIn

-- Old savedPositions frame names: {frameKey, index, scaled}. scaled: the old position was divided by the frame
-- key's scale setting when restored (the undocked runes bar used its own scale of 1)
local LEGACY_FRAMES = {
	XPerl_Player = {"player", nil, true},
	XPerl_Runes = {"player", 2},
	XPerl_Player_Pet = {"pet", nil, true},
	XPerl_Target = {"target", nil, true},
	XPerl_Focus = {"focus", nil, true},
	XPerl_TargetTarget = {"targettarget", nil, true},
	XPerl_TargetTargetTarget = {"targettargettarget", nil, true},
	XPerl_FocusTarget = {"focustarget", nil, true},
	XPerl_PetTarget = {"pettarget", nil, true},
	XPerl_Party_Anchor = {"party", nil, true},
	XPerl_Raid_TitlePets = {"raidpet", nil, true},
}
-- Sections whose scale a frame key uses, where it isn't its own
local SCALE_SECTION = {raidpet = "raid"}

local function PosKey(frameKey, index)
	if (index) then
		return frameKey..index
	end
	return frameKey
end

-- Old absolute positions ({top, left} = GetTop()/GetLeft() * frame scale, i.e. UIParent units from the bottom
-- left corner) to positions relative to UIParent in frame units, using each frame's scale from `sections`.
local function ConvertLegacy(old, sections)
	local new = {}
	if (type(old) ~= "table") then
		return new
	end

	for frameName, pos in pairs(old) do
		local legacy = LEGACY_FRAMES[frameName]
		local frameKey, posKey, scaled
		if (legacy) then
			frameKey, posKey, scaled = legacy[1], PosKey(legacy[1], legacy[2]), legacy[3]
		else
			local index = strmatch(frameName, "^XPerl_Raid_Title(%d+)$")
			if (index) then
				frameKey, posKey, scaled = "raid", PosKey("raid", tonumber(index)), true
			end
		end

		if (frameKey and type(pos) == "table" and tonumber(pos.left) and tonumber(pos.top)) then
			local scale = 1
			if (scaled) then
				local section = sections and sections[SCALE_SECTION[frameKey] or frameKey]
				scale = type(section) == "table" and tonumber(section.scale) or 1
				if (scale <= 0) then
					scale = 1
				end
			end
			new[posKey] = {point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = pos.left / scale, y = pos.top / scale}
		end
	end
	return new
end

-- One-time move of the old per-character position store into the Edit Mode store
local function EnsureStore(sections)
	if (store) then
		return
	end

	store = XPerlConfigNew.editMode
	if (type(store) ~= "table") then
		store = {}
		XPerlConfigNew.editMode = store
	end
	store.layouts = store.layouts or {}
	store.lastLayout = store.lastLayout or {}
	store.legacy = store.legacy or {}
	store.named = store.named or {}

	local old = XPerlConfigNew.savedPositions
	if (type(old) == "table") then
		for realmName, list in pairs(old) do
			if (type(list) == "table") then
				if (realmName == "saved") then
					for name, frames in pairs(list) do
						if (store.named[name] == nil) then
							store.named[name] = ConvertLegacy(frames, sections)
						end
					end
				else
					store.legacy[realmName] = store.legacy[realmName] or {}
					for charName, frames in pairs(list) do
						store.legacy[realmName][charName] = frames
					end
				end
			end
		end
		XPerlConfigNew.savedPositions = nil
	end
end

local function SeedPositions()
	local list = store.legacy[realm]
	return ConvertLegacy(list and list[character], XPerlDB)
end

local function CurrentPositions()
	if (activeData) then
		return activeData.positions
	end
	if (not pendingPositions) then
		pendingPositions = SeedPositions()
	end
	return pendingPositions
end

-- The active layout's unlinked leaders ([leader frameKey] = true); created when `create` is set
local function CurrentUnlinked(create)
	if (activeData) then
		if (create and not activeData.unlinked) then
			activeData.unlinked = {}
		end
		return activeData.unlinked
	end
	if (create and not pendingUnlinked) then
		pendingUnlinked = {}
	end
	return pendingUnlinked
end

-- A new layout's data: a copy of `source`'s, or else what was in use while no layout was active (seeded from
-- this character's old positions)
local function NewLayoutData(name, source)
	if (source) then
		return {name = name, positions = XPerl_CopyTable(source.positions) or {}, unlinked = XPerl_CopyTable(source.unlinked)}
	end
	return {name = name, positions = XPerl_CopyTable(pendingPositions) or SeedPositions(), unlinked = XPerl_CopyTable(pendingUnlinked)}
end

local function SetLastLayout(key)
	local list = store.lastLayout[realm]
	if (not list) then
		list = {}
		store.lastLayout[realm] = list
	end
	list[character] = key
end

------------------------------------------------------------------------------
-- Frame settings from before they were shared between layouts
------------------------------------------------------------------------------

-- Frame settings used to be kept per layout (layouts[key].frames, swapped into the settings slot while that
-- layout was active), so a layout switch, e.g. by a specialization change, changed every frame's settings.
local function HasLayoutFrames()
	for _, data in pairs(store.layouts) do
		if (data.frames) then
			return true
		end
	end
end

-- Once, the frame settings move into the settings slots: this character's slot and the global slot get those
-- of `current` (the layout this character plays with now, else the one it played with last), every other
-- character's slot those of the layout that character played with last (else `current`'s). The slots keep
-- their frame on/off flags, which always were theirs. The other layouts' frame settings go; their unlinked raid
-- groups stay with their positions.
local function ShareFrameSettings(current)
	local layouts = store.layouts
	local function LastFrames(realmName, charName)
		local list = store.lastLayout[realmName]
		local data = list and list[charName] and layouts[list[charName]]
		return data and data.frames
	end
	local currentFrames = current and current.frames or LastFrames(realm, character)

	local function Fill(settings, frames)
		if (type(settings) ~= "table") then
			return
		end
		for _, key in ipairs(FRAME_KEYS) do
			if (type(frames) == "table" and type(frames[key]) == "table") then
				local section = XPerl_CopyTable(frames[key])
				if (type(settings[key]) == "table") then
					section.enable = settings[key].enable
				end
				settings[key] = section
			end
			if (type(settings[key]) == "table") then
				settings[key].unlinked = nil
			end
		end
	end

	Fill(XPerlConfigNew.global, currentFrames)
	for realmName, list in pairs(XPerlConfigNew) do
		if (type(list) == "table" and not XPerl_ConfigReservedKeys[realmName]) then
			for charName, settings in pairs(list) do
				if (realmName == realm and charName == character) then
					Fill(settings, currentFrames)
				else
					Fill(settings, LastFrames(realmName, charName) or currentFrames)
				end
			end
		end
	end

	for _, data in pairs(layouts) do
		if (type(data.frames) == "table") then
			for _, key in ipairs(FRAME_KEYS) do
				local section = data.frames[key]
				if (type(section) == "table" and section.unlinked) then
					data.unlinked = data.unlinked or {}
					data.unlinked[key] = true
				end
			end
		end
		data.frames = nil
	end
end

------------------------------------------------------------------------------
-- Positions
------------------------------------------------------------------------------

-- Default positions that follow Blizzard's frames between layouts. The XML anchors place X-Perl's player,
-- target and focus groups where Blizzard's Classic preset has its frames (top left); in another layout these
-- X-Perl frames move as far as the Blizzard frame they replace does (Modern, Gamepad: above the action bars).
-- Blizzard's party, raid, boss and arena frames sit the same in every preset, so those keys keep the XML anchor.
local MIRRORED = {
	player = "Player", pet = "Player", pettarget = "Player",
	target = "Target", targettarget = "Target", targettargettarget = "Target",
	focus = "Focus", focustarget = "Focus",
}
local BLIZZARD_FRAMES = {Player = "PlayerFrame", Target = "TargetFrame", Focus = "FocusFrame"}
local classicAnchors = {}		-- [system index name] = anchor of that Blizzard frame in the Classic preset, or false

-- Where an anchor point lies across a region: 0 left / bottom, 0.5 middle, 1 right / top
local function PointFractions(point)
	local fx = strfind(point, "LEFT") and 0 or strfind(point, "RIGHT") and 1 or 0.5
	local fy = strfind(point, "TOP") and 1 or strfind(point, "BOTTOM") and 0 or 0.5
	return fx, fy
end

-- Offset of the frame's top left corner from UIParent's at `pos`, in the frame's own units
local function TopLeftOffset(frame, pos)
	local scale = frame:GetScale()
	local width, height = frame:GetSize()
	local px, py = PointFractions(pos.point)
	local rx, ry = PointFractions(pos.relativePoint or pos.point)
	return UIParent:GetWidth() / scale * rx + pos.x - width * px,
		UIParent:GetHeight() / scale * (ry - 1) + pos.y + height * (1 - py)
end

-- Top left corner of Blizzard's frame `blizz` placed by the Edit Mode anchor `anchor`, as an offset from the
-- anchor's relative point (UIParent units, like Edit Mode offsets)
local function AnchorTopLeft(anchor, blizz)
	local scale = blizz:GetScale()
	local px, py = PointFractions(anchor.point)
	return anchor.offsetX - blizz:GetWidth() * scale * px, anchor.offsetY + blizz:GetHeight() * scale * (1 - py)
end

local function ClassicAnchor(index)
	local anchor = classicAnchors[index]
	if (anchor == nil) then
		anchor = EditModePresetLayoutManager:GetPresetLayoutSystemAnchorInfo(Enum.EditModePresetLayouts.Classic,
			Enum.EditModeSystem.UnitFrame, Enum.EditModeUnitFrameSystemIndices[index]) or false
		classicAnchors[index] = anchor
	end
	return anchor or nil
end

-- The frame's default position (reg.default, which is also LibEditMode's "Reset Position" target): the XML
-- anchor, shifted by how far the client's active layout moves the mirrored Blizzard frame from its Classic
-- spot. Anchored at the point the Blizzard frame is anchored to, so it follows a resized screen the same way.
-- Until the client has reported its layouts (or for a Blizzard frame snapped to another frame) it is the XML
-- anchor. A frame registered with info.fixed keeps the XML anchor in every layout.
local function DefaultPosition(reg)
	local default, xml = reg.default, reg.info.default
	local index = not reg.info.fixed and MIRRORED[reg.frameKey]
	local blizz = index and _G[BLIZZARD_FRAMES[index]]
	local info = blizz and EditModeManagerFrame:GetActiveLayoutSystemInfo(Enum.EditModeSystem.UnitFrame, Enum.EditModeUnitFrameSystemIndices[index])
	local active = info and info.anchorInfo
	local classic = active and ClassicAnchor(index)
	if (not (classic and active.relativeTo == "UIParent" and classic.relativeTo == "UIParent")) then
		default.point, default.x, default.y = xml.point, xml.x, xml.y
		return default
	end

	local frame = reg.frame
	local scale = frame:GetScale()
	local width, height = frame:GetSize()
	local x, y = TopLeftOffset(frame, xml)
	local ax, ay = AnchorTopLeft(active, blizz)
	local cx, cy = AnchorTopLeft(classic, blizz)
	local cfx, cfy = PointFractions(classic.relativePoint)
	cx, cy = cx + UIParent:GetWidth() * cfx, cy + UIParent:GetHeight() * (cfy - 1)
	local rx, ry = PointFractions(active.relativePoint)
	default.point = active.relativePoint
	default.x = x + (ax - cx) / scale + width * rx
	default.y = y + (ay - cy) / scale - height * (1 - ry)
	return default
end

local function Position(reg)
	return CurrentPositions()[reg.posKey] or DefaultPosition(reg)
end

-- Whether a leader's followers move with it in the active layout
local function Linked(leaderReg)
	local unlinked = CurrentUnlinked()
	return not (unlinked and unlinked[leaderReg.frameKey])
end

local function SetLinked(leaderReg, linked)
	CurrentUnlinked(true)[leaderReg.frameKey] = not linked or nil
end

-- The leader's registration while the frame follows it
local function LinkedLeader(reg)
	local leaderReg = reg.leader and registered[reg.leader]
	if (leaderReg and Linked(leaderReg)) then
		return leaderReg
	end
end

local function Place(frame, reg)
	if (frame.SetDontSavePosition) then
		frame:SetDontSavePosition(true)
	end
	if (frame:IsUserPlaced()) then
		frame:SetUserPlaced(false)
	end

	local default = DefaultPosition(reg)		-- kept current for LibEditMode's reset while a position is stored
	local pos = CurrentPositions()[reg.posKey] or default
	frame:ClearAllPoints()
	local leaderReg = LinkedLeader(reg)
	if (leaderReg) then
		-- On the leader, as far from it as the stored positions are apart, so it moves with the leader
		local leader = reg.leader
		local x, y = TopLeftOffset(frame, pos)
		local lx, ly = TopLeftOffset(leader, Position(leaderReg))
		local k = leader:GetScale() / frame:GetScale()
		frame:SetPoint("TOPLEFT", leader, "TOPLEFT", x - lx * k, y - ly * k)
	else
		frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
	end
end

local function ApplyAllPositions()
	if (not store) then
		return
	end
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ApplyAllPositions)
		return
	end
	for _, frame in ipairs(order) do
		local reg = registered[frame]
		if (not reg.disabled) then
			Place(frame, reg)
		end
	end
end

-- Edit Mode moves Blizzard's frames when the client's layout data changes, which can come after X-Perl's own
-- layout switch (at login the last layout is active already): the defaults that mirror them are read again
hooksecurefunc(EditModeManagerFrame, "UpdateLayoutInfo", ApplyAllPositions)

-- Stores where the frame is now, as TOPLEFT of UIParent so frames keep growing right and down. Returns the
-- stored position.
local function StoreCurrent(frame)
	local reg = registered[frame]
	local left, top = frame:GetLeft(), frame:GetTop()
	if (not (reg and left and top)) then
		return
	end

	local pos = {point = "TOPLEFT", x = left, y = top - UIParent:GetTop() / frame:GetScale()}
	CurrentPositions()[reg.posKey] = pos

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
	if (frame:IsUserPlaced()) then
		frame:SetUserPlaced(false)
	end
	return pos
end

-- Stores a frame that was dragged, nudged or reset, or that an alignment tool put somewhere (`arranged`). A
-- linked leader's followers moved along: their stored positions keep their offsets from it (unused followers'
-- too, so they line up once in use). A follower moved on its own breaks the link, and the other followers are
-- anchored to UIParent where they are; one an alignment tool moved stays linked.
local function Moved(frame, arranged)
	local reg = registered[frame]
	if (reg.followers and Linked(reg)) then
		local oldX, oldY = TopLeftOffset(frame, Position(reg))
		local pos = StoreCurrent(frame)
		if (pos) then
			local positions = CurrentPositions()
			for _, follower in ipairs(reg.followers) do
				local followerReg = registered[follower]
				local k = frame:GetScale() / follower:GetScale()
				local x, y = TopLeftOffset(follower, Position(followerReg))
				positions[followerReg.posKey] = {point = "TOPLEFT", x = x + (pos.x - oldX) * k, y = y + (pos.y - oldY) * k}
			end
		end
		return
	end

	StoreCurrent(frame)
	local leaderReg = LinkedLeader(reg)
	if (not leaderReg) then
		return
	end
	if (arranged) then
		Place(frame, reg)
		return
	end
	SetLinked(leaderReg, false)
	for _, follower in ipairs(leaderReg.followers) do
		local followerReg = registered[follower]
		if (follower ~= frame and not followerReg.disabled) then
			Place(follower, followerReg)
		end
	end
	XPerl_Notice(XPERL_EDITMODE_GROUPS_UNLINKED)
end

-- The "Link Raid Groups" button: the followers move with the leader again, keeping their current offsets from it
local function Link(frame)
	local reg = registered[frame]
	SetLinked(reg.followers and reg or registered[reg.leader], true)
	ApplyAllPositions()
	XPerl_Notice(XPERL_EDITMODE_GROUPS_LINKED)
end

-- XPerl_EditMode_Link(frame)
-- Links a leader's followers again (frame: the leader or a follower), for the options window's raid alignment
function XPerl_EditMode_Link(frame)
	local reg = registered[frame]
	if (reg and (reg.followers or reg.leader)) then
		Link(frame)
	end
end

local function AddLinkButton(frame)
	LEM:AddFrameSettingsButtons(frame, {{text = XPERL_EDITMODE_LINK_GROUPS, click = function() Link(frame) end}})
end

-- LibEditMode callback after a drag, nudge or position reset in Edit Mode
local function OnMoved(frame)
	if (not InCombatLockdown()) then
		Moved(frame)
	end
end

-- XPerl_SavePosition(frame, arranged)
-- Drag-stop handler of the options window's unlocked mode, and the store of its alignment tools (`arranged`:
-- a linked raid group stays linked): stores a registered frame's position in the active layout. Unregistered
-- frames are left to the client.
function XPerl_SavePosition(frame, arranged)
	if (store and registered[frame] and not InCombatLockdown()) then
		Moved(frame, arranged)
	end
end

-- XPerl_EditMode_ApplyPosition
-- Re-anchors a registered frame to its position in the active layout (e.g. after unit code reset its points)
function XPerl_EditMode_ApplyPosition(frame)
	local reg = registered[frame]
	if (not (store and reg) or reg.disabled) then
		return
	end
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(ApplyAllPositions)
	else
		Place(frame, reg)
	end
end

------------------------------------------------------------------------------
-- Previews, refreshes
------------------------------------------------------------------------------

-- XPerl_EditMode_IsEditing
function XPerl_EditMode_IsEditing()
	return LEM:IsInEditMode()
end

-- XPerl_EditMode_RefreshPreviews
-- Placeholders are shown while Edit Mode is open or the options window has the frames unlocked. Previews
-- show and hide secure frames, so in combat this runs once combat ends (reading the state then).
function XPerl_EditMode_RefreshPreviews()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(XPerl_EditMode_RefreshPreviews)
		return
	end
	local on = LEM:IsInEditMode() or XPerlLocked == 0
	for _, frame in ipairs(order) do
		local preview = registered[frame].info.preview
		if (preview) then
			preview(on)
		end
	end
end

-- LibEditMode makes a frame unmovable again when its Edit Mode selection ends; the options window's
-- unlocked mode drags the frames with StartMoving
local function RestoreMovable()
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(RestoreMovable)
		return
	end
	for _, frame in ipairs(order) do
		frame:SetMovable(true)
	end
end

local function RefreshDialogs()
	for _, frame in ipairs(order) do
		LEM:RefreshFrameSettings(frame)
	end
end

-- Settings changed outside the Edit Mode dialogs (options window, profile import) show in an open dialog. A
-- dialog's own changes don't rebuild it (that would swap its widgets mid-drag).
local applyingDialogChange
hooksecurefunc("XPerl_OptionActions", function()
	if (not applyingDialogChange) then
		RefreshDialogs()
	end
end)

------------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------------

local function AddSettings(frame, reg)
	local settings = ns.EditModeSettings.Get(reg.frameKey)
	if (settings) then
		LEM:AddFrameSettings(frame, settings)
	end
end

-- Keeps the Edit Mode selection of a disabled frame hidden; LibEditMode re-shows all selections whenever
-- something gets selected
local function SelectionOnShow(selection)
	local reg = registered[selection:GetParent()]
	if (reg and reg.disabled) then
		selection:Hide()
	end
end

-- XPerl_EditMode_Register(frame, frameKey, info)
-- info: label, default (position), index (several frames of one key), preview(on) (shows placeholders),
-- leader (a frame registered before, which this one follows while linked), fixed (the default doesn't move
-- with the Blizzard frame its key follows between layouts)
function XPerl_EditMode_Register(frame, frameKey, info)
	assert(type(frame) == "table" and frame.GetName and frame:GetName(), "XPerl_EditMode_Register: frame must be a named frame")
	assert(frameKeySet[frameKey], "XPerl_EditMode_Register: unknown frame key")
	assert(type(info) == "table" and info.label and type(info.default) == "table", "XPerl_EditMode_Register: info needs label and default")
	assert(not info.leader or registered[info.leader], "XPerl_EditMode_Register: the leader must be registered first")

	if (registered[frame]) then
		return
	end

	local default = info.default
	local reg = {frame = frame, frameKey = frameKey, posKey = PosKey(frameKey, info.index), info = info, leader = info.leader,
		default = {point = default.point, x = default.x, y = default.y}}
	registered[frame] = reg
	tinsert(order, frame)

	LEM:AddFrame(frame, OnMoved, reg.default, format(XPERL_EDITMODE_LABEL, info.label))
	LEM.frameSelections[frame]:HookScript("OnShow", SelectionOnShow)

	if (loggedIn) then
		AddSettings(frame, reg)
	end

	if (info.leader) then
		local leaderReg = registered[info.leader]
		if (not leaderReg.followers) then
			leaderReg.followers = {}
			AddLinkButton(info.leader)
		end
		tinsert(leaderReg.followers, frame)
		AddLinkButton(frame)
	end

	XPerl_EditMode_ApplyPosition(frame)

	if (info.preview and (LEM:IsInEditMode() or XPerlLocked == 0)) then
		if (InCombatLockdown()) then
			XPerl_ProtectedCall(XPerl_EditMode_RefreshPreviews)
		else
			info.preview(true)
		end
	end
end

-- XPerl_EditMode_SetEnabled
-- A disabled frame (e.g. docked to another frame, or its unit type switched off) keeps its stored position
-- but isn't placed and can't be selected in Edit Mode.
function XPerl_EditMode_SetEnabled(frame, enabled)
	local reg = registered[frame]
	if (not reg) then
		return
	end

	reg.disabled = not enabled
	local selection = LEM.frameSelections[frame]
	if (enabled) then
		XPerl_EditMode_ApplyPosition(frame)
		if (LEM:IsInEditMode()) then
			selection:ShowHighlighted()
		end
	else
		selection:Hide()
	end
end

------------------------------------------------------------------------------
-- Settings slot attachment (XPerl_Globals.lua GiveConfig)
------------------------------------------------------------------------------

-- XPerl_EditMode_AttachConfig
-- Called with the settings slot that just became XPerlDB, before it is validated: places the frames for the
-- active layout (the last one this character played with until the client reports it).
function XPerl_EditMode_AttachConfig(newSlot)
	realm, character = XPerlAPI.SettingsOwner()
	EnsureStore(newSlot)

	if (not activeKey) then
		local list = store.lastLayout[realm]
		local last = list and list[character]
		if (last and store.layouts[last]) then
			activeKey, activeData = last, store.layouts[last]
		end
	end

	-- Without a last layout, the first layout the client reports picks the frame settings (Activate)
	if (activeData and HasLayoutFrames()) then
		ShareFrameSettings(activeData)
	end

	ApplyAllPositions()
end

------------------------------------------------------------------------------
-- Layouts
------------------------------------------------------------------------------

local function PresetCount()
	local meta = Enum.EditModePresetLayoutsMeta
	return meta and meta.NumValues or 2
end

local function UserLayoutKey(layoutType, name)
	if (layoutType == Enum.EditModeLayoutType.Character) then
		return format("character:%s/%s/%s", realm, character, name)
	end
	return "account:"..name
end

-- Key of the layout at `index` of C_EditMode.GetLayouts() (presets first, as LibEditMode counts them)
local function KeyForIndex(index)
	local presets = PresetCount()
	if (index <= presets) then
		return "preset:"..index
	end
	local info = C_EditMode.GetLayouts().layouts[index - presets]
	return info and UserLayoutKey(info.layoutType, info.layoutName)
end

-- Key of a layout known only by its (client) name, e.g. the source of a copied layout
local function KeyForName(name)
	if (activeData and activeData.name == name) then
		return activeKey
	end
	local presetNames = {LAYOUT_STYLE_MODERN, LAYOUT_STYLE_CLASSIC, LAYOUT_STYLE_GAMEPAD}
	for i = 1, PresetCount() do
		if (presetNames[i] == name) then
			return "preset:"..i
		end
	end
	for _, info in ipairs(C_EditMode.GetLayouts().layouts) do
		if (info.layoutName == name) then
			return UserLayoutKey(info.layoutType, name)
		end
	end
end

-- Name of the layout at `index`, as LibEditMode names it (it calls the presets Modern, Classic, Gamepad)
local PRESET_NAMES = {"Modern", "Classic", "Gamepad"}
local function NameForIndex(index)
	local presets = PresetCount()
	if (index <= presets) then
		if (LEM:GetActiveLayout() == index) then
			return LEM:GetActiveLayoutName()
		end
		local data = store.layouts["preset:"..index]
		return data and data.name or PRESET_NAMES[index]
	end
	local info = C_EditMode.GetLayouts().layouts[index - presets]
	return info and info.layoutName
end

-- The user layouts the client has: [key] = name
local function CurrentLayoutKeys()
	local keys = {}
	for _, info in ipairs(C_EditMode.GetLayouts().layouts) do
		keys[UserLayoutKey(info.layoutType, info.layoutName)] = info.layoutName
	end
	return keys
end

local knownLayouts		-- CurrentLayoutKeys() as of the last layout event; tells which layout a "create" added

-- Switching layouts moves the frames; their settings are the same in every layout
local function Activate(key, name)
	local data = store.layouts[key]
	if (not data) then
		data = NewLayoutData(name)
		store.layouts[key] = data
	end
	data.name = name

	-- First layout of a session that had no last layout to start with: it picks the frame settings
	if (HasLayoutFrames()) then
		ShareFrameSettings(data)
		XPerl_pcall(XPerl_ValidateSettings)
		XPerl_NotifyConfig()
		XPerl_OptionActions()
	end

	SetLastLayout(key)

	if (key == activeKey and data == activeData) then
		return
	end

	activeKey, activeData = key, data
	pendingPositions, pendingUnlinked = nil, nil
	ApplyAllPositions()
end

local function OnLayout(name, index)
	knownLayouts = CurrentLayoutKeys()
	local key = index and KeyForIndex(index)
	if (key) then
		Activate(key, name)
	end
end

-- Activates the client's active layout. LibEditMode reports no layout change when a new layout takes the
-- index the active one had (Blizzard inserts account layouts before character layouts).
local function SyncActiveLayout()
	local index = C_EditMode.GetLayouts().activeLayout
	local key = index and KeyForIndex(index)
	local name = key and NameForIndex(index)
	if (key and name) then
		Activate(key, name)
	end
end

-- LibEditMode's "create": its index is not reliable (it reports the last layout), so the new layout is the
-- one missing from the last snapshot. Existing layout data is never replaced.
local function OnCreate(_, _, sourceName)
	local current = CurrentLayoutKeys()
	if (knownLayouts) then
		local source
		if (sourceName) then
			local sourceKey = KeyForName(sourceName)
			source = sourceKey and store.layouts[sourceKey]
		else
			source = activeData
		end
		for key, name in pairs(current) do
			if (not knownLayouts[key] and not store.layouts[key]) then
				store.layouts[key] = NewLayoutData(name, source)
			end
		end
	end
	knownLayouts = current
	C_Timer.After(0, SyncActiveLayout)
end

local function ReplaceLastLayout(oldKey, newKey)
	for _, list in pairs(store.lastLayout) do
		for charName, key in pairs(list) do
			if (key == oldKey) then
				list[charName] = newKey
			end
		end
	end
end

local function OnRename(oldName, newName, index)
	local info = C_EditMode.GetLayouts().layouts[index]
	knownLayouts = CurrentLayoutKeys()
	if (not info) then
		return
	end

	local oldKey = UserLayoutKey(info.layoutType, oldName)
	local newKey = UserLayoutKey(info.layoutType, newName)
	local data = store.layouts[oldKey]
	if (data and oldKey ~= newKey) then
		data.name = newName
		store.layouts[newKey] = data
		store.layouts[oldKey] = nil
		ReplaceLastLayout(oldKey, newKey)
		if (activeKey == oldKey) then
			activeKey = newKey
		end
	end
end

local function OnDelete(name)
	local present = CurrentLayoutKeys()
	knownLayouts = present

	local candidates = {UserLayoutKey(Enum.EditModeLayoutType.Account, name), UserLayoutKey(Enum.EditModeLayoutType.Character, name)}
	for _, key in ipairs(candidates) do
		if (store.layouts[key] and not present[key]) then
			store.layouts[key] = nil
			ReplaceLastLayout(key, nil)
			-- If it was the active one the client switches layouts next, which activates that one
		end
	end
end

local function OnEnter()
	ns.EditModeSettings.RefreshLimits()
	XPerl_EditMode_RefreshPreviews()
end

local function OnExit()
	RestoreMovable()
	XPerl_EditMode_RefreshPreviews()
end

-- XPerl_EditMode_OnLogin
-- Called once after XPerl_Init: dialogs (their labels come from the options localization) and layout tracking
function XPerl_EditMode_OnLogin()
	loggedIn = true
	for _, frame in ipairs(order) do
		AddSettings(frame, registered[frame])
	end

	LEM:RegisterCallback("enter", OnEnter)
	LEM:RegisterCallback("exit", OnExit)
	LEM:RegisterCallback("create", OnCreate)
	LEM:RegisterCallback("rename", OnRename)
	LEM:RegisterCallback("delete", OnDelete)
	LEM:RegisterCallback("layout", OnLayout)

	XPerl_EditMode_OnLogin = nil
end

------------------------------------------------------------------------------
-- Access for the settings dialogs, profiles and the options window
------------------------------------------------------------------------------

ns.EditMode = {}

local applyQueued
local function ApplySettings()
	applyQueued = nil
	applyingDialogChange = true
	XPerl_pcall(XPerl_OptionActions)
	applyingDialogChange = nil
end

-- A dialog setting was changed; several changes in one frame (Reset to default) apply once
function ns.EditMode.SettingChanged()
	if (not applyQueued) then
		applyQueued = true
		C_Timer.After(0, ApplySettings)
	end
end

-- XPerl_EditMode_GetActiveLayoutName
function XPerl_EditMode_GetActiveLayoutName()
	return activeData and activeData.name
end

-- XPerl_EditMode_GetPositions
-- The active layout's positions (live table)
function XPerl_EditMode_GetPositions()
	return store and CurrentPositions()
end

-- XPerl_EditMode_GetUnlinked
-- The active layout's unlinked leaders ([leader frameKey] = true), or nil
function XPerl_EditMode_GetUnlinked()
	return CurrentUnlinked()
end

-- XPerl_EditMode_SetPositions(positions, unlinked)
-- Replaces the active layout's positions with a copy of `positions`, and its unlinked leaders with `unlinked`
-- when given, and moves the frames
function XPerl_EditMode_SetPositions(positions, unlinked)
	if (unlinked) then
		local current = CurrentUnlinked(true)
		wipe(current)
		for _, key in ipairs(FRAME_KEYS) do
			current[key] = unlinked[key] and true or nil
		end
	end

	local current = CurrentPositions()
	wipe(current)
	for posKey, pos in pairs(positions) do
		if (type(pos) == "table" and pos.point and tonumber(pos.x) and tonumber(pos.y)) then
			current[posKey] = {point = pos.point, relativePoint = pos.relativePoint, x = pos.x, y = pos.y}
		end
	end
	ApplyAllPositions()
end

-- XPerl_EditMode_ConvertLegacyPositions
-- Old {frameName = {top, left}} positions (old profile strings) in the layout format
XPerl_EditMode_ConvertLegacyPositions = ConvertLegacy

local function LayoutLabel(key, data)
	local charName = strmatch(key, "^character:[^/]*/([^/]*)/")
	if (charName) then
		return format(XPERL_EDITMODE_LAYOUT_OTHERCHAR, data.name or key, charName)
	end
	return format(XPERL_EDITMODE_LAYOUT_ENTRY, data.name or key)
end

-- XPerl_EditMode_LayoutList
-- Labels of every layout with stored data, the active one marked (/xperl config list)
function XPerl_EditMode_LayoutList()
	local list = {}
	for key, data in pairs(store.layouts) do
		local label = LayoutLabel(key, data)
		if (key == activeKey) then
			label = label..XPERL_CONFIG_CURRENT
		end
		tinsert(list, label)
	end
	sort(list)
	return list
end

-- XPerl_EditMode_PositionSets
-- Everything the options window's Frame Layout list offers: named layouts and the other Edit Mode layouts.
-- {label =, positions =, named = true for named layouts}, sorted by label.
function XPerl_EditMode_PositionSets()
	local list = {}
	for name, positions in pairs(store.named) do
		tinsert(list, {label = name, positions = positions, named = true})
	end
	for key, data in pairs(store.layouts) do
		if (key ~= activeKey) then
			tinsert(list, {label = LayoutLabel(key, data), positions = data.positions})
		end
	end
	sort(list, function(a, b) return a.label < b.label end)
	return list
end

-- XPerl_EditMode_SaveNamedPositions
function XPerl_EditMode_SaveNamedPositions(name)
	store.named[name] = XPerl_CopyTable(CurrentPositions())
end

-- XPerl_EditMode_DeleteNamedPositions
function XPerl_EditMode_DeleteNamedPositions(name)
	store.named[name] = nil
end

-- XPerl_EditMode_ForgetCharacter
-- Drops a character's Edit Mode data (with its deleted settings slot)
function XPerl_EditMode_ForgetCharacter(realmName, charName)
	if (store.legacy[realmName]) then
		store.legacy[realmName][charName] = nil
	end
	if (store.lastLayout[realmName]) then
		store.lastLayout[realmName][charName] = nil
	end
	local prefix = format("character:%s/%s/", realmName, charName)
	for key in pairs(store.layouts) do
		if (strsub(key, 1, #prefix) == prefix) then
			store.layouts[key] = nil
		end
	end
end

-- XPerl_EditMode_MoveCharacter
-- Moves a character's Edit Mode data to new realm and character keys (XPerlAPI.SettingsOwner) where it has none
-- yet. Runs at ADDON_LOADED, before the store is set up, on the saved data as it is.
function XPerl_EditMode_MoveCharacter(oldRealm, oldChar, newRealm, newChar)
	local data = XPerlConfigNew.editMode
	if (type(data) ~= "table") then
		return
	end

	local movedLayouts = {}
	if (type(data.layouts) == "table") then
		local oldPrefix = format("character:%s/%s/", oldRealm, oldChar)
		local newPrefix = format("character:%s/%s/", newRealm, newChar)
		for key in pairs(data.layouts) do
			if (strsub(key, 1, #oldPrefix) == oldPrefix) then
				local newKey = newPrefix..strsub(key, #oldPrefix + 1)
				if (data.layouts[newKey] == nil) then
					movedLayouts[key] = newKey
				end
			end
		end
		for oldKey, newKey in pairs(movedLayouts) do
			data.layouts[newKey] = data.layouts[oldKey]
			data.layouts[oldKey] = nil
		end
	end

	for _, listName in ipairs({"lastLayout", "legacy"}) do
		local lists = data[listName]
		local old = type(lists) == "table" and lists[oldRealm]
		if (type(old) == "table" and old[oldChar] ~= nil) then
			lists[newRealm] = lists[newRealm] or {}
			if (lists[newRealm][newChar] == nil) then
				local value = old[oldChar]
				lists[newRealm][newChar] = movedLayouts[value] or value
				old[oldChar] = nil
				if (next(old) == nil) then
					lists[oldRealm] = nil
				end
			end
		end
	end
end
