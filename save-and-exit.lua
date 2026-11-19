-- Local campaign resume for Hatred Windows build 1232203 / Hatred 1.333.
-- Main Menu uses the game's native checkpoint for travel and inventory.
-- A separate file records the player and mission state for Continue.
local gameClass = "/Script/Hatred.HatredGameInstance"
local heroClass = "/Script/Hatred.HeroCharacterController"
local vehicleClass = "/Script/Hatred.HatredBaseVehicle"
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local gamePath = source:match("^(.*)/Binaries/Win64/ue4ss/Mods/")
assert(gamePath, "Campaign resume must run as a UE4SS mod")
local savedPath = gamePath .. "/Saved/"
local slotBase = savedPath .. "CampaignResume"
local magic = "HTDRESUME\1"
local maxFileSize = 1024 * 1024
local statics = StaticFindObject("/Script/Engine.Default__GameplayStatics")

local function log(message)
    print("[Campaign resume] " .. message .. "\n")
end

local function valid(object)
    return object and object.IsValid and object:IsValid()
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function numbers(value, keys)
    if type(value) ~= "table" then return false end
    for _, key in ipairs(keys) do
        if not finite(value[key]) then return false end
    end
    return true
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local data = file:read(maxFileSize + 1)
    file:close()
    if data and #data <= maxFileSize then return data end
end

local function toText(value)
    return value and value:ToString() or ""
end

local function mode()
    local path = (readFile(savedPath .. "active_tc") or ""):gsub("\\", "/")
    return path:match("([^/]+)%.hatmod%s*$") or "base"
end

local function campaignMap(gi)
    local name = toText(gi:GetCurrentMapName()):lower()
    return name:match("^lvl_0[1-7]_[a-z0-9_]+_p$") and name or nil
end

local function nativeSlot(gi)
    local profile = gi:GetPersistentUser()
    if not valid(profile) then return nil end
    return {
        map = toText(profile.SimpleCheckpointMapName):lower(),
        path = toText(profile.SimpleCheckpointMapPathName):lower(),
        checkpoint = toText(profile.SimpleCheckpointID):lower(),
        difficulty = profile.SimpleCheckpointDifficulty,
        time = profile.SimpleCheckpointMapGameplayTime,
        mode = mode(),
    }
end

local function sameSlot(a, b)
    return a and b and a.map == b.map and a.path == b.path and
        a.checkpoint == b.checkpoint and a.difficulty == b.difficulty and
        a.time == b.time and a.mode == b.mode
end

