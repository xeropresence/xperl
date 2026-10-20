-- X-Perl UnitFrames
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Boss frames XPerl_Boss1..5 (boss1-5) in the stack XPerl_Boss_Anchor (Units/UnitStack.lua). They are target
-- frames (Units/Target.lua: classification, elite graphic, creature type) following the encounter's boss
-- units. Boss health is restricted during encounters; the framework's health element shows it all the same.
--
-- Only clients with Blizzard boss frames (Boss1TargetFrame) have boss units, so only they get these frames.

if (not Boss1TargetFrame) then
	return
end

local UF = XPerl_UnitFrameMixin
local T = XPerl_TargetFrameMixin
local SF = XPerl_UnitStackFrameMixin

XPerl_BossFrameMixin = CreateFromMixins(T, SF, {
	elementList = {
		"highlight", "bossChanged", "name", "classification", "level", "targetType", "power", "health",
		"combat", "statusIcons", "portrait", "range", "auras", "healPrediction", "combatFeedback",
		"castBar",
	},
	unitPrefix = "boss",
	labelFormat = XPERL_EDITMODE_UNIT_BOSS,
})
local B = XPerl_BossFrameMixin

-- The boss tokens are handed out (and taken back) as the encounter goes on
XPerl_UnitFrame_DefineElement("bossChanged", {events = {INSTANCE_ENCOUNTER_ENGAGE_UNIT = true, UNIT_TARGETABLE_CHANGED = "unit"},
	method = "UnitChanged", full = false})

-- The stack, then its buttons
local stack = XPerl_UnitStack_Create("XPerl_Boss_Anchor", "boss", XPERL_EDITMODE_FRAME_BOSS, {point = "TOPRIGHT", x = -160, y = -300})
B.stack = stack

-- InitType: the stack's setup, and the matching Blizzard boss frame (hidden when the type is enabled at login).
-- The target's combo point meter has no use here.
function B:InitType()
	SF.InitType(self)
	self.blizzardFrame = "Boss"..self.index.."TargetFrame"
	self.nameFrame.cpMeter:Hide()
end

-- ApplyTypeSettings: the target frame's, then the stack's layout
function B:ApplyTypeSettings()
	T.ApplyTypeSettings(self)
	SF.ApplyTypeSettings(self)
end

-- No target sounds, deferred redraws or combo points: those are the target's
B.OnHide = UF.OnHide
B.UpdateDisplay = UF.UpdateDisplay
B.OnTick = UF.OnTick

-- Blizzard's boss frames sit in BossTargetFrameContainer; the framework hides each Boss<n>TargetFrame and the
-- container goes with them. Decided by the settings in use at login (while the core's disable function
-- exists), not by the frames' activation, which waits for combat to end after a /reload in combat.
local blizzardHidden
XPerl_RequestConfig(function(new)
	if (XPerl_BlizzFrameDisable and not blizzardHidden and new.boss and new.boss.enable) then
		blizzardHidden = true
		XPerl_BlizzFrameDisable(BossTargetFrameContainer)
	end
end, "$Revision$")

XPerl_UnitStack_CreateFrames(stack, "XPerl_BossFrameTemplate", "XPerl_Boss", 5)
