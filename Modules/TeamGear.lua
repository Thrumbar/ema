-- ================================================================================ --
--				EMA - ( Ebony's MultiBoxing Assistant )    							--
--				Team Gear Module (custom)												--
--																					--
--  UI goal: "Something like" the grid screenshot:									--
--   - Columns: team members															--
--   - Rows: equipment slots															--
--   - Each cell: item icon + ilvl overlay; tooltip on hover; Alt-click compare		--
--   - Buttons: Refresh, Clear & Refresh												--
--																					--
--  Minimal + safe:																	--
--   - Gear is synced as item links per slot.											--
--   - UI renders from cached snapshots.												--
--   - Auto-sync on equip change optional.												--
-- ================================================================================ --

local EMA = LibStub( "AceAddon-3.0" ):NewAddon(
	"TeamGear",
	"Module-1.0",
	"AceConsole-3.0",
	"AceEvent-3.0",
	"AceHook-3.0",
	"AceTimer-3.0"
)

local EMAUtilities = LibStub:GetLibrary( "EbonyUtilities-1.0" )
local EMAHelperSettings = LibStub:GetLibrary( "EMAHelperSettings-1.0" )

EMA.moduleName = "TeamGear"
EMA.settingsDatabaseName = "TeamGearProfileDB"
EMA.chatCommand = "ema-team-gear"
local L = LibStub( "AceLocale-3.0" ):GetLocale( "Core" )
EMA.parentDisplayName = L["DISPLAY"]
EMA.moduleIcon = "Interface\\Icons\\inv_chest_plate04"
EMA.moduleOrder = 3

-- slotId -> label
local GEAR_SLOTS = {
	{ 1,  "Head" },
	{ 2,  "Neck" },
	{ 3,  "Shoulder" },
	{ 5,  "Chest" },
	{ 6,  "Waist" },
	{ 7,  "Legs" },
	{ 8,  "Feet" },
	{ 9,  "Wrist" },
	{ 10, "Hands" },
	{ 11, "Finger 1" },
	{ 12, "Finger 2" },
	{ 13, "Trinket 1" },
	{ 14, "Trinket 2" },
	{ 15, "Back" },
	{ 16, "Main Hand" },
	{ 17, "Off Hand" },
}

local PAYLOAD_SEP = "\001"

local function EnsureTeamGearTables()
	if EMA.db.teamGear == nil then
		EMA.db.teamGear = {}
	end
	if EMA.db.teamGear.gearByCharacter == nil then
		EMA.db.teamGear.gearByCharacter = {}
	end
end

local function GetPlayerFullName()
	local name, realm = UnitName("player")
	if name == nil then
		return "player"
	end
	if realm == nil or realm == "" then
		realm = GetRealmName() or ""
		realm = realm:gsub("%s+", "")
	end
	if realm ~= "" and not string.find(name, "-") then
		return name .. "-" .. realm
	end
	return name
end

local function GetSnapshot()
	local snap = {}
	for _, s in ipairs(GEAR_SLOTS) do
		local slotId = s[1]
		local link = GetInventoryItemLink("player", slotId)
		snap[tostring(slotId)] = link or ""
	end
	return snap
end

local function SnapshotToString(snap)
	local parts = {}
	for _, s in ipairs(GEAR_SLOTS) do
		local k = tostring(s[1])
		local v = snap[k] or ""
		parts[#parts+1] = k .. "=" .. v
	end
	return table.concat(parts, PAYLOAD_SEP)
end

local function StringToSnapshot(payload)
	local snap = {}
	if payload == nil or payload == "" then
		return snap
	end
	for token in string.gmatch(payload, "([^" .. PAYLOAD_SEP .. "]+)") do
		local k, v = string.match(token, "^(%d+)%=(.*)$")
		if k ~= nil then
			snap[k] = v or ""
		end
	end
	return snap
end

-- ------------------------------------------------------------------------------------------------------------
-- UI helpers
-- ------------------------------------------------------------------------------------------------------------
local function SortedCharacters(t)
	local list = {}
	for name in pairs(t) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

local function GetItemIconAndLevel(itemLink)
	if itemLink == nil or itemLink == "" then
		return nil, nil
	end
	local icon = nil
	local level = nil

	-- Icon: GetItemInfoInstant is fast and doesn't require full cache.
	local itemID = GetItemInfoInstant(itemLink)
	if itemID then
		icon = select(5, GetItemInfoInstant(itemID))
	end
	if icon == nil then
		icon = select(10, GetItemInfo(itemLink))
	end

	-- Level: GetDetailedItemLevelInfo exists on retail; fallback to GetItemInfo if nil.
	if GetDetailedItemLevelInfo then
		level = GetDetailedItemLevelInfo(itemLink)
	end
	if level == nil then
		level = select(4, GetItemInfo(itemLink))
	end
	return icon, level
end

local function ShowItemTooltip(owner, itemLink)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if itemLink and itemLink ~= "" then
		GameTooltip:SetHyperlink(itemLink)
	else
		GameTooltip:SetText("Empty")
	end
	GameTooltip:Show()
end

local function CompareWithEquipped(slotId, itemLink)
	-- Show a comparison tooltip vs the player's currently equipped item in that slot.
	if itemLink == nil or itemLink == "" then
		return
	end
	GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
	GameTooltip:SetHyperlink(itemLink)
	GameTooltip_ShowCompareItem(GameTooltip)
	GameTooltip:Show()
end

-- ------------------------------------------------------------------------------------------------------------
-- Settings / GUI
-- ------------------------------------------------------------------------------------------------------------
local function EnsureUI()
	if EMA.settingsControl == nil or EMA.settingsControl.widgetSettings == nil then
		return false
	end
	if EMA.settingsControl.teamGearFrame then
		return true
	end

	local content = EMA.settingsControl.widgetSettings.content

	-- Container frame for the grid
	local frame = CreateFrame("Frame", "EMATeamGearFrame", content)
	frame:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -140)
	frame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -12, 12)
	EMA.settingsControl.teamGearFrame = frame

	-- ScrollFrame
	local scroll = CreateFrame("ScrollFrame", "EMATeamGearScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 0)

	local child = CreateFrame("Frame", "EMATeamGearScrollChild", scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)

	frame.scroll = scroll
	frame.child = child
	frame.cells = {}
	frame.headers = {}
	frame.rowLabels = {}

	return true
end

local function ClearGrid()
	if not EnsureUI() then
		return
	end
	local f = EMA.settingsControl.teamGearFrame
	for _, b in pairs(f.cells) do
		b:Hide()
	end
	for _, h in pairs(f.headers) do
		h:Hide()
	end
	for _, r in pairs(f.rowLabels) do
		r:Hide()
	end
end

local function AcquireFontString(parent, pool, key)
	if pool[key] == nil then
		pool[key] = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	return pool[key]
end

local function AcquireCell(parent, pool, key)
	if pool[key] == nil then
		-- ItemButtonTemplate gives icon + count textures; we add ilvl text ourselves.
		local b = CreateFrame("Button", nil, parent, "ItemButtonTemplate")
		b:SetSize(36, 36)

		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
		fs:SetTextColor(0, 1, 0, 1)
		b.ilvlText = fs

		b:SetScript("OnEnter", function(self)
			ShowItemTooltip(self, self.itemLink)
		end)
		b:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		b:SetScript("OnClick", function(self, button)
			if IsAltKeyDown() and EMA.db.enableAltClickCompare == true then
				CompareWithEquipped(self.slotId, self.itemLink)
				return
			end
			-- Default: just show tooltip at cursor.
			ShowItemTooltip(self, self.itemLink)
		end)

		pool[key] = b
	end
	return pool[key]
end

local function UpdateGrid()
	if EMA.settingsControl == nil then
		return
	end
	EnsureTeamGearTables()
	if not EnsureUI() then
		return
	end

	local f = EMA.settingsControl.teamGearFrame
	local child = f.child

	-- Build character list (columns)
	local chars = SortedCharacters(EMA.db.teamGear.gearByCharacter)
	if #chars == 0 then
		ClearGrid()
		local msg = AcquireFontString(child, f.headers, "_empty")
		msg:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
		msg:SetText("No team gear received yet. Click Refresh.")
		msg:Show()
		child:SetSize(600, 200)
		return
	end

	-- Layout constants
	local headerH = 18
	local rowH = 40
	local labelW = 110
	local cellW = 44
	local topPad = 8
	local leftPad = 8

	-- Header: character names + (optional) avg ilvl
	for c, name in ipairs(chars) do
		local x = leftPad + labelW + (c-1)*cellW
		local h = AcquireFontString(child, f.headers, "h"..c)
		h:SetPoint("TOPLEFT", child, "TOPLEFT", x, -topPad)
		h:SetText(name:gsub("%-.*$", "")) -- short name
		h:SetTextColor(1, 0.82, 0, 1)
		h:Show()
	end

	-- Rows: slot labels + cells
	for r, slot in ipairs(GEAR_SLOTS) do
		local slotId, label = slot[1], slot[2]
		local y = -topPad - headerH - (r-1)*rowH

		local rl = AcquireFontString(child, f.rowLabels, "r"..r)
		rl:SetPoint("TOPLEFT", child, "TOPLEFT", leftPad, y-10)
		rl:SetText(label)
		rl:SetTextColor(1, 0.82, 0, 1)
		rl:Show()

		for c, name in ipairs(chars) do
			local snap = EMA.db.teamGear.gearByCharacter[name] or {}
			local link = snap[tostring(slotId)] or ""
			local key = "c"..c.."r"..r
			local b = AcquireCell(child, f.cells, key)
			b.slotId = slotId
			b.itemLink = link

			local x = leftPad + labelW + (c-1)*cellW
			b:SetPoint("TOPLEFT", child, "TOPLEFT", x, y-26)

			-- Update icon + ilvl
			local icon, ilvl = GetItemIconAndLevel(link)
			SetItemButtonTexture(b, icon)
			if ilvl then
				b.ilvlText:SetText(tostring(ilvl))
				b.ilvlText:Show()
			else
				b.ilvlText:SetText("")
				b.ilvlText:Hide()
			end

			-- Grey out if empty
			if link == "" then
				b.IconBorder:Hide()
				b:SetAlpha(0.35)
			else
				b.IconBorder:Show()
				b:SetAlpha(1.0)
			end

			b:Show()
		end
	end

	local totalW = leftPad + labelW + (#chars * cellW) + 40
	local totalH = topPad + headerH + (#GEAR_SLOTS * rowH) + 30
	child:SetSize(totalW, totalH)
end

-- ------------------------------------------------------------------------------------------------------------
-- Settings create/refresh
-- ------------------------------------------------------------------------------------------------------------
local function SettingsCreateOptions( top )
	local checkBoxHeight = EMAHelperSettings:GetCheckBoxHeight()
	local buttonHeight = EMAHelperSettings:GetButtonHeight()
	local headingHeight = EMAHelperSettings:HeadingHeight()
	local headingWidth = EMAHelperSettings:HeadingWidth( true )
	local left = EMAHelperSettings:LeftOfSettings()
	local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
	local horizontalSpacing = EMAHelperSettings:GetHorizontalSpacing()
	local movingTop = top

	EMAHelperSettings:CreateHeading( EMA.settingsControl, "Team Gear", movingTop, true )
	movingTop = movingTop - headingHeight

	EMA.settingsControl.checkEnableGearSync = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		"Enable equipment sync for all your team members",
		function()
			EMA.db.enableGearSync = not EMA.db.enableGearSync
			EMA:SettingsRefresh()
		end,
		"Broadcast and receive gear snapshots for your EMA team."
	)
	movingTop = movingTop - checkBoxHeight - verticalSpacing

	EMA.settingsControl.checkAutoSync = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		"Enable auto-sync on equip change",
		function()
			EMA.db.autoSyncOnEquipChange = not EMA.db.autoSyncOnEquipChange
			EMA:SettingsRefresh()
		end,
		"Automatically send an updated snapshot when you change equipment."
	)
	movingTop = movingTop - checkBoxHeight - verticalSpacing

	EMA.settingsControl.checkAltClickCompare = EMAHelperSettings:CreateCheckBox(
		EMA.settingsControl,
		headingWidth,
		left,
		movingTop,
		"Enable alt-click compare",
		function()
			EMA.db.enableAltClickCompare = not EMA.db.enableAltClickCompare
			EMA:SettingsRefresh()
		end,
		"Alt-click a cell to show compare tooltip."
	)
	movingTop = movingTop - checkBoxHeight - (verticalSpacing * 2)

	EMA.settingsControl.buttonRefresh = EMAHelperSettings:CreateButton(
		EMA.settingsControl,
		140,
		left,
		movingTop,
		"Refresh"
	)
	EMA.settingsControl.buttonRefresh:SetCallback( "OnClick", function()
		EMA:RequestTeamGearSnapshots()
	end )

	EMA.settingsControl.buttonClearRefresh = EMAHelperSettings:CreateButton(
		EMA.settingsControl,
		160,
		left + 140 + horizontalSpacing,
		movingTop,
		"Clear & Refresh"
	)
	EMA.settingsControl.buttonClearRefresh:SetCallback( "OnClick", function()
		EnsureTeamGearTables()
		EMA.db.teamGear.gearByCharacter = {}
		EMA:RequestTeamGearSnapshots()
		EMA:SettingsRefresh()
	end )

	movingTop = movingTop - buttonHeight - (verticalSpacing * 2)

	-- Grid is created in EnsureUI(); we just reserve space by returning.
	return movingTop
end

local function SettingsCreate()
	EMA.settingsControl = {}
	--EMAHelperSettings:CreateSettings()
	EMA.settingsControl,
	EMA.moduleDisplayName = "TeamGear"
	EMA.parentDisplayName = L["DISPLAY"]
	EMA.SettingsPushSettingsClick,
	--EMA.moduleIcon,
EMA.moduleOrder = 3
	)

	local bottomOfOptions = SettingsCreateOptions( EMAHelperSettings:TopOfSettings() )
	EMA.settingsControl.widgetSettings.content:SetHeight( -bottomOfOptions )

	local helpTable = {}
	EMAHelperSettings:CreateHelp( EMA.settingsControl, helpTable, EMA:GetConfiguration() )