-- Bounded data format; the save file is never interpreted as Lua source.
local function serialize(value, result, depth)
    assert(depth < 12, "Save nested too deeply")
    local kind = type(value)
    if kind == "number" then
        assert(finite(value), "Non-finite number in save")
        result[#result + 1] = "n" .. string.pack("<d", value)
    elseif kind == "string" then
        assert(#value <= 8192, "String too long")
        result[#result + 1] = "s" .. string.pack("<s4", value)
    elseif kind == "boolean" then
        result[#result + 1] = value and "y" or "x"
    elseif kind == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        assert(count <= 8192, "Too many values in save")
        result[#result + 1] = "t" .. string.pack("<I4", count)
        for key, item in pairs(value) do
            serialize(key, result, depth + 1)
            serialize(item, result, depth + 1)
        end
    else
        error("Unsupported value in save: " .. kind)
    end
end

local function decode(data)
    assert(data:sub(1, #magic) == magic, "Unrecognized campaign save")
    local pos = #magic + 1
    local function parse(depth)
        assert(depth < 12, "Nested save")
        local tag = data:sub(pos, pos)
        pos = pos + 1
        if tag == "s" then
            local text
            text, pos = string.unpack("<s4", data, pos)
            assert(#text <= 8192)
            return text
        elseif tag == "n" then
            local value
            value, pos = string.unpack("<d", data, pos)
            assert(finite(value))
            return value
        elseif tag == "y" or tag == "x" then
            return tag == "y"
        elseif tag == "t" then
            local count, tableValue
            count, pos = string.unpack("<I4", data, pos)
            assert(count <= 8192 and count <= #data - pos + 1)
            tableValue = {}
            for _ = 1, count do
                local key = parse(depth + 1)
                assert(type(key) == "string" or type(key) == "number")
                assert(tableValue[key] == nil)
                tableValue[key] = parse(depth + 1)
            end
            return tableValue
        end
        error("Malformed campaign save")
    end
    local value = parse(0)
    assert(pos == #data + 1 and type(value) == "table" and finite(value.sequence))
    assert(type(value.native) == "table" and type(value.player) == "table")
    assert(numbers(value.player.position, {"X", "Y", "Z"}))
    assert(numbers(value.player.rotation, {"Pitch", "Yaw", "Roll"}))
    assert(numbers(value.player.view, {"Pitch", "Yaw", "Roll"}))
    assert(finite(value.player.health) and value.player.health > 0)
    assert(value.player.vehicle == false or type(value.player.vehicle) == "string")
    assert(not value.player.vehicleHealth or numbers(value.player.vehicleHealth, {"body", "engine", "fuel"}))
    assert(type(value.quests) == "table" and type(value.quests.main) == "table" and type(value.quests.side) == "table")
    assert(type(value.scripts) == "table" and numbers(value, {"kills", "gameplayTime", "finishedSideQuests"}))
    return value
end

local function readSlot(path)
    local data = readFile(path)
    if not data then return nil end
    local ok, result = pcall(decode, data)
    if ok then return result end
    log("Ignoring unreadable resume file " .. path)
end

local function resumeFiles(mod)
    local suffix = mod:gsub("[^%w_-]", "_"):sub(1, 80)
    return slotBase .. "." .. suffix .. ".1", slotBase .. "." .. suffix .. ".2"
end

local function loadSnapshot(slot)
    if not slot then return nil end
    local a, b = resumeFiles(slot.mode)
    local best
    for _, path in ipairs({a, b}) do
        local item = readSlot(path)
        if item and sameSlot(item.native, slot) and (not best or item.sequence > best.sequence) then
            best = item
        end
    end
    return best
end

local function storeSnapshot(snapshot)
    local a, b = resumeFiles(snapshot.native.mode)
    local first, second = readSlot(a), readSlot(b)
    local aSeq, bSeq = first and first.sequence or 0, second and second.sequence or 0
    snapshot.sequence = math.max(aSeq, bSeq) + 1
    local path = aSeq <= bSeq and a or b
    local temporary = path .. ".tmp"
    local parts = {magic}
    serialize(snapshot, parts, 0)
    local data = table.concat(parts)
    assert(#data <= maxFileSize)
    local file = assert(io.open(temporary, "wb"))
    local wrote, reason = file:write(data)
    local closed = file:close()
    assert(wrote and closed, reason or "Could not write resume state")
    assert(readFile(temporary) == data, "Could not verify resume state")
    os.remove(path)
    assert(os.rename(temporary, path))
end

local function worldSettings(world)
    local name = world:GetFullName():match("^World (.+)$")
    if not name then return nil end
    local prefix = name .. ":PersistentLevel."
    for _, settings in ipairs(FindAllOf("HatredWorldSettings") or {}) do
        if settings:GetFullName():find(prefix, 1, true) then return settings end
    end
end

local function positionOf(value)
    return {X = value.X, Y = value.Y, Z = value.Z}
end

local function rotationOf(value)
    return {Pitch = value.Pitch, Yaw = value.Yaw, Roll = value.Roll}
end

local function transformOf(value)
    local q = value.Rotation
    return {Translation = positionOf(value.Translation), Scale3D = positionOf(value.Scale3D),
        Rotation = {X = q.X, Y = q.Y, Z = q.Z, W = q.W}}
end

local function captureQuests(quests)
    local data = {}
    for i = 1, #quests do
        local q = quests[i]
        data[q.ID] = {
            kills = q.KillCounter,
            completed = q.bIsCompleted,
            started = q.TimeWhenQuestStarted,
            finished = q.TimeWhenQuestCompleted,
            alpha = q.Alpha,
            completedAt = q.bIsCompleted and transformOf(q.PlayerTransformWhenQuestCompleted) or false,
        }
    end
    return data
end

local function restoreQuests(quests, saved)
    local count = 0
    for i = 1, #quests do
        local quest = quests[i]
        local values = saved and saved[quest.ID]
        if values then
            quest.KillCounter = values.kills
            quest.bIsCompleted = values.completed
            quest.TimeWhenQuestStarted = values.started
            quest.TimeWhenQuestCompleted = values.finished
            quest.Alpha = values.alpha
            if values.completedAt then
                quest.PlayerTransformWhenQuestCompleted = values.completedAt
            end
            count = count + 1
        end
    end
    return count
end

local function actorKey(actor)
    local class = actor:GetClass():GetFullName()
    local path = actor:GetFullName():match("^[^ ]+ (.+)$")
    return class .. "|" .. path
end

local function levelVariables(actor)
    local fields = {}
    actor:GetClass():ForEachProperty(function(property)
        local success, full = pcall(function() return property:GetFullName() end)
        if not success or not full then return end
        local kind, name = full:match("^(%w+Property) .+:([^:]+)$")
        if not name or name:match("^K2Node_") or name:match("^CallFunc_") or name:match("^Temp_") then return end
        if kind == "BoolProperty" or kind == "IntProperty" or kind == "FloatProperty" or kind == "ByteProperty" then
            local ok, value = pcall(function() return actor[name] end)
            if ok and (type(value) == "boolean" or finite(value)) then fields[name] = value end
        end
    end)
    return fields
end

local function eachLevelScript(world, visit)
    local address = world:GetAddress()
    for _, actor in ipairs(FindAllOf("LevelScriptActor") or {}) do
        if valid(actor) and actor:GetWorld():GetAddress() == address then visit(actor) end
    end
end

local function captureScripts(world)
    local entries = {}
    eachLevelScript(world, function(actor)
        local ok, vars = pcall(levelVariables, actor)
        if ok and next(vars) then entries[actor:GetClass():GetFullName()] = vars end
    end)
    return entries
end

local function restoreScripts(world, scripts)
    eachLevelScript(world, function(actor)
        local row = scripts[actor:GetClass():GetFullName()]
        if not row then return end
        local ok, current = pcall(levelVariables, actor)
        if not ok then return end
        for name, value in pairs(row) do
            if type(value) == type(current[name]) then actor[name] = value end
        end
    end)
end

local function locationString(value)
    return string.format("%.2f %.2f %.2f", value.X, value.Y, value.Z)
end

local function checkpointFor(gi, map)
    local previous = nativeSlot(gi)
    local offset = map:match("^lvl_(0[1-7])_")
    local prefix = "lvl_" .. offset .. "_"
    if previous and previous.map == map and previous.checkpoint:sub(1, #prefix) == prefix then
        return previous.checkpoint
    end
    return prefix .. (offset == "07" and "01" or "00")
end

local function heroFor(controller, pawn)
    if pawn:IsA(heroClass) then return pawn end
    if pawn:IsA(vehicleClass) then
        local driver = pawn.MyDriver
        if valid(driver) and driver:IsA(heroClass) then return driver end
    end
    local hero = controller.HatredPawn
    if valid(hero) and hero:IsA(heroClass) then return hero end
end

local function capture(gi, shortcut)
    local map = campaignMap(gi)
    if not map then return end
    local controller = statics:GetPlayerController(gi, 0)
    local pawn = statics:GetPlayerPawn(gi, 0)
    if not valid(controller) or not valid(pawn) then return end
    local hero = heroFor(controller, pawn)
    if not valid(hero) or hero.Health <= 0 then return end
    local pause = gi.PauseMenuRef
    if valid(pause) and pause.IsDeathScreen then return end
    if not shortcut and not gi:IsPauseMenuActive() then return end

    local world = gi:GetWorld()
    local settings = assert(worldSettings(world), "Mission data is unavailable")
    local vehicle = pawn:IsA(vehicleClass)
    if not vehicle and not pawn:IsA(heroClass) then return end

    local snapshot = {
        player = {
            position = positionOf(pawn:K2_GetActorLocation()),
            rotation = rotationOf(pawn:K2_GetActorRotation()),
            view = rotationOf(controller:GetControlRotation()),
            health = hero.Health,
            vehicle = vehicle and actorKey(pawn) or false,
            vehicleHealth = vehicle and {body = pawn.Health, engine = pawn.EngineHealth, fuel = pawn.FuelTankHealth} or false,
        },
        quests = {main = captureQuests(settings.MainQuests), side = captureQuests(settings.SideQuests)},
        scripts = captureScripts(world),
        kills = gi.KillCounter,
        gameplayTime = gi.MapGameplayTime,
        finishedSideQuests = gi.FinishedSideQuestOnCurrentLevel,
    }
    assert(gi:WriteSimpleCheckpoint(checkpointFor(gi, map)), "Game refused to write its checkpoint")
    snapshot.native = assert(nativeSlot(gi), "Game profile is unavailable")
    assert(snapshot.native.map == map and snapshot.native.checkpoint ~= "", "Wrong native checkpoint after save")
    storeSnapshot(snapshot)
    log("Saved " .. map .. " " .. locationString(snapshot.player.position))
    return true
end

local function readPawn(gi)
    local controller = statics:GetPlayerController(gi, 0)
    local pawn = statics:GetPlayerPawn(gi, 0)
    if not valid(controller) or not valid(pawn) then return nil end
    local hero = heroFor(controller, pawn)
    if not valid(hero) or hero.Health <= 0 then return nil end
    if not (pawn:IsA(vehicleClass) or pawn:IsA(heroClass)) then return nil end
    return pawn, controller, hero
end

local function findVehicle(world, key)
    local worldAddress = world:GetAddress()
    for _, vehicle in ipairs(FindAllOf("HatredBaseVehicle") or {}) do
        if vehicle:GetWorld():GetAddress() == worldAddress and actorKey(vehicle) == key then
            return vehicle
        end
    end
end

local function matchPossession(gi, player, pawn, hero)
    if player.vehicle then
        if pawn:IsA(vehicleClass) and actorKey(pawn) == player.vehicle then return true end
        local target = findVehicle(gi:GetWorld(), player.vehicle)
        if not valid(target) then return false end
        if pawn:IsA(vehicleClass) then
            pawn:ForceStopVehicleAndGetOutAllPawns(false)
            return false
        end
        hero:TeleportToVehicleDriverSeat(target)
        return false
    end
    if pawn:IsA(heroClass) then return true end
    pawn:ForceStopVehicleAndGetOutAllPawns(false)
    return false
end

local function restore(gi, snapshot, pawn, controller, hero)
    local world = gi:GetWorld()
    local settings = assert(worldSettings(world), "Mission data is unavailable")
    local player = snapshot.player
    assert(finite(player.health) and player.health > 0)
    local moved = pawn:K2_SetActorLocationAndRotation(player.position, player.rotation, false, {}, true)
    assert(moved, "Game refused the saved position")
    statics:FlushLevelStreaming(gi)
    controller:SetControlRotation(player.view)
    hero.Health = player.health
    if player.vehicleHealth and pawn:IsA(vehicleClass) then
        pawn.Health = player.vehicleHealth.body
        pawn.EngineHealth = player.vehicleHealth.engine
        pawn.FuelTankHealth = player.vehicleHealth.fuel
    end
    local count = restoreQuests(settings.MainQuests, snapshot.quests.main)
    count = count + restoreQuests(settings.SideQuests, snapshot.quests.side)
    gi.KillCounter = snapshot.kills
    gi.MapGameplayTime = snapshot.gameplayTime
    gi.FinishedSideQuestOnCurrentLevel = snapshot.finishedSideQuests
    restoreScripts(world, snapshot.scripts)
    log("Restored " .. snapshot.native.map .. " " .. locationString(positionOf(pawn:K2_GetActorLocation())) ..
        "; objectives=" .. count)
end

local pending, currentGame, delayHandle
local function schedule(gi, snapshot)
    if delayHandle then CancelDelayedAction(delayHandle) end
    pending, currentGame = snapshot, gi
    local tries, stable, lastPawn, nextPossessionAttempt = 0, 0, nil, 0
    delayHandle = LoopInGameThreadWithDelay(150, function()
        tries = tries + 1
        if tries > 240 or not valid(currentGame) then
            log("Resume timed out waiting for the campaign pawn")
            CancelDelayedAction(delayHandle)
            delayHandle, pending = nil, nil
            return
        end
        if campaignMap(currentGame) ~= pending.native.map then return end
        local pawn, controller, hero = readPawn(currentGame)
        if not valid(pawn) then return end
        local address = pawn:GetAddress()
        stable = address == lastPawn and stable + 1 or 0
        lastPawn = address
        if stable < 3 then return end
        if not worldSettings(currentGame:GetWorld()) then return end
        if tries < nextPossessionAttempt then return end
        local ok, matched = pcall(matchPossession, currentGame, pending.player, pawn, hero)
        if not ok or not matched then
            nextPossessionAttempt = tries + 12
            return
        end

        CancelDelayedAction(delayHandle)
        delayHandle = nil
        local state = pending
        pending = nil
        local success, problem = pcall(restore, currentGame, state, pawn, controller, hero)
        if not success then log("Restore failed: " .. tostring(problem)) end
    end)
end

local shortcutExit = false
RegisterHook(gameClass .. ":ReturnToMainMenu", function(context)
    if shortcutExit then return end
    local success, problem = pcall(capture, context:get())
    if not success then log("Save failed: " .. tostring(problem)) end
end)

RegisterHook(gameClass .. ":StartGameFromSimpleCheckpoint", function(context)
    local gi = context:get()
    if campaignMap(gi) then return end
    local success, snapshot = pcall(function() return loadSnapshot(nativeSlot(gi)) end)
    if success and snapshot then
        log("Loading " .. snapshot.native.map)
        schedule(gi, snapshot)
    elseif not success then
        log("Could not read resume state: " .. tostring(snapshot))
    end
end)

RegisterKeyBind(Key.F6, {ModifierKey.CONTROL}, function()
    ExecuteInGameThread(function()
        local gi = FindFirstOf("BP_HatredGameInstance_C")
        if not valid(gi) then return end
        local success, saved = pcall(capture, gi, true)
        if not success then
            log("Save failed: " .. tostring(saved))
        elseif saved then
            shortcutExit = true
            local exited, result = pcall(function() return gi:ReturnToMainMenu() end)
            shortcutExit = false
            if not exited or result == false then log("Exit failed: " .. tostring(result)) end
        end
    end, EGameThreadMethod.EngineTick)
end)

log("Ready")
