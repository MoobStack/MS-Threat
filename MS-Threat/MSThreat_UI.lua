-- MSThreat_UI.lua
-- Frame-only WoW 1.12 user interface. The meter has one header bar and only
-- creates row bars beneath it; there is no enclosing background panel.

local OT = MSThreat
OT.UI = OT.UI or {}
local UI = OT.UI

local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local tinsert = table.insert
local tconcat = table.concat
local tostring = tostring
local tonumber = tonumber
local type = type
local pcall = pcall

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local CHAT_BG = "Interface\\ChatFrame\\ChatFrameBackground"

UI.rows = {}
UI.controls = {}
UI.activePage = 1
UI.initialized = false
UI.positionRestored = false
UI.warningFlashStart = 0

local function SetFontSafe(fontString, size, flags)
    local ok
    if not fontString then
        return false
    end
    ok = fontString:SetFont(FONT, size or 12, flags or "")
    if not ok and GameFontNormal then
        fontString:SetFontObject(GameFontNormal)
    end
    return true
end

local function NewFontString(parent, layer, size, flags, justify)
    local fontString = parent:CreateFontString(nil, layer or "OVERLAY")
    SetFontSafe(fontString, size or 12, flags or "")
    fontString:SetJustifyH(justify or "LEFT")
    fontString:SetJustifyV("MIDDLE")
    return fontString
end

