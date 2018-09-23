-- ================================================================================ --
--				EMA - ( Ebony's MultiBoxing Assistant )    							--
--				Current Author: Jennifer Cally (Ebony)								--
--																					--
--				License: All Rights Reserved 2018 Jennifer Cally					--
--																					--
--				Some Code Used from "Jamba" that is 								--
--				Released under the MIT License 										--
--				"Jamba" Copyright 2008-2015  Michael "Jafula" Miller				--
--																					--
-- ================================================================================ --


-- Create the addon using AceAddon-3.0 and embed some libraries.
local EMA = LibStub( "AceAddon-3.0" ):NewAddon( 
	"Mail", 
	"Module-1.0", 
	"AceConsole-3.0", 
	"AceEvent-3.0",
	"AceHook-3.0",
	"AceTimer-3.0"
)

-- Get the EMA Utilities Library.
local EMAUtilities = LibStub:GetLibrary( "EbonyUtilities-1.0" )
local EMAHelperSettings = LibStub:GetLibrary( "EMAHelperSettings-1.0" )
--local LibBagUtils = LibStub:GetLibrary( "LibBagUtils-1.0" )
local AceGUI = LibStub( "AceGUI-3.0" )

--  Constants and Locale for this module.
EMA.moduleName = "Mail"
EMA.settingsDatabaseName = "MailProfileDB"
EMA.chatCommand = "ema-Mail"
local L = LibStub( "AceLocale-3.0" ):GetLocale( "Core" )
EMA.parentDisplayName = L["INTERACTION"]
EMA.moduleDisplayName = L["Mail"]
-- Icon 
EMA.moduleIcon = "Interface\\Addons\\EMA\\Media\\MailIcon.tga"
-- order
EMA.moduleOrder = 20

-- Settings - the values to store and their defaults for the settings database.
EMA.settings = {
	profile = {
		messageArea = EMAApi.DefaultMessageArea(),
		showEMAMailWindow = false,
		blackListItem = false,
		MailBoEItems = false,
		autoMailToonNameBoE = "",
		MailTagName = EMAApi.AllGroup(),
		autoBoEItemTag = EMAApi.AllGroup(),	
		MailCRItems = false,
		autoMailToonNameCR = "",
		autoCRItemTag = EMAApi.AllGroup(),
		autoMailItemsList = {},
		adjustMoneyWithMailBank = false,
		goldAmountToKeepOnToon = 250,
	},
}

-- Configuration.
function EMA:GetConfiguration()
	local configuration = {
		name = EMA.moduleDisplayName,
		handler = EMA,
		type = 'group',
		childGroups  = "tab",
		get = "EMAConfigurationGetSetting",
		set = "EMAConfigurationSetSetting",
		args = {
			push = {
				type = "input",
				name = L["PUSH_SETTINGS"],
				desc = L["PUSH_ALL_SETTINGS"],
				usage = "/EMA-Mail push",
				get = false,
				set = "EMASendSettings",
				guiHidden = true,
			},
		},
	}
	return configuration
end

-------------------------------------------------------------------------------------------------------------
-- Command this module sends.
-------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------
-- Messages module sends.
-------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------
-- Popup Dialogs.
-------------------------------------------------------------------------------------------------------------

local function InitializePopupDialogs()
	StaticPopupDialogs["EMAMail_CONFIRM_REMOVE_MAIL_ITEMS"] = {
        text = L["REMOVE_MAIL_LIST"],
        button1 = YES,
        button2 = NO,
        timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
        OnAccept = function()
			EMA:RemoveItem()
		end,
    }
end

------------------------------------------------------------------------------------------------------------
-- Addon initialization, enabling and disabling.
-------------------------------------------------------------------------------------------------------------

-- Initialise the module.
function EMA:OnInitialize()
	-- Initialise the popup dialogs.
	InitializePopupDialogs()
	EMA.autoMailItemLink = nil
	EMA.autoMailToonName = nil
	EMA.MailItemTable = {}
	EMA.ShiftkeyDown = false
	--EMA.putItemsInGB = {}
	-- Create the settings control.
	EMA:SettingsCreate()
	-- Initialse the EMAModule part of this module.
	EMA:EMAModuleInitialize( EMA.settingsControl.widgetSettings.frame )
	-- Populate the settings.
	EMA:SettingsRefresh()	
end

-- Called when the addon is enabled.
function EMA:OnEnable()
	EMA:RegisterEvent( "MAIL_SHOW" )
	EMA:RegisterEvent( "MAIL_CLOSED" )
	EMA:RegisterEvent( "MAIL_SEND_SUCCESS")
	EMA:RegisterMessage( EMAApi.MESSAGE_MESSAGE_AREAS_CHANGED, "OnMessageAreasChanged" )
	EMA:RegisterMessage( EMAApi.GROUP_LIST_CHANGED , "OnGroupAreasChanged" )
end

-- Called when the addon is disabled.
function EMA:OnDisable()
	-- AceHook-3.0 will tidy up the hooks for us. 
end

function EMA:SettingsCreate()
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
	local bottomOfInfo = EMA:SettingsCreateMail( EMAHelperSettings:TopOfSettings() )
	EMA.settingsControl.widgetSettings.content:SetHeight( -bottomOfInfo )
	-- Help
	local helpTable = {}
	EMAHelperSettings:CreateHelp( EMA.settingsControl, helpTable, EMA:GetConfiguration() )		
end

function EMA:SettingsPushSettingsClick( event )
	EMA:EMASendSettings()
end

function EMA:SettingsCreateMail( top )
	local buttonControlWidth = 85
	local checkBoxHeight = EMAHelperSettings:GetCheckBoxHeight()
	local editBoxHeight = EMAHelperSettings:GetEditBoxHeight()
	local buttonHeight = EMAHelperSettings:GetButtonHeight()
	local dropdownHeight = EMAHelperSettings:GetDropdownHeight()
	local left = EMAHelperSettings:LeftOfSettings()
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( false )
	local horizontalSpacing = EMAHelperSettings:GetHorizontalSpacing()
	local indentContinueLabel = horizontalSpacing * 18
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local MailWidth = headingWidth
	local dropBoxWidth = (headingWidth - horizontalSpacing) / 4	
	local halfWidth = (headingWidth - horizontalSpacing) / 2
	local thirdWidth = (headingWidth - indentContinueLabel) / 3
	local left2 = left + thirdWidth +  horizontalSpacing
	local left3 = left2 + thirdWidth +  horizontalSpacing
	local movingTop = top
	local movingTopEdit = - 10
	-- A blank to get layout to show right?
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L[""], movingTop, false )
	movingTop = movingTop - headingHeight
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["MAIL_LIST_HEADER"], movingTop, false )
	movingTop = movingTop - headingHeight
	EMA.settingsControl.checkBoxShowEMAMailWindow = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		headingWidth, 
		left2, 
		movingTop, 
		L["MAIL_LIST"],
		EMA.SettingsToggleShowEMAMailWindow,
		L["MAIL_LIST_HELP"]
	)	
	movingTop = movingTop - checkBoxHeight
	EMA.settingsControl.MailItemsHighlightRow = 1
	EMA.settingsControl.MailItemsOffset = 1
	local list = {}
	list.listFrameName = "EMAMailIteamsSettingsFrame"
	list.parentFrame = EMA.settingsControl.widgetSettings.content
	list.listTop = movingTop
	list.listLeft = left
	list.listWidth = MailWidth
	list.rowHeight = 15
	list.rowsToDisplay = 10
	list.columnsToDisplay = 4
	list.columnInformation = {}
	list.columnInformation[1] = {}
	list.columnInformation[1].width = 40
	list.columnInformation[1].alignment = "LEFT"
	list.columnInformation[2] = {}
	list.columnInformation[2].width = 20
	list.columnInformation[2].alignment = "LEFT"
	list.columnInformation[3] = {}
	list.columnInformation[3].width = 20
	list.columnInformation[3].alignment = "LEFT"	
	list.columnInformation[4] = {}
	list.columnInformation[4].width = 20
	list.columnInformation[4].alignment = "LEFT"
	list.scrollRefreshCallback = EMA.SettingsScrollRefresh
	list.rowClickCallback = EMA.SettingsMailItemsRowClick
	EMA.settingsControl.MailItems = list
	EMAHelperSettings:CreateScrollList( EMA.settingsControl.MailItems )
	movingTop = movingTop - list.listHeight - verticalSpacing
	EMA.settingsControl.MailItemsButtonRemove = EMAHelperSettings:CreateButton(
		EMA.settingsControl, 
		buttonControlWidth, 
		left2 + 50,  
		movingTop,
		L["REMOVE"],
		EMA.SettingsMailItemsRemoveClick
	)
	movingTop = movingTop -	buttonHeight - verticalSpacing
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["ADD_ITEMS"], movingTop, false )
	
	movingTop = movingTop - headingHeight
	EMA.settingsControl.MailItemsEditBoxMailItem = EMAHelperSettings:CreateEditBox( 
		EMA.settingsControl,
		thirdWidth,
		left2,
		movingTop,
		L["ITEM_DROP"]
	)
	EMA.settingsControl.MailItemsEditBoxMailItem:SetCallback( "OnEnterPressed", EMA.SettingsEditBoxChangedMailItem )
	movingTop = movingTop - editBoxHeight	

	EMA.settingsControl.listCheckBoxBoxOtherBlackListItem = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		thirdWidth, 
		left,
		movingTop + movingTopEdit,
		L["BLACKLIST_ITEM"],
		EMA.SettingsToggleBlackListItem,
		L["BLACKLIST_ITEM_HELP"]
	)
	
	EMA.settingsControl.tabNumListDropDownList = EMAHelperSettings:CreateEditBox(
		EMA.settingsControl, 
		thirdWidth,	
		left2,
		movingTop,
		L["MAILTOON"]
	)
	EMA.settingsControl.tabNumListDropDownList:SetCallback( "OnEnterPressed",  EMA.EditMailToonName )
	--Group
	EMA.settingsControl.MailItemsEditBoxMailTag = EMAHelperSettings:CreateDropdown(
		EMA.settingsControl, 
		thirdWidth,	
		left3,
		movingTop, 
		L["GROUP_LIST"]
	)
	EMA.settingsControl.MailItemsEditBoxMailTag:SetList( EMAApi.GroupList() )
	EMA.settingsControl.MailItemsEditBoxMailTag:SetCallback( "OnValueChanged",  EMA.GroupListDropDownList )
	movingTop = movingTop - editBoxHeight	
	EMA.settingsControl.MailItemsButtonAdd = EMAHelperSettings:CreateButton(	
		EMA.settingsControl, 
		buttonControlWidth, 
		left2 + 50, 
		movingTop, 
		L["ADD"],
		EMA.SettingsMailItemsAddClick
	)
	movingTop = movingTop -	buttonHeight		
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["Mail_OPTIONS"], movingTop, false )
	movingTop = movingTop - editBoxHeight - 3
	
	EMA.settingsControl.checkBoxMailBoEItems = EMAHelperSettings:CreateCheckBox( 
	EMA.settingsControl, 
		thirdWidth, 
		left, 
		movingTop + movingTopEdit,
		L["MAIL_BOE_ITEMS"],
		EMA.SettingsToggleMailBoEItems,
		L["MAIL_BOE_ITEMS_HELP"]
	)	
	EMA.settingsControl.tabNumListDropDownListBoE = EMAHelperSettings:CreateEditBox(
		EMA.settingsControl, 
		thirdWidth,	
		left2,
		movingTop,
		L["MAILTOON"]
	)
	EMA.settingsControl.tabNumListDropDownListBoE:SetCallback( "OnEnterPressed",  EMA.EditMailToonNameBoE )	
	EMA.settingsControl.MailTradeBoEItemsTagBoE = EMAHelperSettings:CreateDropdown(
		EMA.settingsControl, 
		thirdWidth,	
		left3,
		movingTop, 
		L["GROUP_LIST"]
	)
	EMA.settingsControl.MailTradeBoEItemsTagBoE:SetList( EMAApi.GroupList() )
	EMA.settingsControl.MailTradeBoEItemsTagBoE:SetCallback( "OnValueChanged",  EMA.GroupListDropDownListBoE)	
	
	movingTop = movingTop - editBoxHeight - 3
	EMA.settingsControl.checkBoxMailCRItems = EMAHelperSettings:CreateCheckBox( 
	EMA.settingsControl, 
		thirdWidth, 
		left, 
		movingTop + movingTopEdit, 
		L["MAIL_REAGENTS"],
		EMA.SettingsToggleMailCRItems,
		L["MAIL_REAGENTS_HELP"]
	)
	EMA.settingsControl.tabNumListDropDownListCR = EMAHelperSettings:CreateEditBox(
		EMA.settingsControl, 
		thirdWidth,	
		left2,
		movingTop,
		L["MAILTOON"]
	)
	EMA.settingsControl.tabNumListDropDownListCR:SetCallback( "OnEnterPressed",  EMA.EditMailToonNameCR )	
	EMA.settingsControl.MailTradeCRItemsTagCR = EMAHelperSettings:CreateDropdown(
		EMA.settingsControl, 
		thirdWidth,	
		left3,
		movingTop, 
		L["GROUP_LIST"]
	)
	EMA.settingsControl.MailTradeCRItemsTagCR:SetList( EMAApi.GroupList() )
	EMA.settingsControl.MailTradeCRItemsTagCR:SetCallback( "OnValueChanged",  EMA.GroupListDropDownListCR )	
		
	movingTop = movingTop - editBoxHeight
	movingTop = movingTop - editBoxHeight
	
	EMA.settingsControl.labelComingSoon = EMAHelperSettings:CreateContinueLabel( 
		EMA.settingsControl, 
		headingWidth, 
		left2, 
		movingTop,
		L["MAIL_GOLD_COMING_SOON"] 
	)	
