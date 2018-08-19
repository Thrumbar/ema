-- ================================================================================ --
--				EMA - ( Ebony's MultiBoxing Assistant )    							--
--				Current Author: Jennifer Cally (Ebony)								--
--																					--
--				License: MIT License 2018 Jennifer Cally							--
--																					--
--				Some Code Used from "Jamba" that is 								--
--				Released under the MIT License 										--
--				"Jamba" Copyright 2008-2015  Michael "Jafula" Miller				--
--																					--
-- ================================================================================ --

-- Create the addon using AceAddon-3.0 and embed some libraries.
local EMA = LibStub( "AceAddon-3.0" ):NewAddon(
	"Team",
	"Module-1.0", 
	"AceConsole-3.0", 
	"AceEvent-3.0",
	"AceHook-3.0",
	"AceTimer-3.0"
)

-- Load libraries.
local EMAUtilities = LibStub:GetLibrary( "EbonyUtilities-1.0" )
local EMAHelperSettings = LibStub:GetLibrary( "EMAHelperSettings-1.0" )

-- Constants required by EMAModule and Locale for this module.
EMA.moduleName = "Team"
EMA.settingsDatabaseName = "TeamProfileDB"
EMA.chatCommand = "ema-team"
local L = LibStub( "AceLocale-3.0" ):GetLocale( "Core" )
EMA.parentDisplayName = L["TEAM"]
EMA.moduleDisplayName = L["TEAM"]
-- Icon 
EMA.moduleIcon = "Interface\\Addons\\EMA\\Media\\TeamCore.tga"
-- order
EMA.moduleOrder = 20


-- EMA key bindings.
BINDING_HEADER_TEAM = L["TEAM"]
BINDING_NAME_TEAMINVITE = L["INVITE_GROUP"]
BINDING_NAME_TEAMDISBAND = L["DISBAND_GROUP"]
BINDING_NAME_TEAMMASTER = L["SET_MASTER"]

-- Settings - the values to store and their defaults for the settings database.
EMA.settings = {
	profile = {
		master = "",
        teamList = {},
		newTeamList = {},
	--	isboxerSync = true,
		masterChangePromoteLeader = false,
		inviteAcceptTeam = true,
		inviteAcceptFriends = false,
		inviteAcceptGuild = false,
		inviteDeclineStrangers = false,
		inviteConvertToRaid = true,
		inviteSetAllAssistant = false,
		masterChangeClickToMove = false,
	},
}

-- Configuration.
function EMA:GetConfiguration()
	local configuration = {
		name = EMA.moduleDisplayName,
		handler = EMA,
		type = "group",
		get = "EMAConfigurationGetSetting",
		set = "EMAConfigurationSetSetting",
		args = {	
			add = {
				type = "input",
				name = L["ADD"],
				desc = L["ADD_HELP"],
				usage = "/EMA-team add <name>",
				get = false,
				set = "AddMemberCommand",
			},			
			remove = {
				type = "input",
				name = L["REMOVE"],
				desc = L["REMOVE_REMOVE"],
				usage = "/EMA-team remove <name>",
				get = false,
				set = "RemoveMemberCommand",
			},						
			master = {
				type = "input",
				name = L["MASTER"],
				desc = L["MASTER_HELP"],
				usage = "/EMA-team master <name> <tag>",
				get = false,
				set = "CommandSetMaster",
			},						
			iammaster = {
				type = "input",
				name = L["I_AM_MASTER"],
				desc = L["I_AM_MASTER_HELP"],
				usage = "/EMA-team iammaster <tag>",
				get = false,
				set = "CommandIAmMaster",
			},	
			invite = {
				type = "input",
				name = L["INVITE"],
				desc = L["INVITE_HELP"],
				usage = "/EMA-team invite",
				get = false,
				set = "InviteTeamToParty",
			},				
			disband = {
				type = "input",
				name = L["DISBAND"],
				desc = L["DISBAND_HELP"],
				usage = "/EMA-team disband",
				get = false,
				set = "DisbandTeamFromParty",
			},
			addparty = {
				type = "input",
				name = L["ADD_GROUPS_MEMBERS"],
				desc = L["ADD_GROUPS_MEMBERS_HELP"],
				usage = "/EMA-team addparty",
				get = false,
				set = "AddPartyMembers",
			},
			removeall = {
				type = "input",
				name = L["REMOVE_ALL_MEMBERS"],
				desc = L["REMOVE_ALL_MEMBERS_HELP"],
				usage = "/EMA-team removeall",
				get = false,
				set = "DoRemoveAllMembersFromTeam",
			},
			setalloffline = {
				type = "input",
				name = L["SET_TEAM_OFFLINE"],
				desc = L["SET_TEAM_OFFLINE_HELP"] ,
				usage = "/EMA-team setalloffline",
				get = false,
				set = "SetAllMembersOffline",
			},
			setallonline = {
				type = "input",
				name = L["SET_TEAM_ONLINE"],
				desc = L["SET_TEAM_ONLINE_HELP"],
				usage = "/EMA-team setallonline",
				get = false,
				set = "SetAllMembersOnline",
			},
			push = {
				type = "input",
				name = L["PUSH_SETTINGS"],
				desc = L["PUSH_SETTINGS_INFO"],
				usage = "/EMA-team push",
				get = false,
				set = "EMASendSettings",
			},				
		},
	}
	return configuration
end

-- Create the character online table and ordered characters tables.
EMA.orderedCharacters = {}
EMA.orderedCharactersOnline = {}

-------------------------------------------------------------------------------------------------------------
-- Command this module sends.
-------------------------------------------------------------------------------------------------------------

EMA.COMMAND_TAG_PARTY = "EMATeamTagGroup"
-- Leave party command.
EMA.COMMAND_LEAVE_PARTY = "EMATeamLeaveGroup"
-- Set master command.
EMA.COMMAND_SET_MASTER = "EMATeamSetMaster"
-- Set Minion OffLine
EMA.COMMAND_SET_OFFLINE = "EMATeamSetOffline"
EMA.COMMAND_SET_ONLINE = "EMATeamSetOnline"


-------------------------------------------------------------------------------------------------------------
-- Messages module sends.
-------------------------------------------------------------------------------------------------------------

-- Master changed, parameter: new master name.
EMA.MESSAGE_TEAM_MASTER_CHANGED = "EMATeamMasterChanged"
-- Team order changed, no parameters.
EMA.MESSAGE_TEAM_ORDER_CHANGED = "EMATeamOrderChanged"
-- Character has been added, parameter: characterName.
EMA.MESSAGE_TEAM_CHARACTER_ADDED = "EMATeamCharacterAdded"
-- Character has been removed, parameter: characterName.
EMA.MESSAGE_TEAM_CHARACTER_REMOVED = "EMATeamCharacterRemoved"
-- character online
EMA.MESSAGE_CHARACTER_ONLINE = "JmbTmChrOn"
-- character offline
EMA.MESSAGE_CHARACTER_OFFLINE = "JmbTmChrOf"


-------------------------------------------------------------------------------------------------------------
-- Constants used by module.
-------------------------------------------------------------------------------------------------------------

EMA.simpleAreaList = {}

-------------------------------------------------------------------------------------------------------------
-- Settings Dialogs.
-------------------------------------------------------------------------------------------------------------

local function SettingsCreateTeamList()
	-- Position and size constants.
	local teamListButtonControlWidth = 250
	local iconSize = 24
	local groupListWidth = 200
	local extaSpacing = 40
	local rowHeight = 30
	local rowsToDisplay = 8
	local inviteDisbandButtonWidth = 105
	local setMasterButtonWidth = 120
	local buttonHeight = EMAHelperSettings:GetButtonHeight()
	local top = EMAHelperSettings:TopOfSettings()
	local left = EMAHelperSettings:LeftOfSettings()
	local dropdownHeight = EMAHelperSettings:GetDropdownHeight()	
	local lefticon =  left + 35
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( false )
	local horizontalSpacing = EMAHelperSettings:GetHorizontalSpacing()
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local dropBoxWidth = (headingWidth - horizontalSpacing) / 4	
	local iconHight = iconSize + 10
	local teamListWidth = headingWidth - teamListButtonControlWidth - horizontalSpacing
	local leftOfList = left + horizontalSpacing
	local rightOfList = teamListWidth + horizontalSpacing
	local checkBoxWidth = (headingWidth - horizontalSpacing) / 2
	local topOfList = top - headingHeight
	local movingTop = top
	-- Team list internal variables (do not change).
	EMA.settingsControl.teamListHighlightRow = 1
	EMA.settingsControl.teamListOffset = 1
	-- A blank to get layout to show right?
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L[""], movingTop, false )
	movingTop = movingTop - headingHeight
	EMA.settingsControl.labelOne = EMAHelperSettings:CreateContinueLabel( 
		EMA.settingsControl, 
		teamListButtonControlWidth,
		teamListWidth / 2, 
		leftOfList,
		L["TEAM_HEADER"]
	)
	EMA.settingsControl.labelTwo = EMAHelperSettings:CreateContinueLabel( 
		EMA.settingsControl, 
		teamListButtonControlWidth,  

		teamListButtonControlWidth + iconSize + groupListWidth, 
		leftOfList,
		L["GROUPS_HEADER"]
	)
	-- Create a team list frame.	
	local list = {}
	list.listFrameName = "EMATeamSettingsTeamListFrame"
	list.parentFrame = EMA.settingsControl.widgetSettings.content
	list.listTop = topOfList
	list.listLeft = lefticon
	list.listWidth = teamListWidth
	list.rowHeight = rowHeight
	list.rowsToDisplay = rowsToDisplay
	list.columnsToDisplay = 3
	list.columnInformation = {}
	list.columnInformation[1] = {}
	list.columnInformation[1].width = 30
	list.columnInformation[1].alignment = "LEFT"
	list.columnInformation[2] = {}
	list.columnInformation[2].width = 55
	list.columnInformation[2].alignment = "CENTER"
	list.columnInformation[3] = {}
	list.columnInformation[3].width = 15
	list.columnInformation[3].alignment = "RIGHT"	
	list.scrollRefreshCallback = EMA.SettingsTeamListScrollRefresh
	list.rowClickCallback = EMA.SettingsTeamListRowClick
	EMA.settingsControl.teamList = list
	EMAHelperSettings:CreateScrollList( EMA.settingsControl.teamList )
	-- Group Frame
	local listTwo = {}
	listTwo.listFrameName = "EMATeamSettingsTeamListTwoFrame"
	listTwo.parentFrame = EMA.settingsControl.widgetSettings.content
	listTwo.listTop = topOfList
	listTwo.listLeft = rightOfList + extaSpacing
	listTwo.listWidth = groupListWidth
	listTwo.rowHeight = rowHeight
	listTwo.rowsToDisplay = rowsToDisplay
	listTwo.columnsToDisplay = 1
	listTwo.columnInformation = {}
	listTwo.columnInformation[1] = {}
	listTwo.columnInformation[1].width = 80
	listTwo.columnInformation[1].alignment = "CENTER"
	listTwo.scrollRefreshCallback = EMA.SettingsGroupListScrollRefresh
	listTwo.rowClickCallback = EMA.SettingsGroupListRowClick
	EMA.settingsControl.groupList = listTwo
	EMAHelperSettings:CreateScrollList( EMA.settingsControl.groupList )
	-- Position and size constants (once list height is known).	
	local bottomOfList = topOfList - list.listHeight - verticalSpacing	
	local bottomOfSection = bottomOfList -  dropdownHeight - verticalSpacing		
	--Create Icons
	EMA.settingsControl.teamListButtonAdd = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharAdd.tga", --icon Image
		left - iconSize - 11 , 
		topOfList - verticalSpacing, 
		L[""], 
		EMA.SettingsAddClick,
		L["BUTTON_ADD_HELP"]
	)
	EMA.settingsControl.teamListButtonParty = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharAddParty.tga", --icon Image
		left - iconSize - 11 , 
		topOfList - verticalSpacing - iconHight, 
		L[""], 
		EMA.SettingsAddPartyClick,
		L["BUTTON_ADDALL_HELP"]
	)
