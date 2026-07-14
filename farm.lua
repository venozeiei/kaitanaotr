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

-- ⚡ [PERF] DEBUG LOG TOGGLE — ปิด print ที่ spam (30 จอ = แลค)
--    เปิดกลับ: _G.VenozDebug = true
_G.VenozDebug = _G.VenozDebug or false
local function dprint(...)
    if _G.VenozDebug then print(...) end
end
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
    -- ⚠️ Handle ไม่นับ! เควส Escort broken ในเกม (ดู getNextIncompleteMapByItem)
    -- นับแค่ Thruster + Base = "ครบ" เพื่อไม่ให้บอทวน Outskirts ตลอดกาล
    for _, part in ipairs({ "Thruster", "Base" }) do
        if not hasThunderSpearPart(part, inventory) then return false end
    end
    return true
end

-- เลือก quest map ถัดไปที่ยังไม่มี item
local function getNextIncompleteMapByItem(inventory)
    inventory = inventory or fetchServerInventory()
    if not inventory then return "Forest" end  -- fallback

    -- ⚠️ SKIP HANDLE — เควส Escort broken โดย dev bug
    --   ยืนยันจาก Questline.lua (line 176) ไม่มี Update_Spear_Escort
    --   ทดสอบ 12 remote pattern คืน nil ทุกอัน
    --   → ข้าม Outskirts ไม่งั้นบอทจะวนไม่จบ
    if not hasThunderSpearPart("Base", inventory) then return "Forest" end
    if not hasThunderSpearPart("Thruster", inventory) then return "Utgard" end
    -- Handle: skip. Bot จะได้แค่ 2/3 ชิ้นจนกว่าเกมจะ patch
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
    -- 🔧 executor-agnostic: ใช้ polling แทน coroutine.yield + task.spawn(thread,args)
    --    เดิม: Potassium (บาง version) resume thread แล้ว args หาย → return nil ตลอด
    --          → AutoBoost/AutoQuest คิดว่า remote fail → ไม่ทำงาน
    local args = table.pack(...)
    local finished, success, result = false, false, nil

    task.spawn(function()
        local s, res = pcall(function() return remote:InvokeServer(_unpack(args, 1, args.n)) end)
        success, result = s, res
        finished = true
    end)

    -- polling — ปลอดภัยทุก executor
    local deadline = os.clock() + timeout
    while not finished and os.clock() < deadline do
        task.wait()
    end

    if not finished then return nil end   -- timeout
    return success and result or nil
end

-- ============================================================
-- ⚔️ PERK SELL THRESHOLD (dynamic)
-- ============================================================
-- แนวคิด: ตอน "ตัน" แล้วรอเงินจุติ = บอทแค่ฟาร์มเงินอย่างเดียว
--         ไม่ควรออกจากด่านบ่อยๆ เพื่อขาย perk (เสียเวลา teleport ไป-กลับ)
--         → ยกเพดานเป็น 500 ให้ RETRY ยาวๆ ใน Chapel
--
-- เงื่อนไข 500:
--   • Level ตัน (>= 100 + prestige*25)  AND
--   • ยังไม่ถึง PrestigeTarget           AND
--   • Gold ยังไม่ถึง RequiredGold ของจุติถัดไป
--
-- นอกนั้น: Level <= 45 → 30 | อื่นๆ → 100 (เหมือนเดิม)
-- ============================================================
local PERK_NORMAL   = 100
local PERK_LOW_LVL  = 30
local PERK_GOLDFARM = 500   -- ⭐ ตอนตันรอเงินจุติ

-- ============================================================
-- ⚔️ PERK READER — ใช้ได้ทั้ง Lobby และในด่าน
-- ============================================================
-- 🐛 บั๊ก: Lobby โชว์ Perks = 0 → ไม่ขาย → เข้าด่านใหม่ → ถึงเป้า → ออก → วนไม่จบ
--    สาเหตุ: Tracker อ่านจาก slotData.TotalPerksCount / .PerksUUIDs
--            → 2 field นี้ "actor สร้างให้" เท่านั้น (Phase 3)
--            → Lobby ไม่มี actor → raw slot ไม่มี field นี้ → ไม่ set → 0
--
-- ✅ แก้: อ่าน slot table จาก getgc ตรงๆ
--    (pattern เดียวกับที่ TS quest / Skills ใช้ — ทำงานได้ทั้ง 2 phase แน่นอน)
--    slot มี: Progression, Quests, Perks, Inventory, Currency ...
-- ============================================================
local function readPerksFromGame()
    local total, uuids, found = 0, {}, false

    -- 1️⃣ getgc: หา "slot table" (ที่มี Progression + Perks)
    pcall(function()
        for _, v in pairs(_getgc(true)) do
            if type(v) == "table"
            and rawget(v, "Progression")
            and rawget(v, "Perks") then
                local st = rawget(v.Perks, "Storage")
                if type(st) == "table" then
                    for k, p in pairs(st) do
                        total = total + 1
                        if type(p) == "table" and p.Name and not p.Equipped then
                            table.insert(uuids, k)
                        end
                    end
                    found = true
                end
                break
            end
        end
    end)

    -- 2️⃣ สำรอง: server remote
    if not found then
        pcall(function()
            local raw = GET:InvokeServer("Functions", "Settings", "Blur", "Off")
            if type(raw) == "table" and type(raw.Slots) == "table" then
                local slot = raw.Slots[plr:GetAttribute("Slot") or _G.TargetSlot or "A"]
                if slot and slot.Perks and type(slot.Perks.Storage) == "table" then
                    total, uuids = 0, {}
                    for k, p in pairs(slot.Perks.Storage) do
                        total = total + 1
                        if type(p) == "table" and p.Name and not p.Equipped then
                            table.insert(uuids, k)
                        end
                    end
                    found = true
                end
            end
        end)
    end

    if not found then return nil end
    return total, uuids
end

-- 🔄 อัปเดต _G — เรียกได้ทุกที่ (Lobby + ด่าน ได้เลขเดียวกัน)
local function refreshPerks()
    local total, uuids = readPerksFromGame()
    if total then
        _G.TotalPerksCount = total
        _G.PerksUUIDs      = uuids
        return true
    end
    return false
end

-- 🔢 นับ perk ที่ "ขายได้จริง" (ไม่รวมที่ใส่อยู่)
local function getSellablePerkCount()
    local u = _G.PerksUUIDs
    if type(u) == "table" then return #u end
    return 0
end

