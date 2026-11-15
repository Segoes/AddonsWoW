local addonName, ns = ...
local L = ns.L

local FISHING_SKILL_ID = 356
local FISHING_SPELL_ID = 7620
local COLOR = "|cff33ccff"

-- LOOT_READY can fire more than once for the same loot window.
local lootHandled = false

local function Print(msg)
    print(COLOR .. addonName .. "|r: " .. msg)
end
ns.Print = Print

local function PrintError(msg)
    Print(RED_FONT_COLOR:WrapTextInColorCode(msg))
end

local function GetFishingSkill()
    local info = C_SkillInfo.GetSkillLineInfoByID(FISHING_SKILL_ID)
    if not info then
        for i = 1, C_SkillInfo.GetNumSkillLines() do
            local line = C_SkillInfo.GetSkillLineInfo(i)
            if line and line.skillID == FISHING_SKILL_ID then
                info = line
                break
            end
        end
    end
    if info and info.maxRank and info.maxRank > 0 then
        return info.rank, info.maxRank, info.modifier or 0
    end
end

local function SkillLine()
    local rank, maxRank, bonus = GetFishingSkill()
    if not rank then return end
    local text = L("FISHING_SKILL"):format(rank, maxRank)
    if bonus ~= 0 then
        text = text .. ("  |cff20ff20(%d)|r"):format(rank + bonus)
    end
    return text, rank, maxRank
end

local function LocalizedName(entry)
    return entry[ns.GetLanguage()] or entry.name
end

local function Highlight(text)
    return "|cffffff00" .. text .. "|r"
end

local WIDTH = 260
local PADDING = 12
local BAR_HEIGHT = 14
-- PortraitFrameTemplate: 21px title bar, and the round portrait covers the top-left 58px.
local TITLE_HEIGHT = 21
local PORTRAIT_WIDTH = 58
local BUTTON_ROW_TOP = 63
local BUTTON_HEIGHT = 22
local LANGUAGE_BUTTON_WIDTH = 36
local BUTTON_GAP = 4
local LURE_ROW_TOP = BUTTON_ROW_TOP + BUTTON_HEIGHT + BUTTON_GAP
local HEIGHT = LURE_ROW_TOP + BUTTON_HEIGHT + PADDING
local SKILL_COLOR = { 0.25, 0.55, 0.95 }

local display = CreateFrame("Frame", "AnglerFrame", UIParent, "PortraitFrameTemplate")
display:SetSize(WIDTH, HEIGHT)
display:SetMovable(true)
display:EnableMouse(true)
display:RegisterForDrag("LeftButton")
display:SetClampedToScreen(true)
display:SetScript("OnDragStart", display.StartMoving)
display:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    AnglerDB.pos = { point, relPoint, x, y }
end)
display:SetTitle(addonName)
display:SetPortraitToAsset("Interface\\AddOns\\" .. addonName .. "\\Media\\Icon")
display.CloseButton:HookScript("OnClick", function()
    AnglerDB.shown = false
end)

local skillBar = CreateFrame("StatusBar", nil, display)
skillBar:SetPoint("TOPLEFT", display, "TOPLEFT", PORTRAIT_WIDTH + 4, -(TITLE_HEIGHT + 10))
skillBar:SetPoint("RIGHT", display, "RIGHT", -PADDING, 0)
skillBar:SetHeight(BAR_HEIGHT)
skillBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
skillBar:SetStatusBarColor(SKILL_COLOR[1], SKILL_COLOR[2], SKILL_COLOR[3])

local skillBarBg = skillBar:CreateTexture(nil, "BACKGROUND")
skillBarBg:SetAllPoints()
skillBarBg:SetColorTexture(0, 0, 0, 0.5)

local skillText = skillBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
skillText:SetPoint("CENTER")

local function UpdateDisplay()
    local text, rank, maxRank = SkillLine()
    if text then
        skillBar:SetMinMaxValues(0, maxRank)
        skillBar:SetValue(rank)
        skillText:SetText(text)
    else
        skillBar:SetMinMaxValues(0, 1)
        skillBar:SetValue(0)
        skillText:SetText(L("NOT_LEARNED"))
    end
end

local function SetWindowShown(shown)
    AnglerDB.shown = shown
    display:SetShown(shown)
end

local MINIMAP_DEFAULT_ANGLE = 200

local minimapIcon = LibStub("LibDBIcon-1.0")
local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
    type = "launcher",
    text = addonName,
    icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon",
    OnClick = function()
        SetWindowShown(not display:IsShown())
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine(addonName)
        local line = SkillLine()
        if line then tooltip:AddLine(line, 1, 1, 1) end
        tooltip:AddLine(L("MINIMAP_CLICK"), 0.7, 0.7, 0.7)
        tooltip:AddLine(L("MINIMAP_DRAG"), 0.7, 0.7, 0.7)
    end,
})

local function UpdateMinimapButton()
    if AnglerDB.minimap.hide then
        minimapIcon:Hide(addonName)
    else
        minimapIcon:Show(addonName)
    end
end

local DEBUG_LOG_MAX = 300