--[[
	EMA.settingsControl.teamListButtonAddIsboxerList = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\Isboxer_Add.tga", --icon Image
		left - iconSize - 11 , 
		topOfList - verticalSpacing - iconHight * 2, 
		L[""], 
		EMA.SettingsAddIsboxerListClick,
		L["BUTTON_ISBOXERADD_HELP"]
	)	
]]
	EMA.settingsControl.teamListButtonMoveUp = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharUp.tga", --icon Image
		left - iconSize - 11,
		topOfList - verticalSpacing - iconHight * 3, 
		L[""], 
		EMA.SettingsMoveUpClick,
		L["BUTTON_UP_HELP"]
	)
	EMA.settingsControl.teamListButtonMoveDown = EMAHelperSettings:Icon(
		EMA.settingsControl, 
		iconSize,
		iconSize,	
		"Interface\\Addons\\EMA\\Media\\CharDown.tga", --icon Image
		left - iconSize - 11,
		topOfList - verticalSpacing - iconHight * 4,
		L[""],
		EMA.SettingsMoveDownClick,
		L["BUTTON_DOWN_HELP"]		
	)
	EMA.settingsControl.teamListButtonRemove = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharRemove.tga", --icon Image
		left - iconSize - 11 , 
		topOfList - verticalSpacing - iconHight * 5,
		L[""], 
		EMA.SettingsRemoveClick,
		L["BUTTON_REMOVE_HELP"]
	)
	EMA.settingsControl.teamListButtonSetMaster = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharMaster.tga", --icon Image
		left - iconSize - 11 , 
		topOfList - verticalSpacing - iconHight * 6,
		L[""], 
		EMA.SettingsSetMasterClick,
		L["BUTTON_MASTER_HELP"]
	)
	EMA.settingsControl.teamListButtonRemoveFromGroup = EMAHelperSettings:Icon( 
		EMA.settingsControl, 
		iconSize,
		iconSize,
		"Interface\\Addons\\EMA\\Media\\CharRemoveParty.tga", --icon Image
		rightOfList + dropBoxWidth + 11 , 
		bottomOfList ,
		L[""], 
		EMA.SettingsRemoveGroupClick,
		L["BUTTON_GROUP_REMOVE_HELP"]
	)	
	-- Group Mangent
	EMA.settingsControl.teamListDropDownList = EMAHelperSettings:CreateDropdown(
		EMA.settingsControl, 
		dropBoxWidth,	
		rightOfList + extaSpacing, -- horizontalSpacing,
		bottomOfList + 11, 
		L["GROUP_LIST"]
	)
	EMA.settingsControl.teamListDropDownList:SetList( EMA.GroupAreaList() )
	EMA.settingsControl.teamListDropDownList:SetCallback( "OnValueChanged",  EMA.TeamListDropDownList )
--[[
	-- IsboxerSync
	EMA.settingsControl.teamListCheckBoxSyncIsboxer = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		lefticon, 
		bottomOfList - 11,
		L["CHECKBOX_ISBOXER_ADD"],
		EMA.SettingsSyncIsboxerToggle,
		L["CHECKBOX_ISBOXER_ADD_HELP"]
	)	
]]	
	return bottomOfSection
end

local function SettingsCreateMasterControl( top )
	-- Get positions.
	local checkBoxHeight = EMAHelperSettings:GetCheckBoxHeight()
	local labelContinueHeight = EMAHelperSettings:GetContinueLabelHeight()
	local left = EMAHelperSettings:LeftOfSettings()
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( false )
	local horizontalSpacing = EMAHelperSettings:GetHorizontalSpacing()
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local checkBoxWidth = (headingWidth - horizontalSpacing) / 2
	local column1Left = left
	local column2Left = left + checkBoxWidth + horizontalSpacing
	local bottomOfSection = top - headingHeight - (checkBoxHeight * 1) - (verticalSpacing * 3)
	-- Create a heading.
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["MASTER_CONTROL"], top, false )
	-- Create checkboxes.
	
	EMA.settingsControl.masterControlCheckBoxMasterChange = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column1Left, 
		top - headingHeight,
		L["CHECKBOX_MASTER_LEADER"],
		EMA.SettingsMasterChangeToggle,
		L["CHECKBOX_MASTER_LEADER_HELP"]
	)
	EMA.settingsControl.masterControlCheckBoxMasterChangeClickToMove = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column2Left, 
		top - headingHeight, 
		L["CHECKBOX_CTM"],
		EMA.SettingsMasterChangeClickToMoveToggle,
		L["CHECKBOX_CTM_HELP"]
	)	
	return bottomOfSection
end

local function SettingsCreatePartyInvitationsControl( top )
	-- Get positions.
	local checkBoxHeight = EMAHelperSettings:GetCheckBoxHeight()
	local left = EMAHelperSettings:LeftOfSettings()
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( false )
	local horizontalSpacing = EMAHelperSettings:GetHorizontalSpacing()
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local checkBoxWidth = (headingWidth - horizontalSpacing) / 2
	local column1Left = left
	local column2Left = left + checkBoxWidth + horizontalSpacing
	local bottomOfSection = top - headingHeight - (checkBoxHeight * 3) - (verticalSpacing * 2)
	-- Create a heading.
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["PARTY_CONTROLS"], top, false )
	-- Create checkboxes.
	EMA.settingsControl.partyInviteControlCheckBoxConvertToRaid = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column1Left, 
		top - headingHeight,
		L["CHECKBOX_CONVERT_RAID"],
		EMA.SettingsinviteConvertToRaidToggle,
		L["CHECKBOX_CONVERT_RAID_HELP"]
	)
	EMA.settingsControl.partyInviteControlCheckBoxSetAllAssist = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column2Left, 
		top - headingHeight,
		L["CHECKBOX_ASSISTANT"],
		EMA.SettingsinviteSetAllAssistToggle,
		L["CHECKBOX_ASSISTANT_HELP"]
	)
	EMA.settingsControl.partyInviteControlCheckBoxAcceptMembers = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column1Left, 
		top - headingHeight - checkBoxHeight, 
		L["CHECKBOX_TEAM"],
		EMA.SettingsAcceptInviteMembersToggle,
		L["CHECKBOX_TEAM_HELP"]
	)
	EMA.settingsControl.partyInviteControlCheckBoxAcceptFriends = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column2Left, 
		top - headingHeight - checkBoxHeight, 
		L["CHECKBOX_ACCEPT_FROM_FRIENDS"],
		EMA.SettingsAcceptInviteFriendsToggle,
		L["CHECKBOX_ACCEPT_FROM_FRIENDS_HELP"]
	)
	EMA.settingsControl.partyInviteControlCheckBoxAcceptGuild = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column1Left, 
		top - headingHeight - checkBoxHeight - checkBoxHeight,
		L["CHECKBOX_ACCEPT_FROM_GUILD"],
		EMA.SettingsAcceptInviteGuildToggle,
		L["CHECKBOX_ACCEPT_FROM_GUILD_HELP"]
	)	
	EMA.settingsControl.partyInviteControlCheckBoxDeclineStrangers = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		checkBoxWidth, 
		column1Left, 
		top - headingHeight  - checkBoxHeight - checkBoxHeight - checkBoxHeight,
		L["CHECKBOX_DECLINE_STRANGERS"],
		EMA.SettingsDeclineInviteStrangersToggle,
		L["CHECKBOX_DECLINE_STRANGERS_HELP"]
	)
	return bottomOfSection	
