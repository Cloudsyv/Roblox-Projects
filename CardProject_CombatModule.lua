-- Combat module for card project game
-- Handles setting up and managing player encounters with enemies.

local module = {}

-- Services
local Debris = game:GetService("Debris")
local CS = game:GetService("CollectionService")

-- Dependencies
local Events = game.ReplicatedStorage.Events
local CardData = require(game.ReplicatedStorage.Modules.CardData)
local RelicData = require(game.ReplicatedStorage.Modules.RelicData)

-- Utility function to check the number of enemies still alive
function CheckRemainingEnemies(Enemies)
    local Count = 0
    for _, v in pairs(Enemies) do
        if v.Humanoid.Health > 0.01 then
            Count += 1
        end
    end
    return Count
end

-- Core function to create and manage a battle encounter
function module.CreateBattle(Player1, Enemies)
    -- Prevent starting a battle if the player is already in combat or has a cooldown
    if module.InCombatChecker(Player1) or Player1.PlayerData.InEncounter.Value or Player1.PlayerData.InEncounter:GetAttribute("EncounterCD") then return end
    Player1.PlayerData.InEncounter.Value = true

    local MatchEnded = false
    local RoundNumber = 0

    -- Stop player movement during combat
    Events.StopMovement:FireClient(Player1, true)
    wait(0.2) -- Short delay to ensure state is updated

    -- Activate player relics that trigger at the start of combat
    for _, v in pairs(Player1.PlayerData.Relics:GetChildren()) do
        local relic = RelicData.Relics[v.Name]
        if relic and relic.ActivationDetails == "OnCombatStart" then
            relic.Activate(Player1, Enemies)
        end
    end

    -- Function to delete enemies that can die (e.g., not test dummies)
    local function DeleteEnemies()
        for _, v in pairs(Enemies) do
            if not v:FindFirstChild("CannotDie") then
                v:Destroy()
            end
        end
    end

    -- Initialize encounter rewards and enemy data tracking
    local TotalXP = 0
    local TotalGold = 0
    local Relic = false
    local EnemyDataTable = {}

    -- Setup each enemy for the encounter
    for i, EnemyChar in pairs(Enemies) do
        local EnemyPlr = game.Players:GetPlayerFromCharacter(EnemyChar)
        local Ai = not EnemyPlr -- If there's no player, treat as AI-controlled
        local AiMoveSet = Ai and require(EnemyChar:FindFirstChild("MoveSet"))

        if Ai then
            EnemyChar.Humanoid.Health = EnemyChar.Humanoid.MaxHealth
        end

        -- Adjust enemy collision group and initial placement
        SetCollisionGroup(EnemyChar, "NoCollision")
        local LRVector = (Player1.Character.HumanoidRootPart.CFrame.RightVector * 4 * i / 2)
        if i <= #Enemies / 2 then
            LRVector = -(Player1.Character.HumanoidRootPart.CFrame.RightVector * 4 * i)
        end
        local position = Player1.Character.HumanoidRootPart.Position + (Player1.Character.HumanoidRootPart.CFrame.LookVector * 12) + LRVector
        EnemyChar.HumanoidRootPart.CFrame = CFrame.new(position)

        -- Orient the enemy to face the player
        local LookAt = Player1.Character.HumanoidRootPart.Position
        EnemyChar.HumanoidRootPart.CFrame = CFrame.new(EnemyChar.HumanoidRootPart.Position, Vector3.new(LookAt.X, EnemyChar.HumanoidRootPart.Position.Y, LookAt.Z))

        -- Add a stats display UI to the enemy if not already present
        if not EnemyChar.Head:FindFirstChild("Display") then
            local Display = game.ReplicatedStorage.Storage.Display:Clone()
            Display.Parent = EnemyChar.Head
            Display.Enabled = true
            Display.Updater.Enabled = true
        else
            EnemyChar.Head.Display.Enabled = true
        end

        -- Enable ragdoll physics for the enemy
        coroutine.wrap(function()
            local BuildRagdoll = require(game.ReplicatedStorage.buildRagdoll)
            BuildRagdoll(EnemyChar.Humanoid)
        end)()

        -- Monitor enemy health and handle defeat
        local EnemyHealthConnection
        EnemyHealthConnection = EnemyChar.Humanoid.HealthChanged:Connect(function(Health)
            if MatchEnded then return end
            if Health <= 0.01 then
                EnemyHealthConnection:Disconnect()
                if CheckRemainingEnemies(Enemies) <= 0 then
                    MatchEnded = true
                    Events.SignalTurn:FireClient(Player1, "Winner")
                    Player1.MatchData.NewTurn:Fire("Ended")
                end

                -- Handle enemy defeat rewards and cleanup
                EnemyChar.Head.Display.Enabled = false
                wait(1.5) -- Delay for smooth transitions
                UpdateStatusEffectTurns(EnemyChar, true)

                local AiMoveSet = require(EnemyChar.MoveSet)
                TotalXP += AiMoveSet.XP
                TotalGold += AiMoveSet.Gold
                if AiMoveSet.Type == "Elite" then
                    Relic = true
                end

                if CheckRemainingEnemies(Enemies) <= 0 then
                    DeleteEnemies()
                    ClearMatchData(Player1)

                    local RewardList = {
                        {Item = "Gold", Value = TotalGold}
                    }

                    -- Level up bonuses or relic rewards
                    local LevelsGained = GiveXP(Player1, TotalXP)
                    if LevelsGained > 0 then
                        if Player1.Character.Humanoid.Health == Player1.Character.Humanoid.MaxHealth then
                            TotalGold += LevelsGained * 100 + (Player1.PlayerData.Level.Value * 10)
                        else
                            Player1.Character.Humanoid.Health += Player1.Character.Humanoid.MaxHealth * 0.2
                        end
                    end

                    if Relic then
                        local Rarity = module:RandomChance(RelicData.Chances)
                        local RarityList = {}
                        for i, v in pairs(RelicData.Relics) do
                            if v.Rarity == Rarity and not Player1.PlayerData.Relics:FindFirstChild(i) then
                                table.insert(RarityList, i)
                            end
                        end
                        if #RarityList > 0 then
                            local ChosenRelic = math.random(1, #RarityList)
                            table.insert(RewardList, {Item = "Relic", Name = RarityList[ChosenRelic]})
                        end
                    end

                    Events.SignalTurn:FireClient(Player1, "Rewards", RewardList)
                end
            end
        end)
    end

    -- Additional connections, player death handling, and post-match logic omitted for brevity
end

return module