local function getPerkSellTarget()
    local level    = tonumber(_G.LastLevel)    or tonumber(plr:GetAttribute("Level"))    or 0
    local prestige = tonumber(_G.LastPrestige) or tonumber(plr:GetAttribute("Prestige")) or 0
    local gold     = tonumber(_G.LastGold)     or 0

    -- 🛡️ ข้อมูลยังไม่โหลด (level = 0) → อย่าใช้ 30 (จะออกไปขายเร็วเกิน)
    if level <= 0 then return PERK_NORMAL end

    -- เลเวลต่ำ → ขายไว (perk เยอะทำให้ช้า)
    if level <= 45 then return PERK_LOW_LVL end

    -- ตันหรือยัง?
    local maxLevel = 100 + (prestige * 25)
    local isTan = (level >= maxLevel)

    -- ยังจุติได้อีกไหม?
    local canStillPrestige = (Config.AutoPrestige and prestige < (Config.PrestigeTarget or 5))

    if isTan and canStillPrestige then
        -- เงินถึงเป้าจุติถัดไปหรือยัง?
        local pk  = "P" .. tostring(prestige + 1)
        local ps  = (Config.VenozPrestige and Config.VenozPrestige[pk]) or { RequiredGold = 0 }
        local req = (ps.RequiredGold or 0) * 1000000

        if gold < req then
            -- 💰 ตัน + เงินไม่พอ = กำลังฟาร์มเงิน → ขาย perk ที่ 500 (ไม่ออกบ่อย)
            return PERK_GOLDFARM
        end
    end

    return PERK_NORMAL
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

        -- 🔍 อ่าน gems หลายทาง — Potassium บางที `_G.LastGems` ยังไม่ populate
        local function readGems()
            local g = tonumber(_G.LastGems)
                   or tonumber(plr:GetAttribute("Gems"))
                   or tonumber(plr:GetAttribute("Gem"))
            if g and g > 0 then return g end
            -- fallback: อ่านจาก topbar GUI
            pcall(function()
                local iface = plr.PlayerGui:FindFirstChild("Interface")
                local top   = iface and iface:FindFirstChild("Topbar")
                local main  = top and top:FindFirstChild("Main")
                local cur   = main and main:FindFirstChild("Currencies")
                if cur then
                    local gemLbl = cur:FindFirstChild("Gems") or cur:FindFirstChild("Gem")
                    if gemLbl then
                        for _, d in ipairs(gemLbl:GetDescendants()) do
                            if d:IsA("TextLabel") and d.Text ~= "" then
                                local n = tonumber(string.gsub(d.Text, "[^%d]", ""))
                                if n then g = n; return end
                            end
                        end
                    end
                end
            end)
            return g or 0
        end

        -- 🐛 DEBUG: log สถานะทุกครั้งที่ boost check ทำงาน (ทุก 10 วิ)
        local gemsNow = readGems()
        local itemsInv = (_G.LastInventory and _G.LastInventory["Items"]) or {}
        local itemCount = 0
        for _ in pairs(itemsInv) do itemCount = itemCount + 1 end
        dprint(string.format("[Boost] 🔍 check: Prestige=%d Level=%d Gems=%d Items=%d Config=%s",
            prestige, level, gemsNow, itemCount, tostring(Config.AutoBoost)))

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
        dprint(string.format("[Boost]    needed = {%s}", table.concat(boostsNeeded, ", ")))

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
            dprint(string.format("[Boost]    %s: active=%s", boostType, tostring(isActive)))
            if isActive then continue end

            -- 🍷 ลองหาของในกระเป๋าก่อน (case-insensitive)
            local activated = false
            local boostLower = string.lower(boostType)
            for realItemName, qty in pairs(itemsInv) do
                local nameLower = string.lower(realItemName)
                if tonumber(qty) > 0 and string.find(nameLower, boostLower) and string.find(nameLower, "boost") then
                    print(string.format("[Boost] 🍷 กินของ: %s (x%s)", realItemName, tostring(qty)))
                    _G.CurrentAction = "AutoBoost: Using " .. realItemName
                    local res = safeInvokeServer(GET, 3, "S_Inventory", "Item", realItemName)
                    dprint(string.format("[Boost]    res = %s", tostring(res)))
                    if res ~= nil then
                        print("[Boost] ✅ กินสำเร็จ")
                        activated = true; actionTaken = true; task.wait(0.3); break
                    end
                end
            end
            if activated then continue end

            -- 💎 ซื้อจาก market
            local minGems = Config.MinGemsToBuyBoosts or 4500
            dprint(string.format("[Boost]    Gems=%d MinToBuy=%d", gemsNow, minGems))
            if gemsNow < minGems then
                dprint("[Boost]    ⏭️ Gems ไม่พอ ข้าม")
                continue
            end

            local buyOrder = (boostType == "Gold") and {
                {9, "2x Gold Boost [2h]", 13999}, {8, "2x Gold Boost [1h]", 7999}, {7, "2x Gold Boost [30m]", 4499}
            } or {
                {3, "2x XP Boost [2h]", 13999}, {2, "2x XP Boost [1h]", 7999}, {1, "2x XP Boost [30m]", 4499}
            }
            for _, target in ipairs(buyOrder) do
                local idx, name, price = target[1], target[2], target[3]
                if gemsNow >= price then
                    print(string.format("[Boost] 💎 ซื้อ %s (%d gems)", name, price))
                    _G.CurrentAction = "AutoBoost: Buying " .. name
                    local res = safeInvokeServer(GET, 5, "S_Market", "Buy", "1_Boosts", idx, 1)
                    dprint(string.format("[Boost]    buy res = %s (type=%s)", tostring(res), type(res)))
                    if res ~= nil and type(res) ~= "string" then
                        task.wait(0.5)
                        local ur = safeInvokeServer(GET, 3, "S_Inventory", "Item", name)
                        print(string.format("[Boost] ✅ ซื้อ+ใช้สำเร็จ (use res = %s)", tostring(ur)))
                        actionTaken = true; break
                    end
                end
            end
        end

        if not actionTaken then
            dprint("[Boost] ⏸ ไม่ทำอะไร → cooldown 5 นาที")
            lastBoostCheck = currentTime + 300
        else
            lastBoostCheck = currentTime + Config.BoostCheckInterval
        end
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
-- 🎥 ปิดเอฟเฟกต์กล้องที่ตัวเกม (ครั้งเดียว) — ลดภาพสั่น + ลด render
--    ไม่ยุ่งกับ logic อะไรเลย เป็น setting ฝั่งเกมล้วนๆ
-- ============================================================
if not _G.VenozSettingsApplied then
    _G.VenozSettingsApplied = true
    task.spawn(function()
        task.wait(3)
        for _, s in ipairs({ "Camera_Shake", "Action_Cam", "Hit_Effect", "Blur" }) do
            pcall(function() GET:InvokeServer("Functions", "Settings", s, "Off") end)
            task.wait(0.15)
        end
        print("[Venoz] 🎥 ปิด Camera_Shake / Action_Cam / Hit_Effect / Blur แล้ว")
    end)
end

-- ============================================================
-- 🛡️ ANTI-AFK
-- ============================================================
task.spawn(function()
    pcall(function() if setfpscap then setfpscap(30) end end)
end)

-- ============================================================
-- 🔥 OPTIMIZED ANTI-LAG
-- ============================================================
-- ============================================================
-- 🛡️ Anti-Lag SKIP ในแมพ Thunder Spear
-- ============================================================
-- User รายงาน: TS mission จบแล้ว Rewards UI ไม่โผล่
--   สาเหตุน่าจะเป็นเรา hide/optimize map ทำให้ collision box/objective marker
--   บางส่วนใช้งานไม่ได้ → mission ไม่สรุปสถานะ
--   → ในแมพ TS ไม่แตะแมพเลย
local function isTSMap()
    for _, ids in pairs(THUNDER_MAP_IDS) do
        if ids[game.PlaceId] then return true end
    end
    return false
end

