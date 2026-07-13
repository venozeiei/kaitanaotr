-- ============================================================
-- 🚀 VENOZ EIEI HUB v8 + THUNDER SPEAR QUEST
-- ============================================================
-- Full main script + integrated Thunder Spear (Handle/Thruster/Base)
-- Uses:
--   • Player.Refills (no need for refill box in Forest/Utgard)
--   • Auto-claim Spears quests via Functions/Quest remote
--   • CoreTable quest status check (skip if complete)
--   • Main script's tween combat (anti-shadow-ban)
--   • Main script's Retry/Leave button system
-- ============================================================
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

local DEFAULT_CONFIG = {
    AutoFarm = true, TargetSlot = "A", AutoAntiLag = true, AutoBoostedMap = false,
    StartType = "Missions", MissionMap = "Chapel", MissionObjective = "Skirmish", MissionDifficulty = "Aberrant++",
    AutoUpgrade = true, AutoDeletePerk = true, AntiBanDelay = 10, AutoPrestige = true, PrestigeTarget = 5, AutoQuest = true,
    VenozPrestige = {
        P1 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P2 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P3 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P4 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
        P5 = { TargetBoost = "Gold Boost", RequiredGold = 0 },
    },
    AutoThunderSpearQuest = true, ThunderSpearAtPrestige = 2, AutoBoost = false, BoostTypes = {}, BoostExpUntilPrestige = 0,
    TrackerUpdateInterval = 2, BoostCheckInterval = 10, CombatLoopInterval = 0.1, DataFetchInterval = 8, MinGemsToBuyBoosts = 999999,
    Disable3D = false, Modifiers = {"No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple"}, HitAll = true
}

getgenv().Venoz_Config = getgenv().Venoz_Config or {}
local Config = getgenv().Venoz_Config
for k, v in pairs(DEFAULT_CONFIG) do
    if Config[k] == nil then Config[k] = v end
end

_G.AutoFarm = Config.AutoFarm
_G.TargetSlot = Config.TargetSlot
_G.CurrentAction = "Initializing..."
_G.SessionStartTime = _G.SessionStartTime or os.time() 

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
task.wait(1)

local plr = Players.LocalPlayer
local placeId = game.PlaceId
local Remotes = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local GET = Remotes:WaitForChild("GET", 10)
local POST = Remotes:WaitForChild("POST", 10)   -- RemoteEvent — ใช้เติมดาบ/แก๊ส

-- ============================================================
-- 🖥️ DISABLE 3D RENDERING (ZERO GPU MODE)
-- ============================================================
if Config.Disable3D and not _G.Disabled3D then
    _G.Disabled3D = true
    task.spawn(function()
        pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(false) end)
        pcall(function()
            local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Map_Elements") or workspace:FindFirstChild("Terrain")
            if map then map:Destroy() end
        end)
    end)
end

-- ============================================================
-- 🔧 EXECUTOR COMPATIBILITY LAYER
-- ============================================================
local _unpack       = table.unpack or unpack
local _getconn      = getconnections or get_signal_cons or function() return {} end
local _firesignal   = firesignal or fireclickdetector or function() end
local _getgc        = getgc or function() return {} end
local _runOnActor   = run_on_actor or getgenv().run_on_actor or nil

local function safeGetConn(sig)
    local ok, r = pcall(_getconn, sig)
    return (ok and type(r) == "table") and r or {}
end
local function safeFireSignal(sig)
    pcall(_firesignal, sig)
end

-- ============================================================
-- ⚡ THUNDER SPEAR GLOBALS
-- ============================================================
_G.ThunderSpearMode = false
_G.ThunderSpearMap = nil  -- "Outskirts" / "Utgard" / "Forest"
_G.ThunderSpearPart = nil -- "Handle" / "Thruster" / "Base"

-- Map IDs
local THUNDER_MAP_IDS = {
    Outskirts = { [13904207646] = true, [17373824844] = true },
    Utgard    = { [15220308770] = true, [18182863694] = true },
    Forest    = { [14638336319] = true, [17373828240] = true },
}

local MAP_TO_PART = {
    Outskirts = "Handle",
    Utgard    = "Thruster",
    Forest    = "Base",
}

local ALL_SPEARS_TAGS = {
    "Towers", "Escort", "Ice Burst Stones",
    "Retrieve Missing Supplies", "Defend Missing Supplies",
}

local QUEST_MAP = {
    Handle   = { "Towers", "Escort" },
    Thruster = { "Ice Burst Stones" },
    Base     = { "Retrieve Missing Supplies", "Defend Missing Supplies" },
}

-- 🎯 Item names for each Thunder Spear part
local SPEARS_ITEM_NAMES = {
    Handle   = "Thunder Spear - Handle",
    Thruster = "Thunder Spear - Thruster",
    Base     = "Thunder Spear - Base",
}

-- Detect current map
local function detectThunderMap()
    for name, ids in pairs(THUNDER_MAP_IDS) do
        if ids[game.PlaceId] then return name end
    end
    return nil
end

_G.ThunderSpearMap = detectThunderMap()
_G.ThunderSpearPart = _G.ThunderSpearMap and MAP_TO_PART[_G.ThunderSpearMap] or nil

-- ============================================================
-- 🎯 INVENTORY-BASED CHECK (แม่นยำที่สุด!)
--   ถ้ามี item "Thunder Spear - <Part>" ใน inventory = ทำเสร็จแล้ว
--   ใช้ server data โดยตรง — ไม่พึ่ง CoreTable
-- ============================================================
local function hasItemInInventory(inventory, itemName)
    if type(inventory) ~= "table" then return false end
    for _, category in pairs(inventory) do
        if type(category) == "table" then
            for name, amount in pairs(category) do
                if name == itemName and tonumber(amount) and tonumber(amount) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

-- ดึง inventory สดจาก server (ผ่าน Settings remote)
local function fetchServerInventory()
    local ok, result = pcall(function()
        return GET:InvokeServer("Functions", "Settings", "Blur", "Off")
    end)
    if not ok or type(result) ~= "table" or not result.Slots then return nil end
    local slot = result.Slots[plr:GetAttribute("Slot") or _G.TargetSlot or "A"]
    return slot and slot.Inventory
end

-- ตรวจว่า Thunder Spear part นี้ได้แล้วหรือยัง (จาก inventory)
local function hasThunderSpearPart(partName, inventory)
    inventory = inventory or fetchServerInventory()
    if not inventory then return false end
    local itemName = SPEARS_ITEM_NAMES[partName]
    if not itemName then return false end
    return hasItemInInventory(inventory, itemName)
end

-- ตรวจว่ามี Thunder Spear ครบทั้ง 3 ไหม (จาก inventory)
local function hasAllThunderSpears(inventory)
    inventory = inventory or fetchServerInventory()
    if not inventory then return false end
    for _, part in ipairs({"Handle", "Thruster", "Base"}) do
        if not hasThunderSpearPart(part, inventory) then return false end
    end
    return true
end

-- เลือก quest map ถัดไปที่ยังไม่มี item
local function getNextIncompleteMapByItem(inventory)
    inventory = inventory or fetchServerInventory()
    if not inventory then return "Forest" end  -- fallback
    if not hasThunderSpearPart("Base", inventory) then return "Forest" end
    if not hasThunderSpearPart("Thruster", inventory) then return "Utgard" end
    if not hasThunderSpearPart("Handle", inventory) then return "Outskirts" end
    return nil
end

-- ============================================================
-- 🎯 SERVER-BASED SPEARS QUEST CHECK (persist ข้าม lobby/mission)
--   อ่านสถานะ Spears quest จาก server data โดยตรง
--   ใช้เช็คว่าเควสไหน Rewarded=true (สำหรับ Escort mode decision)
-- ============================================================
local function fetchSpearsQuestsFromServer()
    local ok, res = pcall(function()
        return GET:InvokeServer("Functions", "Settings", "Blur", "Off")
    end)
    if not ok or type(res) ~= "table" or not res.Slots then return {} end
    local slot = res.Slots[plr:GetAttribute("Slot") or _G.TargetSlot or "A"]
    if not slot or not slot.Quests or not slot.Quests.Spears then return {} end
    local result = {}
    for k, q in pairs(slot.Quests.Spears) do
        if type(q) == "table" then
            result[tostring(k)] = {
                Tag = tostring(q.Tag or ""),
                Current = tonumber(q.Current) or 0,
                Rewarded = q.Rewarded == true,
            }
        end
    end
    return result
end

-- เช็ค quest ตาม tag
local function isSpearsQuestClaimed(tag)
    local quests = fetchSpearsQuestsFromServer()
    for _, q in pairs(quests) do
        if q.Tag == tag then return q.Rewarded == true end
    end
    return false
end

-- ============================================================
-- 🛠️ SHARED UTILS
-- ============================================================
local function safeInvokeServer(remote, timeout, ...)
    local args = table.pack(...)
    local currentThread = coroutine.running()
    local finished = false
    local success = false
    local result = nil
    local yielded = false
    task.spawn(function()
        local s, res = pcall(function() return remote:InvokeServer(_unpack(args, 1, args.n)) end)
        if not finished then
            finished = true
            success, result = s, res
            if yielded then task.spawn(currentThread, s, res) end
        end
    end)
    task.delay(timeout, function()
        if not finished then
            finished = true
            success, result = false, nil
            if yielded then task.spawn(currentThread, false, nil) end
        end
    end)
    if not finished then
        yielded = true
        success, result = coroutine.yield()
    end
    return success and result or nil
end

local function forceClickGui(element)
    if not element then return false end
    pcall(function()
        local btn = element
        if not btn:IsA("GuiButton") then
            local curr = element.Parent
            for i = 1, 3 do
                if not curr then break end
                if curr:IsA("GuiButton") then btn = curr break end
                curr = curr.Parent
            end
        end
        if btn:IsA("GuiButton") and getconnections then
            for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(btn.Activated)) do pcall(function() conn:Fire() end) end
        end
        local absPos = element.AbsolutePosition
        local absSize = element.AbsoluteSize
        local inset = game:GetService("GuiService"):GetGuiInset()
        local cX = absPos.X + absSize.X / 2
        local cY = absPos.Y + absSize.Y / 2 + inset.Y
        pcall(function() game:GetService("VirtualUser"):ClickButton1(Vector2.new(cX, cY)) end)
    end)
    return true
end
_G.forceClickGui = forceClickGui

-- ============================================================
-- ⚡ THUNDER SPEAR HELPERS
-- ============================================================
local function getSpearsQuests()
    -- อ่านผ่าน bindable actor (สร้างทีหลัง)
    local ok, quests = pcall(function()
        local bind = MarketplaceService:FindFirstChild("Remote")
        if bind then return bind:Invoke("CALL", "GetSpearsQuests") end
    end)
    if ok and type(quests) == "table" then return quests end

    -- Fallback: อ่าน getgc ตรงๆ
    local result = {}
    pcall(function()
        for _, v in pairs(_getgc(true)) do
            if type(v) == "table" and rawget(v, "Cache")
            and type(v.Cache) == "table" and rawget(v.Cache, "Data") then
                local data = v.Cache.Data
                if data.Slots then
                    local slot = data.Slots[plr:GetAttribute("Slot") or _G.TargetSlot or "A"]
                    if slot and slot.Quests and slot.Quests.Spears then
                        for k, q in pairs(slot.Quests.Spears) do
                            if type(q) == "table" then
                                result[tostring(k)] = {
                                    Tag = tostring(q.Tag or ""),
                                    Current = tonumber(q.Current) or 0,
                                    Rewarded = q.Rewarded == true,
                                }
                            end
                        end
                    end
                end
                break
            end
        end
    end)
    return result
end

local function isSpearsQuestDone(tag, quests)
    quests = quests or getSpearsQuests()
    for _, q in pairs(quests) do
        if q.Tag == tag then return q.Rewarded == true end
    end
    return false
end

local function isPartComplete(partName, quests)
    quests = quests or getSpearsQuests()
    local tags = QUEST_MAP[partName]
    if not tags then return false end
    for _, tag in ipairs(tags) do
        if not isSpearsQuestDone(tag, quests) then return false end
    end
    return true
end

local function areAllSpearsComplete(quests)
    quests = quests or getSpearsQuests()
    for _, part in ipairs({"Handle", "Thruster", "Base"}) do
        if not isPartComplete(part, quests) then return false end
    end
    return true
end

-- Auto-claim ทั้ง 5 เควส Spears (ยิงหลายครั้งกัน server sync ช้า)
local function claimAllSpearsQuests()
    local claimedAny = false
    for _, tag in ipairs(ALL_SPEARS_TAGS) do
        -- ยิง 3 ครั้งต่อ tag (เผื่อ server ไม่ตอบครั้งแรก)
        for attempt = 1, 3 do
            local ok, res = pcall(function()
                return GET:InvokeServer("Functions", "Quest", tag, "Spears")
            end)
            if ok and res then
                claimedAny = true
                print(string.format("[TS] 🎁 Claimed: %s (attempt %d)", tag, attempt))
                break
            end
            task.wait(0.1)
        end
    end
    return claimedAny
end

