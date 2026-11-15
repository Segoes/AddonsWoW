local _, ns = ...
local L = ns.L

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local PREFIX = "ANGLER1:"
local FORMAT_VERSION = 1
-- Positions travel as integers to keep the string short; four decimals are under a yard on any zone map.
local POSITION_SCALE = 10000
local MAX_KIND_LENGTH = 64
local FORM_URL = "https://forms.gle/DGs2jQ9yjPVqo3jp6"

local function EncodePools()
    local maps, count = {}, 0
    for mapID, spots in pairs(AnglerDB.pools) do
        local list = {}
        for _, spot in ipairs(spots) do
            list[#list + 1] = {
                spot.kind,
                math.floor(spot.x * POSITION_SCALE + 0.5),
                math.floor(spot.y * POSITION_SCALE + 0.5),
                1,
            }
        end
        if #list > 0 then
            maps[mapID] = list
            count = count + #list
        end
    end
    local payload = { v = FORMAT_VERSION, pools = maps }
    local compressed = LibDeflate:CompressDeflate(LibSerialize:Serialize(payload), { level = 9 })
    return PREFIX .. LibDeflate:EncodeForPrint(compressed), count
end

local function DecodePools(text)
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return end
    local compressed = LibDeflate:DecodeForPrint(text:sub(#PREFIX + 1))
    local serialized = compressed and LibDeflate:DecompressDeflate(compressed)
    if not serialized then return end
    local ok, payload = LibSerialize:Deserialize(serialized)
    if not ok or type(payload) ~= "table" or payload.v ~= FORMAT_VERSION or type(payload.pools) ~= "table" then
        return
    end
    return payload.pools
end

local function ValidPosition(value)
    return type(value) == "number" and value >= 0 and value <= POSITION_SCALE
end

local function ImportPools(text)
    local maps = DecodePools(text)
    if not maps then return end
    local added, updated = 0, 0
    for mapID, list in pairs(maps) do
        local width, height
        if type(mapID) == "number" and type(list) == "table" then
            width, height = C_Map.GetMapWorldSize(mapID)
        end
        if width and width > 0 and height and height > 0 then
            for _, entry in ipairs(list) do
                local kind = type(entry) == "table" and type(entry[1]) == "string" and #entry[1] <= MAX_KIND_LENGTH
                    and ns.PoolKey(entry[1])
                -- The fourth field marks a position placed by a catch; nothing else is worth importing.
                if kind and entry[4] == 1 and ValidPosition(entry[2]) and ValidPosition(entry[3]) then
                    local x, y = entry[2] / POSITION_SCALE, entry[3] / POSITION_SCALE
                    local _, isNew = ns.StorePool(kind, nil, mapID, x, y, width, height)
                    if isNew then added = added + 1 else updated = updated + 1 end
                end
            end
        end
    end
    return added, updated
end

local SHARE_WIDTH, SHARE_HEIGHT = 420, 300

local share = CreateFrame("Frame", "AnglerShareFrame", UIParent, "ButtonFrameTemplate")
ButtonFrameTemplate_HidePortrait(share)
ButtonFrameTemplate_HideAttic(share)
share:SetSize(SHARE_WIDTH, SHARE_HEIGHT)
share:SetPoint("CENTER")
share:SetFrameStrata("DIALOG")
share:SetMovable(true)
share:EnableMouse(true)
share:RegisterForDrag("LeftButton")
share:SetClampedToScreen(true)
share:SetScript("OnDragStart", share.StartMoving)
share:SetScript("OnDragStop", share.StopMovingOrSizing)
share:Hide()
tinsert(UISpecialFrames, share:GetName())

local hint = share:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", share.Inset, "TOPLEFT", 8, -8)
hint:SetPoint("RIGHT", share.Inset, "RIGHT", -8, 0)
hint:SetJustifyH("LEFT")

-- The game cannot open web pages, so the form link sits in a read-only box for Ctrl+C.
local linkBox = CreateFrame("EditBox", nil, share.Inset, "InputBoxTemplate")
linkBox:SetHeight(20)
linkBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -6)
linkBox:SetPoint("RIGHT", share.Inset, "RIGHT", -10, 0)
linkBox:SetAutoFocus(false)
linkBox:SetText(FORM_URL)
linkBox:SetCursorPosition(0)
linkBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        self:SetText(FORM_URL)
        self:HighlightText()
    end
end)
linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
linkBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
linkBox:SetScript("OnEscapePressed", function() share:Hide() end)

local scroll = CreateFrame("ScrollFrame", nil, share.Inset, "UIPanelScrollFrameTemplate")
scroll:SetPoint("BOTTOMRIGHT", share.Inset, "BOTTOMRIGHT", -28, 8)

local editBox = CreateFrame("EditBox", nil, scroll)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(false)
editBox:SetMaxLetters(0)
editBox:SetFontObject(ChatFontNormal)
editBox:SetWidth(SHARE_WIDTH - 70)
editBox:SetScript("OnEscapePressed", function() share:Hide() end)
scroll:SetScrollChild(editBox)
scroll:SetScript("OnMouseDown", function() editBox:SetFocus() end)

local actionButton = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
actionButton:SetSize(120, 22)
actionButton:SetPoint("BOTTOMRIGHT", -6, 4)

local mode

local function OpenShare(newMode, text)
    mode = newMode
    share:SetTitle(L(mode == "export" and "SHARE_EXPORT_TITLE" or "SHARE_IMPORT_TITLE"))
    hint:SetText(L(mode == "export" and "SHARE_EXPORT_HINT" or "SHARE_IMPORT_HINT"))
    actionButton:SetText(L(mode == "export" and "SHARE_CLOSE" or "SHARE_IMPORT_BUTTON"))
    linkBox:SetShown(mode == "export")
    scroll:SetPoint("TOPLEFT", mode == "export" and linkBox or hint, "BOTTOMLEFT", mode == "export" and -6 or 0, -8)
    editBox:SetText(text or "")
    share:Show()
    editBox:SetFocus()
    if mode == "export" then editBox:HighlightText() end
end

-- An exported string would be lost if edited by accident, so typing restores it.
editBox:SetScript("OnTextChanged", function(self, userInput)
    if mode == "export" and userInput then
        self:SetText(share.exported or "")
        self:HighlightText()
    end
end)

actionButton:SetScript("OnClick", function()
    if mode == "export" then
        share:Hide()
        return
    end
    local added, updated = ImportPools(editBox:GetText())
    if not added then
        ns.Print(L("SHARE_INVALID"))
        return
    end
    ns.Print(L("SHARE_IMPORTED"):format(added, updated))
    share:Hide()
end)

function ns.ShowExport()
    local text, count = EncodePools()
    if count == 0 then
        ns.Print(L("SHARE_NOTHING"))
        return
    end
    share.exported = text
    OpenShare("export", text)
    ns.Print(L("SHARE_EXPORTED"):format(count))
end

function ns.ShowImport()
    share.exported = nil
    OpenShare("import")
end