end


local function SettingsCreate()
	EMA.settingsControl = {}
	-- Create the settings panel.
	EMAHelperSettings:CreateSettings( 
		EMA.settingsControl, 
		EMA.moduleDisplayName, 
		EMA.parentDisplayName, 
		EMA.SettingsPushSettingsClick,
		EMA.moduleIcon,
		EMA.moduleOrder
	)
	-- Create the team list controls.
	local bottomOfTeamList = SettingsCreateTeamList()
	-- Create the master control controls.
	local bottomOfMasterControl = SettingsCreateMasterControl( bottomOfTeamList )
	-- Create the party invitation controls.
	local bottomOfPartyInvitationControl = SettingsCreatePartyInvitationsControl( bottomOfMasterControl )
	EMA.settingsControl.widgetSettings.content:SetHeight( - bottomOfPartyInvitationControl )
	-- Help
	local helpTable = {}
	EMAHelperSettings:CreateHelp( EMA.settingsControl, helpTable, EMA:GetConfiguration() )	
end

-------------------------------------------------------------------------------------------------------------
-- Popup Dialogs.
-------------------------------------------------------------------------------------------------------------

-- Initialize Popup Dialogs.
local function InitializePopupDialogs()
   -- Ask the name of the character to add as a new member.
   StaticPopupDialogs["EMATEAM_ASK_CHARACTER_NAME"] = {
        text = L["STATICPOPUP_ADD"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = 1,
        timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		OnShow = function( self )
			self.editBox:SetText("")
            self.button1:Disable()
            self.editBox:SetFocus()
        end,
		OnAccept = function( self )
			EMA:AddMemberGUI( self.editBox:GetText() )
		end,
		EditBoxOnTextChanged = function( self )
            if not self:GetText() or self:GetText():trim() == "" then
				self:GetParent().button1:Disable()
            else
                self:GetParent().button1:Enable()
            end
        end,
		EditBoxOnEnterPressed = function( self )
            if self:GetParent().button1:IsEnabled() then
				EMA:AddMemberGUI( self:GetText() )
            end
            self:GetParent():Hide()
        end,			
    }
   -- Confirm removing characters from member list.
   StaticPopupDialogs["EMATEAM_CONFIRM_REMOVE_CHARACTER"] = {
        text = L["STATICPOPUP_REMOVE"],
        button1 = ACCEPT,
        button2 = CANCEL,
        timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
        OnAccept = function( self )
			EMA:RemoveMemberGUI()
		end,
    }
end

-------------------------------------------------------------------------------------------------------------
-- Team management.
-------------------------------------------------------------------------------------------------------------

function EMA:GroupAreaList()
	table.sort( EMA.simpleAreaList )
	return EMA.simpleAreaList
end

local function refreshDropDownList()
	EMAUtilities:ClearTable( EMA.simpleAreaList )
	EMA.simpleAreaList[" "] = " "
	for id, tag in pairs( EMAApi.GroupList() ) do
		local groupName =  EMAUtilities:Capitalise( tag )
		EMA.simpleAreaList[groupName] = groupName	
	end
	table.sort( EMA.simpleAreaList )
	EMA.settingsControl.teamListDropDownList:SetList( EMA.simpleAreaList )
end

local function TeamList()
	--return pairs( EMA.db.teamList )
	local teamlist = {}
	for name, info in pairs( EMA.db.newTeamList ) do
		for _, charInfo in pairs (info) do
			teamlist[name] = charInfo.order
		end
	end
	return pairs( teamlist )
end


local function FullTeamList()
	local fullTeamList = {}
	for name, info in pairs ( EMA.db.newTeamList ) do
		for _, charInfo in pairs (info) do
		table.insert(fullTeamList, { charInfo.name, charInfo.order, charInfo.class, charInfo.online } )
		end
	end
	return pairs( fullTeamList )
end	

local function setClass()
	for characterName, position in pairs( EMA.db.newTeamList ) do
	local class, classFileName, classIndex = UnitClass( Ambiguate(characterName, "none") )
		--EMA:Print("new", class, CharacterName )
		if class ~= nil then
			EMA.db.characterClass[characterName] = classFileName
		end
	end	
end

local function GetClass( characterName )
	local class = nil
	local color = nil
	for teamCharacterName, info in pairs( EMA.db.newTeamList ) do
		if characterName == teamCharacterName then
			for _, charInfo in pairs (info) do
			--charInfo.class
				--EMA:Print("classDatatest",  characterName, charInfo.class )
				if charInfo.class ~= nil or charInfo.class ~= "UNKNOWN" then
					class = EMAUtilities:Lowercase( charInfo.class )
					color = RAID_CLASS_COLORS[charInfo.class]
				end
			end			
		end	
	end
	return class, color
end	

-- Get the largest order number from the team list.
local function GetTeamListMaximumOrder()
	local largestPosition = 0
	for characterName, position in EMAApi.TeamList() do 
		if position > largestPosition then
			largestPosition = position
		end
	end
	return largestPosition
end

local function GetTeamListMaximumOrderOnline()
	local totalMembersDisplayed = 0
		for characterName, position in EMAApi.TeamList() do
			if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
				totalMembersDisplayed = totalMembersDisplayed + 1
			end
		end	
	return totalMembersDisplayed
end		
		
local function IsCharacterInTeam( name )
	local characterName = EMAUtilities:Lowercase( name )
	local isMember = false
	if not isMember then
		for fullCharacterName, position in EMAApi.TeamList() do 
			local checkFullName = EMAUtilities:Lowercase( fullCharacterName )
			local name, realm = strsplit("-", checkFullName, 2 )
			--EMA:Print('checking', name, 'vs', characterName, "or", checkFullName )
			if name == characterName or checkFullName == characterName then
				--EMA:Print('match found')
				isMember = true
				break
			end
		end
	end
	--EMA:Print('returning', isMember)
	return isMember
end


-- Get the master for this character.
local function GetMasterName()
	return EMA.db.master	
end

-- Return true if the character specified is in the master.
local function IsCharacterTheMaster( characterName )
	local isTheMaster = false
	if characterName == GetMasterName() then
		isTheMaster = true
	end
	return isTheMaster
end

-- Set the master for EMA character; the master character must be online.
local function SetMaster( master )
	-- Make sure a valid string value is supplied.
	if (master ~= nil) and (master:trim() ~= "") then
		-- The name must be capitalised i still like this or though its not needed.
		--local character = EMAUtilities:Capitalise( master )
		local character = EMAUtilities:AddRealmToNameIfMissing( master )
		-- Only allow characters in the team list to be the master.
		if IsCharacterInTeam( character ) == true then
			-- Set the master.
			EMA.db.master = character
			-- Refresh the settings.
			EMA:SettingsRefresh()			
			-- Send a message to any listeners that the master has changed.
			EMA:SendMessage( EMA.MESSAGE_TEAM_MASTER_CHANGED, character )
		else
			-- Character not in team.  Tell the team.
			EMA:EMASendMessageToTeam( EMA.characterName, L["A_IS_NOT_IN_TEAM"]( character ), false )
		end
	end
end

-- Add a member to the member list.
local function AddMember( importName, class )
	local name = nil
	local singleName, realm = strsplit( "-" , importName, 2 )
	local characterName = nil
	local name = EMAUtilities:Capitalise( singleName )
	if realm ~= nil then
		characterName = name.."-"..realm
	else
		characterName = name
	end	
	if characterName == "Target" then
		local UnitIsPlayer = UnitIsPlayer("target")
		if UnitIsPlayer == true then
			local unitName = GetUnitName("target", true)
			--EMA:Print("Target", unitName)
			name = unitName
		else
			EMA:Print(L["TEAM_NO_TARGET"])
			return
		end	
	elseif characterName == "Mouseover"  then
		local UnitIsPlayer = UnitIsPlayer("mouseover")
		if UnitIsPlayer == true then
			local unitName = GetUnitName("mouseover", true)
			--EMA:Print("mouseover", unitName)
			name = unitName
		else
			EMA:Print(L["TEAM_NO_TARGET"])
			return
		end	
	else
		name = characterName
	end	
	-- Wow names are at least two characters.
	if name ~= nil and name:trim() ~= "" and name:len() > 1 then
		-- If the character is not already in the list...
		local character = EMAUtilities:AddRealmToNameIfMissing( name )
		if EMA.db.newTeamList[character] == nil then
			-- Get the maximum order number.
			--Store TempData
			local maxOrder = "0"
			local CharacterClass = "UNKNOWN"
			local Online = true
			-- Real Data
			local maxOrder = GetTeamListMaximumOrder()	
			if class ~= nil then
				local upperClass = string.upper(class)
				CharacterClass = upperClass 
			end
			local _, classFileName = UnitClass( Ambiguate(character, "none") )
			if classFileName ~= nil then 
				CharacterClass = classFileName
			end
			--EMA:Print("DebugAddToDB", "toon", character, "order", maxOrder, "class", CharacterClass, "online", Online ) 
			EMA.db.newTeamList[character] = {}
			table.insert( EMA.db.newTeamList[character], {name = character, order = maxOrder + 1, class = CharacterClass, online = Online } )
			-- Send a message to any listeners that EMA character has been added.
			EMA:SendMessage( EMA.MESSAGE_TEAM_CHARACTER_ADDED, character )
			-- Refresh the settings.
			EMA:SettingsRefresh()
		end
	end	
end

-- Add all party/raid members to the member list. does not worl cross rwalm todo
function EMA:AddPartyMembers()
	 for iteratePartyMembers = 1, GetNumGroupMembers() do	
		--EMA:Print("party/raid", numberPartyMembers, iteratePartyMembers)
		local inRaid = IsInRaid()
		if inRaid == true then
			local partyMemberName, partyMemberRealm = UnitName( "raid"..iteratePartyMembers )
			local character = EMAUtilities:AddRealmToNameIfNotNil( partyMemberName, partyMemberRealm )
			if partyMemberName ~= nil then
				if IsCharacterInTeam( character ) == false then
					AddMember( character )
				end	
			end	
		else
			local partyMemberName, partyMemberRealm = UnitName( "party"..iteratePartyMembers )
			local character = EMAUtilities:AddRealmToNameIfNotNil( partyMemberName, partyMemberRealm )
			if partyMemberName ~= nil then
				if IsCharacterInTeam( character ) == false then
					AddMember( character )
				end
			end	
		end
	end
end

-- Add all isboxer team members to the member list. does not worl cross rwalm todo
--[[
function EMA:AddIsboxerMembers()
	if IsAddOnLoaded("Isboxer" ) == true then 
		for characterName, teamStatus in pairs( EMA.IsboxerSyncList ) do
			if IsCharacterInTeam( characterName ) == false then
				if teamStatus == "add" and characterName ~= EMA.characterName then 
					AddMember( characterName )
				end	
			end	
		end
	end	
end
]]
-- Add a member to the member list.
function EMA:AddMemberGUI( value )
	AddMember( value )
	EMA:SettingsTeamListScrollRefresh()
end

-- Add member from the command line.
function EMA:AddMemberCommand( info, parameters )
	--local characterName = EMAUtilities:Capitalise(parameters)
	-- EMA-EE we No-longer remove character's from a team list when isboxer set's up the team we sync!
	if info == nil then
		--EMA:Print("isboxerContralRemove", parameters )
		EMA.IsboxerSyncList[characterName] = "add"
		return
	end
	-- Add the character.
	AddMember( parameters )
end

-- Get the character name at a specific position.
local function GetCharacterNameAtOrderPosition( position )
	local characterNameAtPosition = ""
	for characterName, characterPosition in EMAApi.TeamList() do
		if characterPosition == position then
			characterNameAtPosition = characterName
			break
		end
	end
	return characterNameAtPosition
end

-- Get the position for a specific character.
local function GetPositionForCharacterName( findCharacterName )
	local positionForCharacterName = 0
	for characterName, characterPosition in EMAApi.TeamList() do
		if characterName == findCharacterName then
			positionForCharacterName = characterPosition
			break
		end
	end
	return positionForCharacterName
end

local function GetPositionForCharacterNameOnline( findCharacterName )
	local positionForCharacterName = 0
		for index, characterName in EMAApi.TeamListOrderedOnline() do
			if characterName == findCharacterName then
				--EMA:Print("found", characterName, index)
				positionForCharacterName = index
				--break
			end
	end
	return positionForCharacterName
end

-- Swap character positions.
local function TeamListSwapCharacterPositions( position1, position2 )
	-- Get characters at positions.
	local character1 = GetCharacterNameAtOrderPosition( position1 )
	local character2 = GetCharacterNameAtOrderPosition( position2 )
	for name, info in pairs (EMA.db.newTeamList) do
		for _, charInfo in pairs (info) do
			if name == character1 then
				charInfo.order = position2
			end
			if name == character2 then
				charInfo.order = position1
			end
		end
	end
end

-- Makes sure that EMA character is a team member.  Enables if previously not a member.
local function ConfirmCharacterIsInTeam()
	--EMA:Print("test", EMA.characterName)
	if not IsCharacterInTeam( EMA.characterName ) then
		-- Then add as a member.
		AddMember( EMA.characterName )
	end
end

-- Make sure there is a master, if none, set this character.
local function ConfirmThereIsAMaster()
	-- Read the db option for master.  Is it set?
	if EMA.db.master:trim() == "" then
		-- No, set it to self.
		SetMaster( EMA.characterName )
	end
	-- Is the master in the member list?
	if not IsCharacterInTeam( EMA.db.master ) then
		-- No, set self as master.
		SetMaster( EMA.characterName )
	end	 
end

-- Remove a member from the member list.
local function RemoveMember( importName )
	local singleName, singleRealm = strsplit( "-" , importName, 2 )
	local characterName = nil
	local name = EMAUtilities:Capitalise( singleName )
	local realm = EMAUtilities:Capitalise( singleRealm )
	if realm ~= nil then
		characterName = name.."-"..realm
	else
		characterName = name
	end
	-- Is character in team?
	if IsCharacterInTeam( characterName ) == true and characterName ~= EMA.characterName then
		-- Remove character from list.
		local characterPosition = EMAApi.GetPositionForCharacterName( characterName )		
		-- If any character had an order greater than this character's order, then shift their order down by one.
		for name, position in EMAApi.TeamList() do	
			if position > characterPosition then
				for checkName, info in pairs (EMA.db.newTeamList) do
					for _, charInfo in pairs (info) do
						if name == checkName then
							charInfo.order = position - 1
						end	
					end
				end
			end
		end
		-- Send a message to any listeners that this character has been removed.
		EMA:SendMessage( EMA.MESSAGE_TEAM_CHARACTER_REMOVED, characterName )
		-- Make sure EMA character is a member.
		ConfirmCharacterIsInTeam()
		-- Make sure there is a master, if none, set this character.
		ConfirmThereIsAMaster()
		-- Refresh the settings.
		EMA:SettingsRefresh()
		-- Resets to Top of list!
		EMA.db.newTeamList[characterName] = nil
		--EMA:Print("count", EMA.settingsControl.teamListHighlightRow - 1 )
		EMA:SettingsTeamListRowClick( 1 , 1 )
	else
		EMA:Print("[PH] CAN NOT REMOVE SELF")
	end
end

-- Provides a GUI for a user to confirm removing selected members from the member list.
function EMA:RemoveMemberGUI()
	local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
	RemoveMember( characterName )
	EMA.settingsControl.teamListHighlightRow = 1	
	EMA:SettingsTeamListScrollRefresh()
	EMA:SettingsGroupListScrollRefresh()
end


-- Remove member from the command line.
function EMA:RemoveMemberCommand( info, parameters )
	local characterName = EMAUtilities:Capitalise(parameters)
	-- EMA-EE we No-longer remove character's from a team list when isboxer set's up the team we sync!
	if info == nil then
		--EMA.IsboxerSyncList[characterName] = "remove"
		return
	end		
	--EMA:Print("testremove", info, parameters )
	-- Wow names are at least two characters.
	if characterName ~= nil and characterName:trim() ~= "" and characterName:len() > 1 then
		-- Remove the character.
		RemoveMember( characterName )
	end
end

local function RemoveAllMembersFromTeam()
	for characterName, characterPosition in pairs( EMA.db.teamList ) do
		RemoveMember( characterName )
	end
end

-- Remove all members from the team list via command line.
function EMA:DoRemoveAllMembersFromTeam( info, parameters )
	RemoveAllMembersFromTeam()
end

function EMA:CommandIAmMaster( info, parameters )
	local tag = parameters
	local target = EMA.characterName
	if tag ~= nil and tag:trim() ~= "" then 
		EMA:EMASendCommandToTeam( EMA.COMMAND_SET_MASTER, target, tag )
	else
		EMA:EMASendCommandToTeam( EMA.COMMAND_SET_MASTER, target, "all" )
		SetMaster( target )
	end
end

function EMA:CommandSetMaster( info, parameters )
	local target, tag = strsplit( " ", parameters )
	if tag ~= nil and tag:trim() ~= "" then 
		EMA:EMASendCommandToTeam( EMA.COMMAND_SET_MASTER, target, tag )
	else
		EMA:EMASendCommandToTeam( EMA.COMMAND_SET_MASTER, target, "all" )
		SetMaster( target )
	end
end

function EMA:ReceiveCommandSetMaster( target, tag )
	if EMAPrivate.Tag.DoesCharacterHaveTag( EMA.characterName, tag ) then
		SetMaster( target )
	end
end

-- Test Isboxer Contral EbonyTest

--[[
function EMA:IsboxerSyncTeamList()
	if EMA.db.isboxerSync == true and IsAddOnLoaded("Isboxer" ) == true then
		for characterName, teamStatus in pairs( EMA.IsboxerSyncList ) do
			--EMA:Print("syncList", characterName, teamStatus )
			--if teamStatus == "remove" then 
			--	if IsCharacterInTeam( characterName ) == true and (characterName ~= EMA.characterName ) then	
			--		--EMA:Print("memberNoLongerInIsboxerTeamDelete", characterName, teamStatus )
			--		RemoveMember( characterName )
			--	end	
			else
			if teamStatus == "add" and characterName ~= EMA.characterName then
				if IsCharacterInTeam( characterName ) == false then
					--EMA:Print("Isboxer-AddMember", characterName, teamStatus )
					AddMember( characterName )
				end	
			end
		end
	end
end
]]

-------------------------------------------------------------------------------------------------------------
-- Character online status.
-------------------------------------------------------------------------------------------------------------

-- Get a character's online status..
local function GetCharacterOnlineStatus( characterName )
	local online = nil
	for name, info in pairs (EMA.db.newTeamList) do
		for _, charInfo in pairs (info) do
			if characterName == name then
				online = charInfo.online
			end	
		end
	end
	return online
end

-- Set a character's online status.
local function SetCharacterOnlineStatus( characterName, isOnline )
	--EMA:Print("setting", characterName, "to be", isOnline )
	for name, info in pairs (EMA.db.newTeamList) do
		for _, charInfo in pairs (info) do
			if characterName == name then
				--EMA:Print("Set", characterName, isOnline, charInfo.online )
				charInfo.online = isOnline
			end	
		end
	end
end

local function SetTeamStatusToOffline()
	for characterName, characterPosition in EMAApi.TeamList() do
		SetCharacterOnlineStatus( characterName, false )
		EMA:SendMessage( EMA.MESSAGE_CHARACTER_OFFLINE )
		EMA:SettingsTeamListScrollRefresh()
	end
end

local function SetTeamOnline()
	-- Set all characters online status to false.
	for characterName, characterPosition in EMAApi.TeamList() do
		SetCharacterOnlineStatus( characterName, true )
		EMA:SendMessage( EMA.MESSAGE_CHARACTER_ONLINE )
		EMA:SettingsTeamListScrollRefresh()
		--EMA:SettingsGroupListScrollRefresh()
	end
end
	
--Set character Offline. 
local function setOffline( characterName )
	local character = EMAUtilities:AddRealmToNameIfMissing( characterName )
	SetCharacterOnlineStatus( character, false )
	EMA:SendMessage( EMA.MESSAGE_CHARACTER_OFFLINE )
	EMA:SettingsTeamListScrollRefresh()
	--EMA:SettingsGroupListScrollRefresh()
end

--Set character OnLine. 
local function setOnline( characterName )
	local character = EMAUtilities:AddRealmToNameIfMissing( characterName )
	SetCharacterOnlineStatus( character, true )
	EMA:SendMessage( EMA.MESSAGE_CHARACTER_ONLINE )
	EMA:SettingsTeamListScrollRefresh()
	--EMA:SettingsGroupListScrollRefresh()
end

function EMA.ReceivesetOffline( characterName )
	--EMA:Print("command", characterName )
	setOffline( characterName, false )
	EMA:SettingsRefresh()
end

function EMA.ReceivesetOnline( characterName )
	--EMA:Print("command", characterName )
	setOnline( characterName, false )
	EMA:SettingsRefresh()
end

function EMA:SetAllMembersOffline()
	SetTeamStatusToOffline()
end	

function EMA:SetAllMembersOnline()
	SetTeamOnline()
end

-------------------------------------------------------------------------------------------------------------
-- Character team list ordering.
-------------------------------------------------------------------------------------------------------------

local function SortTeamListOrdered( characterA, characterB )
	local positionA = GetPositionForCharacterName( characterA )
	local positionB = GetPositionForCharacterName( characterB )
	return positionA < positionB
end

-- Return all characters ordered.
local function TeamListOrdered()	
	EMAUtilities:ClearTable( EMA.orderedCharacters )
	for characterName, characterPosition in EMAApi.TeamList() do
		table.insert( EMA.orderedCharacters, characterName )
	end
	table.sort( EMA.orderedCharacters, SortTeamListOrdered )
	return ipairs( EMA.orderedCharacters )
end

-- Return all characters ordered online.
local function TeamListOrderedOnline()	
	EMAUtilities:ClearTable( EMA.orderedCharactersOnline )
	for characterName, characterPosition in EMAApi.TeamList() do
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then	
			table.insert( EMA.orderedCharactersOnline, characterName )
		end	
	end
	table.sort( EMA.orderedCharactersOnline, SortTeamListOrdered )
	return ipairs( EMA.orderedCharactersOnline )
end
-------------------------------------------------------------------------------------------------------------
-- Party.
-------------------------------------------------------------------------------------------------------------

-- Invite team to party.

function EMA.DoTeamPartyInvite()
	InviteUnit( EMA.inviteList[EMA.currentInviteCount] )
	EMA.currentInviteCount = EMA.currentInviteCount + 1
	if EMA.currentInviteCount < EMA.inviteCount then
		--if GetTeamListMaximumOrderOnline() > 5 and EMA.db.inviteConvertToRaid == true then
		if EMA.inviteCount > 5 and EMA.db.inviteConvertToRaid == true then
			if EMA.db.inviteSetAllAssistant == true then	
				ConvertToRaid()
				SetEveryoneIsAssistant(true)
			else				
				ConvertToRaid()
			end
		end
		EMA:ScheduleTimer( "DoTeamPartyInvite", 0.5 )
	end	
end


function EMA:InviteTeamToParty( info, tag )
	-- Iterate each enabled member and invite them to a group.
	if tag == nil or tag == "" then
		tag = "all"
	end
	if EMAApi.DoesGroupExist(tag) == true then
		if EMAApi.IsCharacterInGroup( EMA.characterName, tag ) == false then
			--EMA:Print("IDONOTHAVETAG", tag)
			for index, characterName in TeamListOrderedOnline() do
				--EMA:Print("NextChartohavetag", tag, characterName )
				if EMAApi.IsCharacterInGroup( characterName, tag ) then
					--EMA:Print("i have tag", tag, characterName )
					EMA:EMASendCommandToTeam( EMA.COMMAND_TAG_PARTY, characterName, tag )
					break
				end
			end
			return
		else
			EMA.inviteList = {}
			EMA.inviteCount = 0
			for index, characterName in TeamListOrderedOnline() do
				if EMAApi.IsCharacterInGroup( characterName, tag ) then
					--EMA:Print("HasTag", characterName, tag )
					-- As long as they are not the player doing the inviting.
					if characterName ~= EMA.characterName then
						EMA.inviteList[EMA.inviteCount] = characterName
						EMA.inviteCount = EMA.inviteCount + 1
					end
				end
			end
		end
		EMA.currentInviteCount = 0
		EMA:ScheduleTimer( "DoTeamPartyInvite", 0.5 )
	else
	EMA:Print (L["UNKNOWN_GROUP"]..tag )
	end	
end


function EMA:PARTY_INVITE_REQUEST( event, inviter, ... )
	--EMA:Print("Inviter", inviter)
	-- Accept this invite, initially no.
	local acceptInvite = false
	-- Is character not in a group?
	if not IsInGroup( "player" ) then	
		-- Accept an invite from members?
		if EMA.db.inviteAcceptTeam == true then 
			-- If inviter found in team list, allow the invite to be accepted.
			if IsCharacterInTeam( inviter ) then
			acceptInvite = true
			end
		end			
		-- Accept an invite from friends?
		if EMA.db.inviteAcceptFriends == true then
			-- Iterate each friend; searching for the inviter in the friends list.
			for friendIndex = 1, GetNumFriends() do
				local friendName = GetFriendInfo( friendIndex )
				-- Inviter found in friends list, allow the invite to be accepted.
				if inviter == friendName then
					acceptInvite = true
					break
				end
			end	
		end
		-- Accept an invite from BNET/RealD?
		if EMA.db.inviteAcceptFriends == true and BNFeaturesEnabledAndConnected() == true then
			-- Iterate each friend; searching for the inviter in the friends list.
			local _, numFriends = BNGetNumFriends()
			for bnIndex = 1, numFriends do
				for toonIndex = 1, BNGetNumFriendGameAccounts( bnIndex ) do
					local _, toonName, client, realmName = BNGetFriendGameAccountInfo( bnIndex, toonIndex )
					--EMA:Print("BNFrindsTest", toonName, client, realmName, "inviter", inviter)
					if client == "WoW" then
						if toonName == inviter or toonName.."-"..realmName == inviter then
							acceptInvite = true
							break
						end	
					end
				end
			end	
		end					
		-- Accept and invite from guild members?
		if EMA.db.inviteAcceptGuild == true then
			if UnitIsInMyGuild( inviter ) then
				acceptInvite = true
			end
		end	
	end	
	-- Hide the party invite popup?
	local hidePopup = false
	-- Accept the group invite if allowed.
	if acceptInvite == true then
		AcceptGroup()
		hidePopup = true
	else
		-- Otherwise decline the invite if permitted.
		if EMA.db.inviteDeclineStrangers == true then
			DeclineGroup()
			hidePopup = true
		end
	end		
	-- Hide the popup group invitation request if accepted or declined the invite.
	if hidePopup == true then
		-- Make sure the invite dialog does not decline the invitation when hidden.
		for iteratePopups = 1, STATICPOPUP_NUMDIALOGS do
			local dialog = _G["StaticPopup"..iteratePopups]
			if dialog.which == "PARTY_INVITE" then
				-- Set the inviteAccepted flag to true (even if the invite was declined, as the
				-- flag is only set to stop the dialog from declining in its OnHide event).
				dialog.inviteAccepted = 1
				break
			end
			-- Ebony Sometimes invite is from XREALM even though Your on the same realm and have joined the party. This should hide the Popup.
			if dialog.which == "PARTY_INVITE_XREALM" then
				-- Set the inviteAccepted flag to true (even if the invite was declined, as the
				-- flag is only set to stop the dialog from declining in its OnHide event).
				dialog.inviteAccepted = 1
				break
			end
		end
		StaticPopup_Hide( "PARTY_INVITE" )
		StaticPopup_Hide( "PARTY_INVITE_XREALM" )
	end	
end

function EMA:DisbandTeamFromParty()
	EMA:EMASendCommandToTeam( EMA.COMMAND_LEAVE_PARTY )
end

local function LeaveTheParty()
	if IsInGroup( "player" ) then
		LeaveParty()
	end
end

function EMA:OnMasterChange( message, characterName )
	--EMA:Print("test", message, characterName)
	local playerName = EMA.characterName
	if EMA.db.masterChangePromoteLeader == true then
		if IsInGroup( "player" ) and UnitIsGroupLeader( "player" ) == true and GetMasterName() ~= playerName then
			PromoteToLeader( Ambiguate( GetMasterName(), "all" ) )
		end
	end
	if EMA.db.masterChangeClickToMove == true then
		if IsCharacterTheMaster( self.characterName ) == true then
			ConsoleExec("Autointeract 0")
		else
			ConsoleExec("Autointeract 1")
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- Addon initialization, enabling and disabling.
-------------------------------------------------------------------------------------------------------------

-- Initialise the module.
function EMA:OnInitialize()
	-- Table to Store IsboxerTeamList
	EMA.IsboxerSyncList = {}
	-- Create the settings control.
	SettingsCreate()
	-- Initialise the EMAModule part of this module.
	EMA:EMAModuleInitialize( EMA.settingsControl.widgetSettings.frame )
	-- Populate the settings.
	EMA:SettingsRefresh()	
	-- Initialise the popup dialogs.
	InitializePopupDialogs()
	-- Make sure this character is a member, add and enable if not on the list.
	ConfirmCharacterIsInTeam()
	-- Make sure there is a master, if none, set this character.
	ConfirmThereIsAMaster()
	-- Set team members online status to not connected. we do not want to do this on start-up!
	--SetTeamStatusToOffline()
	SetTeamOnline()
	-- Adds DefaultGroups to GUI
	EMA.characterGroupList = {}
	-- Key bindings.
	EMATeamSecureButtonInvite = CreateFrame( "CheckButton", "EMATeamSecureButtonInvite", nil, "SecureActionButtonTemplate" )
	EMATeamSecureButtonInvite:SetAttribute( "type", "macro" )
	EMATeamSecureButtonInvite:SetAttribute( "macrotext", "/ema-team invite" )
	EMATeamSecureButtonInvite:Hide()	
	EMATeamSecureButtonDisband = CreateFrame( "CheckButton", "EMATeamSecureButtonDisband", nil, "SecureActionButtonTemplate" )
	EMATeamSecureButtonDisband:SetAttribute( "type", "macro" )
	EMATeamSecureButtonDisband:SetAttribute( "macrotext", "/ema-team disband" )
	EMATeamSecureButtonDisband:Hide()
	EMATeamSecureButtonMaster = CreateFrame( "CheckButton", "EMATeamSecureButtonMaster", nil, "SecureActionButtonTemplate" )
	EMATeamSecureButtonMaster:SetAttribute( "type", "macro" )
	EMATeamSecureButtonMaster:SetAttribute( "macrotext", "/ema-team iammaster" )
	EMATeamSecureButtonMaster:Hide()
--Sets The class of the char.
--	setClass()
	-- Click the first row in the team list table to populate the tag list table.
	--EMA:SettingsTeamListRowClick( 1, 1 )
end

-- Called when the addon is enabled.
function EMA:OnEnable()
	EMA:RegisterEvent( "PARTY_INVITE_REQUEST" )
	EMA:RegisterMessage( EMA.MESSAGE_TEAM_MASTER_CHANGED, "OnMasterChange" )
	-- Kickstart the settings team list scroll frame.
	EMA:SettingsTeamListScrollRefresh()
	--EMA.SettingsGroupListScrollRefresh()
	-- Click the first row in the team list table to populate the tag list table.
	--EMA:SettingsTeamListRowClick( 1, 1 )
	EMA:RegisterEvent( "PLAYER_ENTERING_WORLD" )
	-- Initialise key bindings.
	EMA.keyBindingFrame = CreateFrame( "Frame", nil, UIParent )
	EMA:RegisterEvent( "UPDATE_BINDINGS" )		
	EMA:UPDATE_BINDINGS()
	-- Update DropDownList
	refreshDropDownList()
end

-- Called when the addon is disabled.
function EMA:OnDisable()
end

-------------------------------------------------------------------------------------------------------------
-- Settings Populate.
-------------------------------------------------------------------------------------------------------------

function EMA:BeforeEMAProfileChanged()	
end

function EMA:OnEMAProfileChanged()	
	-- Refresh the settings.
	EMA:SettingsRefresh()
	-- Make sure this character is a member, add and enable if not on the list.
	ConfirmCharacterIsInTeam()
	-- Make sure there is a master, if none, set this character.
	ConfirmThereIsAMaster()	
	-- Update the settings team list.
	EMA:SettingsTeamListScrollRefresh()
	--EMA:SettingsGroupListScrollRefresh()	
	-- Send team order changed and team master changed messages.
	EMA:SendMessage( EMA.MESSAGE_TEAM_ORDER_CHANGED )	
	EMA:SendMessage( EMA.MESSAGE_TEAM_MASTER_CHANGED )
end

function EMA:SettingsRefresh()
	-- Team/Group Control
	local test = " "
	--EMA.settingsControl.teamListCheckBoxSyncIsboxer:SetValue( EMA.db.isboxerSync )
	-- Master Control.
	EMA.settingsControl.masterControlCheckBoxMasterChange:SetValue( EMA.db.masterChangePromoteLeader )
	EMA.settingsControl.masterControlCheckBoxMasterChangeClickToMove:SetValue( EMA.db.masterChangeClickToMove )
	-- Party Invitiation Control.
	EMA.settingsControl.partyInviteControlCheckBoxAcceptMembers:SetValue( EMA.db.inviteAcceptTeam )
	EMA.settingsControl.partyInviteControlCheckBoxAcceptFriends:SetValue( EMA.db.inviteAcceptFriends )
	EMA.settingsControl.partyInviteControlCheckBoxAcceptGuild:SetValue( EMA.db.inviteAcceptGuild )
	EMA.settingsControl.partyInviteControlCheckBoxDeclineStrangers:SetValue( EMA.db.inviteDeclineStrangers )
	EMA.settingsControl.partyInviteControlCheckBoxConvertToRaid:SetValue( EMA.db.inviteConvertToRaid )
	EMA.settingsControl.partyInviteControlCheckBoxSetAllAssist:SetValue( EMA.db.inviteSetAllAssistant )
	-- Ensure correct state.
	EMA.settingsControl.partyInviteControlCheckBoxSetAllAssist:SetDisabled (not EMA.db.inviteConvertToRaid )
--	EMA.settingsControl.teamListCheckBoxSyncIsboxer:SetDisabled ( not IsAddOnLoaded("Isboxer" ) )
--	EMA.settingsControl.teamListButtonAddIsboxerList:SetDisabled ( not IsAddOnLoaded("Isboxer" ) )
	-- Update the settings team list.
	EMA:SettingsTeamListScrollRefresh()
	-- Check the opt out of loot settings.
	--EMA:CheckMinionsOptOutOfLoot()
end

-- Settings received.
function EMA:EMAOnSettingsReceived( characterName, settings )	
	if characterName ~= EMA.characterName then	
	-- Update the settings.
		EMA.db.newTeamList = EMAUtilities:CopyTable( settings.newTeamList )
	--	EMA.db.isboxerSync = settings.isboxerSync
		EMA.db.masterChangePromoteLeader = settings.masterChangePromoteLeader 
		EMA.db.inviteAcceptTeam = settings.inviteAcceptTeam 
		EMA.db.inviteAcceptFriends = settings.inviteAcceptFriends 
		EMA.db.inviteAcceptGuild = settings.inviteAcceptGuild 
		EMA.db.inviteDeclineStrangers = settings.inviteDeclineStrangers
		EMA.db.inviteConvertToRaid = settings.inviteConvertToRaid
		EMA.db.inviteSetAllAssistant = settings.inviteSetAllAssistant
		EMA.db.masterChangeClickToMove = settings.masterChangeClickToMove
		EMA.db.master = settings.master
		SetMaster( settings.master )
		-- Refresh the settings.
		--EMA:SettingsRefresh()
		-- Tell the player.
		EMA:Print( L["SETTINGS_RECEIVED_FROM_A"]( characterName ) )
	end
end

function EMA:PLAYER_ENTERING_WORLD(event, ...)
	-- trying this
	-- Click the first row in the team list table to populate the tag list table.
	local initialLogin, reloadingUI = ...
	EMA:SettingsTeamListRowClick( 1, 1 )
	if initialLogin then
		--EMA:Print("test")
		--EMA:IsboxerSyncTeamList()
		--EMA:ScheduleTimer( "IsboxerSyncTeamList", 0.5 )
	end	
end

-------------------------------------------------------------------------------------------------------------
-- Settings Callbacks.
-------------------------------------------------------------------------------------------------------------

function EMA:SettingsTeamListScrollRefresh()
	FauxScrollFrame_Update(
		EMA.settingsControl.teamList.listScrollFrame, 
		GetTeamListMaximumOrder(),
		EMA.settingsControl.teamList.rowsToDisplay, 
		EMA.settingsControl.teamList.rowHeight
	)	
	EMA.settingsControl.teamListOffset = FauxScrollFrame_GetOffset( EMA.settingsControl.teamList.listScrollFrame )
	for iterateDisplayRows = 1, EMA.settingsControl.teamList.rowsToDisplay do
		-- Reset.
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[1].textString:SetText( "" )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[2].textString:SetText( "" )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetText( "" )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[1].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[2].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )
		EMA.settingsControl.teamList.rows[iterateDisplayRows].highlight:SetColorTexture( 0.0, 0.0, 0.0, 0.0 )
		-- Get data.
		local dataRowNumber = iterateDisplayRows + EMA.settingsControl.teamListOffset
		if dataRowNumber <= GetTeamListMaximumOrder() then
			-- Put character name and type into columns.
			local characterName = GetCharacterNameAtOrderPosition( dataRowNumber )
			
		--local class = EMA.db.characterClass[characterName]
			--EMA:Print("Test", class)
			-- Set Class Color
			local class, color = GetClass( characterName )
			if color ~= nil then
				EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[1].textString:SetTextColor( color.r, color.g, color.b, 1.0 )
			end
			local isMaster = false
			local characterType = L["MINION"]
			if IsCharacterTheMaster( characterName ) == true then
				characterType = L["MASTER"]
				isMaster = true
			end
			local displayCharacterName , displayCharacterRleam = strsplit( "-", characterName, 2 )
			
			local isOnline = GetCharacterOnlineStatus( characterName )
			local displayOnline = nil
			if isOnline == false then
				displayOnline = L["OFFLINE"]
				EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetTextColor( 1.0, 0, 0, 1.0 )
			else
				displayOnline = L["ONLINE"]
				EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetTextColor( 0, 1.0, 0, 1.0 )
			end
			
			-- Master is a yellow colour.
			
			if isMaster == true then
				local icon = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
				displayCharacterName = strconcat(" |T"..icon..":20|t", L[" "]..displayCharacterName)
			--	EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetTextColor( 1.0, 0.96, 0.41, 1.0 )
			end
			local RealmLinked = EMAUtilities:CheckIsFromMyRealm( characterName )
			-- Set Realms not linked Red
			if RealmLinked == false then
				displayCharacterRleam = displayCharacterRleam..L[" "]..L["NOT_LINKED"]
				EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[2].textString:SetTextColor( 1.0, 0, 0, 1.0 )
			end
			
			EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[1].textString:SetText( displayCharacterName )
			EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[2].textString:SetText( displayCharacterRleam )
			EMA.settingsControl.teamList.rows[iterateDisplayRows].columns[3].textString:SetText( displayOnline )
			-- Highlight the selected row.
			if dataRowNumber == EMA.settingsControl.teamListHighlightRow then
				EMA.settingsControl.teamList.rows[iterateDisplayRows].highlight:SetColorTexture( 1.0, 1.0, 0.0, 0.5 )
			end
		end
	end
