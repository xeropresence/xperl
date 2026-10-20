-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

XPerl_SetModuleRevision("$Revision$")

-- XPerl_SlashHandler
local function XPerl_SlashHandler(msg)
	local args = {}

	for value in string.gmatch(msg, "[^ ]+") do
		tinsert(args, string.lower(value))
	end
	if (args[1] == nil or args[1] == XPERL_CMD_MENU or args[1] == XPERL_CMD_OPTIONS) then
		XPerl_UnlockFrames()

	elseif (args[1] == XPERL_CMD_LOCK) then
		XPerlLocked = 1
		XPerl_EditMode_RefreshPreviews()

	elseif (args[1] == XPERL_CMD_UNLOCK) then
		XPerlLocked = 0
		XPerl_EditMode_RefreshPreviews()

	elseif (args[1] == XPERL_CMD_CONFIG) then
		if (args[2] == XPERL_CMD_LIST) then
			-- Settings slots; the frame settings live in the Edit Mode layouts listed after them
			local myRealm, myName = strlower(GetRealmName()), strlower(UnitName("player"))
			XPerl_Notice(XPERL_CONFIG_LIST)
			if (XPerlConfigNew.global) then
				DEFAULT_CHAT_FRAME:AddMessage(format("|c00FFFF80%s%s", XPERL_CONFIG_GLOBAL, XPerlConfigSavePerCharacter and "" or XPERL_CONFIG_CURRENT))
			end
			for realmName,realmList in pairs(XPerlConfigNew) do
				if (type(realmList) == "table" and not XPerl_ConfigReservedKeys[realmName]) then
					for playerName, realmSettings in pairs(realmList) do
						local current = ""
						if (XPerlConfigSavePerCharacter and strlower(realmName) == myRealm and strlower(playerName) == myName) then
							current = XPERL_CONFIG_CURRENT
						end

						DEFAULT_CHAT_FRAME:AddMessage(format("|c00FFFF80%s - %s%s", realmName, playerName, current))
					end
				end
			end

			XPerl_Notice(XPERL_CONFIG_LAYOUTS)
			for _, label in ipairs(XPerl_EditMode_LayoutList()) do
				DEFAULT_CHAT_FRAME:AddMessage("|c00FFFF80"..label)
			end

		elseif (args[2] == XPERL_CMD_DELETE) then
			if (args[3] and args[4]) then
				if (strlower(args[3]) ~= strlower(GetRealmName()) or strlower(args[4]) ~= strlower(UnitName("player"))) then

					for realmName,realmList in pairs(XPerlConfigNew) do
						if (strlower(realmName) == strlower(args[3]) and type(realmList) == "table" and not XPerl_ConfigReservedKeys[realmName]) then
							for playerName, realmSettings in pairs(realmList) do
								if (strlower(playerName) == strlower(args[4])) then
									XPerlConfigNew[realmName][playerName] = nil
									XPerl_EditMode_ForgetCharacter(realmName, playerName)
									XPerl_Notice(XPERL_CONFIG_DELETED, realmName, playerName)
									return
								end
							end
						end
					end

					XPerl_Notice(XPERL_CANNOT_FIND_DELETE_TARGET, args[3], args[4])

				else
					XPerl_Notice(XPERL_CANNOT_DELETE_CURRENT)
				end
			else
				XPerl_Notice(XPERL_CANNOT_DELETE_BADARGS)
			end
		end

	elseif (args[1] == XPERL_CMD_VERSION) then
		-- Everything a bug report needs in one line; Forever builds move fast.
		XPerl_Notice(XPERL_VERSION_REPORT, XPerl_VersionNumber, XPerlAPI.flavorName, XPerlAPI.clientVersion, XPerlAPI.clientBuild, XPerlAPI.interfaceVersion)

	elseif (args[1] == XPERL_CMD_EXPORT) then
		XPerl_ProfileExport()

	elseif (args[1] == XPERL_CMD_IMPORT) then
		XPerl_ProfileImport()

	else
		DEFAULT_CHAT_FRAME:AddMessage(XPERL_CMD_HELP.." | "..XPERL_CMD_EXPORT.." | "..XPERL_CMD_IMPORT.." | "..XPERL_CMD_VERSION)
	end
end

SlashCmdList["XPERL"] = XPerl_SlashHandler
SLASH_XPERL1 = "/xperl"