-- 🖱️ Click CLAIM button ใน UI โดยตรง (fallback ถ้า remote ไม่ทำงาน)
local function clickAllClaimButtons()
    local clicked = 0
    pcall(function()
        local pGui = plr:FindFirstChild("PlayerGui")
        if not pGui then return end

        local function scan(root, depth)
            if depth > 8 then return end
            for _, ch in ipairs(root:GetChildren()) do
                if (ch:IsA("TextButton") or ch:IsA("TextLabel")) then
                    local text = string.upper(tostring(ch.Text or ""))
                    if text == "CLAIM" and ch.Visible
                    and ch.AbsolutePosition.X > 10 and ch.AbsolutePosition.Y > 10 then
                        local btn = ch
                        if not btn:IsA("GuiButton") then
                            local p = ch.Parent
                            for _ = 1, 3 do
                                if not p then break end
                                if p:IsA("GuiButton") then btn = p; break end
                                p = p.Parent
                            end
                        end
                        if btn:IsA("GuiButton") then
                            pcall(function()
                                if getconnections then
                                    for _, c in ipairs(getconnections(btn.MouseButton1Click) or {}) do
                                        pcall(function() c:Fire() end)
                                    end
                                    for _, c in ipairs(getconnections(btn.Activated) or {}) do
                                        pcall(function() c:Fire() end)
                                    end
                                end
                                if firesignal then
                                    pcall(function() firesignal(btn.MouseButton1Click) end)
                                    pcall(function() firesignal(btn.Activated) end)
                                end
                            end)
                            clicked = clicked + 1
                        end
                    end
                end
                scan(ch, depth + 1)
            end
        end
        scan(pGui, 0)
    end)
    if clicked > 0 then
        print(string.format("[TS] 🖱️ Clicked %d CLAIM button(s) in UI", clicked))
    end
    return clicked
end

-- เลือก quest map ถัดไปที่ยังไม่เสร็จ
local function getNextIncompleteMap()
    local quests = getSpearsQuests()
    if not isPartComplete("Base", quests) then return "Forest" end
    if not isPartComplete("Thruster", quests) then return "Utgard" end
    if not isPartComplete("Handle", quests) then return "Outskirts" end
    return nil
end

-- แสดง log สถานะเควส
local function logSpearsStatus()
    claimAllSpearsQuests()
    task.wait(0.3)
    local quests = getSpearsQuests()
    print("═══════════════════════════════════════════")
    print("⚡ THUNDER SPEAR STATUS")
    print("═══════════════════════════════════════════")
    for _, k in ipairs({"1","2","3","4","5"}) do
        local q = quests[k]
        if q then
            local icon = q.Rewarded and "✅" or (q.Current > 0 and "🔄" or "⏳")
            print(string.format("%s [Q%s] %s Current=%d Rewarded=%s",
                icon, k, q.Tag, q.Current, tostring(q.Rewarded)))
        end
    end
    print("---")
    for _, part in ipairs({"Handle", "Thruster", "Base"}) do
        print(string.format("%s %s",
            isPartComplete(part, quests) and "✅" or "❌", part))
    end
    print("═══════════════════════════════════════════")
end

-- ============================================================
-- 🧪 CACHED AUTO BOOST SYSTEM
-- ============================================================
local lastBoostCheck = 0

local allQuestTags = {
    "Arm Annihilator", "Casual Explorer", "Cataclysmic Force", "Completionist", 
    "Cooperative Expert", "Critical Demigod", "Critical Legend", "Critical Master", 
    "Critical Sniper", "Currency Emperor", "Damage Dynamo", "Dedicated Adventurer", 
    "Defend Missing Supplies", "Demolition Expert", "Destruction Maestro", "Devastating Precision", 
    "Devastation Virtuoso", "Divine Prestige", "Elite Taskmaster", "Endurance Champion", 
    "Escort", "Eye of the Storm", "Fortune Hoarder", "Guardian Angel", "Ice Burst Stones", 
    "Infinite Voyager", "Leg Lacerator", "Legendary Ascendant", "Legendary Quester", 
    "Lifesaver Pro", "Master of Experience", "Master of Missions", "Money Magician", 
    "Novice Adventurer", "Novice Wrecker", "Penny Pincher", "Player's Champion", 
    "Precise Striker", "Prestige Aspirant", "Prestige Challenger", "Prestige Enthusiast", 
    "Prestige Expert", "Prestige Grandmaster", "Raid Commander", "Raid Conqueror", 
    "A New Beginning", "Abnormal Encounters", "Brave the Unknown", "Clearing the Path", "Combat Master", 
    "Defend the Walls", "Eliminate the Threat", "Endless Fight", "Explore the Unknown", "First Blood",
    "Giant Slayer", "Humanity's Hope", "Into the Fray", "Master of Maneuvers", "No Rest for the Weary",
    "On the Offensive", "Path to Victory", "Protect the Innocent", "Reclaim the Territory", "Relentless Assault",
    "Scout's Honor", "Securing the Future", "Stand Your Ground", "Survival Instinct", "Swift Justice", 
    "The Vanguard", "Titan Bane", "Titan Buster", "Titan Hunter", "Titan Killer", 
    "Titan Slayer", "Titan Torturer", "Titan's Nightmare", "Towers", "Treasure Hunter", 
    "Ultimate Champion", "Ultimate Protector", "Wealth Accumulator",
    "Penny Pincher", "Novice Adventurer", "Thunder Spear 1", "Thunder Spear 2", "Thunder Spear 3", "Thunder Spear 4", "Thunder Spear 5"
}

local lastQuestCheck = 0
local function executeAutoQuestLogic()
    if not Config.AutoQuest then return end
    local currentTime = os.time()
    if currentTime < lastQuestCheck then return end
    lastQuestCheck = currentTime + 300
    
    task.spawn(function()
        _G.QuestCache = _G.QuestCache or {}
        local oldAction = _G.CurrentAction
        _G.CurrentAction = "AutoQuest: Accepting Dailies & Weeklies..."
        for i = 1, 4 do
            local d = "Daily " .. i
            if not _G.QuestCache[d] then
                pcall(function() GET:InvokeServer("Functions", "Quest", d, "Daily") end)
                _G.QuestCache[d] = true
                task.wait(0.05)
            end
            local w = "Weekly " .. i
            if not _G.QuestCache[w] then
                pcall(function() GET:InvokeServer("Functions", "Quest", w, "Weekly") end)
                _G.QuestCache[w] = true
                task.wait(0.05)
            end
        end
        _G.CurrentAction = "AutoQuest: Accepting Main & Side Quests..."
        for _, quest in ipairs(allQuestTags) do
            if not _G.QuestCache[quest] then
                pcall(function() GET:InvokeServer("Functions", "Quest", quest, "Main") end)
                task.wait(0.01)
                pcall(function() GET:InvokeServer("Functions", "Quest", quest, "Side") end)
                task.wait(0.01)
                -- Spears category ด้วย
                pcall(function() GET:InvokeServer("Functions", "Quest", quest, "Spears") end)
                _G.QuestCache[quest] = true
                task.wait(0.01)
            end
        end
        _G.CurrentAction = oldAction
    end)
end

local function executeAutoBoostLogic()
    if not Config.AutoBoost or _G.IsPrestigeing then return end
    local currentTime = os.time()
    if currentTime < lastBoostCheck then return end
    pcall(function()
        local prestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
        local level = _G.LastLevel or plr:GetAttribute("Level") or 0
        local boostsNeeded = {}
        if Config.BoostTypes then
            for _, b in ipairs(Config.BoostTypes) do
                if (prestige == 3 or prestige == 4) and b == "XP" then continue end
                if prestige >= 5 and b == "Gold" then continue end
                if prestige >= 5 and b == "XP" and level > 130 then continue end
                table.insert(boostsNeeded, b)
            end
        else
            if prestige <= 3 then table.insert(boostsNeeded, "XP")
            elseif prestige >= 5 and level <= 130 then table.insert(boostsNeeded, "XP") end
            if prestige <= 4 then table.insert(boostsNeeded, "Gold") end
        end
        local actionTaken = false
        for _, boostType in ipairs(boostsNeeded) do
            if actionTaken then break end
            local isActive = false
            pcall(function()
                local bf = plr:FindFirstChild("Boosts")
                if bf then
                    local checkName = (boostType == "XP") and "Experience" or boostType
                    local bv = bf:FindFirstChild(checkName) or bf:FindFirstChild(boostType)
                    if bv and tonumber(bv.Value) and tonumber(bv.Value) > 0 then isActive = true end
                end
            end)
            if isActive then continue end
            local activated = false
            local itemsInv = (_G.LastInventory and _G.LastInventory["Items"]) or {}
            for realItemName, qty in pairs(itemsInv) do
                if tonumber(qty) > 0 and string.find(realItemName, boostType) and string.find(realItemName, "Boost") then
                    local prevAction = _G.CurrentAction
                    _G.CurrentAction = "AutoBoost: Using " .. realItemName
                    local res = safeInvokeServer(GET, 3, "S_Inventory", "Item", realItemName)
                    _G.CurrentAction = prevAction
                    if res ~= nil then activated = true; actionTaken = true; task.wait(0.3); break end
                end
            end
            if activated then continue end
            local gems = _G.LastGems or plr:GetAttribute("Gems") or 0
            local minGems = Config.MinGemsToBuyBoosts or 4500
            if gems < minGems then continue end
            local buyOrder = (boostType == "Gold") and {
                {9, "2x Gold Boost [2h]", 13999}, {8, "2x Gold Boost [1h]", 7999}, {7, "2x Gold Boost [30m]", 4499}
            } or {
                {3, "2x XP Boost [2h]", 13999}, {2, "2x XP Boost [1h]", 7999}, {1, "2x XP Boost [30m]", 4499}
            }
            for _, target in ipairs(buyOrder) do
                local idx, name, price = target[1], target[2], target[3]
                local currentGems = _G.LastGems or plr:GetAttribute("Gems") or 0
                if currentGems >= price then
                    _G.CurrentAction = "AutoBoost: Buying " .. name
                    local res = safeInvokeServer(GET, 5, "S_Market", "Buy", "1_Boosts", idx, 1)
                    if res ~= nil and type(res) ~= "string" then
                        task.wait(0.5)
                        safeInvokeServer(GET, 3, "S_Inventory", "Item", name)
                        actionTaken = true; break
                    end
                end
            end
        end
        if not actionTaken then lastBoostCheck = currentTime + 300
        else lastBoostCheck = currentTime + Config.BoostCheckInterval end
    end)
end

task.spawn(function()
    while true do
        task.wait(Config.BoostCheckInterval)
        if game.PlaceId == 14916516914 then
            executeAutoQuestLogic()
            executeAutoBoostLogic()
        end
    end
end)

-- ============================================================
-- 🛡️ ANTI-AFK
-- ============================================================
task.spawn(function()
    pcall(function() if setfpscap then setfpscap(30) end end)
end)