end

function EMA:SettingsRefresh()
	if EMA.settingsControl == nil then
		return
	end
	EnsureTeamGearTables()
	EMA.settingsControl.checkEnableGearSync:SetValue( EMA.db.enableGearSync )
	EMA.settingsControl.checkAutoSync:SetValue( EMA.db.autoSyncOnEquipChange )
	EMA.settingsControl.checkAltClickCompare:SetValue( EMA.db.enableAltClickCompare )
	UpdateGrid()
end

-- ------------------------------------------------------------------------------------------------------------
-- Sync
-- ------------------------------------------------------------------------------------------------------------
function EMA:RefreshLocalGearSnapshot()
	EnsureTeamGearTables()
	local me = EMA.characterName or GetPlayerFullName()
	EMA.db.teamGear.gearByCharacter[me] = GetSnapshot()
end

function EMA:SendLocalGearSnapshot()
	if EMA.db.enableGearSync ~= true then
		return
	end
	EnsureTeamGearTables()
	EMA:RefreshLocalGearSnapshot()
	local me = EMA.characterName or GetPlayerFullName()
	local payload = SnapshotToString( EMA.db.teamGear.gearByCharacter[me] )
	EMA:EMASendCommandToTeam( EMA, EMA.COMMAND_TEAM_GEAR_SNAPSHOT, payload )
