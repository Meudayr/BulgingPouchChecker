local addonName, BPC = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")

-- ============================================================
-- Slash commands (Registered Early)
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
        elseif cmd == "help" then
            print("|cff00ccff[Bulging Pouch Checker]|r Commands:")
            print("  /bpc — Toggle main window")
            print("  /bpc summary — Print collection summary to chat")
        else
            if BPC.ToggleUI then
                BPC.ToggleUI()
            elseif BPC.PrintSummary then
                BPC.PrintSummary()
            end
        end
    end)
    if not ok then
        print("|cffff4444[BPC Error]|r Command failed: " .. tostring(err))
    end
end

-- ============================================================
-- CanIMogIt-style Transmog Check
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
-- Auctionator Export & Missing Items Helper
-- ============================================================
function BPC.GetMissingItems(containerId)
    local missing = {}
    if containerId == "all" or not containerId then
        local grand = BPC.AnalyzeAll()
        for _, container in ipairs(BPC.Containers) do
            local res = grand.containers[container.id]
            if res and res.itemsStatus then
                for _, entry in ipairs(res.itemsStatus) do
                    if not entry.isCollected then
                        table.insert(missing, entry.item.name)
                    end
                end
            end
        end
    else
        local container = BPC.ContainerMap[containerId]
        if container then
            local res = BPC.AnalyzeContainer(container)
            if res and res.itemsStatus then
                for _, entry in ipairs(res.itemsStatus) do
                    if not entry.isCollected then
                        table.insert(missing, entry.item.name)
                    end
                end
            end
        end
    end
    return missing
end

function BPC.ExportToAuctionator(containerId)
    local missingNames = BPC.GetMissingItems(containerId)
    if #missingNames == 0 then
        print("|cff00ccff[Bulging Pouch Checker]|r No missing items to export for this view!")
        return
    end

    local listName = "BPC: All Missing"
    if containerId ~= "all" and BPC.ContainerMap[containerId] then
        listName = "BPC: " .. BPC.ContainerMap[containerId].name
    end

    local auctionatorCreated = false
    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.CreateShoppingList then
        local ok, err = pcall(Auctionator.API.v1.CreateShoppingList, "BulgingPouchChecker", listName, missingNames)
        if ok then
            auctionatorCreated = true
            print(string.format("|cff00ccff[Bulging Pouch Checker]|r Created Auctionator shopping list |cffffcc00\"%s\"|r with %d missing item(s)!", listName, #missingNames))
        else
            print("|cffff4444[BPC Error]|r Auctionator export failed: " .. tostring(err))
        end
    end

    if BPC.ShowExportDialog then
        BPC.ShowExportDialog(listName, missingNames, auctionatorCreated)
    end
end

-- ============================================================
-- Auction Price & Expected Value Helpers
-- ============================================================
function BPC.FormatMoney(copper)
    if not copper or copper <= 0 then return "|cff888888-|r" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    if gold > 0 then
        if BreakUpLargeNumbers then
            return string.format("|cffffd700%s|rg", BreakUpLargeNumbers(gold))
        else
            return string.format("|cffffd700%d|rg", gold)
        end
    elseif silver > 0 then
        return string.format("|cffc7c7cf%d|rs", silver)
    else
        return string.format("|cffa0522d%d|rc", copper % 100)
    end
end

function BPC.GetItemAHPrice(itemID)
    if not itemID then return nil end

    if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "BulgingPouchChecker", itemID)
        if ok and price and price > 0 then return price end
    end

    if Auctionator and Auctionator.Database and Auctionator.Database.GetPrice then
        local ok, price = pcall(Auctionator.Database.GetPrice, Auctionator.Database, tostring(itemID))
        if ok and price and price > 0 then return price end
    end

    if TSM_API and TSM_API.GetCustomPriceValue then
        local ok, price = pcall(TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. itemID)
        if ok and price and price > 0 then return price end
    end

    return nil
end

function BPC.GetContainerPricing(container)
    if not container or not container.items then
        return { ev = 0, totalVal = 0, missingVal = 0, pricedCount = 0, totalItems = 0 }
    end

    local totalPrice = 0
    local missingPrice = 0
    local pricedCount = 0
    local totalItems = #container.items

    for _, item in ipairs(container.items) do
        local price = BPC.GetItemAHPrice(item.itemID)
        if price and price > 0 then
            totalPrice = totalPrice + price
            pricedCount = pricedCount + 1

            local hasMog = BPC.PlayerHasTransmog(item)
            if not hasMog then
                missingPrice = missingPrice + price
            end
        end
    end

    local ev = (totalItems > 0 and pricedCount > 0) and math.floor(totalPrice / totalItems) or 0
    return {
        ev = ev,
        totalVal = totalPrice,
        missingVal = missingPrice,
        pricedCount = pricedCount,
        totalItems = totalItems
    }
end

function BPC.GetAllContainersPricing()
    local grandEV, grandTotalVal, grandMissingVal = 0, 0, 0
    local totalContainers = #BPC.Containers

    for _, container in ipairs(BPC.Containers) do
        local pricing = BPC.GetContainerPricing(container)
        if pricing.ev > 0 then
            grandEV = grandEV + pricing.ev
        end
        grandTotalVal = grandTotalVal + pricing.totalVal
        grandMissingVal = grandMissingVal + pricing.missingVal
    end

    local avgEV = (totalContainers > 0) and math.floor(grandEV / totalContainers) or 0
    return {
        ev = avgEV,
        totalVal = grandTotalVal,
        missingVal = grandMissingVal
    }
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
                local pricing = BPC.GetContainerPricing(cData)
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ccffBulging Pouch Checker|r")
                local pc = res.missing == 0 and "|cff00ff00" or "|cffffcc00"
                tooltip:AddDoubleLine("Progress:", string.format("%s%d/%d (%d%%)|r", pc, res.collected, res.total, res.percent))

                if pricing and pricing.ev > 0 then
                    tooltip:AddDoubleLine("Expected Value:", BPC.FormatMoney(pricing.ev) .. " / pouch")
                end

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
        print("|cff00ccff[Bulging Pouch Checker]|r v1.1.7 loaded. Type |cffffcc00/bpc|r to open.")
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