-- ============================================================
-- 🔥 OPTIMIZED ANTI-LAG
-- ============================================================
if Config.AutoAntiLag and not _G.OptimizedMap then
    _G.OptimizedMap = true
    task.spawn(function()
        pcall(function()
            _G.CurrentAction = "Applying Optimized Anti-Lag..."
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            game.Lighting.GlobalShadows = false
            for _, v in ipairs(game.Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                    v.Enabled = false
                end
            end
            pcall(function() if setfpscap then setfpscap(15) end end)
            pcall(function()
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0
            end)
            local Players = game:GetService("Players")
            local function isEntity(part)
                local current = part
                while current and current ~= workspace do
                    if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") and Players:GetPlayerFromCharacter(current) then return true end
                    if current:IsA("Accessory") or current:IsA("Tool") then return true end
                    current = current.Parent
                end
                return false
            end
            local function optimizePart(v)
                pcall(function()
                    if v:IsA("BasePart") then
                        v.Material = Enum.Material.Plastic
                        v.Reflectance = 0
                        v.CastShadow = false
                        if v:IsA("MeshPart") then v.TextureID = "" end
                        if not isEntity(v) then v.Transparency = 1 end
                    elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
                        v.Enabled = false; v:Destroy()
                    elseif v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
                        if v.Name:lower():find("damage") or v.Name:lower():find("kill") or v.Name:lower():find("text") then
                            v.Enabled = false; v:Destroy()
                        end
                    end
                end)
            end
            task.spawn(function()
                pcall(function() workspace.Terrain:Clear() end)
                local lobbyTargets = {
                    workspace:FindFirstChild("World"),
                    workspace:FindFirstChild("Climbable"),
                    workspace:FindFirstChild("Debris"),
                    workspace:FindFirstChild("Hooks"),
                    workspace:FindFirstChild("Unclimbable"),
                    workspace:FindFirstChild("Points"),
                    workspace:FindFirstChild("Map"),
                    workspace:FindFirstChild("Titans")
                }
                local function hidePart(v)
                    pcall(function()
                        if v:IsA("BasePart") and v.Transparency ~= 1 then
                            v.Transparency = 1; v.Material = Enum.Material.Plastic; v.CastShadow = false
                            if v:IsA("MeshPart") then v.TextureID = "" end
                        elseif (v:IsA("Decal") or v:IsA("Texture")) and v.Transparency ~= 1 then v.Transparency = 1 end
                    end)
                end
                for _, target in ipairs(lobbyTargets) do
                    if target then
                        for _, v in ipairs(target:GetDescendants()) do hidePart(v) end
                        target.DescendantAdded:Connect(hidePart)
                    end
                end
                task.spawn(function()
                    while task.wait(120) do
                        pcall(function() workspace.Terrain:Clear() end)
                    end
                end)
            end)
            for _, v in ipairs(workspace:GetDescendants()) do
                pcall(function() optimizePart(v) end)
            end
            pcall(function()
                local rs = game:GetService("ReplicatedStorage")
                local mods = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("Utilities")
                local eff = mods and mods:FindFirstChild("Effects")
                if eff then
                    local effectsTable = require(eff)
                    if type(effectsTable) == "table" then
                        if effectsTable.Shake then effectsTable.Shake = function() return end end
                        pcall(function() if effectsTable.Shake_Amount ~= nil then effectsTable.Shake_Amount = 0 end end)
                    end
                end
            end)
            local safePlat = Instance.new("Part")
            safePlat.Name = "VenozSafePlat"
            safePlat.Size = Vector3.new(1000, 10, 1000)
            safePlat.Position = Vector3.new(233, 3, 37) 
            safePlat.Anchored = true; safePlat.Transparency = 0.5
            safePlat.Color = Color3.fromRGB(0, 255, 0); safePlat.Material = Enum.Material.Neon
            safePlat.Parent = workspace
            for _, v in ipairs(workspace:GetChildren()) do
                if v == safePlat then continue end
                if v:IsA("Texture") or v:IsA("Decal") then pcall(function() v:Destroy() end)
                elseif v:IsA("BasePart") then
                    if not v.Parent:FindFirstChild("Humanoid") and not string.find(v.Name, "Titan") and not v:GetAttribute("Max_Refills") then
                        pcall(function()
                            v.Material = Enum.Material.SmoothPlastic; v.Reflectance = 0
                            v.Transparency = 1; v.CanCollide = false; v.CastShadow = false
                        end)
                    end
                end
            end
        end)
    end)
end

-- ============================================================
-- 📊 OPTIMIZED TRACKER
-- ============================================================
task.spawn(function()
    pcall(function()
        local targetParent
        pcall(function() targetParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui") end)
        if not targetParent or not pcall(function() local _ = targetParent.Name end) then
            targetParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        end
        if targetParent:FindFirstChild("VenozTracker") then targetParent.VenozTracker:Destroy() end
        local sg = Instance.new("ScreenGui"); sg.Name = "VenozTracker"; sg.ResetOnSpawn = false; sg.Parent = targetParent
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 260, 0, 300); frame.Position = UDim2.new(0, 20, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); frame.BackgroundTransparency = 0.15
        frame.BorderSizePixel = 0; frame.Active = true; frame.Draggable = true 
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8); frame.Parent = sg
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundTransparency = 1
        title.Text = "⚡ VENOZ + THUNDER SPEAR"; title.TextColor3 = Color3.fromRGB(170, 100, 255)
        title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.Parent = frame
        local logText = Instance.new("TextLabel")
        logText.Size = UDim2.new(1, -20, 1, -40); logText.Position = UDim2.new(0, 10, 0, 35)
        logText.BackgroundTransparency = 1; logText.TextXAlignment = Enum.TextXAlignment.Left
        logText.TextYAlignment = Enum.TextYAlignment.Top; logText.TextColor3 = Color3.fromRGB(220, 220, 220)
        logText.Font = Enum.Font.GothamSemibold; logText.TextSize = 12; logText.RichText = true; logText.Parent = frame
        local function formatNumber(n) return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
        local function cleanStr(str)
            if not str then return "Unknown" end
            return string.upper(string.sub(str, 1, 1)) .. string.sub(string.lower(str), 2)
        end
        local function formatTime(seconds)
            if not seconds or seconds <= 0 then return "<font color='#ff3333'>None ❌</font>" end
            local h = math.floor(seconds / 3600); local m = math.floor((seconds % 3600) / 60); local s = math.floor(seconds % 60)
            if h > 0 then return string.format("<font color='#55ff55'>%dh %dm %ds</font>", h, m, s)
            else return string.format("<font color='#55ff55'>%dm %ds</font>", m, s) end
        end
        local cachedInterface = nil
        while task.wait(Config.TrackerUpdateInterval) do 
            pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
            local p = game.Players.LocalPlayer
            if not p then continue end
            local currentTick = os.time()
            if not _G.LastFetch or (currentTick - _G.LastFetch > Config.DataFetchInterval) then
                _G.LastFetch = currentTick
                task.spawn(function()
                    pcall(function()
                        local bindable = MarketplaceService:FindFirstChild("Remote")
                        local slotData = nil
                        if bindable then slotData = bindable:Invoke("CALL", "GetSlotData") end
                        if not slotData then
                            GET:InvokeServer("Functions", "Settings", "Blur", "Off")
                            local sd = GET:InvokeServer("Functions", "Settings", "Blur", "Off")
                            if type(sd) == "table" and sd.Slots then
                                slotData = sd.Slots[p:GetAttribute("Slot") or _G.TargetSlot or "A"]
                            end
                        end
                        if slotData then
                            if slotData.Inventory then _G.LastInventory = slotData.Inventory end
                            if slotData.TotalPerksCount then _G.TotalPerksCount = slotData.TotalPerksCount end
                            if slotData.PerksUUIDs then _G.PerksUUIDs = slotData.PerksUUIDs end
                            if slotData.Currency then _G.LastGold = slotData.Currency.Gold end
                            if slotData.Currencies then _G.LastGems = slotData.Currencies.Gems end
                            if slotData.Progression then
                                _G.LastLevel = slotData.Progression.Level or _G.LastLevel
                                _G.LastPrestige = slotData.Progression.Prestige or _G.LastPrestige
                                _G.LastXP = slotData.Progression.XP or _G.LastXP
                                _G.LastMaxXP = slotData.Progression.Max_XP or _G.LastMaxXP
                            end
                        end
                    end)
                end)
            end
            local gold = _G.LastGold or 0
            local gems = _G.LastGems or 0
            local level = _G.LastLevel or p:GetAttribute("Level") or 0
            local prestige = _G.LastPrestige or p:GetAttribute("Prestige") or 0
            local maxLevelReq = 100 + (prestige * 25)
            local displayXP = math.max(tonumber(_G.LastXP) or 0, tonumber(p:GetAttribute("XP")) or 0)
            local displayMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(p:GetAttribute("Max_XP")) or 0)
            local goldBoostTime = 0; local xpBoostTime = 0
            pcall(function()
                local bf = p:FindFirstChild("Boosts")
                if bf then
                    local g = bf:FindFirstChild("Gold"); local x = bf:FindFirstChild("XP")
                    if g then goldBoostTime = tonumber(g.Value) or 0 end
                    if x then xpBoostTime = tonumber(x.Value) or 0 end
                end
            end)
            local statusStr = ""
            if not cachedInterface then cachedInterface = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("Interface") end
            local inTown = false
            if cachedInterface and cachedInterface:FindFirstChild("Topbar") then inTown = true end
            local currentMap = "Unknown"
            local placeIdToMap = {
                [14352123963] = "Chapel", [14638336319] = "Forest", [17373828240] = "Forest",
                [13904207646] = "Outskirts", [17373824844] = "Outskirts",
                [15220308770] = "Utgard", [18182863694] = "Utgard",
                [17688739434] = "Docks", [110415968652032] = "Docks",
                [15824912319] = "Stohess", [139092911630535] = "Stohess",
                [14916516914] = "Town Central", [13379208636] = "Title Screen"
            }
            pcall(function()
                if workspace:GetAttribute("Boosted_Map") then currentMap = workspace:GetAttribute("Boosted_Map")
                elseif placeIdToMap[game.PlaceId] then currentMap = placeIdToMap[game.PlaceId] end
            end)
            if game.PlaceId == 13379208636 then statusStr = "<font color='#ffaa00'>TITLE</font>"
            elseif inTown then statusStr = "<font color='#00ff00'>LOBBY</font>"
            else statusStr = "<font color='#ff3333'>MISSION</font>" end
            local mapStr = currentMap ~= "Unknown" and currentMap or Config.MissionMap or "Unknown"
            local displayMapString = cleanStr(mapStr)
            _G.LastMapStr = mapStr
            local tsStatus = ""
            if _G.ThunderSpearMode then
                tsStatus = string.format("\n⚡ <font color='#ff00ff'>TS: %s</font>", tostring(_G.ThunderSpearPart or "?"))
            end
            local totalPerks = _G.TotalPerksCount or 0
            local perkColor = totalPerks >= 100 and "#ff3333" or "#aaffaa"
            logText.Text = string.format(
                "🎖️ <b>Level:</b> %d / %d (%s/%s)\n👑 <b>Prestige:</b> P%d\n💰 <b>Gold:</b> %s | 💎 <b>Gems:</b> %s\n🧪 <b>Gold:</b> %s\n🧪 <b>XP:</b> %s\n⚔️ <b>Perks:</b> <font color='%s'>%d</font>\n📍 %s | 🗺️ %s%s\n🔄 <font color='#00ffff'>%s</font>",
                level, maxLevelReq, formatNumber(displayXP), formatNumber(displayMaxXP), prestige, formatNumber(gold), formatNumber(gems),
                formatTime(goldBoostTime), formatTime(xpBoostTime), perkColor, totalPerks,
                statusStr, displayMapString, tsStatus, _G.CurrentAction or "Idle"
            )
        end
    end)
end)

-- ============================================================
-- 🚫 HIDE CORE GUI
-- ============================================================
task.spawn(function()
    while task.wait(5) do
        pcall(function() 
            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false) 
        end)
    end
end)

-- =======================================================
-- 🎮 PHASE 1: TITLE SCREEN
-- =======================================================
if placeId == 13379208636 then
    _G.CurrentAction = "Title Screen: Waiting for Play..."
    task.spawn(function()
        local function getRealVisible(gui)
            local curr = gui
            while curr and curr:IsA("GuiObject") do
                if not curr.Visible then return false end
                curr = curr.Parent
            end
            return true
        end
        while game.PlaceId == 13379208636 do
            pcall(function()
                local pGui = plr:WaitForChild("PlayerGui", 5)
                if pGui then
                    for _, v in ipairs(pGui:GetChildren()) do
                        if (v:IsA("TextButton") or v:IsA("TextLabel")) and getRealVisible(v) then
                            local txt = string.upper(v.Text):match("^%s*(.-)%s*$") or ""
                            if txt == "PLAY" or txt == "SELECT" then
                                local targetBtn = v:IsA("GuiButton") and v or (v.Parent:IsA("GuiButton") and v.Parent or nil)
                                if targetBtn and getRealVisible(targetBtn) then
                                    forceClickGui(targetBtn); task.wait(0.5); break
                                end
                            end
                        end
                    end
                end
                GET:InvokeServer("Functions", "Select", _G.TargetSlot); task.wait(1)
                GET:InvokeServer("Functions", "Teleport", "Lobby"); task.wait(10)
            end)
            task.wait(3)
        end
    end)
    return
end