end

local function DisplayGroupsForCharacterInGroupsList( characterName )
	--if not EMA.characterGroupList then
		EMA.characterGroupList = EMAApi.GetGroupListForCharacter( characterName )
		table.sort( EMA.characterGroupList )
		EMA:SettingsGroupListScrollRefresh()
	--end	
end

local function GetGroupAtPosition( position )
	return EMA.characterGroupList[position]
	
end

local function GetTagListMaxPosition()
	return #EMA.characterGroupList
end

function EMA:SettingsTeamListRowClick( rowNumber, columnNumber )
	if EMA.settingsControl.teamListOffset + rowNumber <= GetTeamListMaximumOrder() then	
		EMA.settingsControl.teamListHighlightRow = EMA.settingsControl.teamListOffset + rowNumber
		EMA:SettingsTeamListScrollRefresh()
		-- Group
		EMA.settingsControl.groupListHighlightRow = 1
		local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
		DisplayGroupsForCharacterInGroupsList( characterName )
		if columnNumber == 3 then
			local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
			local onLine = GetCharacterOnlineStatus(characterName)
			if onLine == true and characterName ~= EMA.characterName then
				setOffline( characterName )
			else	
				setOnline( characterName )
			end	
		end
		
	end
end											   

function EMA:SettingsGroupListScrollRefresh()
	FauxScrollFrame_Update(
		EMA.settingsControl.groupList.listScrollFrame, 
		--EMAPrivate.Tag.GetTagListMaxPosition(),
		EMAApi.CharacterMaxGroups(),
		EMA.settingsControl.groupList.rowsToDisplay, 
		EMA.settingsControl.groupList.rowHeight
	)	
	EMA.settingsControl.groupListOffset = FauxScrollFrame_GetOffset( EMA.settingsControl.groupList.listScrollFrame )
	for iterateDisplayRows = 1, EMA.settingsControl.groupList.rowsToDisplay do	
		
		EMA.settingsControl.groupList.rows[iterateDisplayRows].columns[1].textString:SetText( "" )
		EMA.settingsControl.groupList.rows[iterateDisplayRows].columns[1].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )
		EMA.settingsControl.groupList.rows[iterateDisplayRows].highlight:SetColorTexture( 0.0, 0.0, 0.0, 0.0 )
		local dataRowNumber = iterateDisplayRows + EMA.settingsControl.groupListOffset
		if dataRowNumber <= EMAApi.CharacterMaxGroups() then
		--local characterName = EMAApi.GetGroupListForCharacter --EMA.CharGroupListName
		--local group = GetGroupAtPosition(characterName,dataRowNumber)
		local group = GetGroupAtPosition( dataRowNumber )
		local groupName = EMAUtilities:Capitalise( group )
		--local group = EMAApi.GetGroupAtPosition( dataRowNumber )
			EMA.settingsControl.groupList.rows[iterateDisplayRows].columns[1].textString:SetText( groupName ) 
			--EMA:Print("test", dataRowNumber, group, characterName ) 
			local systemGroup = EMAApi.IsASystemGroup( group )
			if systemGroup == true then
				EMA.settingsControl.groupList.rows[iterateDisplayRows].columns[1].textString:SetTextColor( 1.0, 0.96, 0.41, 1.0 )
			end
			if dataRowNumber == EMA.settingsControl.groupListHighlightRow then
				EMA.settingsControl.groupList.rows[iterateDisplayRows].highlight:SetColorTexture( 1.0, 1.0, 0.0, 0.5 )	
			end
		end	
	end

