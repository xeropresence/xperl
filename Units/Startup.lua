-- X-Perl UnitFrames
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)
--
-- Loads after every unit type (last line of Units/Units.xml): config callbacks run in registration order,
-- so registering here means each type's own callback has run when the frames get switched on or off.

XPerl_RequestConfig(XPerl_UnitFrames_ApplyEnableFlags, "$Revision$")
