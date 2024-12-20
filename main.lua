local mod = RegisterMod("Hermes Boots", 1)
local game = Game()
local sfx = SFXManager()
local json = require("json")
local font = Font()
font:Load("font/pftempestasevencondensed.fnt")

-- Constants
local SOUND_THUMBS_UP = Isaac.GetSoundIdByName("Thumbs up")
local HermesBoots = Isaac.GetItemIdByName("Herme's Boots")
local baseTimeLimit = 10 -- Base time limit in seconds
local HermesBootsDamageIncrease = 0.5 -- Flat damage increase per clear
local HermesBootsTearDecrease = 0.2 -- Flat tear delay decrease per clear
local HermesBootsSpeed = 0.3  -- Flat speed increase per clear

-- Variables
local roomsCleared = 0 
local roomStartTime = 0
local clearedRooms = {}
local currentRoomIndex = ""

-- Persistent data storage
function mod:OnGameStart(isContinue)
    if mod:HasData() then
        local loadedData = json.decode(mod:LoadData())
        roomsCleared = loadedData.roomsCleared or 0
        clearedRooms = loadedData.clearedRooms or {}
    else
        roomsCleared = 0
        clearedRooms = {}
    end
end

-- Save data when the run ends or when quitting the game
function mod:OnGameExit()
    local dataToSave = {
        roomsCleared = roomsCleared,
        clearedRooms = clearedRooms
    }
    mod:SaveData(json.encode(dataToSave))
end

function mod:EvaluateCache(player, cacheFlags)
    local itemCount = player:GetCollectibleNum(HermesBoots)
    if itemCount > 0 then
        local damageToAdd = HermesBootsDamageIncrease * roomsCleared
        local tearDecrease = HermesBootsTearDecrease * roomsCleared
        local speedToAdd = HermesBootsSpeed * roomsCleared

        if cacheFlags & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + damageToAdd
        end
        if cacheFlags & CacheFlag.CACHE_FIREDELAY == CacheFlag.CACHE_FIREDELAY then
            player.MaxFireDelay = player.MaxFireDelay - tearDecrease
            -- Ensure fire delay doesn't go below 1
            if player.MaxFireDelay < 1 then
                player.MaxFireDelay = 1
            end
        end
        if cacheFlags & CacheFlag.CACHE_SPEED == CacheFlag.CACHE_SPEED then
            player.MoveSpeed = player.MoveSpeed + speedToAdd
        end
    end
end

function mod:getTimeLimit()
    local currentFloor = game:GetLevel():GetStage()
    local additionalTime = currentFloor + 1
    return baseTimeLimit + additionalTime   
end

function mod:GetRoomUniqueIndex()
    local level = game:GetLevel()
    local roomDesc = level:GetCurrentRoomDesc()
    local roomIndex = level:GetCurrentRoomIndex()
    return tostring(roomDesc.GridIndex) .. "-" .. tostring(roomIndex)
end

function mod:HermesNewRoom()
    local newRoomIndex = mod:GetRoomUniqueIndex()
    
    if newRoomIndex ~= currentRoomIndex then
        currentRoomIndex = newRoomIndex
        if not clearedRooms[currentRoomIndex] then
            roomStartTime = game.TimeCounter
            print("Entered new uncleared room. Starting timer. Time counter: " .. roomStartTime)
        else
            print("Re-entered previously cleared room. No timer started.")
        end
    else
        print("Still in the same room. No changes.")
    end
end

function mod:HermesUpdate()
    local room = game:GetRoom()
    local playerCount = game:GetNumPlayers()

    for playerIndex = 0, playerCount - 1 do
        local player = Isaac.GetPlayer(playerIndex)
        local copyCount = player:GetCollectibleNum(HermesBoots)

        if copyCount > 0 then
            if room:IsClear() and not clearedRooms[currentRoomIndex] then
                local roomTime = (game.TimeCounter - roomStartTime) / 30 -- Convert frames to seconds
                local timeLimit = mod:getTimeLimit()

                if roomTime <= timeLimit then
                    roomsCleared = roomsCleared + 1
                    clearedRooms[currentRoomIndex] = true
                    print("Room cleared! Total rooms cleared: " .. roomsCleared)

                    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                    player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
                    player:AddCacheFlags(CacheFlag.CACHE_SPEED)
                    player:EvaluateItems()
                    
                    sfx:Play(SOUND_THUMBS_UP)
                else
                    print("Room cleared but not within time limit. Room time: " .. roomTime .. ", Time limit: " .. timeLimit)
                    clearedRooms[currentRoomIndex] = true
                end
            end
        end
    end
end

function mod:RenderTimer()
    local player = Isaac.GetPlayer(0)  -- Get the first player
    if player:HasCollectible(HermesBoots) and not clearedRooms[currentRoomIndex] then
        local timeElapsed = (game.TimeCounter - roomStartTime) / 30
        local timeLimit = mod:getTimeLimit()
        local timeRemaining = math.max(0, timeLimit - timeElapsed)
        
        local text = string.format("%.2f", timeRemaining)
        local position = Vector(Isaac.GetScreenWidth() / 2, 35) -- Position it under the Time Score
        font:DrawString(text, position.X - (font:GetStringWidth(text) / 2), position.Y, KColor(1, 1, 1, 1), 0, true)
    end
end

-- Register callbacks
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.EvaluateCache)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.HermesNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.HermesUpdate)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.RenderTimer)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnGameExit)