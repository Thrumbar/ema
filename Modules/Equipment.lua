-- ================================================================================ --
--				EMA - ( Ebony's MultiBoxing Assistant )    							--
--				Current Author: Jennifer Calladine (Ebony)							--
--																					--
--				License: All Rights Reserved 2018-2025 Jennifer Cally				--
--																					--
--				Some Code Used from "Jamba" that is 								--
--				Released under the MIT License 										--
--				"Jamba" Copyright 2008-2015  Michael "Jafula" Miller				--
--																					--	
--				This Module was made by "vecter" and has been changed by Jenn		--
--				For now this is a midnight (12.0) for now							--
--																					--
-- ================================================================================ --

-- Create the addon using AceAddon-3.0 and embed some libraries.
local EMA = LibStub( "AceAddon-3.0" ):NewAddon(
	"Equipment",
	"Module-1.0",
	"AceConsole-3.0",
	"AceEvent-3.0",
	"AceHook-3.0",
	"AceTimer-3.0"
)

-- Get the EMA Utilities Library.
local AceGUI = LibStub( "AceGUI-3.0" )
local EMAUtilities = LibStub:GetLibrary( "EbonyUtilities-1.0" )
local EMAHelperSettings = LibStub:GetLibrary( "EMAHelperSettings-1.0" )
EMA.SharedMedia = LibStub( "LibSharedMedia-3.0" )

--  Constants and Locale for this module.
EMA.moduleName = "Equipment"
EMA.settingsDatabaseName = "EquipmentProfileDB"
EMA.chatCommand = "ema-equip"
local L = LibStub( "AceLocale-3.0" ):GetLocale( "Core" )
EMA.parentDisplayName = L["DISPLAY"]
EMA.moduleDisplayName = L["EQUIPMENT"]
-- Icon (using WoW's built-in character equipment icon)
EMA.moduleIcon = "Interface\\PaperDollInfoFrame\\UI-EquipmentManager-Toggle"
-- order
EMA.moduleOrder = 4

-- EMA Equipment key bindings
BINDING_HEADER_EQUIPMENT = L["BINDING_EQUIPMENT"]
BINDING_NAME_EQUIPMENTWINDOW = L["BINDING_EQUIPMENT_WINDOW"]
BINDING_NAME_EQUIPMENTCOMPARE = L["BINDING_EQUIPMENT_COMPARE"]

-------------------------------------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------------------------------------

-- Equipment slot IDs (matches WoW's INVSLOT_* constants)
local EQUIPMENT_SLOTS = {
	{ id = 1,  name = "HEADSLOT",      displayName = "Head" },
	{ id = 2,  name = "NECKSLOT",      displayName = "Neck" },
	{ id = 3,  name = "SHOULDERSLOT",  displayName = "Shoulder" },
	{ id = 15, name = "BACKSLOT",      displayName = "Back" },
	{ id = 5,  name = "CHESTSLOT",     displayName = "Chest" },
	{ id = 4,  name = "SHIRTSLOT",     displayName = "Shirt" },
	{ id = 19, name = "TABARDSLOT",    displayName = "Tabard" },
	{ id = 9,  name = "WRISTSLOT",     displayName = "Wrist" },
	{ id = 10, name = "HANDSSLOT",     displayName = "Hands" },
	{ id = 6,  name = "WAISTSLOT",     displayName = "Waist" },
	{ id = 7,  name = "LEGSSLOT",      displayName = "Legs" },
	{ id = 8,  name = "FEETSLOT",      displayName = "Feet" },
	{ id = 11, name = "FINGER0SLOT",   displayName = "Ring 1" },
	{ id = 12, name = "FINGER1SLOT",   displayName = "Ring 2" },
	{ id = 13, name = "TRINKET0SLOT",  displayName = "Trinket 1" },
	{ id = 14, name = "TRINKET1SLOT",  displayName = "Trinket 2" },
	{ id = 16, name = "MAINHANDSLOT",  displayName = "Main Hand" },
	{ id = 17, name = "SECONDARYHANDSLOT", displayName = "Off Hand" },
}

-- Number of equipment slots we track
local NUM_EQUIPMENT_SLOTS = #EQUIPMENT_SLOTS

-- Frame prefix for equipment window
EMA.globalEquipmentFramePrefix = "EMAEquipmentFrame"

-------------------------------------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------------------------------------

EMA.settings = {
	profile = {
		-- Feature toggles
		enableEquipmentSync = true,
		enableAltClickCompare = true,
		autoSyncOnEquipChange = true,

		-- Window settings
		equipmentFrameAlpha = 1.0,
		equipmentFramePoint = "CENTER",
		equipmentFrameRelativePoint = "CENTER",
		equipmentFrameXOffset = 0,
		equipmentFrameYOffset = 0,
		equipmentFrameBackgroundColourR = 0.05,
		equipmentFrameBackgroundColourG = 0.05,
		equipmentFrameBackgroundColourB = 0.08,
		equipmentFrameBackgroundColourA = 0.95,
		equipmentFrameBorderColourR = 0.35,
		equipmentFrameBorderColourG = 0.38,
		equipmentFrameBorderColourB = 0.45,
		equipmentFrameBorderColourA = 1.0,
		equipmentBorderStyle = L["BLIZZARD_TOOLTIP"],
		equipmentBackgroundStyle = L["BLIZZARD_DIALOG_BACKGROUND"],
		equipmentScale = 1,
		equipmentLockWindow = false,

		-- Cell sizes
		equipmentIconSize = 32,
		equipmentCellWidth = 50,
		equipmentCellHeight = 50,
	},
}

-------------------------------------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------------------------------------

function EMA:GetConfiguration()
	local configuration = {
		name = EMA.moduleDisplayName,
		handler = EMA,
		type = 'group',
		childGroups = "tab",
		get = "EMAConfigurationGetSetting",
		set = "EMAConfigurationSetSetting",
		args = {
			config = {
				type = "input",
				name = L["OPEN_CONFIG"],
				desc = L["OPEN_CONFIG_HELP"],
				usage = "/ema-equip config",
				get = false,
				set = "",
			},
			show = {
				type = "input",
				name = L["SHOW_EQUIPMENT"],
				desc = L["SHOW_EQUIPMENT_HELP"],
				usage = "/ema-equip show",
				get = false,
				set = "ShowEquipmentWindow",
			},
			hide = {
				type = "input",
				name = L["HIDE_EQUIPMENT"],
				desc = L["HIDE_EQUIPMENT_HELP"],
				usage = "/ema-equip hide",
				get = false,
				set = "HideEquipmentWindow",
			},
			refresh = {
				type = "input",
				name = L["REFRESH_EQUIPMENT"],
				desc = L["REFRESH_EQUIPMENT_HELP"],
				usage = "/ema-equip refresh",
				get = false,
				set = "RefreshTeamEquipment",
			},
			push = {
				type = "input",
				name = L["PUSH_ALL_SETTINGS"],
				desc = L["PUSH_SETTINGS_INFO"],
				usage = "/ema-equip push",
				get = false,
				set = "EMASendSettings",
			},
		},
	}
	return configuration
end

-------------------------------------------------------------------------------------------------------------
-- Command this module sends.
-------------------------------------------------------------------------------------------------------------

EMA.COMMAND_REQUEST_EQUIPMENT = "EqReq"
EMA.COMMAND_HERE_IS_EQUIPMENT = "EqData"

-------------------------------------------------------------------------------------------------------------
-- Variables used by module.
-------------------------------------------------------------------------------------------------------------

-- Storage for team equipment data
-- Format: teamEquipment[characterName] = { slots = { [slotID] = { link, ilvl, icon }, ... }, lastUpdate = timestamp }
EMA.teamEquipment = {}

-- The equipment window frame
EMA.equipmentFrame = nil

-- Character columns in the grid
EMA.characterColumns = {}

-------------------------------------------------------------------------------------------------------------
-- Addon initialization, enabling and disabling.
-------------------------------------------------------------------------------------------------------------

function EMA:OnInitialize()
	-- Create the settings control.
	EMA:SettingsCreate()
	-- Initialize the EMAModule part of this module.
	EMA:EMAModuleInitialize( EMA.settingsControl.widgetSettings.frame )
	-- Populate the settings.
	EMA:SettingsRefresh()
end

function EMA:OnEnable()
	-- Register for equipment change events
	EMA:RegisterEvent( "PLAYER_EQUIPMENT_CHANGED" )
	EMA:RegisterEvent( "PLAYER_ENTERING_WORLD" )
	EMA:RegisterEvent( "UPDATE_BINDINGS" )

	-- Register for messages
	EMA:RegisterMessage( EMAApi.MESSAGE_TEAM_CHARACTER_ADDED, "OnTeamChanged" )
	EMA:RegisterMessage( EMAApi.MESSAGE_TEAM_CHARACTER_REMOVED, "OnTeamChanged" )
	EMA:RegisterMessage( EMAApi.MESSAGE_CHARACTER_ONLINE, "OnCharacterOnline" )

	-- Hook item tooltips for Alt-click comparison
	if EMA.db.enableAltClickCompare then
		EMA:HookItemTooltips()
	end

	-- Initialize keybindings
	EMA:UPDATE_BINDINGS()

	-- Collect own equipment on login
	C_Timer.After( 2, function()
		EMA:CollectOwnEquipment()
	end )
end

-- Handle keybinding updates
function EMA:UPDATE_BINDINGS()
	-- Create keybinding frame if needed
	if not EMA.keyBindingFrame then
		EMA.keyBindingFrame = CreateFrame( "Frame", "EMAEquipmentKeyBindingFrame", UIParent, "SecureHandlerStateTemplate" )
		EMA.keyBindingFrame:SetAttribute( "_onstate-equipwindow", [[
			self:CallMethod( "OpenEquipmentWindow" )
		]] )
		EMA.keyBindingFrame:SetAttribute( "_onstate-equipcompare", [[
			self:CallMethod( "CompareItemAtCursor" )
		]] )
		EMA.keyBindingFrame.OpenEquipmentWindow = function()
			EMA:ShowEquipmentWindow()
		end
		EMA.keyBindingFrame.CompareItemAtCursor = function()
			EMA:CompareItemAtCursor()
		end
	end

	-- Clear existing bindings
	ClearOverrideBindings( EMA.keyBindingFrame )

	-- Set up Equipment Window binding
	local key1, key2 = GetBindingKey( "EQUIPMENTWINDOW" )
	if key1 then
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key1, "EMAEquipmentKeyBindingFrame", "equipwindow" )
	end
	if key2 then
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key2, "EMAEquipmentKeyBindingFrame", "equipwindow" )
	end

	-- Set up Equipment Compare binding
	local key3, key4 = GetBindingKey( "EQUIPMENTCOMPARE" )
	if key3 then
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key3, "EMAEquipmentKeyBindingFrame", "equipcompare" )
	end
	if key4 then
		SetOverrideBindingClick( EMA.keyBindingFrame, false, key4, "EMAEquipmentKeyBindingFrame", "equipcompare" )
	end