if Config.AutoAntiLag and not _G.OptimizedMap and not isTSMap() then
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
                        -- ⚡ [PERF] DescendantAdded ยิงทุก part ใหม่ (ไททันเกิด = 50+ part)
                        --    → throttle: batch เก็บไว้ แล้วประมวลผลทุก 0.5 วิ
                        local queue = {}
                        target.DescendantAdded:Connect(function(v)
                            queue[#queue + 1] = v
                        end)
                        task.spawn(function()
                            while task.wait(0.5) do
                                if #queue > 0 then
                                    local batch = queue
                                    queue = {}
                                    for _, v in ipairs(batch) do hidePart(v) end
                                end
                            end
                        end)
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
            -- ❌ ลบทิ้ง: patch Effects.Shake จาก ReplicatedStorage = คนละ VM กับ Actor
            --    ไม่เคยทำงานเลย → ย้ายไปทำในตัว actor แล้ว (ดู script_actor)
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
                            v.Transparency = 1; v.CastShadow = false
                            -- 🚫 ไม่แตะ CanCollide!
                            --    เดิม: ตั้ง false → พื้นดิน+ผนังไม่ collision
                            --    → ไททันวิ่งตกทะลุแมพ → รถม้าเดินตก → quest ไม่นับ
                            --    ตอนนี้ประหยัด render ได้ แต่ physics ยังทำงาน
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
        frame.Size = UDim2.new(0, 265, 0, 320); frame.Position = UDim2.new(0, 20, 0, 20)
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
                            -- ⚔️ PERK — อ่านจาก getgc (ได้ทั้ง Lobby + ด่าน)
                            --    เดิม: slotData.TotalPerksCount/.PerksUUIDs = actor สร้าง (Phase 3 เท่านั้น)
                            --          → Lobby ไม่มี actor → ไม่ set → โชว์ 0
                            refreshPerks()
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

            -- 🎯 ระดับความยาก + โหมด (อ่านจาก workspace attribute ที่เกมตั้งไว้)
            local diffStr, objStr = nil, nil
            pcall(function()
                local d = workspace:GetAttribute("Difficulty")
                local o = workspace:GetAttribute("Objective")
                if d and tostring(d) ~= "" then diffStr = tostring(d) end
                if o and tostring(o) ~= "" then objStr  = tostring(o) end
            end)

            -- สีตามระดับความยาก
            local DIFF_COLOR = {
                easy       = "#88ff88",
                normal     = "#ffffff",
                hard       = "#ffdd55",
                severe     = "#ff9933",
                aberrant   = "#ff5555",
                ["aberrant+"]  = "#ff3399",
                ["aberrant++"] = "#cc44ff",
            }

            local displayMapString
            if game.PlaceId == 14916516914 or game.PlaceId == 13379208636 then
                -- Lobby / Title → โชว์แค่ชื่อที่
                displayMapString = cleanStr(mapStr)
            else
                -- ในด่าน → Chapel · Skirmish · [Aberrant++]
                local parts = { cleanStr(mapStr) }
                if objStr then table.insert(parts, cleanStr(objStr)) end
                displayMapString = table.concat(parts, " · ")

                if diffStr then
                    local col = DIFF_COLOR[string.lower(diffStr)] or "#ffaa00"
                    displayMapString = displayMapString ..
                        string.format("\n🔥 <b>Difficulty:</b> <font color='%s'><b>%s</b></font>",
                            col, string.upper(diffStr))
                end
            end

            _G.LastMapStr  = mapStr
            _G.LastDiffStr = diffStr
            _G.LastObjStr  = objStr
            local tsStatus = ""
            if _G.ThunderSpearMode then
                tsStatus = string.format("\n⚡ <font color='#ff00ff'>TS: %s</font>", tostring(_G.ThunderSpearPart or "?"))
            end
            local totalPerks = _G.TotalPerksCount or 0
            local perkTarget = getPerkSellTarget()
            local perkColor = totalPerks >= perkTarget and "#ff3333" or "#aaffaa"
            -- 💰 โหมดฟาร์มเงิน (ตันแล้วรอเงินจุติ) → โชว์เป็นสีทอง
            if perkTarget == PERK_GOLDFARM then perkColor = "#ffdd55" end
            logText.Text = string.format(
                "🎖️ <b>Level:</b> %d / %d (%s/%s)\n👑 <b>Prestige:</b> P%d\n💰 <b>Gold:</b> %s | 💎 <b>Gems:</b> %s\n🧪 <b>Gold:</b> %s\n🧪 <b>XP:</b> %s\n⚔️ <b>Perks:</b> <font color='%s'>%d / %d</font>\n📍 %s | 🗺️ %s%s\n🔄 <font color='#00ffff'>%s</font>",
                level, maxLevelReq, formatNumber(displayXP), formatNumber(displayMaxXP), prestige, formatNumber(gold), formatNumber(gems),
                formatTime(goldBoostTime), formatTime(xpBoostTime), perkColor, totalPerks, perkTarget,
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

-- ============================================================
-- 🐎 HORST MANAGER REPORTER (+ Disk Cache)
-- ============================================================
-- ส่งสถานะไปโชว์ในหน้า Horst Manager
--   • เซฟลงฮาร์ดดิสก์ → ค่าไม่มีวันเป็น 0 แม้ตอนโหลด/teleport
--   • อ่านจาก 3 ทาง: attribute → UI Topbar → server remote (ชัวร์สุด)
--   • ⚡ TS = เช็คแค่ Thruster + Base (Handle บั๊กในเกม ทำไม่ได้)
--   • ทำงานทุก phase (Title / Lobby / Mission)
-- ============================================================
task.spawn(function()
    local HttpService = game:GetService("HttpService")
    local CacheFile = "VenozHub_Cache_" .. tostring(plr.UserId) .. ".json"

    local function fmt(n)
        return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end

    local function saveCache()
        pcall(function()
            if writefile then
                writefile(CacheFile, HttpService:JSONEncode({
                    Level    = _G.LastLevel    or 0,
                    Prestige = _G.LastPrestige or 0,
                    Gold     = _G.LastGold     or 0,
                    Gems     = _G.LastGems     or 0,
                    TS       = _G.TSUnlocked   or false,
                    SB       = _G.LastSB,        -- ⭐ สถานะแบน (true = ปกติ / false = โดนแบน)
                }))
            end
        end)
    end

    -- 📥 โหลดค่าเดิมจากดิสก์ทันที (กันโชว์ 0 / SB ผิด ตอนเพิ่งเข้าเกม)
    pcall(function()
        if isfile and readfile and isfile(CacheFile) then
            local d = HttpService:JSONDecode(readfile(CacheFile))
            _G.LastLevel    = _G.LastLevel    or d.Level    or 0
            _G.LastPrestige = _G.LastPrestige or d.Prestige or 0
            _G.LastGold     = _G.LastGold     or d.Gold     or 0
            _G.LastGems     = _G.LastGems     or d.Gems     or 0
            if d.TS then _G.TSUnlocked = true end
            if _G.LastSB == nil and d.SB ~= nil then _G.LastSB = d.SB end
        end
    end)

    while true do
        pcall(function()
            local dirty = false

            -- 1️⃣ attribute จากตัวละคร
            local lv = plr:GetAttribute("Level")
            local pr = plr:GetAttribute("Prestige")
            if lv and lv > 0    then _G.LastLevel = lv;    dirty = true end
            if pr ~= nil        then _G.LastPrestige = pr; dirty = true end

            -- 2️⃣ UI Topbar (เฉพาะตอนอยู่ Lobby)
            pcall(function()
                local cur = plr.PlayerGui.Interface.Topbar.Main.Currencies
                local g = tonumber((cur.Gold.Amount.Text:gsub("[,%s]", "")))
                local m = tonumber((cur.Gems.Amount.Text:gsub("[,%s]", "")))
                if g and g > 0 then _G.LastGold = g; dirty = true end
                if m and m > 0 then _G.LastGems = m; dirty = true end
            end)

            -- 3️⃣ server remote (ชัวร์สุด — ทะลุด่านได้)
            -- ⚡ [PERF] เดิม: ยิงทุก 3 วิ ตลอดเวลา = 30 จอ × 20 remote/นาที
            --    แก้: ยิงทุก 30 วิ (attribute + UI อัปเดตทุก 3 วิ อยู่แล้ว พอ)
            local inventory = nil
            _G._HorstFetch = _G._HorstFetch or 0
            if os.time() - _G._HorstFetch >= 30 or os.time() < _G._HorstFetch then
                _G._HorstFetch = os.time()
                local ok, sd = pcall(function()
                    return GET:InvokeServer("Functions", "Settings", "Blur", "Off")
                end)
                if ok and type(sd) == "table" and sd.Slots then
                    local slot = sd.Slots[plr:GetAttribute("Slot") or _G.TargetSlot or "A"]
                    if slot then
                        inventory = slot.Inventory
                        if slot.Currency then
                            if slot.Currency.Gold then _G.LastGold = slot.Currency.Gold; dirty = true end
                            if slot.Currency.Gems then _G.LastGems = slot.Currency.Gems; dirty = true end
                        end
                        if slot.Currencies and slot.Currencies.Gems then
                            _G.LastGems = slot.Currencies.Gems; dirty = true
                        end
                        if slot.Progression then
                            if slot.Progression.Level    then _G.LastLevel    = slot.Progression.Level;    dirty = true end
                            if slot.Progression.Prestige then _G.LastPrestige = slot.Progression.Prestige; dirty = true end
                        end
                    end
                end
            end

            -- ⚡ THUNDER SPEAR — เช็คแค่ Thruster + Base
            --    (Handle บั๊กในเกม: Questline.lua ไม่มี Update_Spear_Escort)
            if not _G.TSUnlocked and inventory then
                local hasThruster = hasThunderSpearPart("Thruster", inventory)
                local hasBase     = hasThunderSpearPart("Base",     inventory)
                if hasThruster and hasBase then
                    _G.TSUnlocked = true
                    dirty = true
                    print("[Horst] ⚡ Thunder Spear ครบ (Thruster + Base) → ติ๊กถูก ✅")
                end
            end

            if dirty then saveCache() end

            -- 🛡️ SB (สถานะแบน) — อัปเดตเฉพาะเมื่อ attribute โหลดจริงแล้ว
            --    ⚠️ ตอนเพิ่งเข้าเกม attribute ยังเป็น nil → อย่าเพิ่งสรุปว่า "ปกติ"
            --       ใช้ค่าที่เซฟไว้ในดิสก์แทน จนกว่า server จะส่งค่าจริงมา
            local bl  = plr:GetAttribute("Blacklisted")
            local trd = plr:GetAttribute("Trades")

            if bl ~= nil or trd ~= nil then
                -- server ส่งค่ามาแล้ว → คำนวณใหม่ + เซฟ
                local isOK = not (bl == true or trd == 0)
                if _G.LastSB ~= isOK then
                    if isOK then
                        print("[Horst] 🛡️ SB: ✅ ปกติ")
                    else
                        warn(string.format("[Horst] 🚨 SB: ❌ โดนแบน! (Blacklisted=%s Trades=%s)",
                            tostring(bl), tostring(trd)))
                    end
                    _G.LastSB = isOK
                    saveCache()
                end
            end

            -- 📤 ส่งไป Horst Manager
            local sbIcon = (_G.LastSB == false) and "❌" or "✅"   -- nil = ยังไม่รู้ → โชว์ ✅
            local tsIcon = _G.TSUnlocked and "⚡TS:✅" or "⚡TS:❌"

            if _G.Horst_SetDescription then
                _G.Horst_SetDescription(string.format(
                    "SB:%s 🎖️Lv.%d 👑P.%d 💰G:%s 💎Gem:%s %s",
                    sbIcon,
                    _G.LastLevel    or 0,
                    _G.LastPrestige or 0,
                    fmt(_G.LastGold or 0),
                    fmt(_G.LastGems or 0),
                    tsIcon
                ))
            end
        end)
        task.wait(3)
    end
end)

-- ============================================================
-- 🧹 MEMORY GUARD (สำหรับเปิดหลายจอ นานๆ)
-- ============================================================
-- ⚡ ปัญหา: เปิดนานๆ แล้วหน่วง/สคริปต์ไม่โหลด
--    สาเหตุ: cache ใน _G โตไม่หยุด + Lua GC ไม่คืนหน่วยความจำ
--    แก้: เคลียร์ cache ที่ไม่จำเป็นทุก 10 นาที + บังคับ GC
--    ⚠️ ไม่แตะ cache ที่ logic ต้องใช้ (SkillCache / TSUnlocked / LastSB)
-- ============================================================
task.spawn(function()
    while task.wait(600) do   -- ทุก 10 นาที
        pcall(function()
            -- เคลียร์ QuestCache (โตเรื่อยๆ จาก 80+ tag × ทุก 5 นาที)
            local qn = 0
            if _G.QuestCache then for _ in pairs(_G.QuestCache) do qn = qn + 1 end end
            if qn > 200 then _G.QuestCache = {} end

            -- ล้าง reference ที่ไม่ใช้แล้ว
            -- ⚠️ ห้ามลบ _G.PerksUUIDs! logic ตัดสินใจ LEAVE/SELL ใช้อยู่
            _G._CartInfo = nil

            -- บังคับ GC (คืนหน่วยความจำให้ OS)
            collectgarbage("collect")

            local mb = collectgarbage("count") / 1024
            print(string.format("[MEM] 🧹 เคลียร์แล้ว — Lua ใช้ %.1f MB", mb))
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

    -- 🎁 Persistent Claim Loop — จับ reward ที่ค้าง
    -- ⚡ [PERF] เดิม: ยิง 15 remote ทุก 5 วิ ตลอดกาล แม้ TS ครบแล้ว
    --    แก้: TS ครบ → หยุดถาวร | poll 5 → 10 วิ
    if Config.AutoThunderSpearQuest then
        task.spawn(function()
            task.wait(3)
            while game.PlaceId == 14916516914 do
                if _G.TSUnlocked then
                    print("[TS] ✅ TS ครบแล้ว → หยุด claim loop (ประหยัด remote)")
                    break
                end
                pcall(function()
                    claimAllSpearsQuests()
                    task.wait(0.3)
                    clickAllClaimButtons()
                end)
                task.wait(10)
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

                -- ⚔️ อ่าน perk สดจาก getgc ก่อน (Lobby ก็อ่านได้แล้ว)
                refreshPerks()

                local requiredPerksToSell = getPerkSellTarget()   -- 30 / 100 / 500
                if Config.AutoDeletePerk and getSellablePerkCount() >= requiredPerksToSell then
                    local uuids = _G.PerksUUIDs
                    local n0 = #uuids
                    _G.CurrentAction = "Auto Selling " .. n0 .. " Perks..."
                    print(string.format("[Perk] 🗑️ ขาย %d ชิ้น (เป้า %d%s)",
                        n0, requiredPerksToSell,
                        requiredPerksToSell == PERK_GOLDFARM and " — 💰 โหมดฟาร์มเงินจุติ" or ""))

                    -- ⚡ [SPEED] เดิม: ยิง bulk แล้ว "ยิงทีละอันอีก 200 ครั้ง" ทุกครั้ง
                    --            + wait(0.05) × 100 = ~13 วินาที (ทั้งๆ ที่ bulk มักผ่านแล้ว)
                    --    ใหม่: ยิง bulk → เช็คผล → ผ่านแล้วจบ (2 call)

                    -- 1️⃣ Bulk
                    pcall(function() safeInvokeServer(GET, 3, "S_Equipment", "Delete", "Perk", uuids) end)
                    pcall(function() safeInvokeServer(GET, 3, "S_Equipment", "Delete", "Perks", uuids) end)
                    task.wait(0.5)

                    -- 2️⃣ เช็คว่าลดจริงไหม
                    local after = nil
                    pcall(function()
                        local raw = safeInvokeServer(GET, 3, "Functions", "Settings", "Blur", "Off")
                        if type(raw) == "table" and raw.Slots then
                            local sl = raw.Slots[plr:GetAttribute("Slot") or "A"]
                            if sl and sl.Perks and type(sl.Perks.Storage) == "table" then
                                local n = 0
                                for _, v in pairs(sl.Perks.Storage) do
                                    if type(v) == "table" and v.Name and not v.Equipped then n = n + 1 end
                                end
                                after = n
                            end
                        end
                    end)

                    if after and after < n0 then
                        print(string.format("[Perk] ⚡ Bulk delete สำเร็จ (%d → %d) — 2 calls", n0, after))
                        _G.PerksUUIDs = {}
                    else
                        -- 3️⃣ Bulk ไม่ผ่าน → ยิงทีละอัน แต่ parallel เป็นชุดละ 10
                        print("[Perk] ⚠️ Bulk ไม่ผ่าน → ยิงทีละอัน (ชุดละ 10)")
                        for i = 1, n0, 10 do
                            for j = i, math.min(i + 9, n0) do
                                local uuid = uuids[j]
                                task.spawn(function()
                                    pcall(function() GET:InvokeServer("S_Equipment", "Delete", "Perk", { uuid }) end)
                                    pcall(function() GET:InvokeServer("S_Equipment", "Delete", "Perks", { uuid }) end)
                                end)
                            end
                            task.wait(0.1)
                        end
                        task.wait(0.5)
                        _G.PerksUUIDs = {}
                    end
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

            -- 🔍 Debug log (ทุก 30 วิ) — ใช้ os.time() กัน os.clock() รีเซ็ตตอน teleport
            _G._LastTSDebug = _G._LastTSDebug or 0
            if os.time() - _G._LastTSDebug > 30 or os.time() < _G._LastTSDebug then
                _G._LastTSDebug = os.time()
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
                        _G.SkillCacheLevel = nil   -- ⚡ จุติ = สกิลรีเซ็ต → ต้องปลดใหม่หมด
                        _G.LastUpgradeTime = nil   -- ให้อัปเกรดรอบใหม่ทันที ไม่ต้องรอ 60 วิ
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
                -- 🐛 [FIX] เดิมใช้ os.clock() = เวลาตั้งแต่ Lua state เริ่ม
                --    → teleport = เริ่มนับ 0 ใหม่ แต่ _G.LastUpgradeTime ค้างค่าเก่า (เช่น 3000)
                --    → currentTime - LastUpgradeTime = 5 - 3000 = -2995 → ไม่ถึง 60 → ข้ามตลอดกาล!
                --    → ใช้ os.time() (wall clock) แทน = ข้าม teleport ได้
                local currentTime = os.time()

                -- กันค่าเพี้ยน (ถ้าย้อนหลัง = รีเซ็ตทิ้ง)
                if _G.LastUpgradeTime and currentTime < _G.LastUpgradeTime then
                    _G.LastUpgradeTime = nil
                end

                -- gate 20 วิ (พอกัน spam ตอนสร้าง mission ล้มเหลว แต่ยังอัปทุกครั้งที่กลับ Lobby)
                if Config.AutoUpgrade and (not _G.LastUpgradeTime or (currentTime - _G.LastUpgradeTime >= 20)) then
                    _G.LastUpgradeTime = currentTime
                    _G.CurrentAction = "⚙️ Upgrading Equipment..."

                    -- 💰 อ่านทองปัจจุบัน (ใช้ attribute = เร็ว ไม่ต้อง fetch slotdata)
                    local function readGold()
                        return tonumber(plr:GetAttribute("Gold"))
                            or tonumber(_G.LastGold) or 0
                    end
                    local goldStart = readGold()
                    print(string.format("[Upgrade] ⚙️ เริ่มอัปเกรดดาบ... (Gold %s)", tostring(goldStart)))

                    local bladeUpgrades = { "ODM_Damage", "Blade_Durability", "Crit_Damage", "Crit_Chance", "ODM_Gas", "ODM_Speed", "ODM_Control", "ODM_Range" }

                    -- ═══════════════════════════════════════════════════════
                    -- 1️⃣ EQUIPMENT — 3 รอบตายตัว (เร็ว + พิสูจน์แล้วว่าทำงาน)
                    -- ═══════════════════════════════════════════════════════
                    --   ⚡ ใช้ array format = 1 call ต่อ prefix (เดิม 8 call)
                    --   ไม่เช็คทองแล้ว — attribute sync ช้า ทำให้ break ก่อนเวลา
                    --   3 รอบ = ครอบคลุมกรณีทั่วไป + ไม่ค้าง Lobby นาน
                    for i = 1, 3 do
                        for _, prefix in ipairs({ "Equipment", "S_Equipment" }) do
                            pcall(function() GET:InvokeServer(prefix, "Upgrade_All") end)
                            pcall(function() GET:InvokeServer(prefix, "Grade_Up") end)
                            pcall(function() GET:InvokeServer(prefix, "Tier_Up") end)
                            pcall(function() GET:InvokeServer(prefix, "Upgrade", bladeUpgrades) end)
                        end
                        task.wait(0.3)
                    end

                    local goldAfterEq = readGold()
                    local spent = goldStart - goldAfterEq
                    if spent > 0 then
                        print(string.format("[Upgrade] ✅ อัปดาบ | ใช้ทอง %s | เหลือ %s",
                            tostring(spent), tostring(goldAfterEq)))
                    else
                        print("[Upgrade] ✅ ดาบ: ไม่มีที่จะอัป (max/หมดเงิน)")
                    end

                    -- ═══════════════════════════════════════════════════════
                    -- 2️⃣ SKILL TREE — ทำหลังอัปดาบเสร็จ (ด้วยทองที่เหลือ)
                    -- ═══════════════════════════════════════════════════════
                    -- ⚠️ ไม่ยิงเป็น array ใหญ่ (server อาจอ่านแค่ตัวแรก) → ใช้ format เดิม
                    -- ตัวเร่งจริงคือ CACHE:
                    --   เดิม: 116 call ทุก 60 วิ ตลอดชีวิต
                    --   ใหม่: 116 call ครั้งเดียวต่อ level → 0 call จนกว่าจะ level up
                    _G.CurrentAction = "Upgrading Skill Tree..."
                    local bannedSkills = { ["103"]=true, ["158"]=true, ["163"]=true }

                    -- เคลียร์ cache เมื่อ: level เปลี่ยน / ครบ 10 นาที (safety net)
                    local curLv = _G.LastLevel or plr:GetAttribute("Level") or 0
                    if ((_G.SkillCacheLevel or -1) ~= curLv)
                    or (not _G.SkillCacheTime)
                    or (os.time() - _G.SkillCacheTime > 600) then
                        _G.SkillCache = {}
                        _G.SkillCacheLevel = curLv
                        _G.SkillCacheTime = os.time()
                    end
                    _G.SkillCache = _G.SkillCache or {}

                    -- 🎯 MULTI-PASS UNLOCK
                    -- ปัญหาเดิม: สาย 99-168 บางตัวมี dependency ที่ ID ไม่เรียง
                    --   → ยิงตามลำดับตัวเลข = ปลดพ่อไม่ทันลูก = ลูกถูกปฏิเสธ
                    -- แก้: ยิงหลายรอบ + อ่านของจริงจาก server ยืนยัน
                    --   รอบ 1: ปลดพ่อทั้งหมด → รอบ 2-4: ลูก/หลานที่ปลดได้เพิ่ม

                    -- helper: อ่านสกิลที่ปลดจริงจาก server (ผ่าน getgc)
                    local function readUnlockedFromServer()
                        local set = {}
                        pcall(function()
                            for _, v in pairs(getgc(true)) do
                                if type(v) == "table" and rawget(v, "Progression")
                                and rawget(v, "Skills") then
                                    local u = rawget(v.Skills, "Unlocked")
                                    if type(u) == "table" then
                                        for _, sid in pairs(u) do
                                            set[tostring(sid)] = true
                                        end
                                    end
                                    return
                                end
                            end
                        end)
                        return set
                    end

                    local sent = 0

                    -- ═══════════════════════════════════════════════════════
                    -- 🎯 ลำดับปลดสกิล (ตามที่ user สอน)
                    -- ═══════════════════════════════════════════════════════
                    --   1) ซ้าย    1-80  (ยกเว้น 38-69 = Support ไม่เอา)
                    --   2) ข้าม   81-89  (สายซ้ายที่ต่อขึ้น — ไม่เอา)
                    --   3) ขวา main chain  90 → 91 → ... → 98  (จากล่างขึ้นบน!)
                    --   4) ขวา สาขาย่อย   99-168  (ยกเว้น ban list = สายขวาสุด)
                    -- ═══════════════════════════════════════════════════════
                    local targets = {}

                    -- 1) ซ้าย 1-80 (ข้าม Support)
                    for s = 1, 80 do
                        if not (s >= 38 and s <= 69) then
                            table.insert(targets, tostring(s))
                        end
                    end

                    -- 2) ⛔ ข้าม 81-89 (สายซ้ายต่อขึ้น — ไม่แตะ)

                    -- 3) ขวา main chain: 90 → 98 (up — 90 เป็น root ปลดก่อน)
                    for s = 90, 98 do
                        table.insert(targets, tostring(s))
                    end

                    -- 4) ขวา สาขาย่อย 99-168 (ban list = สายขวาสุดหลัก 103/158/163)
                    for s = 99, 168 do table.insert(targets, tostring(s)) end

                    -- ยิง 2 รอบ (พอสำหรับ dependency ปกติ + เร็ว)
                    local serverSet = readUnlockedFromServer()
                    for pass = 1, 2 do
                        local passSent = 0
                        for _, ss in ipairs(targets) do
                            if not bannedSkills[ss]
                            and not _G.SkillCache[ss]
                            and not serverSet[ss] then
                                pcall(function() GET:InvokeServer("S_Equipment", "Unlock", { ss }) end)
                                passSent = passSent + 1
                            end
                        end
                        sent = sent + passSent

                        if passSent == 0 then break end

                        task.wait(0.2)
                        serverSet = readUnlockedFromServer()
                    end

                    -- Mark cache ตามที่ปลดสำเร็จจริงเท่านั้น (ไม่ mark สิ่งที่ยิงไปแล้วพลาด)
                    for ss in pairs(serverSet) do _G.SkillCache[ss] = true end

                    if sent > 0 then
                        local cached = 0
                        for _ in pairs(_G.SkillCache) do cached = cached + 1 end
                        print(string.format("[Skill] ⚡ ยิง %d call (Lv.%d) — ปลดสำเร็จรวม %d",
                            sent, curLv, cached))
                    else
                        print("[Skill] ✅ ครบแล้ว (0 calls)")
                    end

                    print("[Upgrade] ✅ เสร็จหมด → สร้างด่าน")
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
        task.wait(3)
        local checkCount = 0

        -- ⚡ [PERF] เดิม: ยิง 16 remote ทุก 5 วิ ตลอดกาล — แม้ TS ครบแล้ว!
        --    30 จอ = 96 remote/วินาที → server rate-limit → บอทค้าง/โหลดไม่ติด
        --    แก้: 1) เช็คเงื่อนไข "ถูก" ก่อน (level/prestige) → ไม่ผ่านก็ไม่ยิง remote
        --         2) TS ครบแล้ว → หยุด loop ถาวร
        --         3) poll 5 → 15 วิ
        while task.wait(15) do
            checkCount = checkCount + 1

            local rewardsUI = interface:FindFirstChild("Rewards")
            if rewardsUI and rewardsUI.Visible then continue end

            -- อ่านสถานะจาก cache (ไม่ยิง remote)
            local curLevel = tonumber(_G.LastLevel) or tonumber(plr:GetAttribute("Level")) or 0
            local curPrestige = tonumber(_G.LastPrestige) or tonumber(plr:GetAttribute("Prestige")) or 0
            local curXP = math.max(tonumber(_G.LastXP) or 0, tonumber(plr:GetAttribute("XP")) or 0)
            local curMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(plr:GetAttribute("Max_XP")) or 0)
            local tarLevelReq = 100 + (curPrestige * 25)

            if curMaxXP == 0 then continue end   -- ข้อมูลยังไม่โหลด

            local isTan = (curLevel >= tarLevelReq and curXP >= curMaxXP)
            local prstOK = curPrestige >= (Config.ThunderSpearAtPrestige or 2)

            -- 🚪 GATE: ยังไม่ตัน / prestige ไม่ถึง → ไม่ต้องยิง remote เลย
            if not (isTan and prstOK) then continue end

            -- 🛑 TS ครบแล้ว (จำไว้ใน _G) → หยุด loop ถาวร ไม่ยิงอีก
            if _G.TSUnlocked then
                print("[TS AUTO-LEAVE] ✅ TS ครบแล้ว → หยุดเช็ค (ประหยัด remote)")
                break
            end

            -- ผ่านทุกเงื่อนไขแล้วค่อยยิง remote
            claimAllSpearsQuests()
            task.wait(0.3)
            local inv = fetchServerInventory() or _G.LastInventory or {}
            local hHandle = hasThunderSpearPart("Handle", inv)
            local hThruster = hasThunderSpearPart("Thruster", inv)
            local hBase = hasThunderSpearPart("Base", inv)
            local allDone = hThruster and hBase   -- Handle บั๊ก → ไม่นับ

            if allDone then
                _G.TSUnlocked = true
                print("[TS AUTO-LEAVE] ✅ TS ครบ (Thruster + Base) → หยุดเช็ค")
                break
            end

            -- ⚡ ควรทำ TS แต่อยู่ Chapel → LEAVE!
            local nextMap = getNextIncompleteMapByItem(inv)
            if not nextMap then
                _G.TSUnlocked = true
                break
            end

            print("═══════════════════════════════════════════")
            print("⚡ [AUTO-LEAVE] อยู่ Chapel แต่ควรทำ Thunder Spear!")
            print(string.format("   → ต่อไปทำ: %s", tostring(nextMap)))
            print(string.format("   Handle=%s Thruster=%s Base=%s",
                hHandle and "✅" or "❌",
                hThruster and "✅" or "❌",
                hBase and "✅" or "❌"))
            print("═══════════════════════════════════════════")
            _G.CurrentAction = "🚪 LEAVE → ทำ TS: "..tostring(nextMap)
            _G.TS_MUST_LEAVE = true

            for i = 1, 10 do
                pcall(function() GET:InvokeServer("S_Missions", "Leave") end)
                pcall(function() GET:InvokeServer("S_Missions", "Retry") end)
                task.wait(1)
                if game.PlaceId ~= placeId then break end
            end
            break
        end
    end)