--[[	
	EMA.settingsControl.checkBoxAdjustMoneyOnToonViaMailBank = EMAHelperSettings:CreateCheckBox( 
		EMA.settingsControl, 
		headingWidth, 
		left + 110, 
		movingTop, 
		L["MAIL_GOLD"],
		EMA.SettingsToggleAdjustMoneyOnToonViaMailBank,
		L["MAIL_GOLD_HELP"]
	)
	movingTop = movingTop - checkBoxHeight
	EMA.settingsControl.editBoxGoldAmountToLeaveOnToon = EMAHelperSettings:CreateEditBox( 
		EMA.settingsControl,
		dropBoxWidth,
		left2,
		movingTop,
		L["GOLD_TO_KEEP"]
	)
	EMA.settingsControl.editBoxGoldAmountToLeaveOnToon:SetCallback( "OnEnterPressed", EMA.EditBoxChangedGoldAmountToLeaveOnToon )
]]	
	movingTop = movingTop - editBoxHeight	
	
	EMA.settingsControl.dropdownMessageArea = EMAHelperSettings:CreateDropdown( 
		EMA.settingsControl, 
		dropBoxWidth, 
		left2, 
		movingTop, 
		L["MESSAGE_AREA"] 
	)
	EMA.settingsControl.dropdownMessageArea:SetList( EMAApi.MessageAreaList() )
	EMA.settingsControl.dropdownMessageArea:SetCallback( "OnValueChanged", EMA.SettingsSetMessageArea )
	movingTop = movingTop - dropdownHeight - verticalSpacing
	return movingTop	