end	

function EMA:SettingsGroupListRowClick( rowNumber, columnNumber )		
	if EMA.settingsControl.groupListOffset + rowNumber <= GetTagListMaxPosition() then
		EMA.settingsControl.groupListHighlightRow = EMA.settingsControl.groupListOffset + rowNumber
		EMA:SettingsGroupListScrollRefresh()
	end
end

-- For Api Update For anywhere you add a Group. ( mosty Tag.lua )
local function RefreshGroupList()
	EMA:SettingsGroupListScrollRefresh()
end

function EMA:TeamListDropDownList(event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
	local groupName = EMAUtilities:Lowercase( value )
	--EMA:Print("test", characterName, groupName )
	-- We Have a group and characterName Lets Add it to the groupList
	EMAApi.AddCharacterToGroup( characterName, groupName )
	-- Reset the groupList Back to "Nothing"
	EMA.settingsControl.teamListDropDownList:SetValue( " " )
	-- update Lists
	EMA:SettingsRefresh()
	EMA:SettingsGroupListScrollRefresh()
end

function EMA.SettingsRemoveGroupClick(event, value )
	local tag = GetGroupAtPosition( EMA.settingsControl.groupListHighlightRow )
	local systemGroup = EMAApi.IsASystemGroup( tag )
	local groupName = EMAUtilities:Lowercase( tag )
	local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
	local systemGroup = EMAApi.IsASystemGroup( tag )
	-- Remove From Tag List
	if systemGroup == false then
		EMAApi.RemoveGroupFromCharacter( characterName, groupName )
	else
		--TODO: Update
		EMA:Print("[PH] CAN NOT REMOVE FORM THIS GROUP!")
	end
	-- update Lists
	EMA:SettingsRefresh()
	EMA:SettingsGroupListScrollRefresh()
end

function EMA:SettingsPushSettingsClick( event )
	EMA:EMASendSettings()
	--We Needs to Update The TeamGroup List as well.
	EMAApi.PushGroupSettings()
end

function EMA:SettingsMoveUpClick( event )
	if EMA.settingsControl.teamListHighlightRow > 1 then
		TeamListSwapCharacterPositions( EMA.settingsControl.teamListHighlightRow, EMA.settingsControl.teamListHighlightRow - 1 )
		EMA.settingsControl.teamListHighlightRow = EMA.settingsControl.teamListHighlightRow - 1
		if EMA.settingsControl.teamListHighlightRow <= EMA.settingsControl.teamListOffset then
			EMAHelperSettings:SetFauxScrollFramePosition( 
				EMA.settingsControl.teamList.listScrollFrame, 
				EMA.settingsControl.teamListHighlightRow - 1, 
				GetTeamListMaximumOrder(), 
				EMA.settingsControl.teamList.rowHeight 
			)
		end
		EMA:SettingsTeamListScrollRefresh()
		--EMA:SettingsGroupListScrollRefresh()
		EMA:SendMessage( EMA.MESSAGE_TEAM_ORDER_CHANGED )
	end
end

function EMA:SettingsMoveDownClick( event )
	if EMA.settingsControl.teamListHighlightRow < GetTeamListMaximumOrder() then
		TeamListSwapCharacterPositions( EMA.settingsControl.teamListHighlightRow, EMA.settingsControl.teamListHighlightRow + 1 )
		EMA.settingsControl.teamListHighlightRow = EMA.settingsControl.teamListHighlightRow + 1
		if EMA.settingsControl.teamListHighlightRow > ( EMA.settingsControl.teamListOffset + EMA.settingsControl.teamList.rowsToDisplay ) then
			EMAHelperSettings:SetFauxScrollFramePosition( 
				EMA.settingsControl.teamList.listScrollFrame, 
				EMA.settingsControl.teamListHighlightRow + 1, 
				GetTeamListMaximumOrder(), 
				EMA.settingsControl.teamList.rowHeight 
			)
		end
		EMA:SettingsTeamListScrollRefresh()
		--EMA:SettingsGroupListScrollRefresh()
		EMA:SendMessage( EMA.MESSAGE_TEAM_ORDER_CHANGED )
	end
end

function EMA:SettingsAddClick( event )
	StaticPopup_Show( "EMATEAM_ASK_CHARACTER_NAME" )
end

function EMA:SettingsRemoveClick( event )
	local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
	StaticPopup_Show( "EMATEAM_CONFIRM_REMOVE_CHARACTER", characterName )
end

function EMA.SettingsAddPartyClick( event )
	EMA:AddPartyMembers()
end
--[[
function EMA:SettingsAddIsboxerListClick( event )
	EMA:AddIsboxerMembers()
end
]]
function EMA:SettingsInviteClick( event )
	EMA:InviteTeamToParty(nil)
end

function EMA:SettingsDisbandClick( event )
	EMA:DisbandTeamFromParty()
end
--[[
function EMA:SettingsSyncIsboxerToggle( event, checked)
	EMA.db.isboxerSync = checked
	EMA:SettingsRefresh()
end	
]]
function EMA:SettingsSetMasterClick( event )
	local characterName = GetCharacterNameAtOrderPosition( EMA.settingsControl.teamListHighlightRow )
	EMA:EMASendCommandToTeam( EMA.COMMAND_SET_MASTER, characterName, "all" )
	SetMaster( characterName )
	EMA:SettingsTeamListScrollRefresh()
end

function EMA:SettingsMasterChangeToggle( event, checked )
	EMA.db.masterChangePromoteLeader = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsMasterChangeClickToMoveToggle( event, checked )
	EMA.db.masterChangeClickToMove = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsAcceptInviteMembersToggle( event, checked )
	EMA.db.inviteAcceptTeam = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsAcceptInviteFriendsToggle( event, checked )
	EMA.db.inviteAcceptFriends = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsAcceptInviteGuildToggle( event, checked )
	EMA.db.inviteAcceptGuild = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsDeclineInviteStrangersToggle( event, checked )
	EMA.db.inviteDeclineStrangers = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsinviteConvertToRaidToggle( event, checked )
	EMA.db.inviteConvertToRaid = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsinviteSetAllAssistToggle( event, checked )
	EMA.db.inviteSetAllAssistant = checked
end

-------------------------------------------------------------------------------------------------------------
-- Key bindings.
-------------------------------------------------------------------------------------------------------------

function EMA:UPDATE_BINDINGS()
	if InCombatLockdown() then
		return
	end
	ClearOverrideBindings( EMA.keyBindingFrame )
	local key1, key2 = GetBindingKey( "TEAMINVITE" )		
	if key1 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key1, "EMATeamSecureButtonInvite" ) 
	end
	if key2 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key2, "EMATeamSecureButtonInvite" ) 
	end	
	local key1, key2 = GetBindingKey( "TEAMDISBAND" )		
	if key1 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key1, "EMATeamSecureButtonDisband" ) 
	end
	if key2 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key2, "EMATeamSecureButtonDisband" ) 
	end
	local key1, key2 = GetBindingKey( "TEAMMASTER" )		
	if key1 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key1, "EMATeamSecureButtonMaster" ) 
	end
	if key2 then 
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key2, "EMATeamSecureButtonMaster" ) 
	end