end

-- ============================================================
-- 🔧 RETRY/LEAVE BUTTON — ระบบเดิมของ Venoz (ที่กดติดปกติ)
-- ============================================================
-- ⚠️ อย่าไปยุ่งกับ timing! RETRY เป็นปุ่ม toggle:
--    • poll 2 วิ + wait 1.5 + wait 3  = เว้นห่างพอให้ countdown เดินจนจบ
--    • ยิง remote เป็น "fallback ทีหลัง" เท่านั้น ไม่ยิงก่อนคลิก
--      (ยิงก่อน + คลิก = toggle 2 ครั้ง = ยกเลิกตัวเอง)
-- ============================================================
task.spawn(function()
    local rewardsUI = interface:WaitForChild("Rewards", 999)
    local cachedButtons = nil
    local cachedMainInfo = nil
    local cachedBoostElement = nil

    local function clickButtonAdvanced(btn)
        if not btn then return false end

        _G.CurrentAction = "Locking on: " .. btn.Name
        pcall(function()
            game:GetService("GuiService").SelectedObject = btn
        end)

        local isLeave = string.find(string.lower(btn.Name), "leave") ~= nil

        -- Hide ALL Trackers securely so they don't block VirtualInputManager
        local trackers = {}
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if v.Name == "VenozTracker" then table.insert(trackers, v) end
            end
            for _, v in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
                if v.Name == "VenozTracker" then table.insert(trackers, v) end
            end
            for _, t in ipairs(trackers) do t.Enabled = false end
        end)

        local isDisabled = false
        if btn:IsA("GuiButton") then
            isDisabled = (btn.Active == false)
        end

        if isDisabled then
            pcall(function()
                if isLeave then GET:InvokeServer("S_Missions", "Leave")
                else GET:InvokeServer("S_Missions", "Retry") end
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
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton1(Vector2.new(
                btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2,
                btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2))
        end)

        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)

            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            local inset = game:GetService("GuiService"):GetGuiInset()
            local cx = absPos.X + (absSize.X / 2)
            local cy = absPos.Y + (absSize.Y / 2) + inset.Y
            vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.1)
            vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)

        task.wait(0.2)
        -- Fallback Remote (ทีหลังเท่านั้น! ถ้ายิงก่อนคลิก = toggle 2 ครั้ง)
        pcall(function()
            if isLeave then GET:InvokeServer("S_Missions", "Leave")
            else GET:InvokeServer("S_Missions", "Retry") end
        end)

        pcall(function() for _, t in ipairs(trackers) do t.Enabled = true end end)
        return true
    end

    while currentID == _G.VenozScriptID and task.wait(2) do
        if rewardsUI and rewardsUI.Visible then
            task.wait(1.5)
            local curLevel = _G.LastLevel or plr:GetAttribute("Level") or 0
            local curPrestige = _G.LastPrestige or plr:GetAttribute("Prestige") or 0
            local maxLevelReq = 100 + (curPrestige * 25)

            pcall(function()
                if not cachedMainInfo then
                    local rMain = rewardsUI:FindFirstChild("Main")
                    local rInfo = rMain and rMain:FindFirstChild("Info")
                    cachedMainInfo = rInfo and rInfo:FindFirstChild("Main")
                end
                if cachedMainInfo and not cachedButtons then
                    cachedButtons = cachedMainInfo:FindFirstChild("Buttons")
                end
                if cachedMainInfo and not cachedBoostElement then
                    cachedBoostElement = cachedMainInfo:FindFirstChild("Boost")
                end
            end)

            local buttons = cachedButtons

            if buttons then
                local btnRetry = buttons:FindFirstChild("Retry")
                local btnLeave = buttons:FindFirstChild("Leave_2") or buttons:FindFirstChild("Leave")

                local buttonToClick = nil

                local shouldLeaveForPerks = false
                if Config.AutoDeletePerk then
                    refreshPerks()   -- ⭐ อ่านจากแหล่งเดียวกับ Lobby
                    local sellTarget = getPerkSellTarget()   -- 30 / 100 / 500
                    if getSellablePerkCount() >= sellTarget then shouldLeaveForPerks = true end
                end

                -- 🔥 พร้อมจุติ? — ⚠️ ต้องตรงกับ Lobby เป๊ะ!
                --    🐛 บั๊กเดิม: เช็คแค่ Level ไม่เช็ค XP
                --       → Level ตันแต่ XP ยังไม่เต็ม + RequiredGold=0 (gold >= 0 = จริงเสมอ)
                --       → Phase 3 คิดว่า "พร้อมจุติ" → LEAVE
                --       → Lobby เห็นว่า XP ไม่เต็ม → ไม่จุติ → สร้าง Chapel ใหม่
                --       → เล่นจบ → LEAVE อีก → วนไม่จบ 🔁
                local curXP    = math.max(tonumber(_G.LastXP) or 0, tonumber(plr:GetAttribute("XP")) or 0)
                local curMaxXP = math.max(tonumber(_G.LastMaxXP) or 0, tonumber(plr:GetAttribute("Max_XP")) or 0)
                if curMaxXP == 0 then curMaxXP = 999999999 end   -- ข้อมูลยังไม่โหลด = ถือว่าไม่ตัน

                local isTan = (curLevel >= maxLevelReq and curXP >= curMaxXP)   -- ⭐ เช็ค XP ด้วย!

                local isReadyToPrestige = false
                if isTan and Config.AutoPrestige and curPrestige < Config.PrestigeTarget then
                    local pk = "P" .. (curPrestige + 1)
                    local ps = Config.VenozPrestige and Config.VenozPrestige[pk] or { RequiredGold = 0 }
                    local rq = (ps.RequiredGold or 0) * 1000000
                    if (_G.LastGold or 0) >= rq then isReadyToPrestige = true end
                end

                -- ⚡ Thunder Spear: LEAVE ทุกรอบ (Lobby จัดการ claim + สร้าง mission ต่อ)
                if TS_ACTIVE then
                    buttonToClick = btnLeave

                    -- 🕐 รอ 6 วิให้ server sync + claim เควสระหว่างรอ
                    print(string.format("[TS] 🕐 %s: รอ server sync 6 วิ ก่อน LEAVE...",
                        tostring(_G.ThunderSpearPart)))
                    _G.CurrentAction = "🕐 รอ sync + claim ก่อน LEAVE"

                    for i = 1, 3 do
                        pcall(function()
                            claimAllSpearsQuests()
                            clickAllClaimButtons()
                        end)
                        task.wait(2)
                    end

                    pcall(function()
                        local inv = fetchServerInventory() or _G.LastInventory or {}
                        print(string.format("[TS] 🚪 LEAVE | Handle=%s Thruster=%s Base=%s",
                            hasThunderSpearPart("Handle", inv)   and "✅" or "❌",
                            hasThunderSpearPart("Thruster", inv) and "✅" or "❌",
                            hasThunderSpearPart("Base", inv)     and "✅" or "❌"))
                    end)

                elseif _G.TS_MUST_LEAVE then
                    buttonToClick = btnLeave
                    print("[Retry/Leave] 🚪 LEAVE — TS_MUST_LEAVE flag")
                elseif isReadyToPrestige then
                    buttonToClick = btnLeave
                    print(string.format("[Retry/Leave] 🚪 LEAVE — พร้อมจุติ (Lv%d/%d XP=%d/%d Gold=%s P%d)",
                        curLevel, maxLevelReq, curXP, curMaxXP,
                        tostring(_G.LastGold or 0), curPrestige))
                elseif shouldLeaveForPerks then
                    buttonToClick = btnLeave
                    print(string.format("[Retry/Leave] 🚪 LEAVE — Perk เต็ม (ขายได้ %d/%d | ทั้งหมด %d)",
                        getSellablePerkCount(), getPerkSellTarget(), _G.TotalPerksCount or 0))
                elseif btnRetry then
                    buttonToClick = btnRetry
                    print(string.format("[Retry/Leave] 🔁 RETRY — Lv%d/%d XP=%d/%d Perk(ขายได้)=%d/%d",
                        curLevel, maxLevelReq, curXP, curMaxXP,
                        getSellablePerkCount(), getPerkSellTarget()))
                else
                    buttonToClick = btnLeave
                    warn("[Retry/Leave] ⚠️ LEAVE — ไม่พบปุ่ม Retry!")
                end

                if buttonToClick then
                    clickButtonAdvanced(buttonToClick)
                end
            else
                cachedMainInfo = nil
                cachedButtons = nil
                cachedBoostElement = nil
            end

            task.wait(3)
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
        task.wait(0.5)   -- [OPT] 0.1 → 0.5 (collision ปิดอยู่แล้ว แค่ re-assert, ไม่ต้องถี่)
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

    -- ========================================================
    -- 🎥 KILL CAMERA SHAKE (ต้องทำ "ในแอคเตอร์" เท่านั้น!)
    -- ========================================================
    -- Effects.Shake_Amount = ตัวสะสมค่าสั่น มีคนบวกเข้าไปหลายที่:
    --   Zones.lua:287   += 3   ← ตอนยิง hitbox ใส่คอไททัน (ตัวหลัก!)
    --   Char.lua:1240   += 10  ← ลงพื้น
    --   Char.lua:1324   += 10  ← roll
    --   Ragdoll.lua:93  += 5   ← ล้ม
    --
    -- ⚠️ module พวกนี้อยู่ใน Actor = คนละ Luau VM กับสคริปต์หลัก
    --    require() จากข้างนอกได้ "คนละ copy" → ตั้ง 0 ยังไงก็ไม่มีผล
    -- ========================================================
    task.spawn(function()
        local Effects = Modules and Modules.Effects
        if not Effects then return end

        local hasMT = false
        pcall(function() hasMT = getmetatable(Effects) ~= nil end)

        local done = false

        -- วิธีที่ 1: metatable — อ่านได้ 0 / เขียนไม่เข้า (ต้นทุน 0 ต่อเฟรม)
        if not hasMT then
            done = pcall(function()
                Effects.Shake_Amount = nil   -- ต้องลบ key ก่อน __newindex ถึงจะทำงาน
                setmetatable(Effects, {
                    __index = function(_, k)
                        if k == "Shake_Amount" then return 0 end
                        return nil
                    end,
                    __newindex = function(t, k, v)
                        if k == "Shake_Amount" then return end   -- กลืนทิ้ง
                        rawset(t, k, v)
                    end,
                })
            end)
        end

        -- วิธีที่ 2 (สำรอง): บังคับเป็น 0 ทุกเฟรม
        if not done then
            while true do
                pcall(function()
                    Effects.Shake_Amount = 0
                    Effects.Small = false
                end)
                task.wait()
            end
        end
    end)
    
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
-- 🗡️ BLADE SYSTEM v6  (ตามโค้ดที่ทำงานจริง)
-- ============================================================
--   เติม (Sets 0/3 + ดาบพัง):
--     POST:FireServer("Attacks", "Reload", GasTank)
--     wait(4)   ⭐ refill กินเวลา ~4 วิ ต้องรอ อย่าไปกวน
--     GasTank = workspace.Unclimbable.Reloads.<Station>.Refill
--
--   สลับชุด (ดาบพัง + Sets > 0):
--     GET:InvokeServer("Blades", "Reload")
--     wait(2)
--
-- 🐛 บั๊กเดิม:
--   • ยิง GET("Blades","Drop") — ไม่มีผลอะไรเลย (คนละ remote)
--   • เช็คผลที่ 0.6 วิ แล้วบินหนี → ยกเลิก refill ของตัวเอง
--   • ไม่ต้องบินไปสถานี! ยิงจากที่ไหนก็ได้
-- ============================================================
local BLADE = {
    busy    = false,   -- กันเรียกซ้อน (combat loop เรียกทุก 0.1s)
    gui     = nil,
    gasTank = nil,
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

-- ⭐ checkbrokensword() — ตรงตามโค้ดที่ทำงานจริง
--    Broken == true  OR  Transparency ~= 0
local function isBladeBroken()
    local char = plr.Character
    if not char then return false end
    local rig = char:FindFirstChild("Rig_" .. plr.Name)
    if not rig then return false end

    for _, hand in ipairs(rig:GetChildren()) do
        if hand.Name == "RightHand" or hand.Name == "LeftHand" then
            for _, b in ipairs(hand:GetChildren()) do
                if b.Name == "Blade_1" then
                    local attr = b:GetAttribute("Broken")
                    if (attr ~= nil and attr == true)
                    or (b:IsA("BasePart") and b.Transparency ~= 0) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ⭐ หา GasTank (สถานีเติม)
--    หลัก:   workspace.Unclimbable.Reloads.<Station>.Refill
--    สำรอง:  สแกนทั้ง workspace หา part ชื่อ "Refill"
local function findGasTank()
    if BLADE.gasTank and BLADE.gasTank.Parent then return BLADE.gasTank end
    BLADE.gasTank = nil

    pcall(function()
        local unc     = workspace:FindFirstChild("Unclimbable")
        local reloads = unc and unc:FindFirstChild("Reloads")
        if not reloads then return end
        for _, station in ipairs(reloads:GetChildren()) do
            local r = station:FindFirstChild("Refill")
            if r then BLADE.gasTank = r; return end
        end
    end)

    -- fallback: สแกนทั้ง workspace (เผื่อ path ต่างกันในแต่ละแมพ)
    if not BLADE.gasTank then
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d.Name == "Refill" then BLADE.gasTank = d; return end
            end
        end)
    end

    if BLADE.gasTank then
        print("[Blade] 📍 GasTank: " .. BLADE.gasTank:GetFullName())
    end
    return BLADE.gasTank