local function SetSimpleBackdrop(frame, edgeSize)
    frame:SetBackdrop({
        bgFile = CHAT_BG,
        edgeFile = TOOLTIP_BORDER,
        tile = 1,
        tileSize = 16,
        edgeSize = edgeSize or 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
end

local function MakeSolidTexture(parent, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(WHITE)
    return texture
end

local function ClampValue(value, low, high)
    return max(low, min(high, value))
end

local function RoundTo(value, step)
    if not step or step <= 0 then
        return value
    end
    return floor(value / step + 0.5) * step
end

local function ThreatColor(percent)
    local p = ClampValue((percent or 0) / 100, 0, 1)
    if p <= 0.5 then
        return p * 2, 1, 0
    end
    return 1, (1 - p) * 2, 0
end

local function ProviderColor(badge)
    if badge == "NATIVE" or badge == "SERVER" or badge == "NATIVE %" then
        return 0.35, 1.0, 0.45
    elseif badge == "LOCAL EST" then
        return 1.0, 0.72, 0.25
    elseif badge == "PREVIEW" then
        return 0.40, 0.80, 1.0
    elseif badge == "WAIT" or badge == "IDLE" then
        return 1.0, 0.78, 0.25
    end
    return 1.0, 0.35, 0.35
end

local function MakeButton(parent, name, text, width, height)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(width or 90)
    button:SetHeight(height or 22)
    SetSimpleBackdrop(button, 7)
    button:SetBackdropColor(0.08, 0.10, 0.13, 0.95)
    button:SetBackdropBorderColor(0.35, 0.55, 0.70, 0.9)

    button.label = NewFontString(button, "OVERLAY", 11, "", "CENTER")
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.label:SetText(text or "Button")

    button:SetScript("OnEnter", function()
        this:SetBackdropColor(0.13, 0.20, 0.27, 1)
        this:SetBackdropBorderColor(0.35, 0.85, 1.0, 1)
    end)
    button:SetScript("OnLeave", function()
        this:SetBackdropColor(0.08, 0.10, 0.13, 0.95)
        this:SetBackdropBorderColor(0.35, 0.55, 0.70, 0.9)
    end)

    return button
end

function UI:CreateMeter()
    local meter
    local header
    local i
    local row

    meter = CreateFrame("Frame", "MSThreatMeter", UIParent)
    meter:SetWidth(OT.db.width)
    meter:SetHeight(OT.db.headerHeight)
    meter:SetMovable(1)
    meter:SetFrameStrata("MEDIUM")
    meter:SetFrameLevel(20)
    if meter.SetClampedToScreen then
        pcall(meter.SetClampedToScreen, meter, 1)
    end
    self.meter = meter

    header = CreateFrame("Button", "MSThreatHeader", meter)
    header:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, 0)
    header:SetWidth(OT.db.width)
    header:SetHeight(OT.db.headerHeight)
    SetSimpleBackdrop(header, 8)
    header:SetBackdropColor(0.025, 0.035, 0.050, 0.94)
    header:SetBackdropBorderColor(0.22, 0.62, 0.82, 0.95)
    header:SetFrameLevel(22)
    self.header = header

    header.title = NewFontString(header, "OVERLAY", 12, "OUTLINE", "LEFT")
    header.title:SetPoint("LEFT", header, "LEFT", 7, 0)
    header.title:SetText("MS Threat")

    header.refreshButton = MakeButton(header, "MSThreatHeaderRefreshButton", "R", 18, 16)
    header.refreshButton:SetPoint("RIGHT", header, "RIGHT", -3, 0)
    header.refreshButton:SetFrameLevel(24)
    header.refreshButton:SetScript("OnClick", function()
        OT:StopTest()
        OT:RefreshThreatData("header refresh button", true, false, false)
    end)
    header.refreshButton:SetScript("OnEnter", function()
        this:SetBackdropColor(0.13, 0.20, 0.27, 1)
        this:SetBackdropBorderColor(0.35, 0.85, 1.0, 1)
        if GameTooltip then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Refresh threat data", 0.35, 0.85, 1.0)
            GameTooltip:AddLine("Restarts roster and providers without changing settings.", 1, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    header.refreshButton:SetScript("OnLeave", function()
        this:SetBackdropColor(0.08, 0.10, 0.13, 0.95)
        this:SetBackdropBorderColor(0.35, 0.55, 0.70, 0.9)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    self.headerRefreshButton = header.refreshButton

    header.provider = NewFontString(header, "OVERLAY", 10, "OUTLINE", "RIGHT")
    header.provider:SetPoint("RIGHT", header.refreshButton, "LEFT", -5, 0)
    header.provider:SetWidth(76)
    header.provider:SetText("IDLE")

    header.title:SetPoint("RIGHT", header.provider, "LEFT", -5, 0)

    header:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" and not OT.db.locked then
            OT.UI.meter:StartMoving()
        end
    end)

    header:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and not OT.db.locked then
            OT.UI.meter:StopMovingOrSizing()
            OT.UI:SavePosition()
        elseif arg1 == "RightButton" then
            OT.UI:ToggleOptions()
        end
    end)

    header:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("MS Threat", 0.35, 0.85, 1.0)
        if OT.db.locked then
            GameTooltip:AddLine("Right-click for settings.", 1, 1, 1)
            GameTooltip:AddLine("Use /msthreat unlock to move it.", 0.75, 0.75, 0.75)
        else
            GameTooltip:AddLine("Drag with the left mouse button.", 1, 1, 1)
            GameTooltip:AddLine("Right-click for settings.", 0.75, 0.75, 0.75)
        end
        GameTooltip:Show()
    end)

    header:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    for i = 1, 40 do
        row = CreateFrame("StatusBar", "MSThreatRow" .. i, meter)
        row:SetStatusBarTexture(STATUSBAR)
        row:SetMinMaxValues(0, 100)
        row:SetValue(0)
        row:SetFrameLevel(21)
        row:Hide()

        row.background = MakeSolidTexture(row, "BACKGROUND")
        row.background:SetAllPoints(row)
        row.background:SetVertexColor(0.08, 0.10, 0.13, 0.75)

        row.rank = NewFontString(row, "OVERLAY", 11, "OUTLINE", "RIGHT")
        row.rank:SetPoint("LEFT", row, "LEFT", 3, 0)
        row.rank:SetWidth(20)
        row.rank:SetText("")

        row.nameText = NewFontString(row, "OVERLAY", 11, "OUTLINE", "LEFT")
        row.nameText:SetPoint("LEFT", row.rank, "RIGHT", 5, 0)
        row.nameText:SetText("")

        row.valueText = NewFontString(row, "OVERLAY", 10, "OUTLINE", "RIGHT")
        row.valueText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.valueText:SetText("")

        row.leftBorder = MakeSolidTexture(row, "OVERLAY")
        row.leftBorder:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.leftBorder:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.leftBorder:SetWidth(2)
        row.leftBorder:SetVertexColor(1, 1, 1, 0)

        row:SetScript("OnEnter", function()
            local data = this.data
            if not data or not GameTooltip then
                return
            end
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(data.name or "Unknown"), 1, 1, 1)
            if data.statusOnly then
                GameTooltip:AddLine(tostring(data.message or ""), 0.8, 0.8, 0.8, 1)
            else
                if data.estimated then
                    GameTooltip:AddLine("Local solo estimate", 1.0, 0.72, 0.25)
                    GameTooltip:AddLine("Threat: ~" .. OT.FormatNumber(data.absoluteThreat or data.threat, false), 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("Relative: ~" .. tostring(floor((data.relativePercent or 0) + 0.5)) .. "%", 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("TPS: ~" .. OT.FormatNumber(data.tps or 0, false), 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("Damage, healing, visible form modifiers, and pet damage are tracked. Hidden spell threat and some talents cannot be read exactly.", 0.72, 0.76, 0.82, 1)
                else
                    GameTooltip:AddLine("Threat: " .. OT.FormatNumber(data.absoluteThreat or data.threat, false), 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("Relative: " .. tostring(floor((data.relativePercent or 0) + 0.5)) .. "%", 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("To pull aggro: " .. tostring(floor((data.pullPercent or 0) + 0.5)) .. "%", 0.85, 0.85, 0.85)
                    GameTooltip:AddLine("TPS: " .. OT.FormatNumber(data.tps or 0, false), 0.85, 0.85, 0.85)
                end
                if data.tank then
                    GameTooltip:AddLine("Current aggro target", 1.0, 0.45, 0.25)
                end
            end
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)

        self.rows[i] = row
    end

    self:RestorePosition()
    self:ApplyMeterLayout()
end

function UI:RestorePosition()
    local position = OT.db.position or OT.defaults.position
    if not self.meter then
        return
    end
    self.meter:ClearAllPoints()
    self.meter:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or "CENTER",
        position.x or 0,
        position.y or 0
    )
    self.positionRestored = true
end

function UI:SavePosition()
    local point
    local relativeTo
    local relativePoint
    local x
    local y

    if not self.meter then
        return
    end

    point, relativeTo, relativePoint, x, y = self.meter:GetPoint(1)
    OT.db.position = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end

function UI:CenterMeter()
    OT.db.position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 160,
    }
    self:RestorePosition()
    OT:StartTest(15)
end

function UI:ApplyMeterLayout()
    local width = ClampValue(tonumber(OT.db.width) or 300, 180, 520)
    local rowHeight = ClampValue(tonumber(OT.db.rowHeight) or 18, 14, 30)
    local headerHeight = ClampValue(tonumber(OT.db.headerHeight) or 22, 18, 32)
    local spacing = ClampValue(tonumber(OT.db.rowSpacing) or 1, 0, 5)
    local scale = ClampValue(tonumber(OT.db.scale) or 1, 0.5, 2.0)
    local alpha = ClampValue(tonumber(OT.db.alpha) or 1, 0.20, 1.0)
    local fontSize = ClampValue(rowHeight - 7, 9, 15)
    local refreshSize = ClampValue(headerHeight - 6, 14, 24)
    local i
    local row

    if not self.meter then
        return
    end

    self.meter:SetWidth(width)
    self.meter:SetScale(scale)
    self.meter:SetAlpha(alpha)

    self.header:SetWidth(width)
    self.header:SetHeight(headerHeight)
    SetFontSafe(self.header.title, ClampValue(headerHeight - 9, 10, 15), "OUTLINE")
    SetFontSafe(self.header.provider, ClampValue(headerHeight - 11, 9, 13), "OUTLINE")
    if self.headerRefreshButton then
        self.headerRefreshButton:SetWidth(refreshSize)
        self.headerRefreshButton:SetHeight(refreshSize)
        self.headerRefreshButton:ClearAllPoints()
        self.headerRefreshButton:SetPoint("RIGHT", self.header, "RIGHT", -3, 0)
        SetFontSafe(self.headerRefreshButton.label, ClampValue(refreshSize - 7, 9, 13), "OUTLINE")
    end

    if OT.db.locked then
        self.header:SetBackdropBorderColor(0.18, 0.38, 0.50, 0.85)
    else
        self.header:SetBackdropBorderColor(0.30, 0.85, 1.0, 1.0)
    end

    for i = 1, 40 do
        row = self.rows[i]
        row:SetWidth(width)
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -spacing)
        else
            row:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT", 0, -spacing)
        end

        row.rank:SetHeight(rowHeight)
        row.nameText:SetHeight(rowHeight)
        row.valueText:SetHeight(rowHeight)
        row.valueText:SetWidth(max(95, width * 0.48))
        row.nameText:SetWidth(max(50, width - row.valueText:GetWidth() - 34))
        SetFontSafe(row.rank, fontSize, "OUTLINE")
        SetFontSafe(row.nameText, fontSize, "OUTLINE")
        SetFontSafe(row.valueText, max(9, fontSize - 1), "OUTLINE")
    end

    self:Refresh(true)
end

function UI:GetRowColor(data)
    local mode = OT.db.colorMode or "CLASS"
    local color
    if mode == "THREAT" then
        return ThreatColor(data.relativePercent or data.pullPercent or 0)
    elseif mode == "NEUTRAL" then
        return 0.28, 0.60, 0.78
    end
    color = OT:GetClassColor(data.class)
    return color[1], color[2], color[3]
end

function UI:BuildValueText(data)
    local parts = {}
    local threatValue = data.absoluteThreat or data.threat or 0

    if OT.db.showPercent then
        tinsert(parts, (data.estimated and "~" or "") .. tostring(floor((data.relativePercent or 0) + 0.5)) .. "%")
    end
    if OT.db.showThreat then
        tinsert(parts, (data.estimated and "~" or "") .. OT.FormatNumber(threatValue, OT.db.abbreviate))
    end
    if OT.db.showTPS then
        tinsert(parts, (data.estimated and "~" or "") .. OT.FormatNumber(data.tps or 0, OT.db.abbreviate) .. "/s")
    end

    return tconcat(parts, "  ")
end

function UI:SetRowData(row, data, rank, topThreat)
    local r
    local g
    local b
    local nameText
    local relativePercent

    row.data = data

    if data.statusOnly then
        row:SetValue(0)
        row:SetStatusBarColor(0.20, 0.40, 0.55, 0.25)
        row.background:SetVertexColor(0.035, 0.055, 0.075, 0.92)
        row.rank:SetText("")
        row.nameText:SetText(data.message or "Waiting for threat data")
        row.nameText:SetTextColor(0.78, 0.86, 0.92)
        row.valueText:SetText("")
        row.leftBorder:SetVertexColor(0.3, 0.8, 1.0, 0.8)
        row:Show()
        return
    end

    if not data.relativePercent then
        if topThreat and topThreat > 0 then
            data.relativePercent = (data.threat or 0) / topThreat * 100
        else
            data.relativePercent = 0
        end
    end
    relativePercent = ClampValue(data.relativePercent or 0, 0, 100)

    r, g, b = self:GetRowColor(data)
    row:SetStatusBarColor(r, g, b, 0.78)
    row.background:SetVertexColor(r * 0.32, g * 0.32, b * 0.32, 0.82)
    row:SetValue(relativePercent)

    row.rank:SetText(tostring(rank or data.rank or ""))
    row.rank:SetTextColor(0.75, 0.78, 0.82)

    nameText = tostring(data.name or "Unknown")
    if data.tank then
        nameText = "[T] " .. nameText
    elseif data.isPet and data.owner then
        nameText = nameText .. " <" .. tostring(data.owner) .. ">"
    end
    row.nameText:SetText(nameText)
    row.nameText:SetTextColor(r, g, b)
    row.valueText:SetText(self:BuildValueText(data))
    row.valueText:SetTextColor(1, 1, 1)

    if data.isPlayer then
        row.leftBorder:SetVertexColor(1.0, 0.88, 0.30, 1.0)
    elseif data.tank then
        row.leftBorder:SetVertexColor(1.0, 0.36, 0.20, 0.95)
    else
        row.leftBorder:SetVertexColor(1, 1, 1, 0)
    end

    row:Show()
end

function UI:Update(rows, force)
    local shouldShow
    local statusText
    local badge
    local targetName
    local displayCount
    local topThreat = 0
    local i
    local data
    local totalHeight
    local r
    local g
    local b

    if not self.initialized or not self.meter then
        return
    end

    shouldShow = OT:ShouldShowMeter()
    if not shouldShow then
        self.meter:Hide()
        return
    end

    statusText, badge = OT:GetStatusText()
    if OT.testUntil > GetTime() then
        targetName = "Preview"
    else
        targetName = OT.currentTargetName or "No target"
    end

    self.header.title:SetText((OT.db.locked and "MS Threat" or "MS Threat [MOVE]") .. " - " .. targetName)
    self.header.provider:SetText(badge or "NONE")
    r, g, b = ProviderColor(badge)
    self.header.provider:SetTextColor(r, g, b)

    for i = 1, table.getn(rows or {}) do
        if rows[i] and (rows[i].threat or 0) > topThreat then
            topThreat = rows[i].threat or 0
        end
    end

    displayCount = table.getn(rows or {})
    if displayCount > 0 then
        displayCount = min(displayCount, OT.db.maxRows or 20)
        local shown = 0
        for i = 1, table.getn(rows) do
            data = rows[i]
            if data and shown < displayCount then
                shown = shown + 1
                data.rank = data.rank or i
                data.isPlayer = data.isPlayer or (data.name == UnitName("player"))
                self:SetRowData(self.rows[shown], data, data.rank or shown, topThreat)
            end
        end
        displayCount = shown
    else
        displayCount = 1
        self:SetRowData(self.rows[1], {
            statusOnly = true,
            name = statusText,
            message = statusText,
        }, 1, 0)
    end

    for i = displayCount + 1, 40 do
        self.rows[i]:Hide()
        self.rows[i].data = nil
    end

    totalHeight = (OT.db.headerHeight or 22)
        + (displayCount * (OT.db.rowHeight or 18))
        + (displayCount * (OT.db.rowSpacing or 1))
    self.meter:SetHeight(totalHeight)
    self.meter:Show()

    if self.options and self.options:IsVisible() then
        self:RefreshOptionDiagnostics()
    end
end

function UI:Refresh(force)
    if OT and OT.RefreshDisplay then
        OT:RefreshDisplay(force)
    end
end

function UI:FlashWarning()
    self.warningFlashStart = GetTime()
    if self.header then
        self.header:SetBackdropBorderColor(1.0, 0.15, 0.05, 1.0)
    end
end

function UI:UpdateWarningFlash()
    local elapsed
    local pulse
    if not self.header or self.warningFlashStart <= 0 then
        return
    end

    elapsed = GetTime() - self.warningFlashStart
    if elapsed >= 0.8 then
        self.warningFlashStart = 0
        if OT.db.locked then
            self.header:SetBackdropBorderColor(0.18, 0.38, 0.50, 0.85)
        else
            self.header:SetBackdropBorderColor(0.30, 0.85, 1.0, 1.0)
        end
        return
    end

    pulse = 0.45 + abs(math.sin(elapsed * 15)) * 0.55
    self.header:SetBackdropBorderColor(1.0, 0.15, 0.05, pulse)
end

local function CreateSectionTitle(parent, text, x, y)
    local title = NewFontString(parent, "OVERLAY", 12, "OUTLINE", "LEFT")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(text)
    title:SetTextColor(0.35, 0.85, 1.0)
    return title
end

local function CreateCheckbox(parent, name, labelText, x, y, key)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(18)
    button:SetHeight(18)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    SetSimpleBackdrop(button, 6)
    button:SetBackdropColor(0.04, 0.06, 0.08, 1)
    button:SetBackdropBorderColor(0.35, 0.55, 0.70, 1)

    button.mark = NewFontString(button, "OVERLAY", 13, "OUTLINE", "CENTER")
    button.mark:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.mark:SetText("")
    button.mark:SetTextColor(0.30, 0.90, 1.0)

    button.text = NewFontString(parent, "OVERLAY", 11, "", "LEFT")
    button.text:SetPoint("LEFT", button, "RIGHT", 7, 0)
    button.text:SetText(labelText)
    button.text:SetTextColor(0.92, 0.94, 0.97)

    button.key = key
    button.Refresh = function(self)
        if OT.db[self.key] then
            self.mark:SetText("X")
            self:SetBackdropBorderColor(0.30, 0.85, 1.0, 1)
        else
            self.mark:SetText("")
            self:SetBackdropBorderColor(0.35, 0.55, 0.70, 1)
        end
    end

    button:SetScript("OnClick", function()
        OT.db[this.key] = not OT.db[this.key]
        this:Refresh()
        if this.key == "showPets" or this.key == "soloFallback" then
            OT:RefreshThreatData("data option changed", false, false, false)
        else
            OT:RebuildRoster()
        end
        OT.UI:ApplyAllSettings()
    end)

    tinsert(UI.controls, button)
    return button
end

local function CreateSlider(parent, name, labelText, x, y, width, minimum, maximum, step, key, formatter)
    local slider = CreateFrame("Slider", name, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(width)
    slider:SetHeight(16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    if slider.SetValueStep then
        slider:SetValueStep(step)
    end
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    SetSimpleBackdrop(slider, 5)
    slider:SetBackdropColor(0.03, 0.05, 0.07, 1)
    slider:SetBackdropBorderColor(0.28, 0.48, 0.62, 1)

    slider.label = NewFontString(parent, "OVERLAY", 10, "", "LEFT")
    slider.label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
    slider.label:SetText(labelText)
    slider.label:SetTextColor(0.82, 0.86, 0.90)

    slider.valueText = NewFontString(parent, "OVERLAY", 10, "OUTLINE", "RIGHT")
    slider.valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 3)
    slider.valueText:SetText("")
    slider.valueText:SetTextColor(0.35, 0.85, 1.0)

    slider.key = key
    slider.step = step
    slider.formatter = formatter
    slider.updating = false

    slider.Refresh = function(self)
        local value = tonumber(OT.db[self.key]) or minimum
        self.updating = true
        self:SetValue(value)
        self.updating = false
        if self.formatter then
            self.valueText:SetText(self.formatter(value))
        else
            self.valueText:SetText(tostring(value))
        end
    end

    slider:SetScript("OnValueChanged", function()
        local value
        if this.updating then
            return
        end
        value = RoundTo(this:GetValue(), this.step)
        OT.db[this.key] = value
        if this.formatter then
            this.valueText:SetText(this.formatter(value))
        else
            this.valueText:SetText(tostring(value))
        end
        OT.UI:ApplyAllSettings()
    end)

    tinsert(UI.controls, slider)
    return slider
end

local function CreateCycle(parent, name, labelText, x, y, width, key, choices)
    local label = NewFontString(parent, "OVERLAY", 10, "", "LEFT")
    local button = MakeButton(parent, name, "", width, 22)

    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(0.82, 0.86, 0.90)

    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    button.key = key
    button.choices = choices

    button.Refresh = function(self)
        local current = OT.db[self.key]
        local i
        for i = 1, table.getn(self.choices) do
            if self.choices[i][1] == current then
                self.label:SetText(self.choices[i][2])
                return
            end
        end
        OT.db[self.key] = self.choices[1][1]
        self.label:SetText(self.choices[1][2])
    end

    button:SetScript("OnClick", function()
        local current = OT.db[this.key]
        local i
        local nextIndex = 1
        for i = 1, table.getn(this.choices) do
            if this.choices[i][1] == current then
                nextIndex = i + 1
                if nextIndex > table.getn(this.choices) then
                    nextIndex = 1
                end
                break
            end
        end
        OT.db[this.key] = this.choices[nextIndex][1]
        this:Refresh()
        if this.key == "providerMode" then
            OT:RefreshThreatData("provider mode changed", false, false, false)
        end
        OT.UI:ApplyAllSettings()
    end)

    tinsert(UI.controls, button)
    return button
end

function UI:CreateOptions()
    local frame
    local close
    local displayTab
    local behaviorTab
    local displayPage
    local behaviorPage
    local button

    frame = CreateFrame("Frame", "MSThreatOptions", UIParent)
    frame:SetWidth(470)
    frame:SetHeight(555)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(1)
    frame:EnableMouse(1)
    if frame.SetClampedToScreen then
        pcall(frame.SetClampedToScreen, frame, 1)
    end
    SetSimpleBackdrop(frame, 12)
    frame:SetBackdropColor(0.018, 0.025, 0.035, 0.97)
    frame:SetBackdropBorderColor(0.25, 0.70, 0.92, 1)
    frame:Hide()
    self.options = frame

    frame.titleBar = CreateFrame("Button", "MSThreatOptionsTitleBar", frame)
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    frame.titleBar:SetHeight(28)
    frame.titleBar:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            OT.UI.options:StartMoving()
        end
    end)
    frame.titleBar:SetScript("OnMouseUp", function()
        OT.UI.options:StopMovingOrSizing()
    end)

    frame.title = NewFontString(frame.titleBar, "OVERLAY", 15, "OUTLINE", "LEFT")
    frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", 8, 0)
    frame.title:SetText("MS Threat Settings")
    frame.title:SetTextColor(0.35, 0.85, 1.0)

    frame.version = NewFontString(frame.titleBar, "OVERLAY", 10, "", "RIGHT")
    frame.version:SetPoint("RIGHT", frame.titleBar, "RIGHT", -34, 0)
    frame.version:SetText("v" .. OT.version)
    frame.version:SetTextColor(0.65, 0.70, 0.75)

    close = MakeButton(frame, "MSThreatOptionsClose", "X", 24, 22)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function()
        OT.UI:CloseOptions()
    end)

    displayTab = MakeButton(frame, "MSThreatDisplayTab", "Display", 100, 24)
    displayTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -42)
    displayTab:SetScript("OnClick", function()
        OT.UI:ShowPage(1)
    end)
    self.displayTab = displayTab

    behaviorTab = MakeButton(frame, "MSThreatBehaviorTab", "Behavior", 100, 24)
    behaviorTab:SetPoint("LEFT", displayTab, "RIGHT", 8, 0)
    behaviorTab:SetScript("OnClick", function()
        OT.UI:ShowPage(2)
    end)
    self.behaviorTab = behaviorTab

    displayPage = CreateFrame("Frame", "MSThreatDisplayPage", frame)
    displayPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -76)
    displayPage:SetWidth(440)
    displayPage:SetHeight(385)
    self.displayPage = displayPage

    CreateSectionTitle(displayPage, "Meter layout", 0, 0)
    CreateSlider(displayPage, "MSThreatWidthSlider", "Width", 0, -42, 200, 180, 520, 10, "width", function(v) return tostring(floor(v + 0.5)) .. " px" end)
    CreateSlider(displayPage, "MSThreatRowHeightSlider", "Row height", 225, -42, 200, 14, 30, 1, "rowHeight", function(v) return tostring(floor(v + 0.5)) .. " px" end)
    CreateSlider(displayPage, "MSThreatRowsSlider", "Maximum rows", 0, -100, 200, 3, 40, 1, "maxRows", function(v) return tostring(floor(v + 0.5)) end)
    CreateSlider(displayPage, "MSThreatScaleSlider", "Scale", 225, -100, 200, 0.5, 2.0, 0.05, "scale", function(v) return string.format("%.2f", v) end)
    CreateSlider(displayPage, "MSThreatAlphaSlider", "Opacity", 0, -158, 200, 0.20, 1.0, 0.05, "alpha", function(v) return tostring(floor(v * 100 + 0.5)) .. "%" end)

    CreateCycle(displayPage, "MSThreatColorMode", "Row color style", 225, -142, 200, "colorMode", {
        { "CLASS", "Class colors" },
        { "THREAT", "Threat gradient" },
        { "NEUTRAL", "Neutral blue" },
    })

    CreateSectionTitle(displayPage, "Row text", 0, -208)
    CreateCheckbox(displayPage, "MSThreatShowThreat", "Show threat value", 0, -238, "showThreat")
    CreateCheckbox(displayPage, "MSThreatShowPercent", "Show percent of leader", 225, -238, "showPercent")
    CreateCheckbox(displayPage, "MSThreatShowTPS", "Show threat per second", 0, -272, "showTPS")
    CreateCheckbox(displayPage, "MSThreatAbbreviate", "Abbreviate large values", 225, -272, "abbreviate")

    displayPage.note = NewFontString(displayPage, "OVERLAY", 10, "", "LEFT")
    displayPage.note:SetPoint("TOPLEFT", displayPage, "TOPLEFT", 0, -318)
    displayPage.note:SetWidth(430)
    displayPage.note:SetText("The meter itself has no enclosing panel: only the header and active player rows are drawn.")
    displayPage.note:SetTextColor(0.62, 0.68, 0.73)

    behaviorPage = CreateFrame("Frame", "MSThreatBehaviorPage", frame)
    behaviorPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -76)
    behaviorPage:SetWidth(440)
    behaviorPage:SetHeight(385)
    self.behaviorPage = behaviorPage

    CreateSectionTitle(behaviorPage, "Visibility and data", 0, 0)
    CreateCheckbox(behaviorPage, "MSThreatHideOOC", "Hide while out of combat", 0, -34, "hideOutOfCombat")
    CreateCheckbox(behaviorPage, "MSThreatHideNoTarget", "Hide without a hostile NPC target", 225, -34, "hideWithoutTarget")
    CreateCheckbox(behaviorPage, "MSThreatShowPets", "Include pets and guardians", 0, -68, "showPets")
    CreateCheckbox(behaviorPage, "MSThreatKeepFight", "Save the last fight summary", 225, -68, "keepLastFight")
    CreateCheckbox(behaviorPage, "MSThreatLocked", "Lock meter position", 0, -102, "locked")
    CreateCheckbox(behaviorPage, "MSThreatAlwaysPlayer", "Keep your row visible", 225, -102, "alwaysShowPlayer")
    CreateCheckbox(behaviorPage, "MSThreatSoloFallback", "Estimate my threat while solo", 0, -136, "soloFallback")

    CreateCycle(behaviorPage, "MSThreatProviderMode", "Threat provider", 225, -126, 200, "providerMode", {
        { "AUTO", "Auto: exact, then solo estimate" },
        { "NATIVE", "Native API only" },
        { "SERVER", "Server protocol only" },
        { "LOCAL", "Local solo estimate only" },
    })

    CreateCheckbox(behaviorPage, "MSThreatAutoRecover", "Auto-recover stale threat data", 0, -176, "autoRecover")

    CreateSectionTitle(behaviorPage, "Aggro warning", 0, -216)
    CreateCheckbox(behaviorPage, "MSThreatWarningEnabled", "Warn near the pull threshold", 0, -246, "warningEnabled")
    CreateCheckbox(behaviorPage, "MSThreatWarningSound", "Play warning sound", 225, -246, "warningSound")
    CreateSlider(behaviorPage, "MSThreatWarningSlider", "Warning threshold", 0, -298, 200, 50, 100, 1, "warningThreshold", function(v) return tostring(floor(v + 0.5)) .. "%" end)
    CreateSlider(behaviorPage, "MSThreatUpdateSlider", "Update interval", 225, -298, 200, 0.10, 1.00, 0.05, "updateInterval", function(v) return string.format("%.2fs", v) end)
    CreateSlider(behaviorPage, "MSThreatTPSWindow", "TPS averaging window", 0, -356, 200, 2, 15, 1, "tpsWindow", function(v) return tostring(floor(v + 0.5)) .. "s" end)

    behaviorPage.providerNote = NewFontString(behaviorPage, "OVERLAY", 10, "", "LEFT")
    behaviorPage.providerNote:SetPoint("TOPLEFT", behaviorPage, "TOPLEFT", 225, -342)
    behaviorPage.providerNote:SetWidth(205)
    behaviorPage.providerNote:SetText("Hide out of combat is the master visibility switch. Auto recovery performs one soft provider restart; use the R header button or Refresh to do the same manually.")
    behaviorPage.providerNote:SetTextColor(0.62, 0.68, 0.73)

    frame.diagnostics = NewFontString(frame, "OVERLAY", 10, "", "LEFT")
    frame.diagnostics:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 66)
    frame.diagnostics:SetWidth(430)
    frame.diagnostics:SetHeight(54)
    frame.diagnostics:SetText("")
    frame.diagnostics:SetTextColor(0.72, 0.80, 0.86)

    button = MakeButton(frame, "MSThreatPreviewButton", "Preview", 68, 24)
    button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 26)
    button:SetScript("OnClick", function()
        OT:StartTest(20)
    end)

    button = MakeButton(frame, "MSThreatRefreshDataButton", "Refresh", 82, 24)
    button:SetPoint("LEFT", getglobal("MSThreatPreviewButton"), "RIGHT", 5, 0)
    button:SetScript("OnClick", function()
        OT:StopTest()
        OT:RefreshThreatData("manual data refresh", true, false, false)
        OT.UI:RefreshOptionDiagnostics()
    end)

    button = MakeButton(frame, "MSThreatCenterButton", "Center", 62, 24)
    button:SetPoint("LEFT", getglobal("MSThreatRefreshDataButton"), "RIGHT", 5, 0)
    button:SetScript("OnClick", function()
        OT.UI:CenterMeter()
    end)

    button = MakeButton(frame, "MSThreatReportButton", "Last fight", 74, 24)
    button:SetPoint("LEFT", getglobal("MSThreatCenterButton"), "RIGHT", 5, 0)
    button:SetScript("OnClick", function()
        OT:PrintLastFight()
    end)

    button = MakeButton(frame, "MSThreatDefaultsButton", "Defaults", 68, 24)
    button:SetPoint("LEFT", getglobal("MSThreatReportButton"), "RIGHT", 5, 0)
    button:SetScript("OnClick", function()
        OT:ResetSettings(false)
        OT.UI:RefreshControls()
    end)

    button = MakeButton(frame, "MSThreatDoneButton", "Done", 58, 24)
    button:SetPoint("LEFT", getglobal("MSThreatDefaultsButton"), "RIGHT", 5, 0)
    button:SetScript("OnClick", function()
        OT.UI:CloseOptions()
    end)

    frame:SetScript("OnShow", function()
        OT.UI:RefreshControls()
        OT.UI:RefreshOptionDiagnostics()
        OT:StartTest(20)
    end)

    frame:SetScript("OnHide", function()
        OT.UI:Refresh(true)
    end)

    self:ShowPage(1)