-- =======================================================
-- 🧠 PHASE 2: THE HUB BRAIN (Lobby)
-- =======================================================
if placeId == 14916516914 then
    _G.CurrentAction = "Loading Town Central..."

    -- 🎁 Persistent Claim Loop — ยิง claim ทุก 5 วิ (จับ reward ที่ค้าง)
    if Config.AutoThunderSpearQuest then
        task.spawn(function()
            task.wait(3)
            while game.PlaceId == 14916516914 do
                pcall(function()
                    claimAllSpearsQuests()
                    task.wait(0.3)
                    clickAllClaimButtons()  -- fallback: click UI button
                end)
                task.wait(5)
            end
        end)
    end

    task.spawn(function()
        local cachedInterface = nil
        local cachedTopbar = nil
        local cachedCurrencies = nil
        local lastInventoryCheck = 0
        
        while game.PlaceId == 14916516914 do
            if _G.MissionTeleporting then 
                _G.CurrentAction = "Waiting for Teleport..."
                task.wait(2); continue 
            end

            pcall(function()
                local currentTime = os.time()
                if currentTime - lastInventoryCheck > 15 then
                    lastInventoryCheck = currentTime
                    _G.CurrentAction = "Checking Stats & Inventory..."
                    local serverData = nil
                    pcall(function() 
                        local b = MarketplaceService:FindFirstChild("Remote")
                        if b then serverData = b:Invoke("CALL", "GetSlotData") end
                    end)
                    if not serverData then
                        serverData = safeInvokeServer(GET, 3, "Functions", "Settings", "Blur", "Off")
                        if serverData and type(serverData) == "table" and serverData.Slots then
                            local slotData = serverData.Slots[plr:GetAttribute("Slot") or "A"]
                            if slotData then
                                local mapped = {}
                                if slotData.Currency then mapped.Currency = { Gold = slotData.Currency.Gold } end
                                if slotData.Progression then mapped.Progression = slotData.Progression end
                                mapped.Inventory = { Perks = {} }
                                mapped.TotalPerksCount = 0
                                mapped.PerksUUIDs = {}
                                if slotData.Perks and type(slotData.Perks.Storage) == "table" then
                                    for k, v in pairs(slotData.Perks.Storage) do
                                        mapped.TotalPerksCount = mapped.TotalPerksCount + 1
                                        if type(v) == "table" and v.Name then
                                            mapped.Inventory.Perks[v.Name] = (mapped.Inventory.Perks[v.Name] or 0) + 1
                                            if not v.Equipped then table.insert(mapped.PerksUUIDs, k) end
                                        end
                                    end
                                end
                                serverData = mapped
                            end
                        end
                    end
                    if serverData and type(serverData) == "table" then
                        if serverData.Inventory then _G.LastInventory = serverData.Inventory end
                        if serverData.PerksUUIDs then _G.PerksUUIDs = serverData.PerksUUIDs; _G.TotalPerksCount = serverData.TotalPerksCount or 0 end
                        if serverData.Progression then
                            _G.LastLevel = serverData.Progression.Level
                            _G.LastPrestige = serverData.Progression.Prestige
                            _G.LastMaxXP = serverData.Progression.Max_XP
                            _G.LastXP = serverData.Progression.XP
                        end
                        if serverData.Currency then _G.LastGold = serverData.Currency.Gold end
                    end
                end
                
                executeAutoQuestLogic()
                executeAutoBoostLogic()
                
                if not cachedInterface then cachedInterface = plr.PlayerGui:FindFirstChild("Interface") end
                if cachedInterface and not cachedTopbar then
                    cachedTopbar = cachedInterface:FindFirstChild("Topbar")
                    if cachedTopbar then
                        local main = cachedTopbar:FindFirstChild("Main")
                        if main then cachedCurrencies = main:FindFirstChild("Currencies") end
                    end
                end
                local function amt(name)
                    if not cachedCurrencies then return 0 end
                    local c = cachedCurrencies:FindFirstChild(name)
                    return c and tonumber((c.Amount.Text:gsub("[,%s]", ""))) or 0
                end
                local gold = amt("Gold")
                if gold > 0 then _G.LastGold = gold end
                local guiGems = amt("Gems")
                if guiGems > 0 then _G.LastGems = guiGems end
                
                local currentPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
                local currentLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
                local requiredPerksToSell = (currentLevel <= 45) and 30 or 100
                if currentTime - lastInventoryCheck < 20 and Config.AutoDeletePerk and _G.PerksUUIDs and #_G.PerksUUIDs >= requiredPerksToSell then
                    _G.CurrentAction = "Auto Selling " .. tostring(#_G.PerksUUIDs) .. " Perks..."
                    pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perk", _G.PerksUUIDs) end)
                    pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perks", _G.PerksUUIDs) end)
                    for _, uuid in ipairs(_G.PerksUUIDs) do
                        pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perk", {uuid}) end)
                        pcall(function() safeInvokeServer(GET, 2, "S_Equipment", "Delete", "Perks", {uuid}) end)
                        task.wait(0.05)
                    end
                    task.wait(1); _G.PerksUUIDs = {}
                end
            end)

            local checkLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
            local checkPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
            local targetLevelReq = 100 + (checkPrestige * 25)
            local checkXP = math.max(tonumber(_G.LastXP) or 0, tonumber(plr:GetAttribute("XP")) or 0)
            local checkMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(plr:GetAttribute("Max_XP")) or 0)
            if checkMaxXP == 0 then checkMaxXP = 999999999 end

            -- ===================================================
            -- ⚡ THUNDER SPEAR TRIGGER CHECK (before Prestige)
            -- ===================================================
            -- ทำเควส Thunder Spear เฉพาะเมื่อ:
            --   • Config.AutoThunderSpearQuest = true
            --   • Prestige >= ThunderSpearAtPrestige (ตั้ง 2 = จุติ 2 ขึ้นไป)
            --   • Level ตัน (>= max ของ prestige)
            --   • XP ตัน (>= max XP)
            --   • ยังมี Thunder Spear ที่ไม่ครบ (เช็คจาก inventory)
            -- ===================================================
            local isTanState = (checkLevel >= targetLevelReq and checkXP >= checkMaxXP)
            local prestigeOK = checkPrestige >= (Config.ThunderSpearAtPrestige or 2)

            -- Claim ก่อน (สำคัญ! เผื่อมีเควสที่ทำครบแล้วแต่ยังไม่ claim)
            if Config.AutoThunderSpearQuest and prestigeOK and isTanState then
                claimAllSpearsQuests()
                task.wait(0.3)
            end

            -- 🎯 เช็คจาก INVENTORY (แม่นยำที่สุด — ไม่พึ่ง CoreTable)
            local inventory = fetchServerInventory() or (_G.LastInventory) or {}
            local hasHandle = hasThunderSpearPart("Handle", inventory)
            local hasThruster = hasThunderSpearPart("Thruster", inventory)
            local hasBase = hasThunderSpearPart("Base", inventory)
            local allDone = (hasHandle and hasThruster and hasBase)
            local shouldDoTS = (Config.AutoThunderSpearQuest and prestigeOK and isTanState and not allDone)

            -- 🔍 Debug log (ทุก 30 วิ)
            _G._LastTSDebug = _G._LastTSDebug or 0
            if os.clock() - _G._LastTSDebug > 30 then
                _G._LastTSDebug = os.clock()
                print(string.format(
                    "[TS DEBUG] shouldDo=%s | AutoTS=%s Prestige=%d>=%d(%s) | ตัน=%s (L%d/%d XP=%d/%d) | Handle=%s Thruster=%s Base=%s | allDone=%s",
                    tostring(shouldDoTS),
                    tostring(Config.AutoThunderSpearQuest),
                    checkPrestige, (Config.ThunderSpearAtPrestige or 2), tostring(prestigeOK),
                    tostring(isTanState), checkLevel, targetLevelReq, checkXP, checkMaxXP,
                    hasHandle and "✅" or "❌",
                    hasThruster and "✅" or "❌",
                    hasBase and "✅" or "❌",
                    tostring(allDone)
                ))
            end

            if shouldDoTS then
                -- Claim ทั้งหมดก่อน (จับที่ยังค้าง)
                claimAllSpearsQuests()
                task.wait(0.3)

                -- อ่าน inventory สดอีกครั้ง (เผื่อ claim ให้ item แล้ว)
                local invAfterClaim = fetchServerInventory() or inventory
                if hasAllThunderSpears(invAfterClaim) then
                    print("[TS] ⚡ Thunder Spear ครบทั้ง 3 ชิ้น! (จาก inventory)")
                    print(string.format("[TS]   Handle=%s Thruster=%s Base=%s",
                        hasThunderSpearPart("Handle", invAfterClaim) and "✅" or "❌",
                        hasThunderSpearPart("Thruster", invAfterClaim) and "✅" or "❌",
                        hasThunderSpearPart("Base", invAfterClaim) and "✅" or "❌"))
                else
                    local nextMap = getNextIncompleteMapByItem(invAfterClaim)
                    if nextMap then
                        -- ⚡ Track attempts (สำรอง)
                        _G._TSAttempts = _G._TSAttempts or {}
                        local partForMap = MAP_TO_PART[nextMap]
                        _G._TSAttempts[partForMap] = (_G._TSAttempts[partForMap] or 0) + 1
                        local attempts = _G._TSAttempts[partForMap]

                        -- ⚡ เลือก objective:
                        --   Outskirts + TOWERS quest CLAIMED = ไม่ต้องสร้างหอ → Escort mode
                        --   Outskirts + attempts >= 2 = fallback → Escort mode
                        --   อื่นๆ → Skirmish (default)
                        local tsObjective = "Skirmish"
                        if nextMap == "Outskirts" then
                            local towersDone = isSpearsQuestClaimed("Towers")
                            if towersDone then
                                tsObjective = "Escort"
                                print("[TS] 🐎 TOWERS CLAIMED แล้ว → ใช้ Escort mode ตรงๆ")
                            elseif attempts >= 2 then
                                tsObjective = "Escort"
                                print(string.format("[TS] 🐎 Attempt #%d → fallback Escort mode",
                                    attempts))
                            end
                        end

                        print(string.format("[TS] ⚡ ตันแล้ว (P%d L%d/%d XP=%d/%d) → ไปทำ %s (Attempt #%d, %s)",
                            checkPrestige, checkLevel, targetLevelReq, checkXP, checkMaxXP,
                            nextMap, attempts, tsObjective))
                        print(string.format("[TS]   Handle=%s Thruster=%s Base=%s",
                            hasThunderSpearPart("Handle", invAfterClaim) and "✅" or "❌",
                            hasThunderSpearPart("Thruster", invAfterClaim) and "✅" or "❌",
                            hasThunderSpearPart("Base", invAfterClaim) and "✅" or "❌"))
                        _G.CurrentAction = string.format("⚡ TS → %s (%s)", nextMap, tsObjective)
                        -- Create mission for that map
                        local char2 = plr.Character
                        local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
                        if root2 then
                            for _, part in ipairs(char2:GetDescendants()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                            root2.CFrame = CFrame.new(233.395, 8.865, 37.525)
                            root2.Anchored = true; task.wait(1); root2.Anchored = false
                        end
                        safeInvokeServer(GET, 3, "S_Missions", "Leave"); task.wait(1)
                        local mapData = {
                            Name = nextMap, Type = "Missions",
                            Objective = tsObjective, Difficulty = "Aberrant",
                            Modifiers = {}
                        }
                        local res = safeInvokeServer(GET, 5, "S_Missions", "Create", mapData)
                        -- ถ้าใช้ Escort mode แล้วสร้างไม่ได้ → fallback Skirmish
                        if res == nil and tsObjective ~= "Skirmish" then
                            print("[TS] ⚠️ "..tsObjective.." สร้างไม่ได้ → ลอง Skirmish")
                            mapData.Objective = "Skirmish"
                            res = safeInvokeServer(GET, 5, "S_Missions", "Create", mapData)
                        end
                        if res == nil then
                            for _, diff in ipairs({"Hard","Normal","Easy"}) do
                                mapData.Difficulty = diff
                                res = safeInvokeServer(GET, 3, "S_Missions", "Create", mapData)
                                if res ~= nil then break end
                                task.wait(0.5)
                            end
                        end
                        if res ~= nil then
                            safeInvokeServer(GET, 3, "S_Missions", "Modify", mapData.Difficulty)
                            safeInvokeServer(GET, 3, "S_Missions", "Start")
                            _G.MissionTeleporting = true
                            task.delay(10, function() _G.MissionTeleporting = false end)
                        end
                        task.wait(2); continue
                    end
                end
            end

            -- ===================================================
            -- 🔥 PRESTIGE (ทำหลัง Thunder Spear เสร็จ)
            -- ===================================================
            local prestigeKey = "P" .. tostring(checkPrestige + 1)
            local pSettings = Config.VenozPrestige and Config.VenozPrestige[prestigeKey] or { TargetBoost = "Gold Boost", RequiredGold = 0 }
            local reqGold = (pSettings.RequiredGold or 0) * 1000000
            local currentGold = _G.LastGold or 0
            local isReadyToPrestige = (isTanState and checkPrestige < Config.PrestigeTarget and currentGold >= reqGold)

            if Config.AutoPrestige and isReadyToPrestige then
                local didPrestige = false
                pcall(function()
                    if currentGold >= reqGold then
                        _G.CurrentAction = "🔥 PRECISION PRESTIGE 🔥"
                        _G.IsPrestigeing = true; didPrestige = true
                        local tracker = game:GetService("CoreGui"):FindFirstChild("VenozTracker")
                        if tracker then tracker.Enabled = false end
                        local MyTalentList = {
                            "Guardian", "Aegisurge", "Deflectra", "Thanatophobia", "Necromantic", 
                            "Steel Frame", "Resilience", "Riposte", "Vengeflare", "Blitzblade", 
                            "Swiftshot", "Crescendo", "Furyforge", "Stalwart", "Quakestrike", 
                            "Stormcharged", "Supernova", "Gambler", "Overslash", "Amputation", 
                            "Surgeshot", "Assassin", "Afterimages", "Bloodthief", "Apotheosis", 
                            "Lifefeed", "Vitalize", "Flashstep", "Gem Fiend", "Cooldown Blitz", 
                            "Mendmaster", "Tactician", "Omnirange"
                        }
                        pcall(function() GET:InvokeServer("S_Equipment", "Talents") end)
                        for _, tagName in ipairs(MyTalentList) do
                            pcall(function()
                                GET:InvokeServer("S_Equipment", "Prestige", {
                                    Boosts = pSettings.TargetBoost or "Gold Boost",
                                    Talents = tagName
                                })
                            end)
                            task.wait(0.3)
                        end
                        if tracker then tracker.Enabled = true end
                        _G.LastLevel = nil; _G.LastPrestige = nil; _G.LastXP = nil
                        _G.HasUpgradedOnce = false; _G.HighestLevelUpgraded = 0
                        _G.SkillCache = {}; _G.QuestCache = {}
                        _G.IsPrestigeing = false
                        task.wait(5)
                    end
                end)
                if didPrestige then task.wait(3); continue end
            end

            if isReadyToPrestige then
                _G.CurrentAction = "Locking Lobby: Waiting Prestige..."
                task.wait(1); continue
            end

            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then _G.CurrentAction = "Waiting for Character..."; task.wait(2); continue end
            
            pcall(function()
                local currentTime = os.clock()
                if Config.AutoUpgrade and (not _G.LastUpgradeTime or (currentTime - _G.LastUpgradeTime >= 60)) then
                    _G.LastUpgradeTime = currentTime
                    _G.CurrentAction = "Upgrading All Equipment..."
                    local bladeUpgrades = { "ODM_Damage", "Blade_Durability", "Crit_Damage", "Crit_Chance", "ODM_Gas", "ODM_Speed", "ODM_Control", "ODM_Range" }
                    for i = 1, 3 do 
                        pcall(function() GET:InvokeServer("Equipment", "Upgrade_All") end)
                        pcall(function() GET:InvokeServer("Equipment", "Grade_Up") end)
                        pcall(function() GET:InvokeServer("Equipment", "Tier_Up") end)
                        for _, stat in ipairs(bladeUpgrades) do 
                            pcall(function() GET:InvokeServer("Equipment", "Upgrade", {stat}) end)
                        end
                        pcall(function() GET:InvokeServer("S_Equipment", "Upgrade_All") end)
                        pcall(function() GET:InvokeServer("S_Equipment", "Grade_Up") end)
                        pcall(function() GET:InvokeServer("S_Equipment", "Tier_Up") end)
                        for _, stat in ipairs(bladeUpgrades) do 
                            pcall(function() GET:InvokeServer("S_Equipment", "Upgrade", {stat}) end)
                        end
                    end
                    _G.CurrentAction = "Upgrading Skill Tree..."
                    local bannedSkills = { ["103"]=true, ["158"]=true, ["163"]=true }
                    for s = 1, 80 do
                        local sStr = tostring(s)
                        if not (s >= 38 and s <= 69) and not bannedSkills[sStr] then
                            pcall(function() GET:InvokeServer("S_Equipment", "Unlock", {sStr}) end)
                        end
                    end
                    pcall(function()
                        GET:InvokeServer("S_Equipment", "Unlock", {"98","97","96","95","94","93","92","91","90"})
                    end)
                    for s = 99, 168 do
                        local sStr = tostring(s)
                        if not bannedSkills[sStr] then
                            pcall(function() GET:InvokeServer("S_Equipment", "Unlock", {sStr}) end)
                        end
                    end
                end

                _G.PreparingNewMap = true
                _G.CurrentAction = "Preparing Mission..."
                local targetMap = "Chapel"
                local targetObjective = Config.MissionObjective
                for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
                root.CFrame = CFrame.new(233.395, 8.865, 37.525)
                root.Anchored = true; task.wait(1); root.Anchored = false
                _G.CurrentAction = "Leaving Old Group..."
                safeInvokeServer(GET, 3, "S_Missions", "Leave"); task.wait(1)
                _G.CurrentAction = "Creating Mission: " .. targetMap
                local desiredDifficulty = Config.MissionDifficulty
                local mapData = { Name = targetMap, Type = Config.StartType, Objective = targetObjective, Difficulty = desiredDifficulty, Modifiers = Config.Modifiers or {} }
                local actualDifficulty = desiredDifficulty
                local resCreate = safeInvokeServer(GET, 5, "S_Missions", "Create", mapData)
                if resCreate == nil then
                    _G.CurrentAction = "Downgrading Difficulty..."
                    local fallbacks = {"Severe", "Aberrant", "Hard", "Normal", "Easy"}
                    local startIndex = 1
                    for i, diff in ipairs(fallbacks) do if diff == desiredDifficulty then startIndex = i break end end
                    for i = startIndex + 1, #fallbacks do
                        mapData.Difficulty = fallbacks[i]
                        resCreate = safeInvokeServer(GET, 3, "S_Missions", "Create", mapData)
                        if resCreate ~= nil then actualDifficulty = fallbacks[i]; break end
                        task.wait(0.5)
                    end
                end
                if resCreate ~= nil then
                    _G.CurrentAction = "Mission Created! Starting..."; task.wait(0.5)
                    safeInvokeServer(GET, 3, "S_Missions", "Modify", actualDifficulty)
                    safeInvokeServer(GET, 3, "S_Missions", "Start")
                    _G.CurrentAction = "Teleporting to Map..."
                    _G.MissionTeleporting = true; task.delay(10, function() _G.MissionTeleporting = false end)
                    task.wait(1)
                end
                _G.PreparingNewMap = false
            end)
            task.wait(1)
        end
    end)
    return
end

-- =======================================================
-- ⚔️ PHASE 3: MISSION MAP
-- =======================================================
_G.VenozScriptID = (_G.VenozScriptID or 0) + 1
local currentID = _G.VenozScriptID
_G.CurrentAction = "Mission Started"

-- 🧹 เคลียร์ flag จาก mission ก่อน
_G.TS_MUST_LEAVE = false
_G.ThunderSpearMode = false
_G._ThrusterClaimed = false  -- reset thruster mid-mission claim flag

local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 9999)
local actor = char:WaitForChild("Actor", 9999)
local TitansFolder = workspace:WaitForChild("Titans", 9999)
local interface = plr:WaitForChild("PlayerGui"):WaitForChild("Interface", 999)