end

function EMA:RequestTeamGearSnapshots()
	EMA:EMASendCommandToTeam( EMA, EMA.COMMAND_TEAM_GEAR_SNAPSHOT, "" )
end

function EMA:EMAOnCommandReceived( commandName, sender, ... )
	if commandName ~= EMA.COMMAND_TEAM_GEAR_SNAPSHOT then
		return
	end
	EnsureTeamGearTables()
	local payload = ...
	if payload == nil then
		payload = ""
	end
	if payload == "" then
		EMA:SendLocalGearSnapshot()
		return
	end
	EMA.db.teamGear.gearByCharacter[sender] = StringToSnapshot(payload)
	EMA:SettingsRefresh()
end

function EMA:PLAYER_EQUIPMENT_CHANGED()
	if EMA.db.enableGearSync == true and EMA.db.autoSyncOnEquipChange == true then
		EMA:SendLocalGearSnapshot()
	end
end

-- ------------------------------------------------------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------------------------------------------------------
function EMA:OnInitialize()
	EMA.settings = {}
	EMA.settings.enableGearSync = false
	EMA.settings.autoSyncOnEquipChange = false
	EMA.settings.enableAltClickCompare = false

	EMA.db = EMAApi.GetProfileDB( EMA, EMA.settingsDatabaseName, EMA.settings )
	EnsureTeamGearTables()

	SettingsCreate()

	EMAApi.Command.Add( EMAApi.Command.Normal, EMA.COMMAND_TEAM_GEAR_SNAPSHOT, EMA.moduleName, "Receive gear snapshot/request." )
end

function EMA:OnEnable()
	EMA:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	EMAApi.Command.Register( EMA.moduleName, EMA.CommandReceived )

	EMA:RefreshLocalGearSnapshot()
	EMA:SettingsRefresh()
end

function EMA:OnDisable()
	EMA:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
end

function EMA:CommandReceived( prefix, message, channel, sender )
	EMAApi.Command.Process( EMA, sender, message )
end

function EMA:SettingsPushSettingsClick()
	EMA:SendSettings()
	EMA:SendLocalGearSnapshot()
end

function EMA:SendSettings()
	EMA:EMASendSettings( EMA.settingsDatabaseName, EMA.db )
end

function EMA:ReceiveSettings( characterName, settingsTable )
	EMA.db.enableGearSync = settingsTable.enableGearSync
	EMA.db.autoSyncOnEquipChange = settingsTable.autoSyncOnEquipChange
	EMA.db.enableAltClickCompare = settingsTable.enableAltClickCompare
	EMA:SettingsRefresh()
end

EMA:RegisterChatCommand( EMA.chatCommand, function()
	EMAApi.Settings.Toggle( EMA.moduleDisplayName )
end )
