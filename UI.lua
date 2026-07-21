local addonName, BPC = ...

local mainFrame = nil
local selectedContainerId = "all"
local currentFilter = "all" -- "all", "missing", "collected"

local QualityColors = {
    [1] = "|cffffffff",
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
}

local function GetQualityColor(q)
    return QualityColors[q] or "|cffffffff"
end

function BPC.CreateUI()
    if mainFrame then return mainFrame end

    -- Main Frame
    mainFrame = CreateFrame("Frame", "BulgingPouchCheckerFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(720, 540)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "BulgingPouchCheckerFrame")

    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    mainFrame:SetBackdropColor(0.08, 0.09, 0.12, 0.95)
    mainFrame:SetBackdropBorderColor(0.0, 0.7, 0.9, 0.8)

    -- Header Bar
    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)
    header:SetHeight(40)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    header:SetBackdropColor(0.12, 0.14, 0.18, 1)
    header:SetBackdropBorderColor(0.2, 0.25, 0.3, 0.5)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText("|cff00ccffBulging Pouch Checker|r  |cff888888(Midnight 12.0.7)|r")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    sidebar:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4, 4)
    sidebar:SetWidth(180)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    sidebar:SetBackdropColor(0.1, 0.11, 0.14, 0.9)
    sidebar:SetBackdropBorderColor(0.2, 0.22, 0.28, 0.5)

    local sidebarButtons = {}
    local categories = {
        { id = "all", name = "All Containers" }
    }
    for _, c in ipairs(BPC.Containers) do
        table.insert(categories, { id = c.id, name = c.name })
    end

    local btnY = -8
    for _, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetSize(164, 32)
        btn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, btnY)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(0.15, 0.17, 0.22, 0.8)
        btn:SetBackdropBorderColor(0.25, 0.3, 0.38, 0.5)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", btn, "LEFT", 10, 0)
        text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        text:SetJustifyH("LEFT")
        text:SetText(cat.name)
        btn.text = text
        btn.catId = cat.id

        btn:SetScript("OnClick", function()
            selectedContainerId = cat.id
            BPC.UpdateUI()
        end)

        table.insert(sidebarButtons, btn)
        btnY = btnY - 36
    end
    mainFrame.sidebarButtons = sidebarButtons

    -- Main Content Area
    local content = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 6, 0)
    content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)
    content:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    content:SetBackdropColor(0.09, 0.1, 0.13, 0.95)
    content:SetBackdropBorderColor(0.2, 0.22, 0.28, 0.5)

    -- Container Info Box (Header inside content)
    local infoBox = CreateFrame("Frame", nil, content, "BackdropTemplate")
    infoBox:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    infoBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -8)
    infoBox:SetHeight(75)
    infoBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    infoBox:SetBackdropColor(0.12, 0.14, 0.19, 0.8)
    infoBox:SetBackdropBorderColor(0.2, 0.25, 0.35, 0.5)

    local infoTitle = infoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoTitle:SetPoint("TOPLEFT", infoBox, "TOPLEFT", 12, -8)
    infoBox.title = infoTitle

    local infoSub = infoBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoSub:SetPoint("TOPLEFT", infoTitle, "BOTTOMLEFT", 0, -4)
    infoBox.sub = infoSub

    -- Progress Bar
    local pBar = CreateFrame("StatusBar", nil, infoBox)
    pBar:SetSize(490, 16)
    pBar:SetPoint("BOTTOMLEFT", infoBox, "BOTTOMLEFT", 12, 8)
    pBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    pBar:SetStatusBarColor(0.0, 0.65, 0.9, 1)
    pBar:SetMinMaxValues(0, 1)
    infoBox.pBar = pBar

    local pBarBg = pBar:CreateTexture(nil, "BACKGROUND")
    pBarBg:SetAllPoints(pBar)
    pBarBg:SetColorTexture(0.05, 0.05, 0.08, 0.8)

    local pBarText = pBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pBarText:SetPoint("CENTER", pBar, "CENTER", 0, 0)
    infoBox.pBarText = pBarText

    mainFrame.infoBox = infoBox

    -- Filter Tabs (All / Missing Only / Unlocked Only)
    local filterButtons = {}
    local filters = {
        { id = "all", name = "All Items" },
        { id = "missing", name = "Missing Only" },
        { id = "collected", name = "Collected Only" }
    }

    local tabX = 8
    for _, f in ipairs(filters) do
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(110, 24)
        btn:SetPoint("TOPLEFT", infoBox, "BOTTOMLEFT", tabX - 8, -6)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(0.15, 0.17, 0.22, 0.8)
        btn:SetBackdropBorderColor(0.25, 0.3, 0.38, 0.5)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("CENTER", btn, "CENTER", 0, 0)
        text:SetText(f.name)
        btn.text = text
        btn.filterId = f.id

        btn:SetScript("OnClick", function()
            currentFilter = f.id
            BPC.UpdateUI()
        end)

        table.insert(filterButtons, btn)
        tabX = tabX + 116
    end
    mainFrame.filterButtons = filterButtons

    -- Scroll Frame for Items List
    local scrollFrame = CreateFrame("ScrollFrame", "BulgingPouchCheckerScrollFrame", content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", infoBox, "BOTTOMLEFT", 0, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(480, 1)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.scrollChild = scrollChild

    return mainFrame
end

function BPC.UpdateUI()
    if not mainFrame or not mainFrame:IsShown() then return end

    -- Update Sidebar Highlight
    for _, btn in ipairs(mainFrame.sidebarButtons or {}) do
        if btn.catId == selectedContainerId then
            btn:SetBackdropColor(0.0, 0.5, 0.8, 0.9)
            btn:SetBackdropBorderColor(0.0, 0.8, 1.0, 1.0)
            btn.text:SetTextColor(1, 1, 1, 1)
        else
            btn:SetBackdropColor(0.15, 0.17, 0.22, 0.8)
            btn:SetBackdropBorderColor(0.25, 0.3, 0.38, 0.5)
            btn.text:SetTextColor(0.8, 0.8, 0.8, 1)
        end
    end

    -- Update Filter Highlight
    for _, btn in ipairs(mainFrame.filterButtons or {}) do
        if btn.filterId == currentFilter then
            btn:SetBackdropColor(0.2, 0.45, 0.7, 0.9)
            btn:SetBackdropBorderColor(0.0, 0.8, 1.0, 1)
        else
            btn:SetBackdropColor(0.15, 0.17, 0.22, 0.8)
            btn:SetBackdropBorderColor(0.25, 0.3, 0.38, 0.5)
        end
    end

    local itemsToDisplay = {}
    local totalCount = 0
    local collectedCount = 0

    if selectedContainerId == "all" then
        local grand = BPC.AnalyzeAll()
        totalCount = grand.total
        collectedCount = grand.collected

        mainFrame.infoBox.title:SetText("All Containers Overview")
        mainFrame.infoBox.sub:SetText("Analyzing 6 containers from Silvermoon City & Umbral Base Camp")

        for _, container in ipairs(BPC.Containers) do
            local res = grand.containers[container.id]
            if res and res.itemsStatus then
                for _, entry in ipairs(res.itemsStatus) do
                    table.insert(itemsToDisplay, {
                        item = entry.item,
                        isCollected = entry.isCollected,
                        containerName = container.name
                    })
                end
            end
        end
    else
        local container = BPC.ContainerMap[selectedContainerId]
        if container then
            local res = BPC.AnalyzeContainer(container)
            totalCount = res.total
            collectedCount = res.collected

            mainFrame.infoBox.title:SetText(container.name)
            mainFrame.infoBox.sub:SetText(string.format("|cffffcc00Vendor:|r %s  |cffffcc00Cost:|r %s", container.vendor, container.cost))

            for _, entry in ipairs(res.itemsStatus) do
                table.insert(itemsToDisplay, {
                    item = entry.item,
                    isCollected = entry.isCollected,
                    containerName = container.name
                })
            end
        end
    end

    -- Update Progress Bar
    local percent = totalCount > 0 and math.floor((collectedCount / totalCount) * 100 + 0.5) or 0
    mainFrame.infoBox.pBar:SetValue(percent / 100)
    mainFrame.infoBox.pBarText:SetText(string.format("Collected: %d / %d (%d%%)", collectedCount, totalCount, percent))
    if percent == 100 then
        mainFrame.infoBox.pBar:SetStatusBarColor(0.0, 0.9, 0.3, 1)
    else
        mainFrame.infoBox.pBar:SetStatusBarColor(0.0, 0.65, 0.9, 1)
    end

    -- Filter items list
    local filteredList = {}
    for _, entry in ipairs(itemsToDisplay) do
        if currentFilter == "all" then
            table.insert(filteredList, entry)
        elseif currentFilter == "missing" and not entry.isCollected then
            table.insert(filteredList, entry)
        elseif currentFilter == "collected" and entry.isCollected then
            table.insert(filteredList, entry)
        end
    end

    -- Render Rows
    local scrollChild = mainFrame.scrollChild
    if scrollChild.rows then
        for _, r in ipairs(scrollChild.rows) do
            r:Hide()
        end
    else
        scrollChild.rows = {}
    end

    local rowY = 0
    for i, entry in ipairs(filteredList) do
        local row = scrollChild.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetSize(470, 30)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.icon = icon

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            nameText:SetPoint("RIGHT", row, "RIGHT", -150, 0)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            local slotText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            slotText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
            slotText:SetJustifyH("RIGHT")
            row.slotText = slotText

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            statusText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            statusText:SetJustifyH("RIGHT")
            row.statusText = statusText

            row:EnableMouse(true)
            row:SetScript("OnMouseDown", function(s, button)
                if button == "LeftButton" and IsControlKeyDown() then
                    if s.sourceID and DressUpItemModifiedAppearance then
                        DressUpItemModifiedAppearance(s.sourceID)
                    elseif s.itemID then
                        local itemLink = "item:" .. s.itemID
                        if DressUpItemLink then
                            DressUpItemLink(itemLink)
                        elseif DressUpLink then
                            DressUpLink(itemLink)
                        end
                    end
                end
            end)
            row:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.2, 0.25, 0.35, 0.8)
                if s.itemID then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:SetItemByID(s.itemID)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cff00ccffCtrl-Click|r to preview appearance", 0.5, 0.8, 1)
                    GameTooltip:Show()
                else
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(s.itemName or "Unknown")
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(s)
                local bg = (s.rowIndex % 2 == 0) and 0.12 or 0.09
                s:SetBackdropColor(bg, bg, bg + 0.03, 0.8)
                GameTooltip:Hide()
            end)

            table.insert(scrollChild.rows, row)
        end

        row.rowIndex = i
        row.itemName = entry.item.name
        row.itemID   = entry.item.itemID
        row.sourceID = entry.item.sourceID
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, rowY)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, rowY)

        local bg = (i % 2 == 0) and 0.12 or 0.09
        row:SetBackdropColor(bg, bg, bg + 0.03, 0.8)
        row:SetBackdropBorderColor(0.2, 0.22, 0.28, 0.3)

        -- Icon rendering: exact WoW game icon ID directly from Data.lua!
        local iconTex = entry.item.icon or 134400
        row.icon:SetTexture(iconTex)

        -- Name
        local qColor = GetQualityColor(entry.item.quality)
        row.nameText:SetText(string.format("%s%s|r", qColor, entry.item.name))

        -- Slot
        row.slotText:SetText(string.format("|cff888888%s|r", entry.item.slot or ""))

        -- Status
        if entry.isCollected then
            row.statusText:SetText("|cff00ff00✓ Unlocked|r")
        else
            row.statusText:SetText("|cffff4444✗ Missing|r")
        end

        row:Show()
        rowY = rowY - 32
    end

    scrollChild:SetHeight(math.abs(rowY) + 10)
end

function BPC.ToggleUI()
    local ok, err = pcall(function()
        local ui = mainFrame or BPC.CreateUI()
        if ui:IsShown() then
            ui:Hide()
        else
            ui:Show()
            BPC.UpdateUI()
        end
    end)
    if not ok then
        print("|cffff4444[BPC Error]|r ToggleUI failed: " .. tostring(err))
    end
end