-- ============================================================
-- 🎯 THUNDER SPEAR MISSION DETECTION
-- ============================================================
-- ตรวจว่าเข้ามาในแมพ Thunder Spear หรือไม่ + ยังไม่เสร็จ
-- ============================================================
local TS_ACTIVE = false
local TS_MAP = detectThunderMap()  -- "Outskirts" / "Utgard" / "Forest" / nil
local TS_PART = TS_MAP and MAP_TO_PART[TS_MAP] or nil

if TS_MAP and Config.AutoThunderSpearQuest then
    -- ตรวจว่า part นี้ยังไม่เสร็จ (ใช้ inventory เป็นหลัก)
    task.spawn(function()
        task.wait(2)  -- รอ actor พร้อม
        claimAllSpearsQuests()
        task.wait(0.5)
        local inv = fetchServerInventory() or _G.LastInventory or {}
        if not hasThunderSpearPart(TS_PART, inv) then
            TS_ACTIVE = true
            _G.ThunderSpearMode = true
            _G.ThunderSpearMap = TS_MAP
            _G.ThunderSpearPart = TS_PART
            print(string.format("[TS] ⚡ MISSION MODE: %s → Thunder Spear %s", TS_MAP, TS_PART))
        else
            -- ⚡ Part นี้เสร็จแล้ว → ตรวจว่ามี TS อื่นค้างไหม
            print(string.format("[TS] ✅ %s มีอยู่ใน inventory แล้ว", TS_PART))
            task.wait(1)
            if not hasAllThunderSpears(inv) then
                -- ยังมี TS part ที่ค้าง → LEAVE ไปทำอันต่อไป
                local nextMap = getNextIncompleteMapByItem(inv)
                print("═══════════════════════════════════════════")
                print(string.format("⚡ [TS] ยังมี Thunder Spear ค้าง → ต่อไปทำ: %s", tostring(nextMap)))
                print(string.format("   Handle=%s Thruster=%s Base=%s",
                    hasThunderSpearPart("Handle", inv) and "✅" or "❌",
                    hasThunderSpearPart("Thruster", inv) and "✅" or "❌",
                    hasThunderSpearPart("Base", inv) and "✅" or "❌"))
                print("🚪 LEAVE เพื่อไปทำ TS ถัดไป")
                print("═══════════════════════════════════════════")
                _G.CurrentAction = "🚪 LEAVE → ทำ TS ถัดไป: "..tostring(nextMap)

                -- 🔒 ตั้ง flag ให้ Retry/Leave logic เลือก LEAVE ไม่ใช่ Retry
                TS_ACTIVE = true
                _G.TS_MUST_LEAVE = true
                _G.ThunderSpearMode = true

                -- ยิง LEAVE ซ้ำๆ (mid-mission ก็ leave ได้)
                task.spawn(function()
                    for i = 1, 10 do
                        if not _G.TS_MUST_LEAVE then break end
                        pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
                        task.wait(1.5)
                    end
                end)
            else
                -- ⚡ Thunder Spear ครบทุกอัน → OK ทำ mission ธรรมดา
                print("[TS] 🎉 Thunder Spear ครบทั้ง 3 ชิ้น! → ทำ mission ธรรมดา")
            end
        end
    end)
end

-- ============================================================
-- 🚪 AUTO-LEAVE CHAPEL (ถ้าควรทำ TS แต่หลุดเข้า Chapel)
-- ============================================================
-- ป้องกันกรณี Lobby เริ่มก่อนข้อมูลโหลด → สร้าง Chapel mission
-- แล้วพบว่าจริงๆ ควรทำ TS → LEAVE ทันทีเพื่อกลับ Lobby
-- ============================================================
if not TS_MAP and Config.AutoThunderSpearQuest then
    task.spawn(function()
        task.wait(3)  -- รอสั้นๆ ให้ actor พร้อม
        local checkCount = 0
        while task.wait(5) do  -- เช็คทุก 5 วิ (เดิม 15 = ช้าเกิน)
            checkCount = checkCount + 1

            -- ตรวจว่ายังอยู่ใน mission หรือ Rewards UI ขึ้นแล้ว
            local rewardsUI = interface:FindFirstChild("Rewards")
            if rewardsUI and rewardsUI.Visible then continue end

            -- อ่านสถานะปัจจุบัน
            local curLevel = tonumber(_G.LastLevel) or tonumber(plr:GetAttribute("Level")) or 0
            local curPrestige = tonumber(_G.LastPrestige) or tonumber(plr:GetAttribute("Prestige")) or 0
            local curXP = math.max(tonumber(_G.LastXP) or 0, tonumber(plr:GetAttribute("XP")) or 0)
            local curMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(plr:GetAttribute("Max_XP")) or 0)
            local tarLevelReq = 100 + (curPrestige * 25)

            -- ต้องมี MaxXP ที่ valid (ไม่ใช่ 0)
            if curMaxXP == 0 then
                if checkCount % 6 == 0 then
                    print(string.format("[TS AUTO-LEAVE] ⏳ รอ MaxXP โหลด... (L=%d P=%d XP=%d/?)",
                        curLevel, curPrestige, curXP))
                end
                continue
            end

            local isTan = (curLevel >= tarLevelReq and curXP >= curMaxXP)
            local prstOK = curPrestige >= (Config.ThunderSpearAtPrestige or 2)

            -- Claim + check status (ใช้ inventory เป็นหลัก)
            claimAllSpearsQuests()
            task.wait(0.3)
            local inv = fetchServerInventory() or _G.LastInventory or {}
            local hHandle = hasThunderSpearPart("Handle", inv)
            local hThruster = hasThunderSpearPart("Thruster", inv)
            local hBase = hasThunderSpearPart("Base", inv)
            local allDone = hHandle and hThruster and hBase

            -- Log ทุก 15 วิ (checkCount % 3 = ทุก 3 loop × 5s = 15s)
            if checkCount % 3 == 0 then
                print(string.format(
                    "[TS AUTO-LEAVE #%d] Prestige=%d>=%d(%s) ตัน=%s(L%d/%d XP=%d/%d) Handle=%s Thruster=%s Base=%s",
                    checkCount, curPrestige, (Config.ThunderSpearAtPrestige or 2), tostring(prstOK),
                    tostring(isTan), curLevel, tarLevelReq, curXP, curMaxXP,
                    hHandle and "✅" or "❌",
                    hThruster and "✅" or "❌",
                    hBase and "✅" or "❌"))
            end

            if prstOK and isTan and not allDone then
                -- ⚡ ควรทำ TS แต่อยู่ Chapel → LEAVE!
                local nextMap = getNextIncompleteMapByItem(inv)
                print("═══════════════════════════════════════════")
                print("⚡ [AUTO-LEAVE] อยู่ Chapel แต่ควรทำ Thunder Spear!")
                print(string.format("   → ต่อไปทำ: %s", tostring(nextMap)))
                print(string.format("   Handle=%s Thruster=%s Base=%s",
                    hHandle and "✅" or "❌",
                    hThruster and "✅" or "❌",
                    hBase and "✅" or "❌"))
                print("🚪 กด LEAVE ต่อเนื่อง 10 ครั้ง")
                print("═══════════════════════════════════════════")
                _G.CurrentAction = "🚪 LEAVE → ทำ TS: "..tostring(nextMap)
                _G.TS_MUST_LEAVE = true

                -- ยิง LEAVE หลายครั้ง (mid-mission ก็ leave ได้)
                for i = 1, 10 do
                    pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
                    pcall(function() GET:InvokeServer("S_Missions", "Retry") end)
                    task.wait(1)
                    if game.PlaceId ~= placeId then break end
                end
                break
            end
        end
    end)
end