end

-- Compare item currently at cursor (for keybinding)
function EMA:CompareItemAtCursor()
	local infoType, itemID, itemLink = GetCursorInfo()
	if infoType == "item" and itemLink then
		EMA:ShowComparisonPopup( itemLink )
	else
		-- Try to get from tooltip if cursor doesn't have item
		local _, itemLink = GameTooltip:GetItem()
		if itemLink then
			EMA:ShowComparisonPopup( itemLink )
		end
	end
end

function EMA:OnDisable()
	-- AceHook-3.0 will tidy up the hooks for us.
end

-------------------------------------------------------------------------------------------------------------
-- Settings UI
-------------------------------------------------------------------------------------------------------------

function EMA:SettingsCreate()
	EMA.settingsControl = {}
	EMAHelperSettings:CreateSettings(
		EMA.settingsControl,
		EMA.moduleDisplayName,
		EMA.parentDisplayName,
		EMA.SettingsPushSettingsClick,
		EMA.moduleIcon
	)
	local bottomOfInfo = EMA:SettingsCreateOptions( EMAHelperSettings:TopOfSettings() )
	EMA.settingsControl.widgetSettings.content:SetHeight( -bottomOfInfo )
	-- Help
	local helpTable = {}
	EMAHelperSettings:CreateHelp( EMA.settingsControl, helpTable, EMA:GetConfiguration() )
end

function EMA:SettingsPushSettingsClick( event )
	EMA:EMASendSettings()
end

function EMA:SettingsCreateOptions( top )
	local checkBoxHeight = EMAHelperSettings:GetCheckBoxHeight()
	local buttonHeight = EMAHelperSettings:GetButtonHeight()
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( false )
	local left = EMAHelperSettings:LeftOfSettings()
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local movingTop = top

	-- Heading: Equipment Sync
	EMAHelperSettings:CreateHeading( EMA.settingsControl, L["EQUIPMENT_SYNC_HEADER"], movingTop, false )
	movingTop = movingTop - headingHeight

	-- Checkbox: Enable Equipment Sync
	EMA.settingsControl.checkBoxEnableSync = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		L["ENABLE_EQUIPMENT_SYNC"],
		EMA.SettingsToggleEnableSync,
		L["ENABLE_EQUIPMENT_SYNC_HELP"]
	)
	movingTop = movingTop - checkBoxHeight

	-- Checkbox: Auto sync on equip change
	EMA.settingsControl.checkBoxAutoSync = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		L["AUTO_SYNC_ON_EQUIP"],
		EMA.SettingsToggleAutoSync,
		L["AUTO_SYNC_ON_EQUIP_HELP"]
	)
	movingTop = movingTop - checkBoxHeight

	-- Checkbox: Enable Alt-click compare
	EMA.settingsControl.checkBoxAltClickCompare = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		L["ENABLE_ALT_CLICK_COMPARE"],
		EMA.SettingsToggleAltClickCompare,
		L["ENABLE_ALT_CLICK_COMPARE_HELP"]
	)
	movingTop = movingTop - checkBoxHeight

	-- Button: Show Equipment Window
	EMA.settingsControl.buttonShowEquipment = EMAHelperSettings:CreateButton(
		EMA.settingsControl,
		160,
		left,
		movingTop,
		L["SHOW_EQUIPMENT"],
		EMA.ShowEquipmentWindow,
		L["SHOW_EQUIPMENT_HELP"]
	)
	movingTop = movingTop - buttonHeight - verticalSpacing

	return movingTop
end

function EMA:SettingsToggleEnableSync( event, checked )
	EMA.db.enableEquipmentSync = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleAutoSync( event, checked )
	EMA.db.autoSyncOnEquipChange = checked
	EMA:SettingsRefresh()
end

function EMA:SettingsToggleAltClickCompare( event, checked )
	EMA.db.enableAltClickCompare = checked
	if checked then
		EMA:HookItemTooltips()
	end
	EMA:SettingsRefresh()
end

-- Settings received.
function EMA:EMAOnSettingsReceived( characterName, settings )
	if characterName ~= EMA.characterName then
		-- Update the settings.
		EMA.db.enableEquipmentSync = settings.enableEquipmentSync
		EMA.db.enableAltClickCompare = settings.enableAltClickCompare
		EMA.db.autoSyncOnEquipChange = settings.autoSyncOnEquipChange
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
	EMA.settingsControl.checkBoxEnableSync:SetValue( EMA.db.enableEquipmentSync )
	EMA.settingsControl.checkBoxAutoSync:SetValue( EMA.db.autoSyncOnEquipChange )
	EMA.settingsControl.checkBoxAltClickCompare:SetValue( EMA.db.enableAltClickCompare )
	-- Set state
	EMA.settingsControl.checkBoxAutoSync:SetDisabled( not EMA.db.enableEquipmentSync )
end

-------------------------------------------------------------------------------------------------------------
-- Equipment Data Collection
-------------------------------------------------------------------------------------------------------------

-- Get item level from an item link
function EMA:GetItemLevelFromLink( itemLink )
	if not itemLink then return 0 end

	-- Method 1: Use GetItemInfo which is most reliable after item is cached
	-- Returns: name, link, quality, ilvl, reqLevel, class, subclass, maxStack, equipSlot, texture, sellPrice, ...
	local _, _, _, ilvl = GetItemInfo( itemLink )
	if ilvl and ilvl > 0 then
		return ilvl
	end

	-- Method 2: Try GetDetailedItemLevelInfo (better for equipped items with upgrades)
	local effectiveILvl, previewILvl, baseILvl = C_Item.GetDetailedItemLevelInfo( itemLink )
	if effectiveILvl and effectiveILvl > 0 then
		return effectiveILvl
	end

	-- Final fallback: use base level if available
	if baseILvl and baseILvl > 0 then
		return baseILvl
	end

	return 0
end

-- Async version: Load item data and then call GetItemLevelFromLink
-- This ensures item is cached before trying to get its ilvl
function EMA:GetItemLevelAsync( itemLink, callback )
	if not itemLink then
		if callback then callback( 0 ) end
		return
	end

	-- Create item object from the link
	local item = Item:CreateFromItemLink( itemLink )
	if not item or item:IsItemEmpty() then
		-- Couldn't create item object, try sync method
		if callback then callback( EMA:GetItemLevelFromLink( itemLink ) ) end
		return
	end

	-- Wait for item data to load, then get ilvl
	item:ContinueOnItemLoad( function()
		local ilvl = EMA:GetItemLevelFromLink( itemLink )
		if callback then callback( ilvl ) end
	end )
end

-- Get item icon from an item link
function EMA:GetItemIconFromLink( itemLink )
	if not itemLink then return nil end
	local itemID = C_Item.GetItemIDForItemInfo( itemLink )
	if itemID then
		return C_Item.GetItemIconByID( itemID )
	end
	return nil
end

-- Slots that count toward average item level (exclude shirt, tabard)
local ILVL_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

-- Calculate average item level for a character
function EMA:GetCharacterAverageIlvl( characterName )
	local charEquip = EMA.teamEquipment[characterName]
	if not charEquip or not charEquip.slots then return 0 end

	local totalIlvl = 0
	local slotCount = 0

	for _, slotID in ipairs( ILVL_SLOTS ) do
		local slotData = charEquip.slots[slotID]
		if slotData and slotData.ilvl and slotData.ilvl > 0 then
			totalIlvl = totalIlvl + slotData.ilvl
			slotCount = slotCount + 1
		end
	end

	if slotCount == 0 then return 0 end
	return math.floor( totalIlvl / slotCount * 10 ) / 10  -- Round to 1 decimal
end

-- Slots that can be enchanted in modern WoW (varies by expansion)
local ENCHANTABLE_SLOTS = {
	[15] = true,  -- Back (cloak)
	[5]  = true,  -- Chest
	[9]  = true,  -- Wrist
	[8]  = true,  -- Feet (boots)
	[11] = true,  -- Ring 1
	[12] = true,  -- Ring 2
	[16] = true,  -- Main Hand
	[17] = true,  -- Off Hand (if weapon)
}

-- Check if an item has an enchant
function EMA:ItemHasEnchant( itemLink )
	if not itemLink then return false end
	-- Item link format: |Hitem:itemID:enchantID:gem1:gem2:gem3:gem4:...
	-- If enchantID is 0 or empty, no enchant
	local enchantID = itemLink:match( "item:%d+:(%d+)" )
	if enchantID and tonumber( enchantID ) and tonumber( enchantID ) > 0 then
		return true
	end
	return false