end

-- 🧠 BLADE WORKER — ยิงแล้วรอให้เกมทำงานจนจบ (ไม่ไปกวน)
local function ensureBlade()
    if BLADE.busy then return false end
    if not isBladeBroken() then
        BLADE.busy = false
        return true
    end

    BLADE.busy = true

    task.spawn(function()
        -- ═══ 1) Sets = 0 + ดาบพัง → เติมที่ GasTank ═══
        local guard = 0
        while isBladeBroken() and (readSets() or 0) == 0 and guard < 8 do
            guard = guard + 1

            local refills = plr:GetAttribute("Refills") or 0
            if refills <= 0 then
                if not _G._BladeNoRefill then
                    _G._BladeNoRefill = true
                    warn("[Blade] 🚫 Refills หมด (0) — เติมไม่ได้จนจบภารกิจ")
                end
                break
            end

            local tank = findGasTank()
            if not tank then
                if not _G._BladeNoTank then
                    _G._BladeNoTank = true
                    warn("[Blade] ❌ ไม่พบ GasTank ในแมพนี้")
                end
                break
            end

            print(string.format("[Blade] 📦 Refill #%d (Refills %d) — รอ 4 วิ...",
                guard, refills))
            _G.CurrentAction = string.format("📦 Refill (%d)", refills)

            pcall(function() POST:FireServer("Attacks", "Reload", tank) end)
            task.wait(4)   -- ⭐ ต้องรอให้เสร็จ อย่ายิงซ้ำ อย่าขยับ
        end

        -- ═══ 2) ดาบพัง + มี Sets → สลับชุด ═══
        guard = 0
        while isBladeBroken() and (readSets() or 0) > 0 and guard < 6 do
            guard = guard + 1
            local sets = readSets() or 0
            print(string.format("[Blade] 🔄 Reload #%d (Sets %d/3)", guard, sets))
            _G.CurrentAction = string.format("🔄 Reload (%d/3)", sets)

            pcall(function() GET:InvokeServer("Blades", "Reload") end)
            task.wait(2)   -- ⭐ รอ 2 วิ
        end

        if not isBladeBroken() then
            print(string.format("[Blade] ✅ ดาบพร้อมใช้ (Sets %s/3)",
                tostring(readSets() or "?")))
            _G._BladeNoRefill = nil
        end

        BLADE.busy = false
    end)

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
        dprint(string.format("[Blade] 📊 Sets=%s/3  Broken=%s  Refills=%s%s",
            tostring(readSets() or "?"),
            isBladeBroken() and "YES" or "no",
            tostring(plr:GetAttribute("Refills") or "?"),
            BLADE.busy and "  (กำลังเติม...)" or ""))
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
-- ============================================================
-- 🐎 ESCORT — เฝ้าขบวนรถม้า (Outskirts)
-- ============================================================
-- รถม้าอยู่ที่ workspace.Unclimbable.Objective.Escort.Cart (มีหลายคัน)
-- ⚠️ ถ้าบอทลอยไปไล่ฆ่าไททันไกลๆ → รถม้าโดนทุบพัง → Escort Convoy 0/4
--    ต้องเกาะขบวน + ฆ่าเฉพาะไททันที่เข้าใกล้รถ
-- ============================================================
local ESCORT_RADIUS = 400   -- ตีเฉพาะไททันที่อยู่ในรัศมีนี้จากรถม้า