-- Chat text cannot be copied out of the game, so debug output also goes to SavedVariables.
local function DebugLog(line)
    print(line)
    local log = AnglerDB.debugLog
    log[#log + 1] = date("%H:%M:%S ") .. line
    if #log > DEBUG_LOG_MAX then table.remove(log, 1) end
end

local function PlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return ("map=%s pos=nil"):format(tostring(mapID)) end
    return ("map=%d pos=%.4f,%.4f"):format(mapID, pos.x, pos.y)
end

-- Only the mouseover tooltip names a pool, and it gives no position. A catch soon after, near where the pool was
-- hovered, records it in front of the player at a typical cast distance. Each catch keeps the hover alive, so one
-- hover covers a whole fishing session at that pool.
local POOL_HOVER_MEMORY = 180
local POOL_HOVER_RANGE_YARDS = 30
local POOL_CAST_YARDS = 15
local POOL_MERGE_YARDS = 12
-- Shared positions are averages of several reports, so a player's record of the same pool can sit further away.
local SHARED_DUPLICATE_YARDS = 30

local lastPoolHover

local function PlayerMapPoint()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local width, height = C_Map.GetMapWorldSize(mapID)
    if not width or width == 0 or height == 0 then return end
    return mapID, pos.x, pos.y, width, height
end

local function DistanceYards(width, height, x1, y1, x2, y2)
    local dx, dy = (x2 - x1) * width, (y2 - y1) * height
    return math.sqrt(dx * dx + dy * dy)
end

local HBDPins = LibStub("HereBeDragons-Pins-2.0")
local POOL_PIN_SIZE = 14
local POOL_FISH_ICONS = {
    ["Sagefish School"] = 21071,
    ["Greater Sagefish School"] = 21153,
    ["Oily Blackmouth School"] = 6358,
    ["Firefin Snapper School"] = 6359,
    ["Stonescale Eel Swarm"] = 13422,
    ["School of Deviate Fish"] = 6522,
}
local poolPinFrames = {}

local function PoolIcon(kind)
    local fishID = POOL_FISH_ICONS[kind]
    return fishID and C_Item.GetItemIconByID(fishID) or C_Spell.GetSpellTexture(FISHING_SPELL_ID)
end

local function PoolPinOnEnter(self)
    local spot = self.spot
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.PoolLabel(spot.kind, spot.name, ns.GetLanguage()))
    GameTooltip:Show()
end

local function CreatePoolPin()
    local pin = CreateFrame("Frame")
    pin:SetSize(POOL_PIN_SIZE, POOL_PIN_SIZE)
    pin:EnableMouse(true)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin:SetScript("OnEnter", PoolPinOnEnter)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    return pin
end

local function PlacePoolPins(mapID, spot)
    local pins = poolPinFrames[spot]
    if not pins then
        pins = { world = CreatePoolPin(), minimap = CreatePoolPin() }
        poolPinFrames[spot] = pins
    end
    for _, pin in pairs(pins) do
        pin.spot = spot
        pin.icon:SetTexture(PoolIcon(spot.kind))
    end
    HBDPins:AddWorldMapIconMap(addonName, pins.world, mapID, spot.x, spot.y, HBD_PINS_WORLDMAP_SHOW_PARENT)
    HBDPins:AddMinimapIconMap(addonName, pins.minimap, mapID, spot.x, spot.y, true, false)
end

local SHARED_POSITION_SCALE = 10000
local sharedSpots

local function SharedSpots()
    if sharedSpots then return sharedSpots end
    sharedSpots = {}
    for mapID, list in pairs(ns.SHARED_POOLS or {}) do
        local spots = {}
        for _, entry in ipairs(list) do
            spots[#spots + 1] = {
                kind = entry[1],
                x = entry[2] / SHARED_POSITION_SCALE,
                y = entry[3] / SHARED_POSITION_SCALE,
                shared = true,
            }
        end
        sharedSpots[mapID] = spots
    end
    return sharedSpots
end

local function HasPoolNear(spots, mapID, kind, x, y)
    if not spots then return false end
    local width, height = C_Map.GetMapWorldSize(mapID)
    if not width or width == 0 or height == 0 then return false end
    for _, spot in ipairs(spots) do
        if spot.kind == kind and DistanceYards(width, height, spot.x, spot.y, x, y) <= SHARED_DUPLICATE_YARDS then
            return true
        end
    end
    return false
end

-- A shared pool the player has recorded too would show twice; the player's own record wins.
local function IsRecordedByPlayer(mapID, shared)
    return HasPoolNear(AnglerDB.pools[mapID], mapID, shared.kind, shared.x, shared.y)
end

-- Pools already in the shared list reach every player with the next update, so they need no sending.
local function CountUnsentPools()
    local count = 0
    for mapID, spots in pairs(AnglerDB.pools) do
        for _, spot in ipairs(spots) do
            if not spot.sent and not HasPoolNear(SharedSpots()[mapID], mapID, spot.kind, spot.x, spot.y) then
                count = count + 1
            end
        end
    end
    return count
end

function ns.MarkPoolsSent()
    for _, spots in pairs(AnglerDB.pools) do
        for _, spot in ipairs(spots) do
            spot.sent = true
        end
    end
end

local function UpdatePoolPins()
    HBDPins:RemoveAllWorldMapIcons(addonName)
    HBDPins:RemoveAllMinimapIcons(addonName)
    if not AnglerDB.showPools then return end
    for mapID, spots in pairs(AnglerDB.pools) do
        for _, spot in ipairs(spots) do
            PlacePoolPins(mapID, spot)
        end
    end
    for mapID, spots in pairs(SharedSpots()) do
        for _, spot in ipairs(spots) do
            if not IsRecordedByPlayer(mapID, spot) then
                PlacePoolPins(mapID, spot)
            end
        end
    end
end