end

-- Check if an item has gem sockets and if they're filled
-- Returns: hasSocket, numFilled, numEmpty
function EMA:GetItemGemInfo( itemLink )
	if not itemLink then return false, 0, 0 end

	-- Parse gem IDs from item link
	-- Format: item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:linkLevel:...
	local parts = { strsplit( ":", itemLink ) }
	local numFilled = 0
	local numEmpty = 0

	-- Gem slots are positions 4, 5, 6, 7 in the item link (indices after enchant)
	for i = 4, 7 do
		local gemID = parts[i]
		if gemID then
			local gemNum = tonumber( gemID )
			if gemNum and gemNum > 0 then
				numFilled = numFilled + 1
			end
		end
	end

	-- Get item stats to check for empty sockets
	local stats = C_Item.GetItemStats( itemLink )
	if stats then
		-- Check for socket bonus (indicates item has sockets)
		local totalSockets = 0
		for statName, value in pairs( stats ) do
			if statName:find( "SOCKET" ) then
				totalSockets = totalSockets + value
			end
		end
		if totalSockets > 0 then
			numEmpty = totalSockets - numFilled
			return true, numFilled, numEmpty
		end
	end

	-- If we found filled gems but no socket stat, item has sockets
	if numFilled > 0 then
		return true, numFilled, 0
	end

	return false, 0, 0
end

-- Check if a slot should be enchanted
function EMA:SlotShouldBeEnchanted( slotID )
	return ENCHANTABLE_SLOTS[slotID] == true
end

-- Get enchant/gem status for an item
-- Returns: status string ("OK", "MISSING_ENCHANT", "MISSING_GEM", "MISSING_BOTH", "")
function EMA:GetItemEnchantGemStatus( itemLink, slotID )
	if not itemLink then return "" end

	local issues = {}

	-- Check enchant
	if EMA:SlotShouldBeEnchanted( slotID ) then
		if not EMA:ItemHasEnchant( itemLink ) then
			table.insert( issues, "E" )  -- Missing Enchant
		end
	end

	-- Check gems
	local hasSocket, numFilled, numEmpty = EMA:GetItemGemInfo( itemLink )
	if hasSocket and numEmpty > 0 then
		table.insert( issues, "G" )  -- Missing Gem(s)
	end

	if #issues > 0 then
		return table.concat( issues, "/" )
	end
	return ""
end

-- Get item level for an equipped item using the inventory slot
-- This is more accurate than using the item link as it queries the actual equipped item
function EMA:GetEquippedItemLevel( slotID )
	-- Create an ItemLocation for the equipped slot
	local itemLocation = ItemLocation:CreateFromEquipmentSlot( slotID )
	if itemLocation and C_Item.DoesItemExist( itemLocation ) then
		-- Get the actual current item level from the equipped item
		local ilvl = C_Item.GetCurrentItemLevel( itemLocation )
		if ilvl and ilvl > 0 then
			return ilvl
		end
	end
	return 0
end

-- Collect this character's equipment data
function EMA:CollectOwnEquipment()
	local myName = EMA.characterName
	EMA.teamEquipment[myName] = EMA.teamEquipment[myName] or {}
	EMA.teamEquipment[myName].slots = {}
	EMA.teamEquipment[myName].lastUpdate = GetTime()

	for _, slotInfo in ipairs( EQUIPMENT_SLOTS ) do
		local slotID = slotInfo.id
		local itemLink = GetInventoryItemLink( "player", slotID )
		local itemTexture = GetInventoryItemTexture( "player", slotID )

		-- Use GetEquippedItemLevel for own equipment (more accurate)
		-- Falls back to link-based method if slot query fails
		local ilvl = EMA:GetEquippedItemLevel( slotID )
		if ilvl == 0 and itemLink then
			ilvl = EMA:GetItemLevelFromLink( itemLink )
		end

		EMA.teamEquipment[myName].slots[slotID] = {
			link = itemLink,
			ilvl = ilvl,
			icon = itemTexture,
		}
	end

	return EMA.teamEquipment[myName]
end

-- Pack equipment data for transmission (minimize payload)
function EMA:PackEquipmentData()
	local data = {}
	-- Always re-collect to ensure fresh data
	local myEquip = EMA:CollectOwnEquipment()

	for slotID, slotData in pairs( myEquip.slots ) do
		-- Only send slots that have items
		if slotData.link then
			-- Re-query the actual equipped item level to ensure accuracy
			local ilvl = EMA:GetEquippedItemLevel( slotID )
			if ilvl == 0 then
				ilvl = slotData.ilvl
			end
			data[slotID] = {
				l = slotData.link,
				i = ilvl,
			}
		end
	end

	return data
end

-- Unpack received equipment data
function EMA:UnpackEquipmentData( characterName, data )
	EMA.teamEquipment[characterName] = EMA.teamEquipment[characterName] or {}
	EMA.teamEquipment[characterName].slots = {}
	EMA.teamEquipment[characterName].lastUpdate = GetTime()

	for slotID, slotData in pairs( data ) do
		local numSlotID = tonumber(slotID)

		if slotData.l then
			-- TRUST the transmitted ilvl value (slotData.i) from the sender
			-- The sender used GetEquippedItemLevel() which queries the actual equipped item
			-- Do NOT try to recalculate from the link - that uses stale client cache
			EMA.teamEquipment[characterName].slots[numSlotID] = {
				link = slotData.l,
				ilvl = slotData.i or 0,
				icon = EMA:GetItemIconFromLink( slotData.l ),
			}
		else
			EMA.teamEquipment[characterName].slots[numSlotID] = {
				link = nil,
				ilvl = 0,
				icon = nil,
			}
		end
	end
end

-------------------------------------------------------------------------------------------------------------
-- Communication
-------------------------------------------------------------------------------------------------------------

-- Request equipment from all team members
function EMA:RequestTeamEquipment()
	if not EMA.db.enableEquipmentSync then return end
	EMA:EMASendCommandToTeam( EMA.COMMAND_REQUEST_EQUIPMENT, "" )
end

-- Handle equipment request - send our equipment data
function EMA:DoSendEquipment( characterName )
	if not EMA.db.enableEquipmentSync then return end
	local packedData = EMA:PackEquipmentData()
	EMA:EMASendCommandToToon( characterName, EMA.COMMAND_HERE_IS_EQUIPMENT, packedData )
end

-- Handle received equipment data
function EMA:DoReceiveEquipment( characterName, data )
	EMA:UnpackEquipmentData( characterName, data )
	-- Update the equipment window if visible
	if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
		EMA:UpdateEquipmentGrid()
	end
end

-- A EMA command has been received.
function EMA:EMAOnCommandReceived( characterName, commandName, ... )
	if commandName == EMA.COMMAND_REQUEST_EQUIPMENT then
		EMA:DoSendEquipment( characterName )
	end
	if commandName == EMA.COMMAND_HERE_IS_EQUIPMENT then
		EMA:DoReceiveEquipment( characterName, ... )
	end
end

-------------------------------------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------------------------------------

function EMA:PLAYER_EQUIPMENT_CHANGED( event, slotID, hasCurrent )
	if not EMA.db.enableEquipmentSync then return end
	if not EMA.db.autoSyncOnEquipChange then return end

	-- Collect own equipment and broadcast to team
	EMA:CollectOwnEquipment()

	-- Send update to all team members
	local packedData = EMA:PackEquipmentData()
	EMA:EMASendCommandToTeam( EMA.COMMAND_HERE_IS_EQUIPMENT, packedData )
end

function EMA:PLAYER_ENTERING_WORLD( event, isInitialLogin, isReloadingUi )
	-- Collect own equipment
	C_Timer.After( 1, function()
		EMA:CollectOwnEquipment()
	end )
end

function EMA:OnTeamChanged( message, characterName )
	-- Clear equipment data for removed characters
	if message == EMAApi.MESSAGE_TEAM_CHARACTER_REMOVED then
		EMA.teamEquipment[characterName] = nil
	end
	-- Update display if visible
	if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
		EMA:UpdateEquipmentGrid()
	end
end

-- Handle character coming online - request their fresh equipment data
function EMA:OnCharacterOnline()
	if not EMA.db.enableEquipmentSync then return end

	-- Check all team members and request data from those online who have stale/no data
	local currentTime = GetTime()
	local staleThreshold = 60 -- Don't request if data is less than 60 seconds old

	for index, characterName in EMAApi.TeamListOrdered() do
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
			local charEquip = EMA.teamEquipment[characterName]
			local needsRefresh = false

			if not charEquip or not charEquip.lastUpdate then
				needsRefresh = true
			elseif ( currentTime - charEquip.lastUpdate ) > staleThreshold then
				needsRefresh = true
			end

			if needsRefresh and characterName ~= EMA.characterName then
				-- Request equipment from this specific character
				EMA:EMASendCommandToToon( characterName, EMA.COMMAND_REQUEST_EQUIPMENT, "" )
			end
		end
	end
end

-- Clear all cached equipment data and request fresh from everyone
function EMA:ClearAndRefreshEquipment()
	-- Clear ALL cached data including our own
	EMA.teamEquipment = {}

	-- Immediately update grid to show cleared state
	if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
		EMA:UpdateEquipmentGrid()
	end

	-- Re-collect our own data fresh
	EMA:CollectOwnEquipment()

	-- Request from all online team members
	EMA:RequestTeamEquipment()

	-- Update after delay to show incoming data
	C_Timer.After( 0.5, function()
		if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
			EMA:UpdateEquipmentGrid()
		end
	end )

	-- Another update slightly later for slower responses
	C_Timer.After( 1.5, function()
		if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
			EMA:UpdateEquipmentGrid()
		end
	end )
end