end

function UI:ShowPage(pageNumber)
    self.activePage = pageNumber
    if pageNumber == 1 then
        self.displayPage:Show()
        self.behaviorPage:Hide()
        self.displayTab:SetBackdropBorderColor(0.30, 0.85, 1.0, 1)
        self.behaviorTab:SetBackdropBorderColor(0.35, 0.55, 0.70, 0.9)
    else
        self.displayPage:Hide()
        self.behaviorPage:Show()
        self.displayTab:SetBackdropBorderColor(0.35, 0.55, 0.70, 0.9)
        self.behaviorTab:SetBackdropBorderColor(0.30, 0.85, 1.0, 1)
    end
end

function UI:RefreshControls()
    local i
    local control
    if self.options and self.options.title then
        self.options.title:SetText("MS Threat Settings - " .. OT:GetProfileLabel())
    end
    for i = 1, table.getn(self.controls) do
        control = self.controls[i]
        if control.Refresh then
            control:Refresh()
        end
    end
end

function UI:RefreshOptionDiagnostics()
    local statusText
    local badge
    local serverAge
    local refreshAge
    if not self.options or not self.options:IsVisible() then
        return
    end

    statusText, badge = OT:GetStatusText()
    if OT.serverLastResponse > 0 then
        serverAge = string.format("%.1fs ago", GetTime() - OT.serverLastResponse)
    else
        serverAge = "no response yet"
    end
    if OT.lastDataRefreshAt and OT.lastDataRefreshAt > 0 then
        refreshAge = string.format("%.1fs ago", GetTime() - OT.lastDataRefreshAt)
    else
        refreshAge = "never"
    end

    self.options.diagnostics:SetText(
        "Profile: " .. OT:GetProfileLabel()
        .. "  |  Active: " .. tostring(OT.currentProvider)
        .. "  |  Native API: " .. (OT.nativeAvailable and "yes" or "no")
        .. "  |  Server: " .. serverAge
        .. "\n" .. tostring(statusText)
        .. "  |  Recovery " .. (OT.db.autoRecover and "on" or "off")
        .. ", last " .. refreshAge
        .. " (" .. tostring(OT.lastDataRefreshReason or "startup") .. ")"
        .. (OT.Local and OT.Local.GetDiagnostics and ("\n" .. OT.Local:GetDiagnostics()) or "")
    )
end

function UI:ApplyAllSettings()
    if not self.initialized then
        return
    end
    OT:RebuildRoster()
    self:ApplyMeterLayout()
    self:RefreshControls()
    OT:RefreshDisplay(true)
end

function UI:OpenOptions()
    if not self.options then
        return
    end
    self.options:Show()
    self:RefreshControls()
    self:RefreshOptionDiagnostics()
end

function UI:CloseOptions()
    if self.options then
        self.options:Hide()
    end
    OT:StopTest()
end

function UI:ToggleOptions()
    if not self.options then
        return
    end
    if self.options:IsVisible() then
        self:CloseOptions()
    else
        self:OpenOptions()
    end
end

function UI:Initialize()
    if self.initialized then
        return
    end

    self:CreateMeter()
    self:CreateOptions()
    self.initialized = true
    self:ApplyAllSettings()

    self.updateFrame = CreateFrame("Frame", "MSThreatUIUpdateFrame")
    self.updateFrame:SetScript("OnUpdate", function()
        OT.UI:UpdateWarningFlash()
    end)
end

if MSThreat then
    MSThreat.uiLoaded = true
    MSThreat.loadStage = "all addon files loaded"
end