local function StorePool(kind, name, mapID, x, y, width, height)
    local spots = AnglerDB.pools[mapID] or {}
    AnglerDB.pools[mapID] = spots
    for _, spot in ipairs(spots) do
        if spot.kind == kind and DistanceYards(width, height, spot.x, spot.y, x, y) <= POOL_MERGE_YARDS then
            spot.seen = spot.seen + 1
            spot.name = name or spot.name
            return spot, false
        end
    end
    local spot = { kind = kind, name = name, x = x, y = y, seen = 1, precise = true }
    spots[#spots + 1] = spot
    UpdatePoolPins()
    return spot, true
end

local function RecordPoolHover(name)
    local kind = ns.PoolKey(name)
    if not kind then return end
    local mapID, x, y = PlayerMapPoint()
    if not mapID then return end
    lastPoolHover = { kind = kind, name = name, mapID = mapID, x = x, y = y, time = GetTime() }
end

local function RecordPoolCatch()
    local last = lastPoolHover
    if not last or GetTime() - last.time > POOL_HOVER_MEMORY then return end
    local mapID, x, y, width, height = PlayerMapPoint()
    local facing = GetPlayerFacing()
    if mapID ~= last.mapID or not facing then return end
    if DistanceYards(width, height, last.x, last.y, x, y) > POOL_HOVER_RANGE_YARDS then return end
    -- Facing is radians counter-clockwise from north; map x grows east and y grows south.
    local poolX = x - math.sin(facing) * POOL_CAST_YARDS / width
    local poolY = y - math.cos(facing) * POOL_CAST_YARDS / height
    local _, isNew = StorePool(last.kind, last.name, mapID, poolX, poolY, width, height)
    last.time = GetTime()
    if isNew then
        Print(L("POOL_NEW"):format(Highlight(ns.PoolLabel(last.kind, last.name, ns.GetLanguage()))))
    end
end

local function DebugLoot(event)
    DebugLog(("[debug] %s  fishing=%s  slots=%d  %s"):format(event, tostring(IsFishingLoot()), GetNumLootItems(),
        PlayerPosition()))
    for slot = 1, GetNumLootItems() do
        local _, name, quantity = GetLootSlotInfo(slot)
        local link = GetLootSlotLink(slot)
        DebugLog(("   slot %d: %s x%s  link=%s"):format(slot, tostring(name), tostring(quantity),
            link and link:gsub("|", "||") or "nil"))
    end
end

local function OnLoot(event)
    if AnglerDB.debug then DebugLoot(event) end
    if lootHandled or not IsFishingLoot() then return end
    lootHandled = true
    RecordPoolCatch()
end

-- Recasting takes a few seconds; restoring in between would make the music flicker.
local SOUND_RESTORE_DELAY = 15
local FISHING_SOUND = {
    Sound_SFXVolume = "1",
    Sound_MusicVolume = "0",
    Sound_AmbienceVolume = "0",
}
local FISHING_MIN_MASTER_VOLUME = 0.6

local restoreTimer

local function IsFishingSpell(spellID)
    local name = spellID and C_Spell.GetSpellName(spellID)
    return name ~= nil and name == C_Spell.GetSpellName(FISHING_SPELL_ID)
end

-- The game reports why a cast failed only as a UI error, which is not tied to a spell, so errors are
-- linked to fishing by timing: from the cast until shortly after the line comes back.
local FISHING_ERROR_SECONDS = 1
local fishingErrorsUntil = 0

-- Game errors come in the client language, which can differ from the addon language. The message is matched
-- against the client's own error strings and replaced by the official text in the addon language.
local errorTexts, errorPatterns

local function FormatToPattern(format)
    local pattern = format:gsub("%%%%", "\1"):gsub("%%[%d%$]*[%-%.%d]*([sdif])", function(kind)
        return kind == "s" and "\2" or "\3"
    end)
    pattern = pattern:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    pattern = pattern:gsub("\1", "%%%%"):gsub("\2", "(.-)"):gsub("\3", "([%%d%%.,%%-]+)")
    return "^" .. pattern .. "$"
end

local function IndexErrors()
    errorTexts, errorPatterns = {}, {}
    for tag, texts in pairs(ns.ERROR_STRINGS) do
        local own = _G[tag]
        if type(own) == "string" and own ~= "" then
            local literal = own:gsub("%%[%d%$]*[%-%.%d]*[sdif%%]", "")
            if #literal < #own then
                -- A string that is little more than "%s" would match any message.
                if #literal >= 4 then
                    errorPatterns[#errorPatterns + 1] = { FormatToPattern(own), texts, tag, #literal }
                end
            else
                errorTexts[own] = { texts, tag }
            end
        end
    end
    table.sort(errorPatterns, function(a, b) return a[4] > b[4] end)
end

local function TranslateError(message)
    if not errorTexts then IndexErrors() end
    local language = ns.LanguageIndex()
    local exact = errorTexts[message]
    if exact then return exact[1][language], exact[2] end
    for _, entry in ipairs(errorPatterns) do
        local captures = { message:match(entry[1]) }
        if #captures > 0 then
            local ok, text = pcall(string.format, entry[2][language], unpack(captures))
            if ok then return text, entry[3] end
        end
    end
    return message
end

local function ReportFishingError(message)
    if GetTime() > fishingErrorsUntil or type(message) ~= "string" or issecretvalue(message) then return end
    local text, tag = TranslateError(message)
    if tag == "SPELL_FAILED_LOW_CASTLEVEL" then
        text = text:gsub("[%.!]?%s*$", ". ", 1) .. L("FISH_SKILL_HINT")
    end
    PrintError(text)
end

-- Originals live in SavedVariables so a crash mid-fishing can be undone on the next login.
local function RestoreSound()
    if restoreTimer then
        restoreTimer:Cancel()
        restoreTimer = nil
    end
    local saved = AnglerDB.soundSaved
    if not saved then return end
    for name, value in pairs(saved) do
        C_CVar.SetCVar(name, value)
    end
    AnglerDB.soundSaved = nil
end

local function BoostSound()
    if restoreTimer then
        restoreTimer:Cancel()
        restoreTimer = nil
    end
    if AnglerDB.soundSaved then return end

    local saved = { Sound_MasterVolume = C_CVar.GetCVar("Sound_MasterVolume") }
    for name in pairs(FISHING_SOUND) do
        saved[name] = C_CVar.GetCVar(name)
    end
    AnglerDB.soundSaved = saved

    for name, value in pairs(FISHING_SOUND) do
        C_CVar.SetCVar(name, value)
    end
    if (tonumber(saved.Sound_MasterVolume) or 0) < FISHING_MIN_MASTER_VOLUME then
        C_CVar.SetCVar("Sound_MasterVolume", tostring(FISHING_MIN_MASTER_VOLUME))
    end
end

local function ScheduleSoundRestore()
    if not AnglerDB.soundSaved then return end
    if restoreTimer then restoreTimer:Cancel() end
    restoreTimer = C_Timer.NewTimer(SOUND_RESTORE_DELAY, RestoreSound)
end

local castButton = CreateFrame("Button", "AnglerCastButton", UIParent, "SecureActionButtonTemplate")
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")
castButton:HookScript("OnClick", function(self, button, down)
    if AnglerDB.debug then
        DebugLog(("[debug] castButton click button=%s down=%s spell=%s"):format(
            tostring(button), tostring(down), tostring(self:GetAttribute("spell"))))
    end
end)

local DIAGNOSTIC_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UI_ERROR_MESSAGE",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_START", "PLAYER_SOFT_INTERACT_CHANGED" }

local diagnostics = CreateFrame("Frame")

-- UNIT_SPELLCAST_START fires for every unit nearby, so these events are only listened to while debugging.
local function UpdateDiagnostics()
    for _, event in ipairs(DIAGNOSTIC_EVENTS) do
        if AnglerDB.debug then
            diagnostics:RegisterEvent(event)
        else
            diagnostics:UnregisterEvent(event)
        end
    end
end

diagnostics:SetScript("OnEvent", function(_, event, ...)
    local args = {}
    -- Spell casts by other units carry secret values, which cannot be turned into text.
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        args[#args + 1] = issecretvalue(value) and "<secret>" or tostring(value)
    end
    if event == "PLAYER_SOFT_INTERACT_CHANGED" then
        args[#args + 1] = "name=" .. tostring(UnitName("softinteract"))
    elseif event == "UNIT_SPELLCAST_SENT" then
        args[#args + 1] = PlayerPosition()
    end
    DebugLog(("[debug] %s %s"):format(event, table.concat(args, " ")))
end)

-- World objects such as fishing pools only reveal their name through the mouseover tooltip.
GameTooltip:HookScript("OnShow", function(self)
    if not AnglerDB or self:GetUnit() or self:GetOwner() ~= UIParent then return end
    local first = _G[self:GetName() .. "TextLeft1"]
    local text = first and first:GetText()
    if not text or issecretvalue(text) then return end
    if AnglerDB.debug then
        DebugLog(("[debug] tooltip %q  %s"):format(text, PlayerPosition()))
    end
    RecordPoolHover(text)
end)

local keyMode
local pendingKeyMode, hasPendingKeyMode = nil, false

local function IsFishingPole(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon and subClassID == Enum.ItemWeaponSubclass.Fishingpole
end

local function HasFishingPole()
    return IsFishingPole(GetInventoryItemID("player", INVSLOT_MAINHAND))
end

local function FindInBags(matches)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and matches(itemID) then return itemID, bag, slot end
        end
    end
end

local function FindPoleInBags()
    return (FindInBags(IsFishingPole))
end

-- Equipping the main hand first frees the off-hand slot, so the off-hand waits for that change.
local pendingOffHand

local function CreatePanelButton()
    local button = CreateFrame("Button", nil, display, "UIPanelButtonTemplate")
    button:SetHeight(BUTTON_HEIGHT)
    button:SetNormalFontObject(GameFontNormal)
    button:SetDisabledFontObject(GameFontDisable)
    button:SetHighlightFontObject(GameFontHighlight)
    button:SetMotionScriptsWhileDisabled(true)
    return button
end

local equipButton = CreatePanelButton()
equipButton:SetPoint("TOPLEFT", display, "TOPLEFT", PADDING, -BUTTON_ROW_TOP)
-- The equip and key buttons split the row left of the narrow language button.
local ROW_CENTER_SHIFT = (LANGUAGE_BUTTON_WIDTH + BUTTON_GAP) / 2
equipButton:SetPoint("TOPRIGHT", display, "TOP", -ROW_CENTER_SHIFT - BUTTON_GAP / 2, -BUTTON_ROW_TOP)

local function UpdateEquipButton()
    if HasFishingPole() then
        equipButton:SetText(L("SWAP_BACK"))
        local saved = AnglerCharDB.weapons
        equipButton:SetEnabled(saved ~= nil and (saved.main ~= nil or saved.off ~= nil))
    else
        equipButton:SetText(L("EQUIP_POLE"))
        equipButton:SetEnabled(FindPoleInBags() ~= nil)
    end
end

equipButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        Print(L("NO_SWAP_IN_COMBAT"))
        return
    end
    if HasFishingPole() then
        local saved = AnglerCharDB.weapons
        if not saved then return end
        if saved.main then
            pendingOffHand = saved.off
            C_Item.EquipItemByName(saved.main, INVSLOT_MAINHAND)
        elseif saved.off then
            C_Item.EquipItemByName(saved.off, INVSLOT_OFFHAND)
        end
        AnglerCharDB.weapons = nil
    else
        local pole = FindPoleInBags()
        if not pole then return end
        AnglerCharDB.weapons = {
            main = GetInventoryItemID("player", INVSLOT_MAINHAND),
            off = GetInventoryItemID("player", INVSLOT_OFFHAND),
        }
        C_Item.EquipItemByName(pole, INVSLOT_MAINHAND)
    end
end)

equipButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if HasFishingPole() then
        GameTooltip:SetText(L("TIP_SWAP"))
    elseif self:IsEnabled() then
        GameTooltip:SetText(L("TIP_EQUIP"))
    else
        GameTooltip:SetText(L("TIP_NO_POLE"))
    end
    GameTooltip:Show()
end)
equipButton:SetScript("OnLeave", GameTooltip_Hide)

-- One key casts; while the line is out the same key reels in through the soft-interact target.
-- Without a pole equipped the key keeps its normal binding.
local function SetKeyMode(mode)
    local key = AnglerDB.key
    local requested = mode
    if mode == "cast" and not HasFishingPole() then
        mode = nil
    end
    if AnglerDB.debug then
        local itemID = GetInventoryItemID("player", INVSLOT_MAINHAND)
        DebugLog(("[debug] SetKeyMode requested=%s applied=%s key=%s slot=%s item=%s pole=%s combat=%s"):format(
            tostring(requested), tostring(mode), tostring(key), tostring(INVSLOT_MAINHAND), tostring(itemID),
            tostring(HasFishingPole()), tostring(InCombatLockdown())))
    end
    if InCombatLockdown() then
        pendingKeyMode, hasPendingKeyMode = mode, true
        return
    end
    pendingKeyMode, hasPendingKeyMode = nil, false
    ClearOverrideBindings(castButton)
    keyMode = nil
    if not key or not mode then return end

    if mode == "reel" then
        SetOverrideBinding(castButton, true, key, "INTERACTTARGET")
    else
        castButton:SetAttribute("spell", C_Spell.GetSpellName(FISHING_SPELL_ID))
        SetOverrideBindingClick(castButton, true, key, "AnglerCastButton")
    end
    keyMode = mode
    if AnglerDB.debug then
        DebugLog(("[debug] binding %s -> %s"):format(key, tostring(GetBindingAction(key, true))))
    end
end

local function SoftInteractReady()
    return tonumber(C_CVar.GetCVar("SoftTargetInteract")) == 3
        and (tonumber(C_CVar.GetCVar("SoftTargetInteractRange")) or 0) >= 30
end

-- These CVars are listed as protected; try anyway and fall back to /console instructions.
local function ReportSoftInteract()
    if SoftInteractReady() then return end
    if not InCombatLockdown() then
        pcall(C_CVar.SetCVar, "SoftTargetInteract", "3")
        pcall(C_CVar.SetCVar, "SoftTargetInteractRange", "30")
        if SoftInteractReady() then
            Print(L("SOFT_AUTO"))
            return
        end
    end
    Print(L("SOFT_MANUAL"))
    print("   |cffffff00/console SoftTargetInteract 3|r")
    print("   |cffffff00/console SoftTargetInteractRange 30|r")
end

local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true,
}

local keyButton = CreatePanelButton()
keyButton:SetPoint("TOPLEFT", display, "TOP", -ROW_CENTER_SHIFT + BUTTON_GAP / 2, -BUTTON_ROW_TOP)
keyButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", -(PADDING + LANGUAGE_BUTTON_WIDTH + BUTTON_GAP), -BUTTON_ROW_TOP)
keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local function UpdateKeyButton()
    if keyButton.listening then
        keyButton:SetText(L("PRESS_KEY"))
    else
        keyButton:SetText(AnglerDB.key and L("KEY_LABEL"):format(AnglerDB.key) or L("SET_KEY"))
    end
end

local function SetFishingKey(key)
    if InCombatLockdown() then
        Print(L("NO_KEY_IN_COMBAT"))
        return
    end
    SetKeyMode(nil)
    AnglerDB.key = key
    UpdateKeyButton()
    if not key then
        Print(L("KEY_REMOVED"))
        return
    end
    SetKeyMode("cast")
    Print(L("KEY_SET"):format(Highlight(key)))
    ReportSoftInteract()
end

local LISTEN_TIMEOUT = 10

-- Taking over a movement key would leave the player unable to walk while a pole is equipped.
local MOVEMENT_ACTIONS = {
    MOVEFORWARD = true, MOVEBACKWARD = true, TURNLEFT = true, TURNRIGHT = true,
    STRAFELEFT = true, STRAFERIGHT = true, JUMP = true, TOGGLEAUTORUN = true,
}

local listenTimer

local function StopListening()
    if listenTimer then
        listenTimer:Cancel()
        listenTimer = nil
    end
    keyButton.listening = false
    keyButton:SetScript("OnKeyDown", nil)
    keyButton:EnableKeyboard(false)
    UpdateKeyButton()
end

local function CaptureKey(_, key)
    if MODIFIER_KEYS[key] then return end
    StopListening()
    if key == "ESCAPE" then return end
    local modifiers = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "")
    local combo = modifiers .. key
    if MOVEMENT_ACTIONS[GetBindingAction(combo)] then
        Print(L("MOVEMENT_KEY"):format(Highlight(combo), Highlight(AnglerDB.key or L("KEY_UNSET"))))
        return
    end
    SetFishingKey(combo)
end

keyButton:SetScript("OnClick", function(self, button)
    if self.listening then
        StopListening()
    elseif button == "RightButton" then
        if AnglerDB.key then SetFishingKey(nil) end
    elseif InCombatLockdown() then
        Print(L("NO_KEY_IN_COMBAT"))
    else
        self.listening = true
        -- Setting an OnKeyDown script turns keyboard input on by itself, so the handler only exists while listening.
        self:SetScript("OnKeyDown", CaptureKey)
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)
        listenTimer = C_Timer.NewTimer(LISTEN_TIMEOUT, StopListening)
        UpdateKeyButton()
    end
end)