-- Clear data for a specific character and request fresh
function EMA:ClearCharacterEquipment( characterName )
	EMA.teamEquipment[characterName] = nil

	-- If it's us, just recollect
	if characterName == EMA.characterName then
		EMA:CollectOwnEquipment()
	else
		-- Request fresh data from that character if online
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
			EMA:EMASendCommandToToon( characterName, EMA.COMMAND_REQUEST_EQUIPMENT, "" )
		end
	end

	-- Update display
	C_Timer.After( 0.3, function()
		if EMA.equipmentFrame and EMA.equipmentFrame:IsShown() then
			EMA:UpdateEquipmentGrid()
		end
	end )
end

-------------------------------------------------------------------------------------------------------------
-- Equipment Grid Window
-------------------------------------------------------------------------------------------------------------

-- Modern color palette matching WoW 12.0 aesthetic (same as EMAWindow)
local ModernColors = {
	backgroundDark = { 0.05, 0.05, 0.08, 0.97 },
	backgroundMedium = { 0.08, 0.08, 0.12, 0.95 },
	backgroundLight = { 0.12, 0.12, 0.16, 0.90 },
	borderDark = { 0.20, 0.22, 0.28, 1.0 },
	borderMedium = { 0.35, 0.38, 0.45, 1.0 },
	borderLight = { 0.50, 0.55, 0.62, 1.0 },
	accentBlue = { 0.30, 0.50, 0.80, 1.0 },
	textNormal = { 0.90, 0.90, 0.90, 1.0 },
	textHighlight = { 1.0, 0.85, 0.0, 1.0 },
}