end


-------------------------------------------------------------------------------------------------------------
-- Settings Callbacks.
-------------------------------------------------------------------------------------------------------------

function EMA:SettingsScrollRefresh()
	FauxScrollFrame_Update(
		EMA.settingsControl.MailItems.listScrollFrame, 
		EMA:GetMailItemsMaxPosition(),
		EMA.settingsControl.MailItems.rowsToDisplay, 
		EMA.settingsControl.MailItems.rowHeight
	)
	EMA.settingsControl.MailItemsOffset = FauxScrollFrame_GetOffset( EMA.settingsControl.MailItems.listScrollFrame )
	for iterateDisplayRows = 1, EMA.settingsControl.MailItems.rowsToDisplay do
		-- Reset.
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[1].textString:SetText( "" )
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[1].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[2].textString:SetText( "" )
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[2].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )		
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[3].textString:SetText( "" )
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[3].textString:SetTextColor( 1.0, 1.0, 1.0, 1.0 )		
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[4].textString:SetText( "" )
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[4].textString:SetTextColor( 1.0, 0, 0, 1.0 )		
		EMA.settingsControl.MailItems.rows[iterateDisplayRows].highlight:SetColorTexture( 0.0, 0.0, 0.0, 0.0 )
		-- Get data.
		local dataRowNumber = iterateDisplayRows + EMA.settingsControl.MailItemsOffset
		if dataRowNumber <= EMA:GetMailItemsMaxPosition() then
			-- Put data information into columns.
			local MailItemsInformation = EMA:GetMailItemsAtPosition( dataRowNumber )
			local blackListText = ""
			if MailItemsInformation.blackList == true then
				blackListText = L["ITEM_ON_BLACKLIST"]
			end
			EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[1].textString:SetText( MailItemsInformation.name )
			EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[2].textString:SetText( MailItemsInformation.GBTab )
			EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[3].textString:SetText( MailItemsInformation.tag )
			EMA.settingsControl.MailItems.rows[iterateDisplayRows].columns[4].textString:SetText( blackListText )
			-- Highlight the selected row.
			if dataRowNumber == EMA.settingsControl.MailItemsHighlightRow then
				EMA.settingsControl.MailItems.rows[iterateDisplayRows].highlight:SetColorTexture( 1.0, 1.0, 0.0, 0.5 )
			end
		end
	end