-- ============================================================
-- 🔧 RETRY/LEAVE BUTTON FIX (ระบบเดิมของ Venoz)
-- ============================================================
task.spawn(function()
    local rewardsUI = interface:WaitForChild("Rewards", 999)
    local cachedButtons = nil
    local cachedMainInfo = nil
    local cachedBoostElement = nil

    local function clickButtonAdvanced(btn)
        if not btn then return false end
        _G.CurrentAction = "Locking on: " .. btn.Name
        pcall(function() game:GetService("GuiService").SelectedObject = btn end)
        local isLeave = string.find(string.lower(btn.Name), "leave") ~= nil
        local isRetry = string.find(string.lower(btn.Name), "retry") ~= nil

        -- 🚀 กด LEAVE ทันที (ไม่รอ claim — persistent claim loop ใน Lobby จัดการแล้ว)
        pcall(function()
            if isLeave then GET:InvokeServer("S_Missions", "Leave")
            elseif isRetry then GET:InvokeServer("S_Missions", "Retry") end
        end)
        local trackers = {}
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do if v.Name == "VenozTracker" then table.insert(trackers, v) end end
            for _, v in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do if v.Name == "VenozTracker" then table.insert(trackers, v) end end
            for _, t in ipairs(trackers) do t.Enabled = false end
        end)
        local isDisabled = false
        if btn:IsA("GuiButton") then isDisabled = (btn.Active == false) end
        if isDisabled then
            pcall(function() 
                if isLeave then GET:InvokeServer("S_Missions", "Leave") else GET:InvokeServer("S_Missions", "Retry") end
            end)
            pcall(function() for _, t in ipairs(trackers) do t.Enabled = true end end)
            return true
        end
        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(btn.MouseButton1Click) or {}) do pcall(function() conn:Fire() end) end
                for _, conn in ipairs(getconnections(btn.Activated) or {}) do pcall(function() conn:Fire() end) end
                for _, conn in ipairs(getconnections(btn.MouseButton1Down) or {}) do pcall(function() conn:Fire() end) end
            end
            if firesignal then
                pcall(function() firesignal(btn.MouseButton1Click) end)
                pcall(function() firesignal(btn.Activated) end)
            end
        end)
        pcall(function()
            if btn.AbsolutePosition.X > 10 and btn.AbsolutePosition.Y > 10 then
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton1(Vector2.new(btn.AbsolutePosition.X + btn.AbsoluteSize.X/2, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y/2))
            end
        end)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
            if btn.AbsolutePosition.X > 10 and btn.AbsolutePosition.Y > 10 then
                local absPos = btn.AbsolutePosition; local absSize = btn.AbsoluteSize
                local inset = game:GetService("GuiService"):GetGuiInset()
                local cx = absPos.X + (absSize.X / 2); local cy = absPos.Y + (absSize.Y / 2) + inset.Y
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end
        end)
        -- Fallback Remote (ไม่รอ, ยิงเลย)
        pcall(function() 
            if isLeave then GET:InvokeServer("S_Missions", "Leave") else GET:InvokeServer("S_Missions", "Retry") end
        end)
        pcall(function() for _, t in ipairs(trackers) do t.Enabled = true end end)
        return true
    end
    
    while currentID == _G.VenozScriptID and task.wait(0.2) do
        if rewardsUI and rewardsUI.Visible then
            -- ไม่รอ 1.5s แล้ว — คลิกทันที (user ต้องการเร็ว)
            local curLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
            local curPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
            local maxLevelReq = 100 + (curPrestige * 25)
            pcall(function()
                if not cachedMainInfo then
                    local rMain = rewardsUI:FindFirstChild("Main")
                    local rInfo = rMain and rMain:FindFirstChild("Info")
                    cachedMainInfo = rInfo and rInfo:FindFirstChild("Main")
                end
                if cachedMainInfo and not cachedButtons then cachedButtons = cachedMainInfo:FindFirstChild("Buttons") end
                if cachedMainInfo and not cachedBoostElement then cachedBoostElement = cachedMainInfo:FindFirstChild("Boost") end
            end)
            local buttons = cachedButtons
            if buttons then
                local btnRetry = buttons:FindFirstChild("Retry")
                local btnLeave = buttons:FindFirstChild("Leave_2") or buttons:FindFirstChild("Leave")
                local buttonToClick = nil
                local shouldLeaveForPerks = false
                if Config.AutoDeletePerk then
                    local sellTarget = (curLevel <= 45) and 30 or 100
                    if (_G.TotalPerksCount or 0) >= sellTarget then shouldLeaveForPerks = true end
                end
                local isReadyToPrestige = false
                if curLevel >= maxLevelReq and Config.AutoPrestige and curPrestige < Config.PrestigeTarget then
                    local pk = "P" .. (curPrestige + 1)
                    local ps = Config.VenozPrestige and Config.VenozPrestige[pk] or { RequiredGold = 0 }
                    local rq = (ps.RequiredGold or 0) * 1000000
                    if (_G.LastGold or 0) >= rq then isReadyToPrestige = true end
                end

                -- ⚡ Thunder Spear logic:
                --   ทุก TS map: LEAVE หลัง 1 mission เสมอ
                --   Lobby จะ claim reward + เช็ค inventory + สร้าง mission ใหม่ถ้าต้อง
                --   เหตุผล: บอทกวาดทุก titan อยู่แล้ว 1 mission = ครบเควส
                if TS_ACTIVE then
                    buttonToClick = btnLeave

                    -- 🕐 TS MODE: รอ 6 วิก่อนกด LEAVE
                    --    ให้ server sync quest progress + จ่าย item เข้ากระเป๋าให้เสร็จก่อน
                    --    (ถ้ากดออกไวเกิน → Lobby อ่าน inventory ได้ข้อมูลเก่า → เข้าแมพซ้ำ)
                    --    ระหว่างรอ: claim เควสไปด้วยเลย
                    print(string.format("[TS] 🕐 %s: รอ server sync 6 วิ ก่อน LEAVE...",
                        tostring(_G.ThunderSpearPart)))
                    _G.CurrentAction = "🕐 รอ sync + claim ก่อน LEAVE"

                    for i = 1, 3 do
                        pcall(function()
                            claimAllSpearsQuests()
                            clickAllClaimButtons()
                        end)
                        task.wait(2)   -- 3 รอบ × 2 วิ = 6 วิ
                    end

                    -- เช็คผลว่าได้ item หรือยัง (แค่ log — ยังไงก็ LEAVE)
                    pcall(function()
                        local inv = fetchServerInventory() or _G.LastInventory or {}
                        print(string.format("[TS] 🚪 LEAVE | Handle=%s Thruster=%s Base=%s",
                            hasThunderSpearPart("Handle", inv)   and "✅" or "❌",
                            hasThunderSpearPart("Thruster", inv) and "✅" or "❌",
                            hasThunderSpearPart("Base", inv)     and "✅" or "❌"))
                    end)

                -- 🚀 ไม่ใช่ TS → กดทันที (ไว เหมือนเดิม)
                elseif _G.TS_MUST_LEAVE then
                    buttonToClick = btnLeave
                elseif isReadyToPrestige then buttonToClick = btnLeave
                elseif shouldLeaveForPerks then buttonToClick = btnLeave
                elseif btnRetry then buttonToClick = btnRetry
                else buttonToClick = btnLeave end
                if buttonToClick then clickButtonAdvanced(buttonToClick) end
            else cachedMainInfo = nil; cachedButtons = nil; cachedBoostElement = nil end
            task.wait(0.5)  -- รอสั้นๆ ก่อนเช็ครอบหน้า (เดิม 3 วิ = ช้า)
        end
    end
end)

task.spawn(function()
    while currentID == _G.VenozScriptID do
        pcall(function()
            local cc = plr.Character
            if cc and cc:FindFirstChild("HumanoidRootPart") then
                for _, part in ipairs(cc:GetChildren()) do 
                    if part:IsA("BasePart") then part.CanCollide = false end 
                end
            end
        end)
        task.wait(0.1)
    end
end)

-- 🛡️ Anti-Fall Watchdog: ถ้าบอทตกแมพ (Y < -50) → teleport กลับที่สูง
task.spawn(function()
    while currentID == _G.VenozScriptID do
        task.wait(0.5)
        pcall(function()
            local cc = plr.Character
            local hrp = cc and cc:FindFirstChild("HumanoidRootPart")
            local hum = cc and cc:FindFirstChildWhichIsA("Humanoid")
            if hrp and hum and hum.Health > 0 then
                if hrp.Position.Y < -50 then
                    print(string.format("[ANTI-FALL] ⚠️ Y=%d → teleport กลับ", math.floor(hrp.Position.Y)))
                    hrp.Anchored = true
                    -- หา titan ในแมพ
                    local target
                    for _, t in ipairs(TitansFolder:GetChildren()) do
                        if t.Parent then
                            local tRoot = t:FindFirstChild("HumanoidRootPart")
                            if tRoot and tRoot.Position.Y > 0 then
                                target = tRoot.Position + Vector3.new(0, 250, 0)
                                break
                            end
                        end
                    end
                    if not target then
                        -- ไม่มี titan → หา cart/convoy (Escort)
                        for _, m in ipairs(workspace:GetChildren()) do
                            if m.Name:find("Cart") or m.Name:find("Convoy") then
                                local part = m:FindFirstChildWhichIsA("BasePart", true)
                                if part then
                                    target = part.Position + Vector3.new(0, 200, 0)
                                    break
                                end
                            end
                        end
                    end
                    if not target then
                        target = Vector3.new(0, 300, 0)  -- fallback
                    end
                    hrp.CFrame = CFrame.new(target)
                end
            end
        end)
    end
end)

-- ============================================================
-- 🤖 ACTOR — Combat + Refill (+ PlayerRefill + GetSpearsQuests)
-- ============================================================
local script_actor = [[
    local MarketplaceService = game:GetService('MarketplaceService')
    local CoreTable
    while not CoreTable do 
        task.wait(0.05)
        local gc = getgc(true)
        for i,v in pairs(gc) do 
            if type(v) == 'table' and rawget(v, 'Cache') and type(v.Cache) == 'table' and rawget(v.Cache,'Data') then 
                CoreTable = v break
            end
        end
    end
    local Modules = CoreTable.Modules
    local Func = {}
    
    function Func.SlashOnly() CoreTable:Send("Attacks", "Slash", true) end
    function Func.RegisterHitOnly(basePart) 
        CoreTable:Send('Hitboxes', 'Register', basePart, 400, Modules.Zones and Modules.Zones.Time_Difference or 0.125) 
    end
    function Func.ResetState()
        pcall(function()
            local V = CoreTable.Cache.Variables
            if V then
                if V.Reloading ~= nil then V.Reloading = false end
                if V.Action ~= nil then V.Action = false end
                if V.HitLag ~= nil then V.HitLag = false end
                if V.KillCam ~= nil then V.KillCam = false end
                if V.Slash then V.Slash.Slashing = false; V.Slash.Active = false end
            end
            local plr = game:GetService("Players").LocalPlayer
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and root:FindFirstChild("VenozAntiFall") then
                root.VenozAntiFall:Destroy()
            end
        end)
    end
    function Func.BypassRefill()
        pcall(function() CoreTable:Send("Attacks", "Reload") end)
        pcall(function() CoreTable:Send("Equipment", "Reload") end)
        pcall(function() CoreTable:Invoke("Blades", "Reload") end)
        pcall(function() CoreTable:Invoke("Spears", "Reload") end)
    end
    function Func.PlayerRefill()
        -- Server ใช้ Player.Refills เมื่อ targetPart = nil
        pcall(function() CoreTable:Send("Attacks", "Reload", nil) end)
        pcall(function() CoreTable:Send("Equipment", "Reload", nil) end)
    end
    function Func.SupplyReload(targetPart)
        pcall(function() CoreTable:Send("Attacks", "Reload", targetPart) end)
        pcall(function() CoreTable:Send("Equipment", "Reload", targetPart) end)
    end
    function Func.GetSlotData()
        local p = game:GetService("Players").LocalPlayer
        local result = nil
        pcall(function()
            if CoreTable and CoreTable.Cache and CoreTable.Cache.Data and CoreTable.Cache.Data.Slots then
                local slotData = CoreTable.Cache.Data.Slots[p:GetAttribute("Slot") or "A"]
                if slotData then
                    result = {}
                    if slotData.Currency then result.Currency = { Gold = slotData.Currency.Gold } end
                    if slotData.Currencies then result.Currencies = { Gems = slotData.Currencies.Gems } end
                    if slotData.Progression then 
                        result.Progression = { 
                            Level = slotData.Progression.Level, Prestige = slotData.Progression.Prestige, 
                            XP = slotData.Progression.XP, Max_XP = slotData.Progression.Max_XP 
                        } 
                    end
                    local safeInv = { Perks = {} }
                    local totalPerks = 0; local uuids = {}
                    if slotData.Perks and type(slotData.Perks.Storage) == "table" then
                        for k, v in pairs(slotData.Perks.Storage) do
                            totalPerks = totalPerks + 1
                            if type(v) == "table" and v.Name then
                                safeInv.Perks[v.Name] = (safeInv.Perks[v.Name] or 0) + 1
                                if not v.Equipped then table.insert(uuids, k) end
                            end
                        end
                    end
                    result.Inventory = safeInv
                    result.TotalPerksCount = totalPerks
                    result.PerksUUIDs = uuids
                end
            end
        end)
        return result
    end
    function Func.GetSpearsQuests()
        local p = game:GetService("Players").LocalPlayer
        local result = {}
        pcall(function()
            local slot = CoreTable.Cache.Data.Slots[p:GetAttribute("Slot") or "A"]
            if slot and slot.Quests and slot.Quests.Spears then
                for k, q in pairs(slot.Quests.Spears) do
                    if type(q) == "table" then
                        result[tostring(k)] = {
                            Tag = tostring(q.Tag or ""),
                            Current = tonumber(q.Current) or 0,
                            Rewarded = q.Rewarded == true,
                        }
                    end
                end
            end
        end)
        return result
    end
    local remoteFunc = MarketplaceService:WaitForChild('Remote')
    remoteFunc.OnInvoke = function(method, key, ...) 
        if method == 'CALL' and Func[key] then return Func[key](...) end 
    end
]]

local bindable = MarketplaceService:FindFirstChild("Remote")
if bindable then bindable:Destroy() end
bindable = Instance.new("BindableFunction")
bindable.Name = "Remote"
bindable.Parent = MarketplaceService

if actor then task.spawn(function() pcall(function() run_on_actor(actor, script_actor) end) end) end

-- ============================================================
-- ⚡ THUNDER SPEAR MISSION HELPERS
-- ============================================================
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")

-- Ice Burst filter
local function isIceBurst(titan)
    if not titan or not titan.Parent then return false end
    local fake = titan:FindFirstChild("Fake")
    if not fake then return false end
    return fake:FindFirstChild("Blue_Lines") ~= nil
end

-- ============================================================
-- 🗡️ BLADE SYSTEM v5  (ถูกต้องแล้ว!)
-- ============================================================
-- 🔑 remote ที่ถูกต้อง (ยืนยันจาก remote spy):
--
--   เติมดาบ/แก๊ส (Refill):
--     POST:FireServer("Attacks", "Reload", <RefillPart>)
--     RefillPart = workspace.Unclimbable.Reloads.<Station>.Refill
--     ⚠️ เป็น POST (RemoteEvent) ไม่ใช่ GET (RemoteFunction)!
--     → Sets กลับมา 3/3, กิน Player.Refills 1 หน่วย
--
--   สลับใบมีดชุดใหม่:
--     GET:InvokeServer("Blades", "Reload")
--     → Sets −1, ใบมีดในมือกลับมาใหม่
--
-- 🐛 บั๊กเดิม: ยิง GET("Blades","Drop") ซึ่งไม่มีผลอะไรเลย
--             (server รับแต่ไม่ทำ → Refills 3→3 ตลอด)
--             + หาสถานีเติมผิดที่ (workspace ชั้นบน แทน Unclimbable.Reloads)
-- ============================================================
local BLADE = {
    COOLDOWN   = 2.0,    -- หลังยิง remote ห้ามยุ่งกี่วินาที
    brokenSince = nil,
    lastAction = 0,
    gui        = nil,
    refillPart = nil,
}

-- 🔎 cache Blades GUI
task.spawn(function()
    while currentID == _G.VenozScriptID do
        if not (BLADE.gui and BLADE.gui.Parent) then
            pcall(function()
                local hud = interface:FindFirstChild("HUD")
                local top = hud and hud:FindFirstChild("Main") and hud.Main:FindFirstChild("Top")
                if not top then return end
                for _, v in ipairs(top:GetDescendants()) do
                    if v.Name == "Blades"
                    and v:FindFirstChild("Inner")
                    and v:FindFirstChild("Sets") then
                        BLADE.gui = v
                        break
                    end
                end
            end)
        end
        task.wait(2)
    end
end)