keyButton:SetScript("OnHide", StopListening)

keyButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("KEY_TIP_TITLE"))
    GameTooltip:AddLine(L("KEY_TIP_USE"), 1, 1, 1, true)
    GameTooltip:AddLine(L("KEY_TIP_SET"), 0.7, 0.7, 0.7, true)
    if AnglerDB.key then
        GameTooltip:AddLine(L("KEY_TIP_REMOVE"), 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end)
keyButton:SetScript("OnLeave", GameTooltip_Hide)

local languageButton = CreatePanelButton()
languageButton:SetWidth(LANGUAGE_BUTTON_WIDTH)
languageButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", -PADDING, -BUTTON_ROW_TOP)

local function UpdateLanguageButton()
    languageButton:SetText(ns.LanguageInfo(ns.GetLanguage()).short)
end

languageButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("LANGUAGE"))
    GameTooltip:AddLine(L("LANGUAGE_TIP"), 1, 1, 1, true)
    GameTooltip:Show()
end)
languageButton:SetScript("OnLeave", GameTooltip_Hide)

local function FindLure()
    local rank, _, bonus = GetFishingSkill()
    if not rank then return end
    local baseRank = rank - math.max(bonus, 0)
    for _, lure in ipairs(ns.LURES) do
        local count = C_Item.GetItemCount(lure.id)
        if count > 0 and baseRank >= lure.skill then
            return lure, count
        end
    end