-- 🎯 หา cart ทั้งหมดใน Objective folder — โครงสร้างจริงคือ:
--   workspace.Unclimbable.Objective:
--     [1] Escort (Model)  ← main + side #1
--         └── Cart.Main   ← จุดเกาะจริง
--         └── Health      ← มี Max_Health attribute
--     [2] Escort (Model)  ← MAIN convoy (Max_Health=41 = 2x)
--     [3] Escort (Model)  ← side #2
-- 🚨 บอทต้องเฝ้า MAIN (Max_Health สูงสุด) เป็นอันดับแรก!
--    ไม่งั้น main ตาย → Objective.Escort ไม่มีทาง = 1/1 → SPEARS ไม่ credit
local function findCarts()
    local list = {}
    local unc = workspace:FindFirstChild("Unclimbable")
    local objFolder = unc and unc:FindFirstChild("Objective")
    if not objFolder then return list end

    for _, escModel in ipairs(objFolder:GetChildren()) do
        if escModel.Name == "Escort" and not escModel:GetAttribute("Dead") then
            -- ข้าม cart ที่ตายแล้ว
            local cart = escModel:FindFirstChild("Cart")
            local health = escModel:FindFirstChild("Health")
            local maxHP = health and health:GetAttribute("Max_Health") or 0

            local base = cart and (cart:FindFirstChild("Main")
                                or cart:FindFirstChild("LPCartBase")
                                or cart:FindFirstChildWhichIsA("BasePart", true))
            if base and base:IsA("BasePart") then
                table.insert(list, {
                    part = base,
                    maxHP = maxHP,
                    curHP = health and health.Value or 0,
                    isMain = maxHP > 25,   -- main = HP > 25 (main=41, side=21)
                    esc = escModel,
                })
            end
        end
    end

    -- 🎯 เรียงลำดับ: MAIN ก่อน (Max_HP สูงสุด) → ตามด้วย HP ต่ำสุด (ใกล้ตาย)
    table.sort(list, function(a, b)
        if a.isMain ~= b.isMain then return a.isMain end   -- main มาก่อน
        return a.curHP < b.curHP                            -- HP ต่ำก่อน (urgent)
    end)

    -- แปลงเป็น array ของ BasePart (backward compat กับโค้ดเดิม)
    local parts = {}
    for _, c in ipairs(list) do table.insert(parts, c.part) end

    -- ส่ง metadata ผ่าน _G เผื่อ debug
    _G._CartInfo = list

    return parts