function EMA:CreateEquipmentWindow()
	if EMA.equipmentFrame then return end

	-- Create main frame
	local frame = CreateFrame( "Frame", "EMAEquipmentFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil )
	frame:SetSize( 600, 500 )
	frame:SetPoint( EMA.db.equipmentFramePoint, UIParent, EMA.db.equipmentFrameRelativePoint,
		EMA.db.equipmentFrameXOffset, EMA.db.equipmentFrameYOffset )
	frame:SetFrameStrata( "DIALOG" )
	frame:SetToplevel( true )
	frame:SetMovable( true )
	frame:SetResizable( true )
	frame:EnableMouse( true )
	frame:SetClampedToScreen( true )

	-- Modern WoW 12.0 backdrop
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	}
	frame:SetBackdrop( backdrop )
	-- Modern dark background with subtle blue tint (matches main EMA window)
	frame:SetBackdropColor( unpack( ModernColors.backgroundDark ) )
	frame:SetBackdropBorderColor( unpack( ModernColors.borderMedium ) )

	-- Make movable
	frame:SetScript( "OnMouseDown", function( self, button )
		if button == "LeftButton" and not EMA.db.equipmentLockWindow then
			self:StartMoving()
		end
	end )
	frame:SetScript( "OnMouseUp", function( self, button )
		self:StopMovingOrSizing()
		local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
		EMA.db.equipmentFramePoint = point
		EMA.db.equipmentFrameRelativePoint = relativePoint
		EMA.db.equipmentFrameXOffset = xOfs
		EMA.db.equipmentFrameYOffset = yOfs
	end )

	-- Title bar background (modern accent strip)
	local titleBar = CreateFrame( "Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil )
	titleBar:SetPoint( "TOPLEFT", 5, -5 )
	titleBar:SetPoint( "TOPRIGHT", -5, -5 )
	titleBar:SetHeight( 28 )
	titleBar:SetBackdrop( {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	} )
	titleBar:SetBackdropColor( unpack( ModernColors.backgroundLight ) )
	titleBar:SetBackdropBorderColor( unpack( ModernColors.borderDark ) )
	titleBar:EnableMouse( true )
	titleBar:SetScript( "OnMouseDown", function( self, button )
		if button == "LeftButton" and not EMA.db.equipmentLockWindow then
			frame:StartMoving()
		end
	end )
	titleBar:SetScript( "OnMouseUp", function( self, button )
		frame:StopMovingOrSizing()
		local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
		EMA.db.equipmentFramePoint = point
		EMA.db.equipmentFrameRelativePoint = relativePoint
		EMA.db.equipmentFrameXOffset = xOfs
		EMA.db.equipmentFrameYOffset = yOfs
	end )
	frame.titleBar = titleBar

	-- Title text
	local title = titleBar:CreateFontString( nil, "OVERLAY", "GameFontNormalLarge" )
	title:SetPoint( "LEFT", 10, 0 )
	title:SetText( L["TEAM_EQUIPMENT"] )
	title:SetTextColor( unpack( ModernColors.textNormal ) )
	frame.title = title

	-- Close button
	local closeButton = CreateFrame( "Button", nil, titleBar, "UIPanelCloseButton" )
	closeButton:SetPoint( "RIGHT", -2, 0 )
	closeButton:SetScript( "OnClick", function() frame:Hide() end )

	-- Clear & Refresh button (full reset)
	local clearRefreshButton = CreateFrame( "Button", nil, titleBar, "UIPanelButtonTemplate" )
	clearRefreshButton:SetSize( 100, 20 )
	clearRefreshButton:SetPoint( "RIGHT", closeButton, "LEFT", -5, 0 )
	clearRefreshButton:SetText( L["CLEAR_REFRESH"] or "Clear & Refresh" )
	clearRefreshButton:SetScript( "OnClick", function() EMA:ClearAndRefreshEquipment() end )
	clearRefreshButton:SetScript( "OnEnter", function( self )
		GameTooltip:SetOwner( self, "ANCHOR_BOTTOM" )
		GameTooltip:SetText( L["CLEAR_REFRESH_HELP"] or "Clear all cached data and request fresh equipment from team" )
		GameTooltip:Show()
	end )
	clearRefreshButton:SetScript( "OnLeave", function() GameTooltip:Hide() end )
	frame.clearRefreshButton = clearRefreshButton

	-- Refresh button (just request updates)
	local refreshButton = CreateFrame( "Button", nil, titleBar, "UIPanelButtonTemplate" )
	refreshButton:SetSize( 70, 20 )
	refreshButton:SetPoint( "RIGHT", clearRefreshButton, "LEFT", -5, 0 )
	refreshButton:SetText( L["REFRESH"] )
	refreshButton:SetScript( "OnClick", function() EMA:RefreshTeamEquipment() end )
	frame.refreshButton = refreshButton

	-- Scroll frame for the grid (positioned below title bar)
	local scrollFrame = CreateFrame( "ScrollFrame", "EMAEquipmentScrollFrame", frame, "UIPanelScrollFrameTemplate" )
	scrollFrame:SetPoint( "TOPLEFT", 10, -40 )
	scrollFrame:SetPoint( "BOTTOMRIGHT", -30, 10 )
	frame.scrollFrame = scrollFrame

	-- Content frame inside scroll
	local content = CreateFrame( "Frame", "EMAEquipmentContent", scrollFrame )
	content:SetSize( 1, 1 ) -- Will be resized dynamically
	scrollFrame:SetScrollChild( content )
	frame.content = content

	-- Store reference
	EMA.equipmentFrame = frame

	-- Add to special frames for ESC closing
	table.insert( UISpecialFrames, "EMAEquipmentFrame" )

	-- Start hidden
	frame:Hide()
end

function EMA:UpdateEquipmentGrid()
	if not EMA.equipmentFrame then return end

	local content = EMA.equipmentFrame.content

	-- Clear existing content
	for _, child in ipairs( { content:GetChildren() } ) do
		child:Hide()
		child:SetParent( nil )
	end

	-- Get team members (build a table from the ordered iterator, only online characters)
	local teamList = {}
	for index, characterName in EMAApi.TeamListOrdered() do
		-- Only include online characters
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
			table.insert( teamList, characterName )
		end
	end
	local numTeamMembers = #teamList

	if numTeamMembers == 0 then
		-- Show a message if no team members are online
		local noDataText = EMA.equipmentFrame.content:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
		noDataText:SetPoint( "CENTER", EMA.equipmentFrame.content, "CENTER", 0, 0 )
		noDataText:SetText( L["NO_ONLINE_MEMBERS"] or "No team members online" )
		return
	end

	-- Layout constants
	local slotLabelWidth = 80
	local cellWidth = EMA.db.equipmentCellWidth
	local cellHeight = EMA.db.equipmentCellHeight
	local iconSize = EMA.db.equipmentIconSize
	local padding = 5
	local headerHeight = 45  -- Increased to fit avg iLvl

	-- Calculate content size
	local contentWidth = slotLabelWidth + ( numTeamMembers * cellWidth ) + padding
	local contentHeight = headerHeight + ( NUM_EQUIPMENT_SLOTS * cellHeight ) + padding
	content:SetSize( contentWidth, contentHeight )

	-- Create header row (character names)
	local headerY = 0

	-- Slot label header
	local slotHeader = content:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
	slotHeader:SetPoint( "TOPLEFT", content, "TOPLEFT", 0, -headerY )
	slotHeader:SetSize( slotLabelWidth, headerHeight )
	slotHeader:SetText( L["SLOT"] )
	slotHeader:SetJustifyH( "LEFT" )

	-- Character name headers (clickable for refresh)
	for i, characterName in ipairs( teamList ) do
		-- Create a button frame to catch clicks
		local charHeaderButton = CreateFrame( "Button", nil, content )
		charHeaderButton:SetPoint( "TOPLEFT", content, "TOPLEFT", slotLabelWidth + ( (i-1) * cellWidth ), -headerY )
		charHeaderButton:SetSize( cellWidth, headerHeight )
		charHeaderButton.characterName = characterName

		-- Right-click to refresh this character's data
		charHeaderButton:SetScript( "OnClick", function( self, button )
			if button == "RightButton" then
				EMA:ClearCharacterEquipment( self.characterName )
			end
		end )
		charHeaderButton:RegisterForClicks( "RightButtonUp" )

		-- Tooltip
		charHeaderButton:SetScript( "OnEnter", function( self )
			GameTooltip:SetOwner( self, "ANCHOR_BOTTOM" )
			local charEquip = EMA.teamEquipment[self.characterName]
			local lastUpdate = charEquip and charEquip.lastUpdate
			local ageText = ""
			if lastUpdate then
				local age = GetTime() - lastUpdate
				if age < 60 then
					ageText = string.format( " (%.0fs ago)", age )
				else
					ageText = string.format( " (%.1fm ago)", age / 60 )
				end
			end
			GameTooltip:AddLine( self.characterName .. ageText )
			-- Show average iLvl in tooltip
			local charAvgIlvl = EMA:GetCharacterAverageIlvl( self.characterName )
			if charAvgIlvl > 0 then
				GameTooltip:AddLine( string.format( "Average iLvl: %.1f", charAvgIlvl ), 1, 0.82, 0 )
			end
			GameTooltip:AddLine( L["RIGHT_CLICK_REFRESH"] or "Right-click to refresh", 0.7, 0.7, 0.7 )
			GameTooltip:Show()
		end )
		charHeaderButton:SetScript( "OnLeave", function() GameTooltip:Hide() end )

		-- Character name text
		local charHeader = charHeaderButton:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		charHeader:SetPoint( "TOP", charHeaderButton, "TOP", 0, -2 )
		charHeader:SetSize( cellWidth, 14 )
		-- Show just the character name without realm
		local shortName = strsplit( "-", characterName )
		charHeader:SetText( shortName )
		charHeader:SetJustifyH( "CENTER" )
		charHeader:SetJustifyV( "TOP" )

		-- Color by class if known
		local _, classColor = EMAApi.GetClass( characterName )
		if classColor then
			charHeader:SetTextColor( classColor.r, classColor.g, classColor.b )
		end

		-- Armor type text (below name)
		local armorTypeText = charHeaderButton:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		armorTypeText:SetPoint( "TOP", charHeader, "BOTTOM", 0, 0 )
		armorTypeText:SetSize( cellWidth, 12 )
		armorTypeText:SetJustifyH( "CENTER" )
		local armorType = EMA:GetCharacterArmorType( characterName )
		if armorType then
			armorTypeText:SetText( armorType )
			armorTypeText:SetTextColor( 0.7, 0.7, 0.7 )  -- Gray for subtle display
		else
			armorTypeText:SetText( "" )
		end

		-- Average iLvl text
		local avgIlvl = EMA:GetCharacterAverageIlvl( characterName )
		local avgIlvlText = charHeaderButton:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		avgIlvlText:SetPoint( "BOTTOM", charHeaderButton, "BOTTOM", 0, 2 )
		avgIlvlText:SetSize( cellWidth, 14 )
		avgIlvlText:SetJustifyH( "CENTER" )
		avgIlvlText:SetJustifyV( "BOTTOM" )
		if avgIlvl > 0 then
			avgIlvlText:SetText( string.format( "%.1f", avgIlvl ) )
			-- Color by avg ilvl range
			if avgIlvl >= 600 then
				avgIlvlText:SetTextColor( 1, 0.5, 0 )  -- Orange for high
			elseif avgIlvl >= 500 then
				avgIlvlText:SetTextColor( 0.64, 0.21, 0.93 )  -- Purple for epic range
			else
				avgIlvlText:SetTextColor( 0.12, 1, 0 )  -- Green for lower
			end
		else
			avgIlvlText:SetText( "-" )
			avgIlvlText:SetTextColor( 0.5, 0.5, 0.5 )
		end
	end

	-- Create equipment rows
	for rowIndex, slotInfo in ipairs( EQUIPMENT_SLOTS ) do
		local rowY = headerHeight + ( (rowIndex - 1) * cellHeight )

		-- Slot label
		local slotLabel = content:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		slotLabel:SetPoint( "TOPLEFT", content, "TOPLEFT", 0, -rowY )
		slotLabel:SetSize( slotLabelWidth, cellHeight )
		slotLabel:SetText( slotInfo.displayName )
		slotLabel:SetJustifyH( "LEFT" )
		slotLabel:SetJustifyV( "MIDDLE" )

		-- Equipment cells for each character
		for colIndex, characterName in ipairs( teamList ) do
			local cellX = slotLabelWidth + ( (colIndex - 1) * cellWidth )

			-- Create cell button
			local cell = CreateFrame( "Button", nil, content )
			cell:SetSize( cellWidth - 2, cellHeight - 2 )
			cell:SetPoint( "TOPLEFT", content, "TOPLEFT", cellX, -rowY )

			-- Icon texture
			local icon = cell:CreateTexture( nil, "ARTWORK" )
			icon:SetSize( iconSize, iconSize )
			icon:SetPoint( "CENTER", cell, "CENTER", 0, 5 )
			cell.icon = icon

			-- Item level text
			local ilvlText = cell:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
			ilvlText:SetPoint( "BOTTOM", cell, "BOTTOM", 0, 2 )
			ilvlText:SetJustifyH( "CENTER" )
			cell.ilvlText = ilvlText

			-- Enchant/Gem status indicator (top-right corner)
			local statusText = cell:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
			statusText:SetPoint( "TOPRIGHT", cell, "TOPRIGHT", -1, -1 )
			statusText:SetJustifyH( "RIGHT" )
			cell.statusText = statusText

			-- Get equipment data for this character/slot
			local charEquip = EMA.teamEquipment[characterName]
			if charEquip and charEquip.slots and charEquip.slots[slotInfo.id] then
				local slotData = charEquip.slots[slotInfo.id]

				if slotData.icon then
					icon:SetTexture( slotData.icon )
					icon:Show()
				elseif slotData.link then
					local itemIcon = EMA:GetItemIconFromLink( slotData.link )
					icon:SetTexture( itemIcon )
					icon:Show()
				else
					icon:Hide()
				end

				if slotData.ilvl and slotData.ilvl > 0 then
					ilvlText:SetText( slotData.ilvl )
					-- Color by ilvl range
					if slotData.ilvl >= 600 then
						ilvlText:SetTextColor( 1, 0.5, 0 ) -- Orange for high
					elseif slotData.ilvl >= 500 then
						ilvlText:SetTextColor( 0.64, 0.21, 0.93 ) -- Purple for epic range
					else
						ilvlText:SetTextColor( 0.12, 1, 0 ) -- Green for lower
					end
				else
					ilvlText:SetText( "" )
				end

				-- Check enchant/gem status
				local enchantGemStatus = ""
				if slotData.link then
					enchantGemStatus = EMA:GetItemEnchantGemStatus( slotData.link, slotInfo.id )
				end
				if enchantGemStatus ~= "" then
					statusText:SetText( enchantGemStatus )
					statusText:SetTextColor( 1, 0.3, 0.3 )  -- Red for missing
				else
					statusText:SetText( "" )
				end

				-- Tooltip on hover (suppress comparison tooltips since we're already showing team comparison)
				cell:SetScript( "OnEnter", function( self )
					if slotData.link then
						GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
						GameTooltip:SetHyperlink( slotData.link )
						-- Add enchant/gem status to tooltip
						if enchantGemStatus ~= "" then
							GameTooltip:AddLine( " " )
							if enchantGemStatus:find( "E" ) then
								GameTooltip:AddLine( "Missing Enchant!", 1, 0.3, 0.3 )
							end
							if enchantGemStatus:find( "G" ) then
								GameTooltip:AddLine( "Missing Gem!", 1, 0.3, 0.3 )
							end
						end
						GameTooltip:Show()
						-- Hide the automatic comparison/shopping tooltips
						if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
						if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
					end
				end )
				cell:SetScript( "OnLeave", function( self )
					GameTooltip:Hide()
					if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
					if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
				end )
			else
				icon:SetTexture( "Interface\\PaperDoll\\UI-Backpack-EmptySlot" )
				icon:SetDesaturated( true )
				icon:SetAlpha( 0.3 )
				ilvlText:SetText( "" )
			end
		end
	end
end

function EMA:ShowEquipmentWindow()
	if not EMA.equipmentFrame then
		EMA:CreateEquipmentWindow()
	end

	-- Request equipment from team
	EMA:RequestTeamEquipment()

	-- Show window
	EMA.equipmentFrame:Show()

	-- Update grid after a short delay to allow data to come in
	C_Timer.After( 0.5, function()
		EMA:UpdateEquipmentGrid()
	end )
end

function EMA:HideEquipmentWindow()
	if EMA.equipmentFrame then
		EMA.equipmentFrame:Hide()
	end
end

function EMA:RefreshTeamEquipment()
	-- Request fresh equipment data from all team members
	EMA:RequestTeamEquipment()

	-- Update after delay
	C_Timer.After( 0.5, function()
		EMA:UpdateEquipmentGrid()
	end )
end

-------------------------------------------------------------------------------------------------------------
-- Alt-Click Comparison
-------------------------------------------------------------------------------------------------------------

function EMA:HookItemTooltips()
	-- Use a simpler approach: hook HandleModifiedItemClick if available
	-- This is the central function called when shift/ctrl/alt clicking items
	if not EMA.altClickHooked then
		-- Hook HandleModifiedItemClick - this is called for all modified item clicks
		if _G.HandleModifiedItemClick then
			hooksecurefunc( "HandleModifiedItemClick", function( itemLink )
				if EMA.db.enableAltClickCompare and IsAltKeyDown() and itemLink then
					-- Small delay to avoid conflicts with other handlers
					C_Timer.After( 0.05, function()
						EMA:ShowComparisonPopup( itemLink )
					end )
				end
			end )
			EMA.altClickHooked = true
		end
	end
end

function EMA:GetEquipSlotFromItemLink( itemLink )
	if not itemLink then return nil end

	local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo( itemLink )

	-- Map equip location to slot ID
	local equipLocToSlot = {
		["INVTYPE_HEAD"] = 1,
		["INVTYPE_NECK"] = 2,
		["INVTYPE_SHOULDER"] = 3,
		["INVTYPE_CLOAK"] = 15,
		["INVTYPE_CHEST"] = 5,
		["INVTYPE_ROBE"] = 5,
		["INVTYPE_BODY"] = 4,
		["INVTYPE_TABARD"] = 19,
		["INVTYPE_WRIST"] = 9,
		["INVTYPE_HAND"] = 10,
		["INVTYPE_WAIST"] = 6,
		["INVTYPE_LEGS"] = 7,
		["INVTYPE_FEET"] = 8,
		["INVTYPE_FINGER"] = 11, -- Could be 11 or 12
		["INVTYPE_TRINKET"] = 13, -- Could be 13 or 14
		["INVTYPE_WEAPON"] = 16,
		["INVTYPE_WEAPONMAINHAND"] = 16,
		["INVTYPE_2HWEAPON"] = 16,
		["INVTYPE_SHIELD"] = 17,
		["INVTYPE_WEAPONOFFHAND"] = 17,
		["INVTYPE_HOLDABLE"] = 17,
		["INVTYPE_RANGED"] = 16,
		["INVTYPE_RANGEDRIGHT"] = 16,
	}

	return equipLocToSlot[equipLoc]
end

-- Check if an item is tradeable (BoE, Warbound, or not bound)
-- Returns: true if tradeable, false if soulbound
function EMA:IsItemTradeable( itemLink )
	if not itemLink then return false end

	-- Get item binding info
	local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo( itemLink )

	-- bindType values:
	-- 0 = No binding (can be traded)
	-- 1 = Binds on Pickup (BoP) - NOT tradeable (unless in loot trade window)
	-- 2 = Binds on Equip (BoE) - Tradeable if not equipped
	-- 3 = Binds on Use - Tradeable if not used
	-- 4 = Quest item - NOT tradeable
	-- 5 = Warbound (account-bound but can trade to party in same account)

	-- For comparison purposes, we consider BoE (2), No binding (0), and Warbound (5) as tradeable
	-- BoP items can only be traded in the short loot trade window, so we skip those
	if bindType == 0 or bindType == 2 or bindType == 3 or bindType == 5 then
		return true
	end

	return false
end

-- Armor subclass IDs (from Enum.ItemArmorSubclass)
local ARMOR_SUBCLASS = {
	MISC = 0,       -- Miscellaneous (trinkets, rings, neck, cloaks)
	CLOTH = 1,
	LEATHER = 2,
	MAIL = 3,
	PLATE = 4,
	COSMETIC = 5,
	SHIELD = 6,
}

-- Armor subclass display names
local ARMOR_SUBCLASS_NAMES = {
	[0] = "Misc",
	[1] = "Cloth",
	[2] = "Leather",
	[3] = "Mail",
	[4] = "Plate",
	[5] = "Cosmetic",
	[6] = "Shield",
}

-- Weapon subclass IDs (from Enum.ItemWeaponSubclass)
local WEAPON_SUBCLASS = {
	AXE_1H = 0,
	AXE_2H = 1,
	BOW = 2,
	GUN = 3,
	MACE_1H = 4,
	MACE_2H = 5,
	POLEARM = 6,
	SWORD_1H = 7,
	SWORD_2H = 8,
	WARGLAIVE = 9,
	STAFF = 10,
	BEARCLAW = 11,    -- Exotic (not used)
	CATCLAW = 12,     -- Exotic (not used)
	FIST = 13,
	MISC = 14,        -- Miscellaneous
	DAGGER = 15,
	THROWN = 16,
	SPEAR = 17,       -- Not used in retail
	CROSSBOW = 18,
	WAND = 19,
	FISHING = 20,
}

-- Weapon subclass display names
local WEAPON_SUBCLASS_NAMES = {
	[0] = "1H Axe",
	[1] = "2H Axe",
	[2] = "Bow",
	[3] = "Gun",
	[4] = "1H Mace",
	[5] = "2H Mace",
	[6] = "Polearm",
	[7] = "1H Sword",
	[8] = "2H Sword",
	[9] = "Warglaive",
	[10] = "Staff",
	[13] = "Fist",
	[14] = "Misc",
	[15] = "Dagger",
	[18] = "Crossbow",
	[19] = "Wand",
	[20] = "Fishing",
}

-- Class weapon proficiencies
-- Key = classID, Value = set of weapon subclass IDs they can use
local CLASS_WEAPON_PROFICIENCY = {
	-- Warrior (1) - Most melee weapons
	[1] = { [0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true, [13]=true, [15]=true, [18]=true },
	-- Paladin (2) - Swords, maces, axes, polearms
	[2] = { [0]=true, [1]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true },
	-- Hunter (3) - Ranged, some melee
	[3] = { [0]=true, [1]=true, [2]=true, [3]=true, [6]=true, [7]=true, [8]=true, [13]=true, [15]=true, [18]=true, [10]=true },
	-- Rogue (4) - Light melee weapons
	[4] = { [0]=true, [4]=true, [7]=true, [13]=true, [15]=true, [2]=true, [3]=true, [18]=true },
	-- Priest (5) - Caster weapons
	[5] = { [4]=true, [15]=true, [10]=true, [19]=true },
	-- Death Knight (6) - Heavy melee
	[6] = { [0]=true, [1]=true, [4]=true, [5]=true, [6]=true, [7]=true, [8]=true },
	-- Shaman (7) - Maces, axes, fist, staves
	[7] = { [0]=true, [1]=true, [4]=true, [5]=true, [13]=true, [15]=true, [10]=true },
	-- Mage (8) - Caster weapons
	[8] = { [7]=true, [15]=true, [10]=true, [19]=true },
	-- Warlock (9) - Caster weapons
	[9] = { [7]=true, [15]=true, [10]=true, [19]=true },
	-- Monk (10) - Fist, staves, polearms, swords, maces, axes (1H)
	[10] = { [0]=true, [4]=true, [6]=true, [7]=true, [13]=true, [10]=true },
	-- Druid (11) - Staves, maces, fist, daggers, polearms
	[11] = { [4]=true, [5]=true, [6]=true, [13]=true, [15]=true, [10]=true },
	-- Demon Hunter (12) - Warglaives, fist, 1H axes, 1H swords
	[12] = { [0]=true, [7]=true, [9]=true, [13]=true },
	-- Evoker (13) - Staves, fist, 1H axes, 1H swords, daggers, maces
	[13] = { [0]=true, [4]=true, [7]=true, [13]=true, [15]=true, [10]=true },
}

-- Classes and their max armor proficiency (what they can equip at max level)
-- Key = classID, Value = highest armor subclass they can wear
local CLASS_ARMOR_PROFICIENCY = {
	-- Cloth only
	[5] = ARMOR_SUBCLASS.CLOTH,   -- Priest
	[8] = ARMOR_SUBCLASS.CLOTH,   -- Mage
	[9] = ARMOR_SUBCLASS.CLOTH,   -- Warlock
	-- Leather
	[4] = ARMOR_SUBCLASS.LEATHER,  -- Rogue
	[10] = ARMOR_SUBCLASS.LEATHER, -- Monk
	[11] = ARMOR_SUBCLASS.LEATHER, -- Druid
	[12] = ARMOR_SUBCLASS.LEATHER, -- Demon Hunter
	-- Mail
	[3] = ARMOR_SUBCLASS.MAIL,    -- Hunter
	[7] = ARMOR_SUBCLASS.MAIL,    -- Shaman
	[13] = ARMOR_SUBCLASS.MAIL,   -- Evoker
	-- Plate
	[1] = ARMOR_SUBCLASS.PLATE,   -- Warrior
	[2] = ARMOR_SUBCLASS.PLATE,   -- Paladin
	[6] = ARMOR_SUBCLASS.PLATE,   -- Death Knight
}

-- Class primary armor type names (for display)
-- Key = classID, Value = armor type name string
local CLASS_PRIMARY_ARMOR = {
	[1] = "Plate",    -- Warrior
	[2] = "Plate",    -- Paladin
	[3] = "Mail",     -- Hunter
	[4] = "Leather",  -- Rogue
	[5] = "Cloth",    -- Priest
	[6] = "Plate",    -- Death Knight
	[7] = "Mail",     -- Shaman
	[8] = "Cloth",    -- Mage
	[9] = "Cloth",    -- Warlock
	[10] = "Leather", -- Monk
	[11] = "Leather", -- Druid
	[12] = "Leather", -- Demon Hunter
	[13] = "Mail",    -- Evoker
}

-- Get item equipment type info from item link
-- Returns: subclass (number), typeName (string), isEquipment (bool), isWeapon (bool)
function EMA:GetItemArmorType( itemLink )
	if not itemLink then return nil, nil, false, false end

	-- Get item class and subclass
	local _, _, _, _, _, itemClassID, itemSubclassID = C_Item.GetItemInfoInstant( itemLink )

	-- Item class 4 = Armor
	if itemClassID == 4 then
		local armorName = ARMOR_SUBCLASS_NAMES[itemSubclassID] or "Unknown"
		return itemSubclassID, armorName, true, false
	end

	-- Item class 2 = Weapon
	if itemClassID == 2 then
		local weaponName = WEAPON_SUBCLASS_NAMES[itemSubclassID] or "Weapon"
		return itemSubclassID, weaponName, true, true
	end

	return nil, nil, false, false
end

-- Check if a class can equip a weapon type
-- Returns: canEquip (bool)
function EMA:CanClassEquipWeapon( classID, weaponSubclass )
	if not classID or weaponSubclass == nil then return true end

	local proficiency = CLASS_WEAPON_PROFICIENCY[classID]
	if not proficiency then return true end

	return proficiency[weaponSubclass] == true
end

-- Check if a class can equip an armor type
-- Returns: canEquip (bool), isPrimary (bool - true if it's their main armor type)
function EMA:CanClassEquipArmor( classID, armorSubclass )
	if not classID or not armorSubclass then return true, false end

	-- Misc items (trinkets, rings, neck, cloak) can be equipped by everyone
	if armorSubclass == ARMOR_SUBCLASS.MISC or armorSubclass == ARMOR_SUBCLASS.COSMETIC then
		return true, true
	end

	-- Shields - only Warriors, Paladins, and Shamans
	if armorSubclass == ARMOR_SUBCLASS.SHIELD then
		local canUseShield = (classID == 1 or classID == 2 or classID == 7)
		return canUseShield, canUseShield
	end

	local maxProficiency = CLASS_ARMOR_PROFICIENCY[classID]
	if not maxProficiency then return true, false end

	-- Can they wear this armor type?
	local canEquip = (armorSubclass <= maxProficiency)

	-- Is this their PRIMARY armor type? (what gives them best stats)
	local isPrimary = (armorSubclass == maxProficiency)

	return canEquip, isPrimary
end

-- Get class info for a character (using Team module data)
-- Returns: classID, className
function EMA:GetCharacterClassInfo( characterName )
	-- Convert class name to classID
	local classIDs = {
		["WARRIOR"] = 1,
		["PALADIN"] = 2,
		["HUNTER"] = 3,
		["ROGUE"] = 4,
		["PRIEST"] = 5,
		["DEATHKNIGHT"] = 6,
		["SHAMAN"] = 7,
		["MAGE"] = 8,
		["WARLOCK"] = 9,
		["MONK"] = 10,
		["DRUID"] = 11,
		["DEMONHUNTER"] = 12,
		["EVOKER"] = 13,
	}

	-- Try getting from Team module first
	local className, classColor = EMAApi.GetClass( characterName )

	-- If not found and this is the current character, get directly from WoW API
	if not className or className == "" then
		-- Compare without realm and case-insensitive
		local charNameOnly = strsplit( "-", characterName )
		local playerName = UnitName( "player" )
		if charNameOnly:lower() == playerName:lower() then
			local _, classFileName = UnitClass( "player" )
			if classFileName then
				local classID = classIDs[classFileName:upper()]
				return classID, classFileName
			end
		end
	end

	if not className then return nil, nil end

	local classID = classIDs[className:upper()]
	return classID, className
end

-- Get a character's primary armor type name
-- Returns: armorTypeName (string) or nil
function EMA:GetCharacterArmorType( characterName )
	local classID = EMA:GetCharacterClassInfo( characterName )
	if not classID then return nil end
	return CLASS_PRIMARY_ARMOR[classID]
end

function EMA:ShowComparisonPopup( itemLink )
	if not itemLink then return end

	-- Check if item is tradeable (BoE, Warbound, or unbound)
	if not EMA:IsItemTradeable( itemLink ) then
		EMA:Print( L["ITEM_NOT_TRADEABLE"] )
		return
	end

	local slotID = EMA:GetEquipSlotFromItemLink( itemLink )
	if not slotID then
		EMA:Print( L["CANNOT_COMPARE_ITEM"] )
		return
	end

	-- Get slot name for display
	local slotName = "Unknown"
	for _, slotInfo in ipairs( EQUIPMENT_SLOTS ) do
		if slotInfo.id == slotID then
			slotName = slotInfo.displayName
			break
		end
	end

	-- Create or show comparison frame
	if not EMA.comparisonFrame then
		EMA:CreateComparisonFrame()
	end

	-- Load item data first to ensure accurate ilvl, then show comparison
	local item = Item:CreateFromItemLink( itemLink )
	if item and not item:IsItemEmpty() then
		item:ContinueOnItemLoad( function()
			EMA:UpdateComparisonFrame( itemLink, slotID, slotName )
			EMA.comparisonFrame:Show()
		end )
	else
		-- Fallback: show immediately if item object couldn't be created
		EMA:UpdateComparisonFrame( itemLink, slotID, slotName )
		EMA.comparisonFrame:Show()
	end
end

function EMA:CreateComparisonFrame()
	local frame = CreateFrame( "Frame", "EMAComparisonFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil )
	frame:SetSize( 700, 200 )
	frame:SetPoint( "CENTER" )
	frame:SetFrameStrata( "FULLSCREEN_DIALOG" )
	frame:SetFrameLevel( 100 )
	frame:SetToplevel( true )
	frame:SetMovable( true )
	frame:EnableMouse( true )
	frame:SetClampedToScreen( true )

	-- Modern WoW 12.0 backdrop (matches Equipment window)
	local backdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	}
	frame:SetBackdrop( backdrop )
	frame:SetBackdropColor( unpack( ModernColors.backgroundDark ) )
	frame:SetBackdropBorderColor( unpack( ModernColors.borderMedium ) )

	-- Title bar background (modern accent strip)
	local titleBar = CreateFrame( "Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil )
	titleBar:SetPoint( "TOPLEFT", 5, -5 )
	titleBar:SetPoint( "TOPRIGHT", -5, -5 )
	titleBar:SetHeight( 28 )
	titleBar:SetBackdrop( {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	} )
	titleBar:SetBackdropColor( unpack( ModernColors.backgroundLight ) )
	titleBar:SetBackdropBorderColor( unpack( ModernColors.borderDark ) )
	titleBar:EnableMouse( true )
	titleBar:SetScript( "OnMouseDown", function() frame:StartMoving() end )
	titleBar:SetScript( "OnMouseUp", function() frame:StopMovingOrSizing() end )
	frame.titleBar = titleBar

	-- Title text
	local title = titleBar:CreateFontString( nil, "OVERLAY", "GameFontNormalLarge" )
	title:SetPoint( "LEFT", 10, 0 )
	title:SetTextColor( unpack( ModernColors.textNormal ) )
	frame.title = title

	-- Close button
	local closeButton = CreateFrame( "Button", nil, titleBar, "UIPanelCloseButton" )
	closeButton:SetPoint( "RIGHT", -2, 0 )
	closeButton:SetScript( "OnClick", function() frame:Hide() end )

	-- Content area for tooltips (positioned below title bar)
	local content = CreateFrame( "Frame", nil, frame )
	content:SetPoint( "TOPLEFT", 10, -40 )
	content:SetPoint( "BOTTOMRIGHT", -10, 10 )
	frame.content = content

	-- Add to special frames
	table.insert( UISpecialFrames, "EMAComparisonFrame" )

	EMA.comparisonFrame = frame
end

function EMA:UpdateComparisonFrame( itemLink, slotID, slotName )
	local frame = EMA.comparisonFrame
	local content = frame.content

	-- Get armor/weapon type info for the item
	local itemSubclass, itemTypeName, isEquipment, isWeapon = EMA:GetItemArmorType( itemLink )

	-- Update title with armor/weapon type
	local titleText = string.format( L["COMPARE_SLOT"], slotName )
	if isEquipment and itemTypeName then
		titleText = titleText .. " (" .. itemTypeName .. ")"
	end
	frame.title:SetText( titleText )

	-- Clear existing tooltip frames
	for _, child in ipairs( { content:GetChildren() } ) do
		child:Hide()
		child:SetParent( nil )
	end

	-- Get team list (build a table from the ordered iterator, only online characters)
	local teamList = {}
	for _, characterName in EMAApi.TeamListOrdered() do
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
			table.insert( teamList, characterName )
		end
	end
	local numTooltips = #teamList + 1 -- +1 for the loot item

	-- Calculate layout
	local tooltipWidth = 150
	local spacing = 10
	local totalWidth = ( numTooltips * tooltipWidth ) + ( (numTooltips - 1) * spacing )
	frame:SetWidth( math.max( totalWidth + 20, 400 ) )

	local startX = 0

	-- Create loot item tooltip column
	local lootColumn = CreateFrame( "Frame", nil, content )
	lootColumn:SetSize( tooltipWidth, 150 )
	lootColumn:SetPoint( "TOPLEFT", content, "TOPLEFT", startX, 0 )

	local lootLabel = lootColumn:CreateFontString( nil, "OVERLAY", "GameFontNormalLarge" )
	lootLabel:SetPoint( "TOP", 0, 0 )
	lootLabel:SetText( L["LOOT_ITEM"] )
	lootLabel:SetTextColor( 0, 1, 0 )

	-- Larger icon for loot item (48x48 vs 36x36 for team members)
	local lootIcon = lootColumn:CreateTexture( nil, "ARTWORK" )
	lootIcon:SetSize( 48, 48 )
	lootIcon:SetPoint( "TOP", lootLabel, "BOTTOM", 0, -5 )
	lootIcon:SetTexture( EMA:GetItemIconFromLink( itemLink ) )

	local lootIlvl = lootColumn:CreateFontString( nil, "OVERLAY", "GameFontNormalLarge" )
	lootIlvl:SetPoint( "TOP", lootIcon, "BOTTOM", 0, -2 )
	lootIlvl:SetText( "iLvl: ..." )  -- Placeholder while loading
	lootIlvl:SetTextColor( 1, 0.82, 0 )

	-- Use async loading to get accurate item level
	EMA:GetItemLevelAsync( itemLink, function( ilvl )
		if lootIlvl and lootIlvl:IsShown() then
			lootIlvl:SetText( "iLvl: " .. ( ilvl or 0 ) )
		end
	end )

	-- Tooltip on hover
	lootColumn:EnableMouse( true )
	lootColumn:SetScript( "OnEnter", function( self )
		GameTooltip:SetOwner( self, "ANCHOR_BOTTOM" )
		GameTooltip:SetHyperlink( itemLink )
		GameTooltip:Show()
	end )
	lootColumn:SetScript( "OnLeave", function() GameTooltip:Hide() end )

	startX = startX + tooltipWidth + spacing

	-- Get benefit ranking to determine who benefits most
	local rankings = EMA:GetItemBenefitRanking( itemLink, slotID )
	local bestBenefitName = nil
	local bestBenefitDiff = 0
	if rankings and #rankings > 0 and rankings[1].diff > 0 then
		bestBenefitName = rankings[1].name
		bestBenefitDiff = rankings[1].diff
	end

	-- Create columns for each team member
	local newItemIlvl = EMA:GetItemLevelFromLink( itemLink )

	for _, characterName in ipairs( teamList ) do
		local charColumn = CreateFrame( "Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil )
		charColumn:SetSize( tooltipWidth, 150 )
		charColumn:SetPoint( "TOPLEFT", content, "TOPLEFT", startX, 0 )

		-- Get their equipped item in this slot (need this early for benefit calculation)
		local charEquip = EMA.teamEquipment[characterName]
		local equippedLink = nil
		local equippedIlvl = 0
		local equippedIcon = nil

		if charEquip and charEquip.slots and charEquip.slots[slotID] then
			equippedLink = charEquip.slots[slotID].link
			equippedIlvl = charEquip.slots[slotID].ilvl or 0
			equippedIcon = charEquip.slots[slotID].icon
		end

		local ilvlDiff = newItemIlvl - equippedIlvl
		local isBestBenefit = ( characterName == bestBenefitName and bestBenefitDiff > 0 )

		-- Check armor/weapon type usability for this character
		local classID = EMA:GetCharacterClassInfo( characterName )
		local canEquip, isPrimary
		if isWeapon then
			canEquip = EMA:CanClassEquipWeapon( classID, itemSubclass )
			isPrimary = canEquip  -- For weapons, if they can use it, consider it "primary"
		else
			canEquip, isPrimary = EMA:CanClassEquipArmor( classID, itemSubclass )
		end
		local dimColumn = isEquipment and not canEquip

		-- Add highlight border for best benefit character (only if they can equip it)
		if isBestBenefit and canEquip then
			charColumn:SetBackdrop( {
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			} )
			charColumn:SetBackdropColor( 0, 0.4, 0, 0.3 )  -- Green tint background
			charColumn:SetBackdropBorderColor( 0, 1, 0, 1 )  -- Green border
		elseif dimColumn then
			-- Dim background for characters who can't use this armor type
			charColumn:SetBackdrop( {
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 }
			} )
			charColumn:SetBackdropColor( 0.2, 0.2, 0.2, 0.5 )  -- Dark gray background
			charColumn:SetBackdropBorderColor( 0.4, 0.4, 0.4, 0.5 )  -- Gray border
		end

		-- Character name
		local charLabel = charColumn:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		charLabel:SetPoint( "TOP", 0, -3 )
		local shortName = strsplit( "-", characterName )
		charLabel:SetText( shortName )

		-- Color by class (dimmed if can't equip)
		local _, classColor = EMAApi.GetClass( characterName )
		if classColor then
			if dimColumn then
				charLabel:SetTextColor( classColor.r * 0.5, classColor.g * 0.5, classColor.b * 0.5 )
			else
				charLabel:SetTextColor( classColor.r, classColor.g, classColor.b )
			end
		end

		-- Armor/weapon type indicator below name
		local typeLabel = charColumn:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
		typeLabel:SetPoint( "TOP", charLabel, "BOTTOM", 0, -1 )
		if isEquipment and itemSubclass then
			local charTypeName = "?"
			if isWeapon then
				-- For weapons, show if they can use this weapon type
				charTypeName = canEquip and "Can Use" or "Can't Use"
			else
				-- For armor, show the character's primary armor type
				-- Use GetCharacterArmorType which has fallback for current player
				charTypeName = EMA:GetCharacterArmorType( characterName ) or CLASS_PRIMARY_ARMOR[classID] or "?"
			end
			typeLabel:SetText( charTypeName )
			if dimColumn then
				typeLabel:SetTextColor( 1, 0.3, 0.3, 0.7 )  -- Red, dimmed - can't use
			elseif isPrimary then
				typeLabel:SetTextColor( 0.3, 1, 0.3 )  -- Green - primary/can use
			else
				typeLabel:SetTextColor( 1, 1, 0.3 )  -- Yellow - can use but not primary
			end
		else
			typeLabel:SetText( "" )
		end

		-- "BEST" indicator for top benefit (only if they can equip)
		local nextAnchor = typeLabel
		if isBestBenefit and canEquip then
			local bestLabel = charColumn:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
			bestLabel:SetPoint( "TOP", typeLabel, "BOTTOM", 0, -1 )
			bestLabel:SetText( "★ BEST ★" )
			bestLabel:SetTextColor( 0, 1, 0 )
			nextAnchor = bestLabel
		end

		-- Icon
		local charIcon = charColumn:CreateTexture( nil, "ARTWORK" )
		charIcon:SetSize( 36, 36 )
		charIcon:SetPoint( "TOP", nextAnchor, "BOTTOM", 0, -3 )
		if equippedIcon then
			charIcon:SetTexture( equippedIcon )
		elseif equippedLink then
			charIcon:SetTexture( EMA:GetItemIconFromLink( equippedLink ) )
		else
			charIcon:SetTexture( "Interface\\PaperDoll\\UI-Backpack-EmptySlot" )
			charIcon:SetDesaturated( true )
			charIcon:SetAlpha( 0.5 )
		end

		-- Dim icon if can't equip
		if dimColumn then
			charIcon:SetDesaturated( true )
			charIcon:SetAlpha( 0.5 )
		end

		-- iLvl and upgrade indicator
		local charIlvl = charColumn:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
		charIlvl:SetPoint( "TOP", charIcon, "BOTTOM", 0, -2 )
		if equippedIlvl > 0 then
			charIlvl:SetText( "iLvl: " .. equippedIlvl )
		else
			charIlvl:SetText( L["EMPTY_SLOT"] )
		end
		if dimColumn then
			charIlvl:SetTextColor( 0.5, 0.5, 0.5 )
		end

		-- Upgrade indicator
		local upgradeText = charColumn:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
		upgradeText:SetPoint( "TOP", charIlvl, "BOTTOM", 0, -2 )

		if dimColumn then
			upgradeText:SetText( L["CANNOT_USE"] or "Can't Use" )
			upgradeText:SetTextColor( 0.6, 0.3, 0.3 )
		elseif ilvlDiff > 0 then
			upgradeText:SetText( "+" .. ilvlDiff .. " " .. L["UPGRADE"] )
			upgradeText:SetTextColor( 0, 1, 0 )
		elseif ilvlDiff < 0 then
			upgradeText:SetText( ilvlDiff .. " " .. L["DOWNGRADE"] )
			upgradeText:SetTextColor( 1, 0, 0 )
		else
			upgradeText:SetText( L["SAME_ILVL"] )
			upgradeText:SetTextColor( 1, 1, 0 )
		end

		-- Tooltip on hover
		charColumn:EnableMouse( true )
		charColumn:SetScript( "OnEnter", function( self )
			if equippedLink then
				GameTooltip:SetOwner( self, "ANCHOR_BOTTOM" )
				GameTooltip:SetHyperlink( equippedLink )
				if isBestBenefit then
					GameTooltip:AddLine( " " )
					GameTooltip:AddLine( "Best upgrade candidate!", 0, 1, 0 )
				end
				GameTooltip:Show()
			end
		end )
		charColumn:SetScript( "OnLeave", function() GameTooltip:Hide() end )

		startX = startX + tooltipWidth + spacing
	end
end

-------------------------------------------------------------------------------------------------------------
-- API for other modules
-------------------------------------------------------------------------------------------------------------

-- Get a character's equipment in a specific slot
function EMA:GetCharacterEquipment( characterName, slotID )
	if EMA.teamEquipment[characterName] and EMA.teamEquipment[characterName].slots then
		return EMA.teamEquipment[characterName].slots[slotID]
	end
	return nil
end

-- Get all equipment for a character
function EMA:GetCharacterAllEquipment( characterName )
	if EMA.teamEquipment[characterName] then
		return EMA.teamEquipment[characterName].slots
	end
	return nil
end

-------------------------------------------------------------------------------------------------------------
-- Item Benefit Ranking for Comparison
-------------------------------------------------------------------------------------------------------------

-- Calculate who benefits most from an item (by iLvl difference)
-- Returns sorted table: { { name=characterName, currentIlvl=X, diff=Y }, ... }
function EMA:GetItemBenefitRanking( itemLink, slotID )
	local newIlvl = EMA:GetItemLevelFromLink( itemLink )
	if not newIlvl or newIlvl == 0 then return {} end

	local rankings = {}

	for _, characterName in EMAApi.TeamListOrdered() do
		if EMAApi.GetCharacterOnlineStatus( characterName ) == true then
			local charEquip = EMA.teamEquipment[characterName]
			local currentIlvl = 0

			if charEquip and charEquip.slots and charEquip.slots[slotID] then
				currentIlvl = charEquip.slots[slotID].ilvl or 0
			end

			local diff = newIlvl - currentIlvl
			table.insert( rankings, {
				name = characterName,
				currentIlvl = currentIlvl,
				diff = diff,
				isUpgrade = diff > 0,
			} )
		end
	end

	-- Sort by benefit (highest diff first)
	table.sort( rankings, function( a, b ) return a.diff > b.diff end )

	return rankings
end