end

local function LureTimeLeftMs()
    for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand) or {}) do
        if enchant.hasEnchant and enchant.timeLeft then
            return enchant.timeLeft
        end
    end
end

local function LureMinutesLeft()
    local ms = LureTimeLeftMs()
    return ms and math.ceil(ms / 60000)
end

local lureButton = CreatePanelButton()
lureButton:SetPoint("TOPLEFT", display, "TOPLEFT", PADDING, -LURE_ROW_TOP)
lureButton:SetPoint("TOPRIGHT", display, "TOPRIGHT", -PADDING, -LURE_ROW_TOP)

-- Using an item on the pole is protected, so a secure button takes the click. It lives on UIParent and is
-- only placed over lureButton while hovered out of combat; as a child of the window it would make the
-- window itself protected, and moving, resizing or closing it in combat would be blocked.
local lureSecure = CreateFrame("Button", "AnglerLureButton", UIParent, "SecureActionButtonTemplate")
-- With ActionButtonUseKeyDown the template acts on the press, so both press and release must reach it.
lureSecure:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
lureSecure:SetAttribute("type", "item")
lureSecure:SetAttribute("target-slot", INVSLOT_MAINHAND)
lureSecure:SetFrameStrata("DIALOG")
lureSecure:Hide()

local lureGlow = lureButton:CreateTexture(nil, "OVERLAY")
lureGlow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
lureGlow:SetTexCoord(0, 0.625, 0, 0.6875)
lureGlow:SetBlendMode("ADD")
lureGlow:SetAllPoints()
lureGlow:Hide()