-- 📖 Sets (0-3)
local function readSets()
    local g = BLADE.gui
    if not (g and g.Parent) then return nil end
    local s = g:FindFirstChild("Sets")
    if s and s:IsA("TextLabel") then
        return tonumber(string.match(s.Text, "%d+"))
    end
    return nil
end
local function readBladeSets() return readSets() or 3 end

-- ⭐ ดาบพังไหม (อ่านโมเดล 3D จริง)
--    true = พัง, false = ดี, nil = อ่านไม่ได้
local function isBladeBroken()
    local char = plr.Character
    if not char then return nil end
    local rig = char:FindFirstChild("Rig_" .. plr.Name)
    if not rig then return nil end

    local found, broken = false, false
    for _, hand in ipairs(rig:GetChildren()) do
        if hand.Name == "RightHand" or hand.Name == "LeftHand" then
            local b = hand:FindFirstChild("Blade_1")
            if b then
                found = true
                local attr = b:GetAttribute("Broken")
                if attr ~= nil then
                    if attr == true then broken = true end
                elseif b:IsA("BasePart") and b.Transparency ~= 0 then
                    broken = true
                end
            end
        end
    end
    if not found then return nil end
    return broken
end

local function getHRP()
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function partPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local ok, pivot = pcall(function() return inst:GetPivot().Position end)
    return ok and pivot or nil
end

-- ⭐ หาสถานีเติมที่ workspace.Unclimbable.Reloads.<Station>.Refill
--    เลือกอันที่ใกล้ตัวที่สุด
local function findRefillPart()
    if BLADE.refillPart and BLADE.refillPart.Parent then
        return BLADE.refillPart
    end
    BLADE.refillPart = nil

    local unc     = workspace:FindFirstChild("Unclimbable")
    local reloads = unc and unc:FindFirstChild("Reloads")
    if not reloads then return nil end

    local hrp = getHRP()
    local best, bestDist

    for _, station in ipairs(reloads:GetChildren()) do
        local refill = station:FindFirstChild("Refill")
        if refill then
            local pos = partPos(refill)
            local d = (hrp and pos) and (hrp.Position - pos).Magnitude or math.huge
            if not best or d < bestDist then
                best, bestDist = refill, d
            end
        end
    end

    BLADE.refillPart = best
    if best then
        print(string.format("[Blade] 📍 สถานีเติม: %s (%.0f studs)",
            best:GetFullName(), bestDist or -1))
    end
    return best
end

-- 🔫 ยิง remote เติม (POST = RemoteEvent)
local function fireRefill(part)
    pcall(function() POST:FireServer("Attacks", "Reload", part) end)
end

-- 📦 เติมดาบ: ยิงจากที่เดิมก่อน → ไม่ติดค่อยบินไปยืนที่สถานี
local function doRefill()
    local part = findRefillPart()
    if not part then
        if not _G._BladeNoStation then
            _G._BladeNoStation = true
            warn("[Blade] ❌ ไม่พบสถานีเติมใน workspace.Unclimbable.Reloads")
        end
        return
    end

    local setsBefore = readSets() or 0
    local refBefore  = plr:GetAttribute("Refills") or 0

    -- 1️⃣ ลองยิงจากที่เดิมก่อน (เร็ว ไม่ต้องบิน)
    fireRefill(part)
    task.wait(0.6)

    if (readSets() or 0) > setsBefore then
        print(string.format("[Blade] ✅ เติมสำเร็จจากระยะไกล (Sets %d→%d, Refills %d→%d)",
            setsBefore, readSets() or 0, refBefore, plr:GetAttribute("Refills") or 0))
        return
    end

    -- 2️⃣ ไม่ติด → บินไปยืนที่สถานีแล้วยิงซ้ำ
    local hrp = getHRP()
    local pos = partPos(part)
    if not (hrp and pos) then return end

    print("[Blade] 🚁 บินไปสถานีเติม...")
    _G.CurrentAction = "🚁 บินไปเติมดาบ"

    local saved = hrp.CFrame
    hrp.Anchored = false
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.wait(0.35)

    for _ = 1, 3 do
        fireRefill(part)
        if firetouchinterest and part:IsA("BasePart") then
            pcall(function()
                firetouchinterest(hrp, part, 0)
                firetouchinterest(hrp, part, 1)
            end)
        end
        task.wait(0.35)
    end

    local setsAfter = readSets() or 0
    local refAfter  = plr:GetAttribute("Refills") or 0
    print(string.format("[Blade] 🔬 Refill@station | Sets %d→%d | Refills %d→%d",
        setsBefore, setsAfter, refBefore, refAfter))

    -- กลับที่เดิม
    hrp.CFrame = saved
    hrp.Anchored = true
end

-- 🔄 สลับใบมีดชุดใหม่ (ใช้ spare 1 ชุด)
local function bladeReload()
    pcall(function() GET:InvokeServer("Blades", "Reload") end)
end

-- 🧠 ensureBlade — cooldown-based, non-blocking
local function ensureBlade()
    local broken = isBladeBroken()
    if broken == nil then return false end

    -- ✅ ดาบดี
    if not broken then
        if BLADE.brokenSince then
            print(string.format("[Blade] ✅ ดาบพร้อมใช้ (Sets %s/3)", tostring(readSets() or "?")))
        end
        BLADE.brokenSince = nil
        _G._BladeNoRefill = nil
        return true
    end

    -- ❌ ดาบพัง
    if not BLADE.brokenSince then BLADE.brokenSince = os.clock() end

    -- ⏳ cooldown → ปล่อยให้เกมทำ animation จนจบ
    if os.clock() - BLADE.lastAction < BLADE.COOLDOWN then return false end
    BLADE.lastAction = os.clock()

    local sets    = readSets() or 0
    local refills = plr:GetAttribute("Refills") or 0

    if sets > 0 then
        -- มี spare → สลับชุด
        print(string.format("[Blade] 🔄 ดาบพัง → Reload (Sets %d/3)", sets))
        _G.CurrentAction = string.format("🔄 Reload (%d/3)", sets)
        task.spawn(bladeReload)
    else
        -- Sets = 0 → ต้องเติมที่สถานี
        if refills <= 0 then
            if not _G._BladeNoRefill then
                _G._BladeNoRefill = true
                warn("[Blade] 🚫 Refills หมด (0) — เติมไม่ได้จนจบภารกิจ")
            end
            return false
        end
        print(string.format("[Blade] 📦 Sets 0/3 → เติมที่สถานี (Refills %d)", refills))
        _G.CurrentAction = string.format("📦 Refill (%d)", refills)
        task.spawn(doRefill)   -- spawn เพื่อไม่ block combat loop
    end

    return false
end

-- ชื่อเดิมที่ combat loop เรียก
local function tryRefill()
    ensureBlade()
end

-- 📊 Debug ทุก 5 วิ
task.spawn(function()
    while currentID == _G.VenozScriptID do
        task.wait(5)
        local broken = isBladeBroken()
        if broken ~= nil then
            print(string.format("[Blade] 📊 Sets=%s/3  Broken=%s  Refills=%s",
                tostring(readSets() or "?"),
                broken and "YES" or "no",
                tostring(plr:GetAttribute("Refills") or "?")))
        end
    end
end)

-- ค้นหา crate + circle (Base mode)
local function scanCrates()
    local list = {}
    local Unclimbable = workspace:FindFirstChild("Unclimbable")
    if not Unclimbable then return list end
    for _, m in ipairs(Unclimbable:GetChildren()) do
        if m.Name:find("^ThunderSpear_Supplies%d") or m.Name:find("^Supplies%d") then
            local hitbox = m:FindFirstChild("Hitbox")
            if hitbox then
                local spot = m:FindFirstChild("Spot")
                if not (spot and spot.Value) then
                    table.insert(list, { model = m, hitbox = hitbox, name = m.Name })
                end
            end
        end
    end
    return list
end

local function findCircle()
    local Unclimbable = workspace:FindFirstChild("Unclimbable")
    if not Unclimbable then return nil end
    for _, m in ipairs(Unclimbable:GetChildren()) do
        if m.Name == "Supplies_Circle" then
            local hb = m:FindFirstChild("Hitbox")
            if hb then return { model = m, hitbox = hb } end
        end
    end
    return nil
end

-- Touch hitbox (crate/tower/delivery)
local function touchHitbox(hitbox, holdTime)
    holdTime = holdTime or 1.2
    if not hitbox or not hitbox.Parent then return false end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.Anchored = false
    hrp.CFrame = CFrame.new(hitbox.Position + Vector3.new(0, 5, 0))
    task.wait(0.2)
    local endTime = os.clock() + holdTime
    local offsets = {
        Vector3.new(0, 0, 0), Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0),
        Vector3.new(0, 0, 2), Vector3.new(0, 0, -2), Vector3.new(0, -2, 0),
    }
    local i = 1
    while os.clock() < endTime and hrp.Parent do
        hrp.CFrame = CFrame.new(hitbox.Position + offsets[i])
        if firetouchinterest then
            pcall(function() 
                firetouchinterest(hrp, hitbox, 0)
                firetouchinterest(hrp, hitbox, 1)
            end)
        end
        task.wait(0.15)
        i = i % #offsets + 1
    end
    return true
end

-- Build tower (Handle mode)
--   ยืนในวง 22 วิ + re-check character ทุก 2 วิ กัน respawn ทำ hrp stale
local function buildTower(idx)
    local wt = workspace:FindFirstChild("WatchTower_"..idx)
    if not wt then return false end
    local circle = wt:FindFirstChild("Circle")
    local hitbox = circle and circle:FindFirstChild("Hitbox")
    if not hitbox then return false end
    print(string.format("[TS] 🏗️ สร้างหอคอย #%d", idx))
    _G.CurrentAction = string.format("🏗️ Tower %d/3", idx)

    -- Loop 22 วิ: re-check character + re-anchor ทุก 2 วิ
    local endTime = os.clock() + 22
    while os.clock() < endTime do
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildWhichIsA("Humanoid")
        if hrp and hum and hum.Health > 0 then
            hrp.Anchored = false
            hrp.CFrame = CFrame.new(hitbox.Position)
            task.wait(0.1)
            hrp.Anchored = true
        else
            -- character อาจตาย → รอ respawn
            print(string.format("[TS] ⏳ Tower %d: รอ character respawn...", idx))
            task.wait(1)
        end
        task.wait(2)
    end
    print(string.format("[TS] ✅ หอคอย #%d เสร็จ", idx))

    -- Un-anchor หลังเสร็จ (สำคัญ! ให้ combat loop control ต่อ)
    pcall(function()
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end)
    return true
end

-- ============================================================
-- 🎯 THUNDER SPEAR ORCHESTRATOR
-- ============================================================
local TS_STATE = "INIT"  -- HANDLE: KILL_TO_5 → BUILD_TOWERS → KILL_ALL
                          -- BASE:   KILL_TO_MARGIN → COLLECT → KILL_ALL
                          -- THRUSTER: KILL_ICE_BURST
local TS_TOWER_IDX = 1
local TS_CRATE_DELIVERED = 0
local TS_CRATE_VISITED = {}
local TS_ICE_KILLS = 0

-- Track Ice Burst kills
if TS_MAP == "Utgard" then
    local iceBurstTracker = {}
    for _, t in ipairs(TitansFolder:GetChildren()) do
        if isIceBurst(t) then iceBurstTracker[t] = true end
    end
    TitansFolder.ChildAdded:Connect(function(t)
        task.spawn(function()
            for _ = 1, 20 do
                if not t.Parent then return end
                if t:FindFirstChild("Fake") then
                    if isIceBurst(t) then iceBurstTracker[t] = true end
                    return
                end
                task.wait(0.1)
            end
        end)
    end)
    TitansFolder.ChildRemoved:Connect(function(t)
        if iceBurstTracker[t] then
            iceBurstTracker[t] = nil
            TS_ICE_KILLS = TS_ICE_KILLS + 1
            print(string.format("[TS] ❄️ Ice Burst %d/3", TS_ICE_KILLS))
        end
    end)
end