end

-------------------------------------------------------------------------------------------------------------
-- Commands.
-------------------------------------------------------------------------------------------------------------

function EMA:EMAOnCommandReceived( sender, commandName, ... )
	if commandName == EMA.COMMAND_LEAVE_PARTY then
		if IsCharacterInTeam( sender ) == true then
			LeaveTheParty()
		end
	end
	if commandName == EMA.COMMAND_SET_MASTER then
		if IsCharacterInTeam( sender ) == true then
			EMA:ReceiveCommandSetMaster( ... )
		end	
	end
	--Ebony
	if commandName == EMA.COMMAND_SET_OFFLINE then
		if IsCharacterInTeam( sender ) == true then
			EMA.ReceivesetOffline( ... )
		end
	end
	if commandName == EMA.COMMAND_SET_ONLINE then
		if IsCharacterInTeam( sender ) == true then
			EMA.ReceivesetOnline( ... )
		end
	end
	if commandName == EMA.COMMAND_TAG_PARTY then
		if IsCharacterInTeam( sender ) == true then
			EMA.TagParty( characterName, tag, ... )
		end	
	end	
end

-- Functions available from EMA Team for other EMA internal objects.
EMAPrivate.Team.MESSAGE_TEAM_MASTER_CHANGED = EMA.MESSAGE_TEAM_MASTER_CHANGED
EMAPrivate.Team.MESSAGE_TEAM_ORDER_CHANGED = EMA.MESSAGE_TEAM_ORDER_CHANGED
EMAPrivate.Team.MESSAGE_TEAM_CHARACTER_ADDED = EMA.MESSAGE_TEAM_CHARACTER_ADDED
EMAPrivate.Team.MESSAGE_TEAM_CHARACTER_REMOVED = EMA.MESSAGE_TEAM_CHARACTER_REMOVED
EMAPrivate.Team.TeamList = TeamList
EMAPrivate.Team.IsCharacterInTeam = IsCharacterInTeam
EMAPrivate.Team.IsCharacterTheMaster = IsCharacterTheMaster
EMAPrivate.Team.GetMasterName = GetMasterName
EMAPrivate.Team.SetTeamStatusToOffline = SetTeamStatusToOffline
EMAPrivate.Team.GetCharacterOnlineStatus = GetCharacterOnlineStatus
EMAPrivate.Team.SetTeamOnline = SetTeamOnline
EMAPrivate.Team.GetCharacterNameAtOrderPosition = GetCharacterNameAtOrderPosition
EMAPrivate.Team.GetTeamListMaximumOrder = GetTeamListMaximumOrder
EMAPrivate.Team.RemoveAllMembersFromTeam = RemoveAllMembersFromTeam
EMAPrivate.Team.setOffline = setOffline
EMAPrivate.Team.setOnline = setOline
EMAPrivate.Team.RefreshGroupList = RefreshGroupList