end

local function convoyCenter(carts)
    if not carts or #carts == 0 then return nil end
    local sum = Vector3.new(0, 0, 0)
    for _, c in ipairs(carts) do sum = sum + c.Position end
    return sum / #carts
end

-- ไททันตัวนี้อยู่ใกล้รถม้าไหม
local function nearAnyCart(titan, carts)
    local tr = titan:FindFirstChild("HumanoidRootPart")
             or titan:FindFirstChild("Nape", true)
    if not tr then return false end
    for _, cart in ipairs(carts) do
        if (tr.Position - cart.Position).Magnitude <= ESCORT_RADIUS then
            return true
        end
    end
    return false
end

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
                    local carts = findCarts()
                    local phase = "GUARD"
                    pcall(function()
                        local e = ReplicatedStorage:FindFirstChild("Objectives")
                                and ReplicatedStorage.Objectives:FindFirstChild("Escort")
                        if e and (e.Value or 0) >= (e:GetAttribute("Requirement") or 1) then
                            phase = "CLEANUP"
                        end
                    end)
                    if phase == "CLEANUP" then
                        _G.CurrentAction = string.format("⚔️ CLEANUP: ไล่ตี titan ที่เหลือ (%d)", aliveCount)
                    elseif #carts > 0 then
                        _G.CurrentAction = string.format("🐎 GUARD %d คัน (titan ใกล้=%d)",
                            #carts, aliveCount)
                    else
                        _G.CurrentAction = string.format("⚡ KILL_ALL (alive=%d)", aliveCount)
                    end

                    -- 🎯 ไม่กด LEAVE mid-mission!
                    --    ทำให้ mission ถูกนับเป็น "abandon" → SPEARS Escort quest ไม่ credit
                    --    (Rewards UI จะโผล่เอง → Retry/Leave logic จัดการต่อ)
                    --    Anti-lag ถูกปิดใน TS map แล้ว → ไททันไม่ตกแมพ → mission จบธรรมชาติได้
                end
            -- THRUSTER: Utgard (kill 3 Ice Burst — แต่ตีทุก titan เพื่อ progress)
            elseif TS_MAP == "Utgard" then
                _G.CurrentAction = string.format("❄️ Ice Burst %d/3 (ตี titan ทั้งหมด)", TS_ICE_KILLS)

                -- 🎯 ไม่กด LEAVE mid-mission ตัวจะทำให้ SPEARS Ice Burst quest ไม่ credit
                --    ปล่อย mission จบ 3 Ice Burst → Rewards UI โผล่ → Retry/Leave logic จัดการ
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

                    -- 🎯 ไม่กด LEAVE mid-mission ทำให้ SPEARS Defend quest ไม่ credit
                    --    Mission จะจบเองเมื่อรอด defend phase → Rewards UI โผล่
                end
            end
        end

        -- ============================================================
        -- ⚔️ COMBAT (ทั้ง TS + normal farming)
        -- ============================================================
        local aliveTitans = {}
        local currentTotalHealth = 0
        local currentTitans = TitansFolder:GetChildren()

        -- 🎯 Filter เป้าหมาย
        local filterFn = nil

        -- 🐎 ESCORT (Outskirts) — 2-Phase
        --   Phase 1: GUARD  → เกาะรถ ตีไททันใกล้รถ (จนกว่ารถถึงปลายทาง)
        --   Phase 2: CLEANUP → ไล่ล่าไททันที่เหลือทุกตัวในแมพ (mission ต้องฆ่าครบ)
        --   สลับเมื่อ Objectives.Escort.Value >= Requirement
        local escortCarts, convoyPos = nil, nil
        local escortPhase = "GUARD"
        if TS_ACTIVE and TS_MAP == "Outskirts" then
            -- เช็ค Escort objective — ถ้าครบแล้ว = สลับเป็น CLEANUP
            pcall(function()
                local objf = ReplicatedStorage:FindFirstChild("Objectives")
                local e = objf and objf:FindFirstChild("Escort")
                if e then
                    local cur = e.Value or 0
                    local req = e:GetAttribute("Requirement") or 1
                    if cur >= req then escortPhase = "CLEANUP" end
                end
            end)

            escortCarts = findCarts()

            if escortPhase == "CLEANUP" then
                -- 🎯 CLEANUP: ไล่ล่าทุกไททัน — ไม่ filter
                if not _G._CleanupAnnounced then
                    _G._CleanupAnnounced = true
                    _G._EscortAnnounced = false
                    print("[TS] ⚔️ Escort ✅ ครบแล้ว → CLEANUP: ตี titan ที่เหลือทุกตัว")
                end
                -- filterFn = nil = ตีทุก titan
                -- convoyPos = nil = บอทบินตาม titan ปกติ (ไม่เกาะรถ)
            elseif #escortCarts > 0 then
                -- 🐎 GUARD phase
                convoyPos = convoyCenter(escortCarts)
                _G._LastConvoyPos = convoyPos
                filterFn = function(t) return nearAnyCart(t, escortCarts) end

                if not _G._EscortAnnounced then
                    _G._EscortAnnounced = true
                    _G._CleanupAnnounced = false
                    local info = _G._CartInfo or {}
                    local msg = string.format("[TS] 🐎 GUARD — %d คัน", #escortCarts)
                    for i, c in ipairs(info) do
                        msg = msg .. string.format("\n   #%d %s HP=%d/%d %s",
                            i, c.isMain and "MAIN⭐" or "side ",
                            c.curHP, c.maxHP,
                            i == 1 and "← เฝ้าก่อน" or "")
                    end
                    print(msg)
                end
            else
                -- findCarts พลาดชั่วคราว → ใช้ตำแหน่งเก่า
                if _G._LastConvoyPos then
                    convoyPos = _G._LastConvoyPos
                end
                if _G._EscortAnnounced then _G._EscortAnnounced = false end
            end
        end

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

            -- 🎯 คำนวณจุดที่ควรอยู่ให้เสร็จก่อน แล้วค่อยขยับ "ครั้งเดียว"
            --    เดิม: set CFrame 2 ครั้ง ทุก 0.1 วิ (ซ้ำที่เดิม) → สั่น + เปลือง
            if not currentRoot.Anchored then currentRoot.Anchored = true end

            if TS_ACTIVE and TS_MAP == "Forest" then
                -- ระหว่าง defend, hover ที่ Supplies_Circle
                local circle = findCircle()
                if circle and circle.hitbox then
                    safePos = circle.hitbox.Position + Vector3.new(0, 150, 0)
                end
                _G.CurrentAction = "⏳ รอ titan spawn (Defend)"
            elseif TS_ACTIVE and TS_MAP == "Utgard" then
                _G.CurrentAction = string.format("⏳ รอ titan spawn (Ice Burst %d/3)", TS_ICE_KILLS)
            elseif TS_ACTIVE and TS_MAP == "Outskirts" then
                -- 🐎 ไม่มีไททันใกล้รถ → เกาะรถแน่น (คันหลัก)
                local carts = findCarts()
                if carts[1] then
                    safePos = carts[1].Position + Vector3.new(0, 6, 0)   -- เกาะแนบ
                    _G.CurrentAction = string.format("🐎 เกาะรถ %d คัน", #carts)
                elseif _G._LastConvoyPos then
                    safePos = _G._LastConvoyPos + Vector3.new(0, 6, 0)
                    _G.CurrentAction = "🐎 เกาะรถ (cached)"
                else
                    _G.CurrentAction = "⏳ รอ titan / รถม้า"
                end
            else
                _G.CurrentAction = "Combat: Waiting for Titans..."
            end

            -- ขยับเฉพาะเมื่อหลุดเกิน 10 studs (deadzone = ไม่สั่น)
            -- 🐎 escort = deadzone 2 (ตามรถขยับ) / อื่นๆ deadzone 10
            local idleDead = (TS_ACTIVE and TS_MAP == "Outskirts") and 2 or 10
            if (currentRoot.Position - safePos).Magnitude > idleDead then
                currentRoot.CFrame = CFrame.new(safePos)
            end
            continue
        end
        
        table.sort(aliveTitans, function(a, b) return a.dist < b.dist end)
        local targetTitan = aliveTitans[1]
        
        if targetTitan and targetTitan.root then
            local FloatHeight = 250
            local targetPos = Vector3.new(targetTitan.root.Position.X, targetTitan.root.Position.Y + FloatHeight, targetTitan.root.Position.Z)

            -- 🐎 ESCORT GUARD: เกาะรถแน่น (ไม่ลอย ไม่ห่าง)
            --    ⭐ พิกัดอิงตรงกับ escortCarts[1] (คันหลัก) + offset นิดเดียว
            --    → บอทติดรถแน่น physics ตามรถทันที
            --    ⚠️ CLEANUP → บินตามไททันปกติ (เพื่อเก็บให้ครบ mission จบ)
            local isEscortGuard = TS_ACTIVE and TS_MAP == "Outskirts" and escortPhase == "GUARD"
            if isEscortGuard and escortCarts and escortCarts[1] then
                -- เกาะคันหลัก (คันแรก) เพื่อ server track ว่าเรา ride cart นี้อยู่
                targetPos = escortCarts[1].Position + Vector3.new(0, 6, 0)
            elseif isEscortGuard and convoyPos then
                -- fallback ถ้าไม่มี escortCarts (findCarts พลาด)
                targetPos = convoyPos + Vector3.new(0, 6, 0)
            end

            -- 🎯 ANTI-SHAKE
            --   • ตั้ง CFrame ตอน Anchored อยู่ได้เลย → วาร์ปเนียน ไม่มี physics
            --     (เดิม: ปลด anchor → wait(0.02) → anchor กลับ
            --            = แรงโน้มถ่วงเข้ามา 1 เฟรม → ตัวกระตุก + หยุดลูปตี)
            --   • deadzone 40 studs → ขยับน้อยลง กล้องนิ่งกว่ามาก
            --     (hitbox ยิงได้ไกล 400 อยู่แล้ว ไม่ต้องเกาะติดขนาดนั้น)
            local distToTarget = (currentRoot.Position - targetPos).Magnitude

            if not currentRoot.Anchored then
                currentRoot.Anchored = true
            end

            -- 🐎 เกาะรถแน่น deadzone 2 studs / combat ปกติ 40 studs
            local deadzone = isEscortGuard and 2 or 40
            if distToTarget > deadzone then
                currentRoot.CFrame = CFrame.new(targetPos)   -- anchored อยู่ = วาร์ปนิ่ง ไม่มี wait
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