-- ============================================================
-- ⚔️ MAIN COMBAT LOOP (Fast + Thunder Spear integrated)
-- ============================================================
task.spawn(function()
    if not _G.AutoFarm then return end
    local lastTotalHealth = 999999999
    local cycleStuckCount = 0
    local blacklistedTitans = {}
    local cachedRefillPart = nil
    
    while currentID == _G.VenozScriptID and task.wait(Config.CombatLoopInterval) do 
        if not _G.AutoFarm then continue end
        local pGui = plr:FindFirstChild("PlayerGui")
        local currentInterface = interface or (pGui and pGui:FindFirstChild("Interface"))
        if not currentInterface then continue end
        local rewardsUI = currentInterface:FindFirstChild("Rewards")
        if (rewardsUI and rewardsUI.Visible) then continue end
        
        local hum = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
        if not TitansFolder or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or not hum or hum.Health <= 0 then continue end
        local currentRoot = plr.Character.HumanoidRootPart

        -- 🗡️ BLADE: อ่านหลอดแดงจริง → Reload เมื่อหมด, Drop เมื่อ Sets=0
        tryRefill()   -- = ensureBlade()

        -- ============================================================
        -- ⚡ THUNDER SPEAR STATE MACHINE
        -- ============================================================
        if TS_ACTIVE then
            -- HANDLE: Outskirts (kill to 5 → build 3 towers → kill all)
            if TS_MAP == "Outskirts" then
                if TS_STATE == "INIT" then
                    -- ⚡ ถ้าอยู่ใน Escort mode → ข้ามการสร้างหอ (mission มี escort โดยตรง)
                    --   Detect: Objective attribute หรือ WatchTower_1 ไม่มีในแมพ
                    local isEscortMode = false
                    pcall(function()
                        local obj = workspace:GetAttribute("Objective")
                        if obj and string.upper(obj) == "ESCORT" then
                            isEscortMode = true
                        end
                    end)
                    if isEscortMode then
                        TS_STATE = "KILL_ALL"
                        print("[TS] 🐎 Escort mode → ข้ามสร้างหอ, ตี titan defend รถม้าเลย")
                    else
                        TS_STATE = "KILL_TO_5"
                    end
                end
                local aliveCount = 0
                for _, t in ipairs(TitansFolder:GetChildren()) do
                    if t.Parent then
                        local h = t:FindFirstChildWhichIsA("Humanoid")
                        if h and h.Health > 0 then aliveCount = aliveCount + 1 end
                    end
                end
                if TS_STATE == "KILL_TO_5" then
                    _G.CurrentAction = string.format("⚡ KILL_TO_5 (%d alive)", aliveCount)
                    if aliveCount <= 5 then
                        TS_STATE = "BUILD_TOWERS"
                        print("[TS] ✅ เหลือ 5 → สร้างหอคอย")
                    end
                    -- ตกลงมา combat ต่อ (fall through)
                elseif TS_STATE == "BUILD_TOWERS" then
                    if TS_TOWER_IDX <= 3 then
                        local ok = buildTower(TS_TOWER_IDX)
                        TS_TOWER_IDX = TS_TOWER_IDX + 1
                        if TS_TOWER_IDX > 3 then
                            TS_STATE = "KILL_ALL"
                            -- 🔄 Reset combat state (สำคัญ! ให้ combat ทำงานต่อได้)
                            blacklistedTitans = {}
                            cycleStuckCount = 0
                            lastTotalHealth = 999999999
                            -- Un-anchor + refresh character
                            pcall(function()
                                local ch = plr.Character
                                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                                if hrp then hrp.Anchored = false end
                            end)
                            print("[TS] ✅ ครบ 3 หอคอย → รีเซ็ต combat + ตี titan ทั้งหมด")
                        end
                        continue
                    end
                elseif TS_STATE == "KILL_ALL" then
                    _G.CurrentAction = string.format("⚡ KILL_ALL Escort (alive=%d)", aliveCount)
                    -- 🎯 ไม่กด LEAVE mid-mission!
                    -- ปล่อย mission จบธรรมชาติ (Escort ครบ) → Rewards UI ขึ้น
                    -- Retry/Leave logic จะเช็คว่าได้ Handle หรือไม่:
                    --   ✅ ได้ Handle → LEAVE
                    --   ❌ ยังไม่ได้ → RETRY (ทำ mission ซ้ำจนได้)
                    -- Auto-claim ทำงานอยู่แล้วจาก persistent claim loop
                end
            -- THRUSTER: Utgard (kill 3 Ice Burst — แต่ตีทุก titan เพื่อ progress)
            elseif TS_MAP == "Utgard" then
                _G.CurrentAction = string.format("❄️ Ice Burst %d/3 (ตี titan ทั้งหมด)", TS_ICE_KILLS)
                -- 🎯 ตีทุก titan ตลอด mission — Retry/Leave logic จะตัดสินใจเอง
                --   ครบ 3 Ice Burst → Thruster item จะเข้า inventory
                --   Mission จบ → Retry/Leave เช็ค inventory → LEAVE ถ้าได้ / RETRY ถ้ายัง
            -- BASE: Forest (collect crates → deliver → defend)
            elseif TS_MAP == "Forest" then
                if TS_STATE == "INIT" then TS_STATE = "KILL_TO_MARGIN" end
                local Objectives = ReplicatedStorage:FindFirstChild("Objectives")
                local slay = Objectives and Objectives:FindFirstChild("Slay") and Objectives.Slay.Value or 0
                local slayReq = Objectives and Objectives:FindFirstChild("Slay") and Objectives.Slay:GetAttribute("Requirement") or 40
                local ds = Objectives and Objectives:FindFirstChild("Defend_Supplies") and Objectives.Defend_Supplies.Value or nil
                if ds and TS_STATE ~= "KILL_ALL" then
                    TS_STATE = "KILL_ALL"
                    blacklistedTitans = {}; cycleStuckCount = 0; lastTotalHealth = 999999999
                    print("[TS] 🎯 Defend_Supplies active → ตี titan")
                end
                if TS_STATE == "KILL_TO_MARGIN" then
                    local safeMax = slayReq - 5
                    _G.CurrentAction = string.format("⚡ KILL_TO_MARGIN (%d/%d)", slay, safeMax)
                    if slay >= safeMax then
                        TS_STATE = "COLLECT"
                        print("[TS] ✅ margin ถึง → เก็บ crate")
                    end
                elseif TS_STATE == "COLLECT" then
                    local crates = scanCrates()
                    local circle = findCircle()
                    if not circle then
                        TS_STATE = "KILL_ALL"; continue
                    end
                    local available = {}
                    for _, c in ipairs(crates) do
                        if not TS_CRATE_VISITED[c.model] then table.insert(available, c) end
                    end
                    if #available == 0 then
                        TS_STATE = "KILL_ALL"; continue
                    end
                    table.sort(available, function(a, b)
                        return (a.hitbox.Position - currentRoot.Position).Magnitude
                             < (b.hitbox.Position - currentRoot.Position).Magnitude
                    end)
                    local target = available[1]
                    TS_CRATE_VISITED[target.model] = true
                    print(string.format("[TS] 📦 [%d] เก็บ %s", TS_CRATE_DELIVERED + 1, target.name))
                    _G.CurrentAction = string.format("📦 เก็บกล่อง %d", TS_CRATE_DELIVERED + 1)
                    touchHitbox(target.hitbox)
                    task.wait(0.3)
                    print(string.format("[TS] 🚚 [%d] ส่งวงเหลือง", TS_CRATE_DELIVERED + 1))
                    _G.CurrentAction = string.format("🚚 ส่งกล่อง %d", TS_CRATE_DELIVERED + 1)
                    touchHitbox(circle.hitbox)
                    TS_CRATE_DELIVERED = TS_CRATE_DELIVERED + 1
                    task.wait(0.3)
                    continue
                elseif TS_STATE == "KILL_ALL" then
                    _G.CurrentAction = string.format("⚡ KILL_ALL (Defend %s)", tostring(ds or "-"))
                end
            end
        end

        -- ============================================================
        -- ⚔️ COMBAT (ทั้ง TS + normal farming)
        -- ============================================================
        local aliveTitans = {}
        local currentTotalHealth = 0
        local currentTitans = TitansFolder:GetChildren()

        -- 🎯 ไม่ filter ตี titan ทุกตัว (Utgard ก็ตีทุกตัว, Ice Burst นับผ่าน event)
        local filterFn = nil

        for _, titan in ipairs(currentTitans) do
            if blacklistedTitans[titan] then continue end 
            if filterFn and not filterFn(titan) then continue end
            local nape = titan:FindFirstChild("Nape", true)
            local humanoid = titan:FindFirstChildWhichIsA("Humanoid")
            local titanRoot = titan:FindFirstChild("HumanoidRootPart") or nape
            if nape and humanoid and humanoid.Health > 0 and titanRoot then
                local dist = (currentRoot.Position - titanRoot.Position).Magnitude
                table.insert(aliveTitans, { titan = titan, nape = nape, root = titanRoot, dist = dist })
                currentTotalHealth = currentTotalHealth + humanoid.Health
            end
        end

        if #aliveTitans == 0 then 
            if next(blacklistedTitans) ~= nil then blacklistedTitans = {} end

            -- 🛡️ ANTI-FALL: ล็อคตำแหน่งเดิม (ไม่ให้ตก)
            --   ถ้าตกลึกมาก → teleport กลับที่ปลอดภัย
            local currentY = currentRoot.Position.Y
            local safeY = math.max(currentY, 100)
            local safePos = Vector3.new(currentRoot.Position.X, safeY, currentRoot.Position.Z)

            -- ถ้าตกต่ำมาก (Y < 0) → หา titan ตัวไหนก็ได้ในแมพ แล้วบินไปหา
            if currentY < 0 then
                print(string.format("[TS] ⚠️ บอทตกแมพ (Y=%d) → หา titan ในแมพ", math.floor(currentY)))
                local nearestT
                for _, t in ipairs(TitansFolder:GetChildren()) do
                    if t.Parent then
                        local tRoot = t:FindFirstChild("HumanoidRootPart")
                        if tRoot and tRoot.Position.Y > 0 then
                            nearestT = tRoot
                            break
                        end
                    end
                end
                if nearestT then
                    safePos = nearestT.Position + Vector3.new(0, 250, 0)
                else
                    -- ไม่มี titan → ใช้ spawn point ของแมพ
                    safePos = Vector3.new(0, 300, 0)
                end
            end

            currentRoot.Anchored = true
            currentRoot.CFrame = CFrame.new(safePos)

            if TS_ACTIVE and TS_MAP == "Forest" then
                -- ระหว่าง defend, hover ที่ Supplies_Circle
                local circle = findCircle()
                if circle and circle.hitbox then
                    currentRoot.CFrame = CFrame.new(circle.hitbox.Position + Vector3.new(0, 150, 0))
                end
                _G.CurrentAction = "⏳ รอ titan spawn (Defend)"
            elseif TS_ACTIVE and TS_MAP == "Utgard" then
                _G.CurrentAction = string.format("⏳ รอ titan spawn (Ice Burst %d/3)", TS_ICE_KILLS)
            elseif TS_ACTIVE and TS_MAP == "Outskirts" then
                -- Handle Escort: hover ใกล้ carriage/convoy
                local cart
                for _, m in ipairs(workspace:GetChildren()) do
                    if m.Name:find("Cart") or m.Name:find("Convoy") or m.Name:find("Carriage") then
                        local part = m:FindFirstChildWhichIsA("BasePart", true)
                        if part then cart = part; break end
                    end
                end
                if cart then
                    currentRoot.CFrame = CFrame.new(cart.Position + Vector3.new(0, 200, 0))
                end
                _G.CurrentAction = "⏳ รอ titan spawn (Escort)"
            else
                _G.CurrentAction = "Combat: Waiting for Titans..."
            end
            continue
        end
        
        table.sort(aliveTitans, function(a, b) return a.dist < b.dist end)
        local targetTitan = aliveTitans[1]
        
        if targetTitan and targetTitan.root then
            local FloatHeight = 250
            local targetPos = Vector3.new(targetTitan.root.Position.X, targetTitan.root.Position.Y + FloatHeight, targetTitan.root.Position.Z)

            -- 🎯 ANTI-SHAKE: reposition เฉพาะเมื่อไกล + anchor เสมอ
            --   เดิม: set CFrame ทุก 0.1s → jitter ขึ้นลง
            --   ใหม่: อยู่ในระยะ 15 studs → นิ่ง (แค่ anchor)
            --         ไกลกว่านั้น → ย้ายทีเดียว + anchor ต่อ
            local distToTarget = (currentRoot.Position - targetPos).Magnitude

            if distToTarget > 15 then
                -- Titan ขยับไกล → move ทีเดียว
                currentRoot.Anchored = false
                currentRoot.CFrame = CFrame.new(targetPos)
                task.wait(0.02)
                currentRoot.Anchored = true
            else
                -- อยู่ใกล้แล้ว → นิ่งไว้ (ไม่ set CFrame ทุก tick)
                if not currentRoot.Anchored then
                    currentRoot.Anchored = true
                end
            end

            -- ลบ BodyVelocity ทิ้ง (Anchored แล้วไม่ต้องใช้)
            local bv = currentRoot:FindFirstChild("VenozAntiFall")
            if bv then bv:Destroy() end
        end
        
        -- 🔥 HIT ALL: ตีทุกตัวที่ยังไม่ตาย (ไม่จำกัด batch)
        local batchSize = Config.HitAll and 100 or 20
        local batchTitans = {}
        for i = 1, math.min(batchSize, #aliveTitans) do 
            table.insert(batchTitans, aliveTitans[i]) 
        end
        
        if lastTotalHealth - currentTotalHealth <= 0 then cycleStuckCount = cycleStuckCount + 1
        else cycleStuckCount = 0 end
        lastTotalHealth = currentTotalHealth

        -- Stuck: reset (ไม่ waste sets)
        -- 🗡️ ไม่ยุ่งกับ blade ที่นี่แล้ว — ensureBlade() ดูจากหลอดแดงโดยตรง
        --    (เดิม: stuck → force refill = สาเหตุที่ "รีมั่ว/เปลือง sets")
        if cycleStuckCount == 4 or cycleStuckCount == 8 then 
            pcall(function() bindable:Invoke("CALL", "ResetState") end)
        elseif cycleStuckCount >= 12 then
            _G.CurrentAction = "Combat: Titan Blacklisted!"
            if targetTitan and targetTitan.titan then blacklistedTitans[targetTitan.titan] = true end
            cycleStuckCount = 0; lastTotalHealth = 999999999
        end
        
        -- ⚡ FAST SLASH: cooldown 0.15s (จาก 0.25s = ไวขึ้น 40%)
        if cycleStuckCount < 4 then
            local ca = _G.CurrentAction or ""
            if not ca:find("⚡") and not ca:find("❄️") and not ca:find("🏗️") and not ca:find("📦") and not ca:find("🚚") then
                _G.CurrentAction = "Combat: Slashing!"
            end
            local currentTime = os.clock()
            if not _G.LastSlashTime or (currentTime - _G.LastSlashTime >= 0.15) then
                _G.LastSlashTime = currentTime
                pcall(function() bindable:Invoke("CALL", "SlashOnly") end)
            end
            -- ⚡ HIT ทุกตัวใน batch พร้อมกัน
            for _, target in ipairs(batchTitans) do 
                pcall(function() bindable:Invoke("CALL", "RegisterHitOnly", target.nape) end) 
            end
            pcall(function() bindable:Invoke("CALL", "ResetState") end)
        end
    end
end)