local lurePulse = lureGlow:CreateAnimationGroup()
lurePulse:SetLooping("BOUNCE")
local lurePulseAlpha = lurePulse:CreateAnimation("Alpha")
lurePulseAlpha:SetFromAlpha(0.15)
lurePulseAlpha:SetToAlpha(1)
lurePulseAlpha:SetDuration(0.8)
lurePulseAlpha:SetSmoothing("IN_OUT")

local lureExpiryTimer

local function UpdateLureButton()
    local lure, count = FindLure()
    local hasPole = HasFishingPole()
    lureButton:SetText(count and ("%s (%d)"):format(L("APPLY_LURE"), count) or L("APPLY_LURE"))
    lureButton:SetEnabled(lure ~= nil and hasPole)

    local timeLeft = hasPole and LureTimeLeftMs()
    local glow = lureButton:IsEnabled() and not timeLeft
    lureGlow:SetShown(glow)
    if glow and not lurePulse:IsPlaying() then
        lurePulse:Play()
    elseif not glow then
        lurePulse:Stop()
    end

    -- An expiring lure is not reliably announced by an event, so check again once it should be gone.
    if lureExpiryTimer then lureExpiryTimer:Cancel() end
    lureExpiryTimer = timeLeft and C_Timer.NewTimer(timeLeft / 1000 + 1, UpdateLureButton) or nil
end

local function ShowLureTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("APPLY_LURE"))
    local lure, count = FindLure()
    if not HasFishingPole() then
        GameTooltip:AddLine(L("TIP_LURE_NEEDS_POLE"), 1, 1, 1, true)
    elseif not lure then
        GameTooltip:AddLine(L("TIP_NO_LURE"), 1, 1, 1, true)
    else
        GameTooltip:AddLine(L("TIP_LURE"):format(Highlight(LocalizedName(lure)), count), 1, 1, 1, true)
    end
    local minutes = HasFishingPole() and LureMinutesLeft()
    if minutes then
        GameTooltip:AddLine(L("LURE_ACTIVE"):format(minutes), 0.2, 1, 0.2, true)
    end
    GameTooltip:Show()
end

local function HideLureSecure()
    if not InCombatLockdown() then
        lureSecure:Hide()
        lureSecure:ClearAllPoints()
    end
end

lureButton:SetScript("OnEnter", function(self)
    if self:IsEnabled() and not InCombatLockdown() then
        local lureID = FindLure().id
        local _, bag, slot = FindInBags(function(itemID) return itemID == lureID end)
        lureSecure:SetAttribute("item", bag and ("%d %d"):format(bag, slot))
        -- Matching scales lets the button's own rectangle be reused as offsets from the screen corner.
        lureSecure:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
        local left, bottom, width, height = self:GetRect()
        lureSecure:ClearAllPoints()
        lureSecure:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        lureSecure:SetSize(width, height)
        lureSecure:Show()
    end
    ShowLureTooltip(self)
end)
lureButton:SetScript("OnLeave", GameTooltip_Hide)
lureButton:SetScript("OnClick", function()
    if InCombatLockdown() then Print(L("NO_LURE_IN_COMBAT")) end
end)

lureSecure:SetScript("OnEnter", function(self)
    lureButton:LockHighlight()
    ShowLureTooltip(self)
end)
lureSecure:SetScript("OnLeave", function()
    lureButton:UnlockHighlight()
    GameTooltip:Hide()
    HideLureSecure()
end)
lureSecure:SetScript("OnMouseDown", function()
    lureButton:SetButtonState("PUSHED")
end)
lureSecure:SetScript("OnMouseUp", function()
    lureButton:SetButtonState("NORMAL")
end)
display:HookScript("OnHide", HideLureSecure)