-- Functions available for other addons.
EMAApi.MESSAGE_TEAM_MASTER_CHANGED = EMA.MESSAGE_TEAM_MASTER_CHANGED
EMAApi.MESSAGE_TEAM_ORDER_CHANGED = EMA.MESSAGE_TEAM_ORDER_CHANGED
EMAApi.MESSAGE_TEAM_CHARACTER_ADDED = EMA.MESSAGE_TEAM_CHARACTER_ADDED
EMAApi.MESSAGE_TEAM_CHARACTER_REMOVED = EMA.MESSAGE_TEAM_CHARACTER_REMOVED
EMAApi.IsCharacterInTeam = IsCharacterInTeam
EMAApi.IsCharacterTheMaster = IsCharacterTheMaster
EMAApi.GetMasterName = GetMasterName
EMAApi.TeamList = TeamList
EMAApi.FullTeamList = FullTeamList
EMAApi.Offline = Offline
EMAApi.TeamListOrdered = TeamListOrdered
EMAApi.GetCharacterNameAtOrderPosition = GetCharacterNameAtOrderPosition
EMAApi.GetPositionForCharacterName = GetPositionForCharacterName 
EMAApi.GetTeamListMaximumOrder = GetTeamListMaximumOrder
EMAApi.GetCharacterOnlineStatus = GetCharacterOnlineStatus
EMAApi.RemoveAllMembersFromTeam = RemoveAllMembersFromTeam
EMAApi.MESSAGE_CHARACTER_ONLINE = EMA.MESSAGE_CHARACTER_ONLINE
EMAApi.MESSAGE_CHARACTER_OFFLINE = EMA.MESSAGE_CHARACTER_OFFLINE
EMAApi.setOffline = setOffline
EMAApi.setOnline = setOnline
EMAApi.GetTeamListMaximumOrderOnline = GetTeamListMaximumOrderOnline
EMAApi.TeamListOrderedOnline = TeamListOrderedOnline
EMAApi.GetPositionForCharacterNameOnline = GetPositionForCharacterNameOnline
EMAApi.GetClass = GetClass
--EMAApi.SetClass = setClass
EMAApi.GroupAreaList = EMA.GroupAreaList
EMAApi.refreshDropDownList = refreshDropDownList