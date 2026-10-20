-- X-Perl UnitFrames
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Unit stacks: the boss and arena frames are five unit buttons each, stacked in an anchor frame of their own.
-- Edit Mode moves the anchor (the buttons aren't registered themselves); the anchor follows the frame key's
-- scale, spacing and growth settings and is as large as the stack, so its Edit Mode selection covers every
-- button. The buttons are protected and anchored to the stack, so the stack is only laid out, moved, shown
-- or hidden out of combat.
--
-- A stack's buttons are created in Lua (Units/Boss.lua, Units/Arena.lua) from their type's template, named
-- <prefix>1..5; their type mixin includes XPerl_UnitStackFrameMixin and sets `stack`, `unitPrefix` and
-- `labelFormat` (Edit Mode placeholder name, "%d" = index).

XPerl_UnitStackMixin = {}
local S = XPerl_UnitStackMixin

-- XPerl_UnitStack_Create(name, frameKey, label, default)
-- name: global name of the anchor frame; label: its Edit Mode label; default: its Edit Mode default position
-- ({point =, x =, y =} relative to UIParent)
function XPerl_UnitStack_Create(name, frameKey, label, default)
	local stack = CreateFrame("Frame", name, UIParent)
	Mixin(stack, S)
	stack.frameKey = frameKey
	stack.label = label
	stack.default = default
	stack.frames = {}
	stack:SetSize(1, 1)
	stack:SetPoint(default.point, UIParent, default.point, default.x, default.y)
	stack:SetMovable(true)
	stack:SetClampedToScreen(true)
	stack:Hide()
	stack.layoutDeferred = function() stack:Layout() end
	stack.preview = function(on) stack:Preview(on) end
	return stack
end

-- XPerl_UnitStack_CreateFrames(stack, template, prefix, count)
-- Creates the stack's buttons <prefix>1..count from a unit button template whose type mixin sets `stack`
function XPerl_UnitStack_CreateFrames(stack, template, prefix, count)
	for i = 1, count do
		CreateFrame("Button", prefix..i, UIParent, template)
	end
	return stack.frames
end

-- Add(frame): buttons are stacked in the order they are added (their InitType adds them)
function S:Add(frame)
	tinsert(self.frames, frame)
end

-- SetActive(on)
-- The buttons share the frame key's enable flag; the first one switched on registers the anchor with Edit
-- Mode. Called from the buttons' OnActivate, which the framework only runs out of combat.
function S:SetActive(on)
	on = on and true or false
	if (on == (self.active or false)) then
		return
	end
	self.active = on
	if (on and not self.registered) then
		self.registered = true
		XPerl_EditMode_Register(self, self.frameKey, {label = self.label, default = self.default, preview = self.preview})
	end
	self:SetShown(on)
	if (self.registered) then
		XPerl_EditMode_SetEnabled(self, on)
	end
	self:Layout()
	self:OnActiveChanged(on)
end

-- OnActiveChanged(on): for the stack's owner (events of its own)
function S:OnActiveChanged()
end

-- OnPreviewChanged(on): for the stack's owner (placeholders of its own)
function S:OnPreviewChanged()
end

-- Layout
-- Scale (as the buttons'), button positions by conf.growth ("down" or "up") and conf.spacing, and the
-- anchor's size. The buttons run it from their ApplyTypeSettings, i.e. out of combat.
function S:Layout()
	local first = self.frames[1]
	local c = first and first.conf
	if (not c or not self.active) then
		return
	end
	if (InCombatLockdown()) then
		XPerl_ProtectedCall(self.layoutDeferred)
		return
	end

	self:SetScale(c.scale or 1)
	local spacing = max(0, tonumber(c.spacing) or 0)
	local up = c.growth == "up"
	local prev
	for _, frame in ipairs(self.frames) do
		frame:ClearAllPoints()
		if (up) then
			if (prev) then
				frame:SetPoint("BOTTOMLEFT", prev, "TOPLEFT", 0, spacing)
			else
				frame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
			end
		elseif (prev) then
			frame:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -spacing)
		else
			frame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		end
		prev = frame
	end

	local count = #self.frames
	self:SetSize(first:GetWidth(), count * first:GetHeight() + (count - 1) * spacing)
	XPerl_EditMode_ApplyPosition(self)
end

-- Preview(on): Edit Mode (or the options window's unlock) shows every button, unit or not
function S:Preview(on)
	on = on and true or false
	self.previewing = on
	for _, frame in ipairs(self.frames) do
		frame:EditModePreview(on)
	end
	self:OnPreviewChanged(on)
end

-- StartDrag / StopDrag: the options window's unlocked drag of any button moves the whole stack
function S:StartDrag()
	if (XPerlLocked == 0 and not InCombatLockdown()) then
		self.xperlMoving = true
		self:StartMoving()
	end
end

function S:StopDrag()
	if (self.xperlMoving) then
		self.xperlMoving = nil
		self:StopMovingOrSizing()
		XPerl_SavePosition(self)
	end
end

------------------------------------------------------------------------------
-- Button side
------------------------------------------------------------------------------

XPerl_UnitStackFrameMixin = {}
local SF = XPerl_UnitStackFrameMixin

-- InitType: the unit token and Edit Mode name come from the button's index (the trailing number of its name)
function SF:InitType()
	local index = tonumber(strmatch(self:GetName(), "(%d+)$"))
	local unit = self.unitPrefix..index
	self.index = index
	self.partyid = unit
	self:SetAttribute("unit", unit)
	self.nameFrame:SetAttribute("unit", unit)
	self.editModeLabel = format(self.labelFormat, index)
	self.stack:Add(self)
end

-- OnActivate(on): the stack follows its buttons; a button switched on while Edit Mode is open shows at once
function SF:OnActivate(on)
	self.stack:SetActive(on)
	if (on and self.stack.previewing) then
		self:EditModePreview(true)
	end
end

-- OnShow: the unit watch shows the button when its unit appears, which needs a full refresh
function SF:OnShow()
	self:UnitChanged()
end

-- OnDragStart / OnDragStop: the stack moves as one
function SF:OnDragStart()
	self.stack:StartDrag()
end

function SF:OnDragStop()
	self.stack:StopDrag()
end

-- ApplyTypeSettings: the stack's layout follows the buttons' size
function SF:ApplyTypeSettings()
	self.stack:Layout()
end