local function CheckSkillUp()
    UpdateDisplay()
    local rank, maxRank = GetFishingSkill()
    if not rank then return end

    local last = AnglerDB.lastRank
    if last and rank > last then
        local msg = L("SKILL_UP"):format(rank, maxRank)
        Print("|cff00ff00" .. msg .. "|r")
        UIErrorsFrame:AddMessage(msg, 0.2, 0.8, 1.0)
        PlaySound(SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 or 888)
    end
    AnglerDB.lastRank = rank
end

-- Once a day at most, and late enough after login not to drown in the other addons' login messages.
local SHARE_REMINDER_DELAY = 15
local SHARE_REMINDER_INTERVAL = 24 * 60 * 60

local function RemindToShare()
    if not AnglerDB.reminder or time() - (AnglerDB.lastReminder or 0) < SHARE_REMINDER_INTERVAL then return end
    local count = CountUnsentPools()
    if count == 0 then return end
    AnglerDB.lastReminder = time()
    Print(L("REMINDER_TEXT"):format(count, Highlight("/angler export")))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("UNIT_SPELLCAST_SENT")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("UI_ERROR_MESSAGE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("BAG_UPDATE_DELAYED")

events:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == addonName then
        AnglerDB = AnglerDB or {}
        if AnglerDB.shown == nil then AnglerDB.shown = true end
        if AnglerDB.sound == nil then AnglerDB.sound = true end
        -- The log is kept until the next load after debugging stops, so it can still be read from disk.
        if not AnglerDB.debug or not AnglerDB.debugLog then AnglerDB.debugLog = {} end
        UpdateDiagnostics()
        AnglerDB.pools = AnglerDB.pools or {}
        -- Earlier versions also saved pools on hover alone, at the player's position; only catches are kept.
        for mapID, spots in pairs(AnglerDB.pools) do
            for i = #spots, 1, -1 do
                if not spots[i].precise then table.remove(spots, i) end
            end
            if #spots == 0 then AnglerDB.pools[mapID] = nil end
        end
        if AnglerDB.showPools == nil then AnglerDB.showPools = true end
        if AnglerDB.reminder == nil then AnglerDB.reminder = true end
        AnglerDB.minimap = AnglerDB.minimap or { minimapPos = MINIMAP_DEFAULT_ANGLE }
        minimapIcon:Register(addonName, launcher, AnglerDB.minimap)
        AnglerCharDB = AnglerCharDB or {}
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        display:ClearAllPoints()
        local p = AnglerDB.pos
        if p then
            display:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        else
            display:SetPoint("TOP", UIParent, "TOP", 0, -120)
        end
        display:SetShown(AnglerDB.shown)
        UpdateLanguageButton()
        UpdateEquipButton()
        UpdateKeyButton()
        UpdateLureButton()
        UpdatePoolPins()
        CheckSkillUp()
        Print(L("LOADED"):format(Highlight("/angler help")))
        C_Timer.After(SHARE_REMINDER_DELAY, RemindToShare)
        RestoreSound()
        if AnglerDB.key then
            SetKeyMode("cast")
            ReportSoftInteract()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if hasPendingKeyMode then SetKeyMode(pendingKeyMode) end

    -- Fires just before the combat lockdown starts, the last moment the secure lure button can be hidden.
    elseif event == "PLAYER_REGEN_DISABLED" then
        HideLureSecure()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == INVSLOT_MAINHAND and AnglerDB.key and keyMode ~= "reel" then
            SetKeyMode("cast")
        end
        if arg1 == INVSLOT_MAINHAND and pendingOffHand and not InCombatLockdown() then
            C_Item.EquipItemByName(pendingOffHand, INVSLOT_OFFHAND)
            pendingOffHand = nil
        end
        UpdateDisplay()
        UpdateEquipButton()
        UpdateLureButton()

    elseif event == "BAG_UPDATE_DELAYED" then
        UpdateEquipButton()
        UpdateLureButton()

    -- Lures are weapon enchants; they change the skill bonus without an equipment change.
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            UpdateDisplay()
            UpdateLureButton()
        end

    elseif event == "UNIT_SPELLCAST_SENT" then
        if arg1 == "player" and IsFishingSpell(arg4) then
            fishingErrorsUntil = GetTime() + FISHING_ERROR_SECONDS
        end

    elseif event == "UI_ERROR_MESSAGE" then
        ReportFishingError(arg2)

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if AnglerDB.debug and arg1 == "player" then
            DebugLog(("[debug] CHANNEL_START spell=%s name=%s fishingName=%s sound=%s"):format(
                tostring(arg3), tostring(arg3 and C_Spell.GetSpellName(arg3)),
                tostring(C_Spell.GetSpellName(FISHING_SPELL_ID)), tostring(AnglerDB.sound)))
        end
        if arg1 == "player" and IsFishingSpell(arg3) then
            fishingErrorsUntil = math.huge
            if AnglerDB.sound then BoostSound() end
            if AnglerDB.key then SetKeyMode("reel") end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if AnglerDB.debug and arg1 == "player" then
            DebugLog(("[debug] CHANNEL_STOP spell=%s saved=%s"):format(tostring(arg3), tostring(AnglerDB.soundSaved ~= nil)))
        end
        if arg1 == "player" and IsFishingSpell(arg3) then
            fishingErrorsUntil = GetTime() + FISHING_ERROR_SECONDS
            ScheduleSoundRestore()
            if AnglerDB.key then SetKeyMode("cast") end
        end

    elseif event == "PLAYER_LOGOUT" then
        RestoreSound()

    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        OnLoot(event)

    elseif event == "LOOT_CLOSED" then
        lootHandled = false

    elseif event == "SKILL_LINES_CHANGED" then
        CheckSkillUp()
        UpdateLureButton()
    end
end)

local function OnOff(enabled)
    return enabled and L("ON") or L("OFF")