end

function EMA:SettingsMailItemsRowClick( rowNumber, columnNumber )		
	if EMA.settingsControl.MailItemsOffset + rowNumber <= EMA:GetMailItemsMaxPosition() then
		EMA.settingsControl.MailItemsHighlightRow = EMA.settingsControl.MailItemsOffset + rowNumber
		EMA:SettingsScrollRefresh()
	end
end

function EMA:SettingsMailItemsRemoveClick( event )
	StaticPopup_Show( "EMAMail_CONFIRM_REMOVE_MAIL_ITEMS" )
end

function EMA:SettingsEditBoxChangedMailItem( event, text )
	EMA.autoMailItemLink = text
	EMA:SettingsRefresh()
end

function EMA:SettingsMailItemsAddClick( event )
	if EMA.autoMailItemLink ~= nil and EMA.autoMailToonName ~= nil and EMA.db.MailTagName ~= nil then
		EMA:AddItem( EMA.autoMailItemLink, EMA.autoMailToonName, EMA.db.MailTagName, EMA.db.blackListItem )
		EMA.autoMailItemLink = nil
		EMA:SettingsRefresh()
	end
end

function EMA:GroupListDropDownList (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	for index, groupName in ipairs( EMAApi.GroupList() ) do
		if index == value then
			EMA.db.MailTagName = groupName
			break
		end
	end
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleBlackListItem( event, checked ) 
	EMA.db.blackListItem = checked
	EMA:SettingsRefresh()
end	


function EMA:EditMailToonName (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	EMA.autoMailToonName = value
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleMailBoEItems(event, checked )
	EMA.db.MailBoEItems = checked
	EMA:SettingsRefresh()
end


function EMA:EditMailToonNameBoE (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	EMA.db.autoMailToonNameBoE = value
	EMA:SettingsRefresh()
end

function EMA:GroupListDropDownListBoE (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	for index, groupName in ipairs( EMAApi.GroupList() ) do
		if index == value then
			EMA.db.autoBoEItemTag = groupName
			break
		end
	end
	EMA:SettingsRefresh()
end


function EMA:SettingsToggleMailCRItems(event, checked )
	EMA.db.MailCRItems = checked
	EMA:SettingsRefresh()
end

function EMA:EditMailToonNameCR (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	EMA.db.autoMailToonNameCR = value
	EMA:SettingsRefresh()
end

function EMA:GroupListDropDownListCR (event, value )
	-- if nil or the blank group then don't get Name.
	if value == " " or value == nil then 
		return 
	end
	for index, groupName in ipairs( EMAApi.GroupList() ) do
		if index == value then
			EMA.db.autoCRItemTag = groupName
			break
		end
	end
	EMA:SettingsRefresh()
end

function EMA:OnMessageAreasChanged( message )
	EMA.settingsControl.dropdownMessageArea:SetList( EMAApi.MessageAreaList() )
end

function EMA:OnGroupAreasChanged( message )
	EMA.settingsControl.MailItemsEditBoxMailTag:SetList( EMAApi.GroupList() )
	EMA.settingsControl.MailTradeBoEItemsTagBoE:SetList( EMAApi.GroupList() )
	EMA.settingsControl.MailTradeCRItemsTagCR:SetList( EMAApi.GroupList() )
end

function EMA:SettingsSetMessageArea( event, value )
	EMA.db.messageArea = value
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleShowEMAMailWindow( event, checked )
	EMA.db.showEMAMailWindow = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleAdjustMoneyOnToonViaMailBank( event, checked )
	EMA.db.adjustMoneyWithMailBank = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleAdjustMoneyWithMasterOnMail( event, checked )
	EMA.db.adjustMoneyWithMasterOnMail = checked
	EMA:SettingsRefresh()
end

function EMA:EditBoxChangedGoldAmountToLeaveOnToon( event, text )
	EMA.db.goldAmountToKeepOnToon = tonumber( text )
	if EMA.db.goldAmountToKeepOnToon == nil then
		EMA.db.goldAmountToKeepOnToon = 0
	end
	EMA:SettingsRefresh()
end

-- Settings received.
function EMA:EMAOnSettingsReceived( characterName, settings )	
	if characterName ~= EMA.characterName then
		-- Update the settings.
		EMA.db.messageArea = settings.messageArea
		EMA.db.showEMAMailWindow = settings.showEMAMailWindow
		EMA.db.MailTagName = settings.MailTagName
		EMA.db.MailBoEItems = settings.MailBoEItems
		EMA.db.autoMailToonNameBoE = settings.autoMailToonNameBoE
		EMA.db.autoBoEItemTag = settings.autoBoEItemTag
		EMA.db.MailCRItems = settings.MailCRItems
		EMA.db.autoMailToonNameCR = settings.autoMailToonNameCR
		EMA.db.autoCRItemTag = settings.autoCRItemTag
		EMA.db.autoMailItemsList = EMAUtilities:CopyTable( settings.autoMailItemsList )
		EMA.db.adjustMoneyWithMailBank = settings.adjustMoneyWithMailBank
		EMA.db.goldAmountToKeepOnToon = settings.goldAmountToKeepOnToon
		-- Refresh the settings.
		EMA:SettingsRefresh()
		-- Tell the player.
		EMA:Print( L["SETTINGS_RECEIVED_FROM_A"]( characterName ) )
	end
end

function EMA:BeforeEMAProfileChanged()	
end

function EMA:OnEMAProfileChanged()	
	EMA:SettingsRefresh()
end

function EMA:SettingsRefresh()
	EMA.settingsControl.checkBoxShowEMAMailWindow:SetValue( EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailItemsEditBoxMailTag:SetText( EMA.db.MailTagName )
	EMA.settingsControl.listCheckBoxBoxOtherBlackListItem:SetValue( EMA.db.blackListItem )
	EMA.settingsControl.checkBoxMailBoEItems:SetValue( EMA.db.MailBoEItems )
	EMA.settingsControl.tabNumListDropDownListBoE:SetText( EMA.db.autoMailToonNameBoE )
	EMA.settingsControl.MailTradeBoEItemsTagBoE:SetText( EMA.db.autoBoEItemTag )
	EMA.settingsControl.checkBoxMailCRItems:SetValue( EMA.db.MailCRItems )
	EMA.settingsControl.tabNumListDropDownListCR:SetText( EMA.db.autoMailToonNameCR )
	EMA.settingsControl.MailTradeCRItemsTagCR:SetText( EMA.db.autoCRItemTag )
	EMA.settingsControl.dropdownMessageArea:SetValue( EMA.db.messageArea )
--	EMA.settingsControl.checkBoxAdjustMoneyOnToonViaMailBank:SetValue( EMA.db.adjustMoneyWithMailBank )
--	EMA.settingsControl.editBoxGoldAmountToLeaveOnToon:SetText( tostring( EMA.db.goldAmountToKeepOnToon ) )
--	EMA.settingsControl.editBoxGoldAmountToLeaveOnToon:SetDisabled( not EMA.db.adjustMoneyWithMailBank )
	EMA.settingsControl.MailItemsEditBoxMailItem:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.listCheckBoxBoxOtherBlackListItem:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailItemsEditBoxMailTag:SetDisabled( not EMA.db.showEMAMailWindow )	
	EMA.settingsControl.tabNumListDropDownList:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailItemsButtonRemove:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailItemsButtonAdd:SetDisabled( not EMA.db.showEMAMailWindow )	
	EMA.settingsControl.checkBoxMailBoEItems:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.tabNumListDropDownListBoE:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailTradeBoEItemsTagBoE:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.checkBoxMailCRItems:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.tabNumListDropDownListCR:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA.settingsControl.MailTradeCRItemsTagCR:SetDisabled( not EMA.db.showEMAMailWindow )
	EMA:SettingsScrollRefresh()

end

--Comms not sure if we going to use comms here.
-- A EMA command has been received.
function EMA:EMAOnCommandReceived( characterName, commandName, ... )
	if characterName == self.characterName then
		return
	end
end

-------------------------------------------------------------------------------------------------------------
-- Mail functionality.
-------------------------------------------------------------------------------------------------------------

function EMA:GetMailItemsMaxPosition()
	return #EMA.db.autoMailItemsList
end

function EMA:GetMailItemsAtPosition( position )
	return EMA.db.autoMailItemsList[position]
end

function EMA:AddItem( itemLink, GBTab, itemTag, blackList )
	--EMA:Print("testDBAdd", itemLink, GBTab, itemTag )
	-- Get some more information about the item.
	local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo( itemLink )
	-- If the item could be found.
	if name ~= nil then
		local itemInformation = {}
		itemInformation.link = link
		itemInformation.name = name
		itemInformation.GBTab = GBTab
		itemInformation.tag = itemTag
		itemInformation.blackList = blackList
			table.insert( EMA.db.autoMailItemsList, itemInformation )
			EMA:SettingsRefresh()			
			EMA:SettingsMailItemsRowClick( 1, 1 )
	end	
end

function EMA:RemoveItem()
	table.remove( EMA.db.autoMailItemsList, EMA.settingsControl.MailItemsHighlightRow )
	EMA:SettingsRefresh()
	EMA:SettingsMailItemsRowClick( EMA.settingsControl.MailItemsHighlightRow  - 1, 1 )		
end


function EMA:MAIL_SHOW(event, ...)
	--EMA:Print("test")
	if EMA.db.showEMAMailWindow == true then
		if not IsShiftKeyDown() then
			EMA:AddAllToMailBox()
		else 
			EMA.ShiftkeyDown = true
		end	
	end
	--[[
	if EMA.db.adjustMoneyWithMailBank == true then
		 AddGoldToMailBox()
	end
	]]
end

function EMA:MAIL_CLOSED(event, ...)
	EMA.ShiftkeyDown = false
end

function EMA:AddAllToMailBox()
	--EMA:Print("run")
	MailFrameTab_OnClick(nil, "2")
	SendMailNameEditBox:SetText( "" )
	SendMailNameEditBox:ClearFocus()
	local count = 1 
	for bagID = 0, NUM_BAG_SLOTS do
		for slotID = 1,GetContainerNumSlots( bagID ),1 do 
			--EMA:Print( "Bags OK. checking", itemLink )
			local item = Item:CreateFromBagAndSlot(bagID, slotID)
			if ( item ) then
				local bagItemLink = item:GetItemLink()
				if ( bagItemLink ) then	
					local itemLink = item:GetItemLink()
					local location = item:GetItemLocation()
					local itemType = C_Item.GetItemInventoryType( location )
					local isBop = C_Item.IsBound( location )
					local itemRarity =  C_Item.GetItemQuality( location )
					local _,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,isCraftingReagent = GetItemInfo( bagItemLink )
					local canSend = false
					local toonName = nil
					if EMA.db.MailBoEItems == true then
						if itemType ~= 0 then
							if EMAApi.IsCharacterInGroup(  EMA.characterName, EMA.db.autoBoEItemTag ) == true then
								if isBop == false then
									if itemRarity == 2 or itemRarity == 3 or itemRarity == 4 then	
										canSend = true
										toonName = EMA.db.autoMailToonNameBoE
									end			
								end
							end										
						end									
					end	
					if EMA.db.MailCRItems == true then
						if isCraftingReagent == true then
							if EMAApi.IsCharacterInGroup(  EMA.characterName, EMA.db.autoCRItemTag ) == true then
								if isBop == false then
									canSend = true
									toonName = EMA.db.autoMailToonNameCR		
								end
							end										
						end
					end
					for position, itemInformation in pairs( EMA.db.autoMailItemsList ) do
						if EMAUtilities:DoItemLinksContainTheSameItem( itemLink, itemInformation.link ) then
							if EMAApi.IsCharacterInGroup(  EMA.characterName, itemInformation.tag ) == true then
								--EMA:Print("DataTest", itemInformation.link, itemInformation.blackList )
								--EMA:Print("test", itemLink)
								canSend = true
								toonName = itemInformation.GBTab
							end
							if itemInformation.blackList == true then
								canSend = false
							end
						end
					end
					if canSend == true and toonName ~= "" and toonName ~= nil then	
						local currentMailToon = SendMailNameEditBox:GetText()
						local characterName = EMAUtilities:AddRealmToNameIfMissing( toonName )
						if toonName == currentMailToon or currentMailToon == "" and characterName ~= EMA.characterName then
							if count <= ATTACHMENTS_MAX_SEND then	
								--EMA:Print("sending Mail:", count)
								count = count + 1
								SendMailNameEditBox:SetText( toonName )
								SendMailSubjectEditBox:SetText( L["SENT_AUTO_MAILER"] )
								PickupContainerItem( bagID, slotID )
								UseContainerItem( bagID , slotID  )
							end	
						end	
					end
				end	
			end
		end
	end	
	EMA:ScheduleTimer( "DoSendMail", 0.5, nil )
end

function EMA:MAIL_SEND_SUCCESS( event, ... )
	--EMA:Print("try sendMail Again")
	if EMA.ShiftkeyDown == false then
		EMA:ScheduleTimer( "AddAllToMailBox", 1, nil )
	end	
end

function EMA:DoSendMail()
	--EMA:Print("newSendRun")
	for iterateMailSlots = 1, ATTACHMENTS_MAX_SEND do
		if HasSendMailItem( iterateMailSlots ) == true then
			SendMailFrame_SendMail()	
			break
		end
	end						
end	

-- gold
function AddGoldToMailBox()
	local moneyToKeepOnToon = tonumber( EMA.db.goldAmountToKeepOnToon ) 
	local moneyOnToon = GetMoney()
	local moneyToDepositOrWithdraw = moneyOnToon - moneyToKeepOnToon
	if moneyToDepositOrWithdraw == 0 then
		return
	end
	if moneyToDepositOrWithdraw > 0 then
		--local tradePlayersName = GetUnitName("NPC", true)
		--local characterName = EMAUtilities:AddRealmToNameIfMissing( tradePlayersName )
		--if EMAApi.IsCharacterTheMaster(characterName) == true and EMAUtilities:CheckIsFromMyRealm(characterName) == true then	
			SendMailMoneyGold:SetText(moneyToDepositOrWithdraw)
		--end
	end
end