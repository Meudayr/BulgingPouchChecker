local addonName, BPC = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")

-- ============================================================
-- CanIMogIt-style Transmog Check (Includes Shared Appearance Sources)
-- ============================================================
function BPC.PlayerHasTransmog(item)
    if not item then return false end

    local sourceID = item.sourceID
    local itemID   = item.itemID

    -- 1. Check direct sourceID for this item
    if sourceID and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        local ok, has = pcall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, sourceID)
        if ok and has then return true end
    end

    -- 2. Check all shared appearance sources for this appearance
    if (sourceID or itemID) and C_TransmogCollection then
        local appearanceID = nil
        if sourceID and C_TransmogCollection.GetAppearanceSourceInfo then
            local info = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
            appearanceID = info and info.itemAppearanceID
        end
        if not appearanceID and itemID and C_TransmogCollection.GetItemInfo then
            appearanceID = C_TransmogCollection.GetItemInfo(itemID)
        end

        if appearanceID and C_TransmogCollection.GetAllAppearanceSources then
            local ok, sourceIDs = pcall(C_TransmogCollection.GetAllAppearanceSources, appearanceID)
            if ok and sourceIDs then
                for _, sID in ipairs(sourceIDs) do
                    if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
                        local ok2, has = pcall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, sID)
                        if ok2 and has then return true end
                    end
                end
            end
        end
    end

    -- 3. Fallback: PlayerHasTransmog by itemID
    if itemID and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
        local ok, has = pcall(C_TransmogCollection.PlayerHasTransmog, itemID)
        if ok and has then return true end
    end

    return false
end

-- ============================================================
-- Analysis Engine
-- ============================================================
function BPC.AnalyzeContainer(container)
    local total, collected = 0, 0
    local itemsStatus = {}
    if container and container.items then
        total = #container.items
        for _, item in ipairs(container.items) do
            local hasMog = BPC.PlayerHasTransmog(item)
            if hasMog then collected = collected + 1 end
            table.insert(itemsStatus, {
                item = item,
                isCollected = hasMog
            })
        end
    end
    return {
        container   = container,
        total       = total,
        collected   = collected,
        missing     = total - collected,
        percent     = total > 0 and math.floor((collected / total) * 100 + 0.5) or 0,
        itemsStatus = itemsStatus
    }
end

function BPC.AnalyzeAll()
    local grandTotal, grandCollected = 0, 0
    local results = {}
    for _, container in ipairs(BPC.Containers) do
        local res = BPC.AnalyzeContainer(container)
        results[container.id] = res
        grandTotal     = grandTotal     + res.total
        grandCollected = grandCollected + res.collected
    end
    return {
        containers = results,
        total      = grandTotal,
        collected  = grandCollected,
        missing    = grandTotal - grandCollected,
        percent    = grandTotal > 0 and math.floor((grandCollected / grandTotal) * 100 + 0.5) or 0,
    }
end

function BPC.PrintSummary()
    local data = BPC.AnalyzeAll()
    print("|cff00ccff[Bulging Pouch Checker]|r " .. data.collected .. "/" .. data.total .. " transmogs collected")
    for _, container in ipairs(BPC.Containers) do
        local res = data.containers[container.id]
        if res then
            local color = res.missing == 0 and "|cff00ff00" or "|cffffcc00"
            print(string.format("  %s%s:|r %d/%d (%d%%)", color, container.name, res.collected, res.total, res.percent))
        end
    end
end

-- ============================================================
-- Tooltip Integration for Pouch Items in Bags/Vendors
-- ============================================================
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local itemName = data and data.name
        if not itemName and tooltip.GetItem then itemName = tooltip:GetItem() end
        if not itemName then return end
        local cleanName = string.lower(itemName)
        if not BPC.ContainerNameMap then return end
        for cKey, cData in pairs(BPC.ContainerNameMap) do
            if cleanName:find(cKey, 1, true) then
                local res = BPC.AnalyzeContainer(cData)
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ccffBulging Pouch Checker|r")
                local pc = res.missing == 0 and "|cff00ff00" or "|cffffcc00"
                tooltip:AddDoubleLine("Progress:", string.format("%s%d/%d (%d%%)|r", pc, res.collected, res.total, res.percent))
                if res.missing > 0 then
                    tooltip:AddLine("|cff888888/bpc to view full list|r")
                else
                    tooltip:AddLine("|cff00ff00All appearances collected!|r")
                end
                tooltip:Show()
                break
            end
        end
    end)
end

-- ============================================================
-- Events & Events Handler
-- ============================================================
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not BulgingPouchCheckerDB then BulgingPouchCheckerDB = {} end
        if BPC.CreateUI then BPC.CreateUI() end
    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        if BPC.UpdateUI and BulgingPouchCheckerFrame and BulgingPouchCheckerFrame:IsShown() then
            BPC.UpdateUI()
        end
    end
end)

function BULGINGPOUCHCHECKER_OnCompartmentClick()
    if BPC.ToggleUI then
        BPC.ToggleUI()
    end
end

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_BULGINGPOUCHCHECKER1 = "/bpc"
SLASH_BULGINGPOUCHCHECKER2 = "/pouch"
SLASH_BULGINGPOUCHCHECKER3 = "/pouchcheck"
SLASH_BULGINGPOUCHCHECKER4 = "/bulgingpouch"

SlashCmdList["BULGINGPOUCHCHECKER"] = function(msg)
    local ok, err = pcall(function()
        local cmd = string.lower(string.match(msg or "", "^%s*(.-)%s*$") or "")

        if cmd == "summary" or cmd == "sum" then
            BPC.PrintSummary()
        else
            if BPC.ToggleUI then
                BPC.ToggleUI()
            else
                BPC.PrintSummary()
            end
        end
    end)
    if not ok then
        print("|cffff4444[BPC Error]|r Command failed: " .. tostring(err))
    end
end