end

local TOGGLES = {
    sound = {
        strings = "SOUND",
        get = function() return AnglerDB.sound end,
        set = function(enabled)
            AnglerDB.sound = enabled
            if not enabled then RestoreSound() end
        end,
    },
    minimap = {
        strings = "MINIMAP",
        get = function() return not AnglerDB.minimap.hide end,
        set = function(enabled)
            AnglerDB.minimap.hide = not enabled
            UpdateMinimapButton()
        end,
    },
    pools = {
        strings = "POOLS",
        get = function() return AnglerDB.showPools end,
        set = function(enabled)
            AnglerDB.showPools = enabled
            UpdatePoolPins()
        end,
    },
    reminder = {
        strings = "REMINDER",
        get = function() return AnglerDB.reminder end,
        set = function(enabled) AnglerDB.reminder = enabled end,
    },
    debug = {
        strings = "DEBUG",
        get = function() return AnglerDB.debug end,
        set = function(enabled)
            AnglerDB.debug = enabled
            if enabled then AnglerDB.debugLog = {} end
            UpdateDiagnostics()
        end,
    },
}
local MENU_TOGGLES = { "sound", "minimap", "pools", "reminder" }

local function SetToggle(name, enabled)
    local toggle = TOGGLES[name]
    toggle.set(enabled)
    Print(L(toggle.strings .. "_STATE"):format(OnOff(enabled)))
end

local function ReportToggle(name)
    local toggle = TOGGLES[name]
    Print(L(toggle.strings .. "_IS"):format(OnOff(toggle.get()),
        Highlight(("/angler %s on"):format(name)), Highlight(("/angler %s off"):format(name))))
end

local function SetLanguage(code)
    AnglerDB.language = code
    UpdateLanguageButton()
    UpdateDisplay()
    UpdateEquipButton()
    UpdateKeyButton()
    UpdateLureButton()
    Print(L("LANGUAGE_SET"):format(ns.LanguageInfo(code).label))
end

languageButton:SetScript("OnClick", function(self)
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(L("LANGUAGE"))
        for _, language in ipairs(ns.LANGUAGES) do
            root:CreateRadio(language.label,
                function() return ns.GetLanguage() == language.code end,
                function() SetLanguage(language.code) end)
        end
    end)
end)

local optionsButton = CreateFrame("DropdownButton", nil, display, "UIPanelIconDropdownButtonTemplate")
optionsButton:SetPoint("RIGHT", display.CloseButton, "LEFT", -2, 0)
-- The template's title bar art sits on a raised child frame and would cover a default-level button.
optionsButton:SetFrameLevel(display.CloseButton:GetFrameLevel())
optionsButton:SetupMenu(function(_, root)
    -- SetupMenu builds the menu once at load, before SavedVariables exist; it is rebuilt on every open.
    if not AnglerDB then return end
    root:CreateTitle(addonName)
    for _, name in ipairs(MENU_TOGGLES) do
        local toggle = TOGGLES[name]
        root:CreateCheckbox(L("MENU_" .. toggle.strings), toggle.get,
            function() SetToggle(name, not toggle.get()) end)
    end
    root:CreateButton(L("MENU_EXPORT"), function() ns.ShowExport() end)

    root:CreateDivider()
    root:CreateButton(AnglerDB.key and L("MENU_CHANGE_KEY"):format(AnglerDB.key) or L("MENU_SET_KEY"), function()
        keyButton:Click("LeftButton")
    end)
    root:CreateButton(L("MENU_REMOVE_KEY"), function() SetFishingKey(nil) end):SetEnabled(AnglerDB.key ~= nil)
end)

SLASH_ANGLER1 = "/angler"
SlashCmdList.ANGLER = function(msg)
    msg = strlower(strtrim(msg or ""))
    local keyArg = msg:match("^key%s+(%S+)$")
    local languageArg = msg:match("^language%s+(%a+)$")
    local toggleName, toggleArg = msg:match("^(%a+)%s*(%a*)$")
    if not TOGGLES[toggleName] then toggleName = nil end
    if msg == "key" then
        Print(AnglerDB.key and L("KEY_IS"):format(Highlight(AnglerDB.key))
            or L("KEY_NONE"):format(Highlight("/angler key F"), Highlight("/angler key off")))
    elseif keyArg == "off" then
        SetFishingKey(nil)
    elseif keyArg then
        SetFishingKey(strupper(keyArg))
    elseif msg == "show" or msg == "hide" then
        SetWindowShown(msg == "show")
    elseif toggleName and (toggleArg == "on" or toggleArg == "off") then
        SetToggle(toggleName, toggleArg == "on")
    elseif toggleName and toggleArg == "" then
        ReportToggle(toggleName)
    elseif msg == "export" then
        ns.ShowExport()
    elseif languageArg and ns.LanguageByShort(languageArg) then
        SetLanguage(ns.LanguageByShort(languageArg).code)
    elseif msg == "language" or languageArg then
        Print(L("LANGUAGE_IS"):format(ns.LanguageInfo(ns.GetLanguage()).label,
            Highlight("/angler language " .. ns.LanguageShortList())))
    else
        Print(L("COMMANDS"))
        local help = {
            { "/angler show", "HELP_SHOW" },
            { "/angler hide", "HELP_HIDE" },
            { "/angler minimap on|off", "HELP_MINIMAP" },
            { "/angler pools on|off", "HELP_POOLS" },
            { "/angler export", "HELP_EXPORT" },
            { "/angler reminder on|off", "HELP_REMINDER" },
            { "/angler sound on|off", "HELP_SOUND" },
            { "/angler key F|off", "HELP_KEY" },
            { "/angler language " .. ns.LanguageShortList(), "HELP_LANGUAGE" },
        }
        for _, line in ipairs(help) do
            print(("   %s - %s"):format(line[1], L(line[2])))
        end
    end
end
