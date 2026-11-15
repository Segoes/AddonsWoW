local _, ns = ...
local L = ns.L

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local PREFIX = "ANGLER1:"
local FORMAT_VERSION = 1
-- Positions travel as integers to keep the string short; four decimals are under a yard on any zone map.
local POSITION_SCALE = 10000
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
                -- Marks a position placed by a catch; the shared pool build skips entries without it.
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
share:SetTitle(L("SHARE_EXPORT_TITLE"))

local hint = share:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", share.Inset, "TOPLEFT", 8, -8)
hint:SetPoint("RIGHT", share.Inset, "RIGHT", -8, 0)
hint:SetJustifyH("LEFT")
hint:SetText(L("SHARE_EXPORT_HINT"))

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
scroll:SetPoint("TOPLEFT", linkBox, "BOTTOMLEFT", -6, -8)
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

local closeButton = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
closeButton:SetSize(120, 22)
closeButton:SetPoint("BOTTOMRIGHT", -6, 4)
closeButton:SetText(L("SHARE_CLOSE"))
closeButton:SetScript("OnClick", function() share:Hide() end)

local exported

-- An exported string would be lost if edited by accident, so typing restores it.
editBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
        self:SetText(exported or "")
        self:HighlightText()
    end
end)

function ns.ShowExport()
    local text, count = EncodePools()
    if count == 0 then
        ns.Print(L("SHARE_NOTHING"))
        return
    end
    exported = text
    ns.MarkPoolsSent()
    editBox:SetText(text)
    share:Show()
    editBox:SetFocus()
    editBox:HighlightText()
    ns.Print(L("SHARE_EXPORTED"):format(count))
end
