local module = {}

local Debris = game:GetService("Debris")
local CS = game:GetService("CollectionService")

local Events = game.ReplicatedStorage.Events
local CardData = require(game.ReplicatedStorage.Modules.CardData)
local RelicData = require(game.ReplicatedStorage.Modules.RelicData)

-- Handles the entire combat mechanic (VERY IMPORTANT)
function module.CreateBattle(Player1, Enemies)
	if module.InCombatChecker(Player1) or Player1.PlayerData.InEncounter.Value or Player1.PlayerData.InEncounter:GetAttribute("EncounterCD") then return end
	Player1.PlayerData.InEncounter.Value = true
	
	local MatchEnded = false
	local RoundNumber = 0
	
	-- Set up player
	Events.StopMovement:FireClient(Player1, true)
	wait(.2)
	
	
	
	-- Set up enemies (VERY IMPORTANT)
	local function DeleteEnemies()
		for _,v in pairs(Enemies) do
			if v:FindFirstChild("CannotDie") == nil then -- For test enemies
				v:Destroy()
			end
		end
	end
	
	local TotalXP = 0
	local TotalGold = 0
	local Relic = false
	
	local EnemyDataTable = {}
	
	for i,EnemyChar in pairs(Enemies) do
		local EnemyPlr = game.Players:GetPlayerFromCharacter(EnemyChar)
		local Ai = false
		local AiMoveSet

		if EnemyPlr == nil then -- Is AI <- Just a check for future 1v1 game mode
			Ai = true
			AiMoveSet = require(EnemyChar:FindFirstChild("MoveSet"))
			EnemyChar.Humanoid.Health = EnemyChar.Humanoid.MaxHealth
		end
		
		-- Set Collision Group
		SetCollisionGroup(EnemyChar, "NoCollision")
		
		-- Move enemies to location
		local LRVector = (Player1.Character.HumanoidRootPart.CFrame.RightVector*4*i/2)
		if i <= #Enemies/2 then
			LRVector = -(Player1.Character.HumanoidRootPart.CFrame.RightVector*4*i)
		end
		if #Enemies ~= 1 then
			EnemyChar.HumanoidRootPart.CFrame = CFrame.new(Player1.Character.HumanoidRootPart.Position+(Player1.Character.HumanoidRootPart.CFrame.LookVector*12)+LRVector)
		else
			EnemyChar.HumanoidRootPart.CFrame = CFrame.new(Player1.Character.HumanoidRootPart.Position+(Player1.Character.HumanoidRootPart.CFrame.LookVector*12))
		end
		
		-- Orient enemies
		local LookAt = Player1.Character.HumanoidRootPart.Position -- Change later when party system
		EnemyChar.HumanoidRootPart.CFrame = CFrame.new(EnemyChar.HumanoidRootPart.Position, Vector3.new(LookAt.X, EnemyChar.HumanoidRootPart.Position.Y, LookAt.Z))
		
		-- Add or Enable enemy stats display
		if EnemyChar.Head:FindFirstChild("Display") == nil then
			local Display = game.ReplicatedStorage.Storage.Display:Clone()
			Display.Parent = EnemyChar.Head
			Display.Enabled = true
			Display.Updater.Enabled = true
		else
			EnemyChar.Head.Display.Enabled = true
		end
		
		-- Enable ragdoll
		coroutine.wrap(function()
			local BuildRagdoll = require(game.ReplicatedStorage.buildRagdoll)
			BuildRagdoll(EnemyChar.Humanoid)
		end)()
		
		-- Health Checks
		local EnemyHealthConnection
		EnemyHealthConnection = EnemyChar.Humanoid.HealthChanged:Connect(function(Health)
			if MatchEnded then return end -- Temporary solution

			if (Health <= 0.01) then
				-- Fling Ragdoll
				--game.Workspace.BiscuitOliva.HumanoidRootPart:ApplyImpulseAtPosition(EnemyChar.HumanoidRootPart.CFrame.LookVector*-100, EnemyChar.HumanoidRootPart.Position)
				--EnemyChar.HumanoidRootPart:ApplyImpulse
				--RagdollFling(EnemyChar, -10000)
				
				EnemyHealthConnection:Disconnect()
				
				-- End match
				if CheckRemainingEnemies(Enemies) <= 0 then
					MatchEnded = true
					Events.SignalTurn:FireClient(Player1, "Winner")
					Player1.MatchData.NewTurn:Fire("Ended")
				end
				
				-- When enemy dies
				EnemyChar.Head:FindFirstChild("Display").Enabled = false
				
				-- Update rewards
				wait(1.5)
				UpdateStatusEffectTurns(EnemyChar, true)
				
				local AiMoveSet = require(EnemyChar.MoveSet)
				TotalXP += AiMoveSet.XP --EnemyChar.XPWorth.Value
				TotalGold += AiMoveSet.Gold--EnemyChar:FindFirstChild("XPWorth"):GetAttribute("Gold")
				if AiMoveSet.Type == "Elite" then
					Relic = true
				end
				
				-- Rewards
				if CheckRemainingEnemies(Enemies) <= 0 then -- Finished last enemy
					DeleteEnemies()
					ClearMatchData(Player1)
					
					local RewardList = {
						--{Item = "NormalCard", Selection = {}},
						--{Item = "Relic", Name = ""},
						{Item = "Gold", Value = TotalGold}
					}
					
					-- Leveling mechanic <- Remove in future
					local LevelsGained = GiveXP(Player1, TotalXP) --RewardCards(Player1)
					if LevelsGained > 0 then
						if Player1.Character.Humanoid.Health == Player1.Character.Humanoid.MaxHealth then
							-- If leveled without losing any hp give bonus gold
							TotalGold += LevelsGained*100 + (Player1.PlayerData.Level.Value*10)
						else
							-- 20% HP restoration on level up
							Player1.Character.Humanoid.Health += Player1.Character.Humanoid.MaxHealth*.2
						end
					end
					
					if Relic then -- Revamp relics later
						local Rarity = module:RandomChance(RelicData.Chances)
						local RarityList = {}
						for i,v in pairs(RelicData.Relics) do
							if v.Rarity == Rarity and Player1.PlayerData.Relics:FindFirstChild(i) == nil then
								table.insert(RarityList, i)
							end
						end
						
						-- Cant get the same relic
						if #RarityList > 0 then
							local ChosenRelic = math.random(1,#RarityList)
							table.insert(RewardList, {Item = "Relic", Name = RarityList[ChosenRelic]})
						end
					end
					
					Events.SignalTurn:FireClient(Player1, "Rewards", RewardList)
					--print(RewardList)
				end
			end
		end)
		
		-- Set up individual data table
		local IntentAttackName
		local function Intent(New)
			if New then
				if EnemyChar.Head:FindFirstChild("Display") then
					if AiMoveSet.Order == "Chance" then
						local AttackName = module:RandomChance(AiMoveSet.Moves)
						IntentAttackName = AttackName 
					elseif AiMoveSet.Order == "Random" then
						local AttackNumber = math.random(1,#AiMoveSet.Moves)
						IntentAttackName = AiMoveSet.Moves[AttackNumber]
					end
					EnemyChar.Head.Display.UpdateIntent:Fire(AiMoveSet.Moves[IntentAttackName])
				end
			end
			
			return IntentAttackName
		end

		table.insert(EnemyDataTable, {Ai = Ai, Char = EnemyChar, AiMoveSet = AiMoveSet, GetIntent = Intent})
	end
	
	local function UpdateAllStatusEnemies()
		for _,EnemyChar in pairs(Enemies) do
			UpdateStatusEffectTurns(EnemyChar, true)
		end
	end
	
	
	
	-- Player connection
	local PlayerHealthConnection
	PlayerHealthConnection = Player1.Character.Humanoid.HealthChanged:Connect(function(Health)
		if MatchEnded then return end -- Temporary solution

		if (Health <= 0.01) then
			PlayerHealthConnection:Disconnect()
			print("Player died")
			
			MatchEnded = true
			Events.SignalTurn:FireClient(Player1, "Loser")
			Player1.MatchData.NewTurn:Fire("Ended")
			
			Events.StopMovement:FireClient(Player1, false)
			
			DeleteEnemies()
			ClearMatchData(Player1)
			
			coroutine.wrap(function()
				Player1.PlayerData.InEncounter:SetAttribute("EncounterCD", true)
				wait(math.random(15,25))
				Player1.PlayerData.InEncounter:SetAttribute("EncounterCD", false)
			end)()
			
			DeathWipe(Player1)
		end
	end)
	Player1.Character.Humanoid.Health -= .000001 --Trigger health connection
	
	-- Disconnect player on leave
	Player1:GetPropertyChangedSignal("Parent"):Connect(function()
		UpdateAllStatusEnemies()
		DeleteEnemies()
		MatchEnded = true
	end)
	
	-- Reward connection (Possibly alter this later due to exploits and boring system)
	local RewardConnection
	RewardConnection = Player1.MatchData.ClaimReward.OnServerEvent:Connect(function(plr, RewardType, Value)
		if RewardType == "End" then
			RewardConnection:Disconnect()
			
			-- Regain movement
			Events.StopMovement:FireClient(Player1, false)
			plr.PlayerData.InEncounter.Value = false
			plr.PlayerData.Encounters.Value += 1
			coroutine.wrap(function()
				Player1.PlayerData.InEncounter:SetAttribute("EncounterCD", true)
				wait(math.random(15,25)) -- Off CD
				Player1.PlayerData.InEncounter:SetAttribute("EncounterCD", false)
			end)()
		end
		
		if RewardType == "Card" then
			local CardClone = game.ReplicatedStorage.Modules.CardData.CardTemplate:Clone()
			CardClone.Name = Value
			CardClone.Parent = plr.PlayerData.Deck
			print("Claimed card")
			
		elseif RewardType == "Gold" then
			plr.PlayerData.Gold.Value += Value
			
		elseif RewardType == "Relic" then
			local RelicClone = game.ReplicatedStorage.Modules.CardData.CardTemplate:Clone()
			RelicClone.Name = Value
			RelicClone.Parent = plr.PlayerData.Relics
			
			if RelicData.Relics[Value].ActivationDetails == "OnObtain" then
				RelicData.Relics[Value].Activate(plr)
			end
		end
	end)
	
	
	
	-- Set up draw pile
	for i,v in pairs(Player1.PlayerData.Deck:GetChildren()) do
		local MatchVersion = v:Clone()
		MatchVersion.Parent = Player1.MatchData.DrawPile
	end
	
	-- Innate / Check for special card effects at start of combat
	for _,v in pairs(Player1.MatchData.DrawPile:GetChildren()) do
		if CardData[v.Name].Description ~= nil then
			if SearchForWord(CardData[v.Name].Description.Text, "Innate") then
				v.Parent = Player1.MatchData.Hand
			end
		end
	end
	
	-- Start up relics
	for _,v in pairs(Player1.PlayerData.Relics:GetChildren()) do
		if RelicData.Relics[v.Name] ~= nil and RelicData.Relics[v.Name].ActivationDetails == "OnCombatStart" then
			RelicData.Relics[v.Name].Activate(Player1, Enemies)
		end
	end
	
	
	
	-- Turn System (VERY IMPORTANT)
	while (Player1.Character.Humanoid.Health > 0.01 and CheckRemainingEnemies(Enemies) ~= 0) do
		if MatchEnded then break end
		
		-- Every Turn
		RoundNumber += 1
		DrawCards(Player1, 5)
		Player1.MatchData.Energy.Value = Player1.PlayerData.StartingEnergy.Value
		
		-- Set up intent
		for i,v in pairs(EnemyDataTable) do
			if v.Ai == true and v.Char.Humanoid.Health > .01 then
				v.GetIntent(true)
			end
		end
		
		-- Turn actions
		Events.SignalTurn:FireClient(Player1, RoundNumber, false, Enemies)
		Player1.MatchData.NewTurn:Fire(RoundNumber)
		
		-- Wait for action from player (Via connection)
		local AttackConnection = Player1.MatchData.ActivateCard.OnServerEvent:Connect(function(plr, CardName, Victim, Object)
			if MatchEnded then print("Attack conncetion is still active") return end -- If somehow the match ended while waiting for attack connection then cancel
			
			if plr.MatchData.Hand:FindFirstChild(CardName) and ((CardData[CardName].EnergyCost == "X" and plr.MatchData.Energy.Value > 0) or ((plr.MatchData.Energy.Value-CardData[CardName].EnergyCost) >= 0)) then
				
				-- All checker
				if Victim == "ALL" then
					--CardData[RealCardName].Upgraded.Activate(plr, Enemies, CardData[CardName])
					CardData[CardName].Activate(plr, Enemies, Object)
				else
					CardData[CardName].Activate(plr, Victim, Object)
				end
				
				-- X energy checker
				if CardData[CardName].EnergyCost ~= "X" then
					Player1.MatchData.Energy.Value -= CardData[CardName].EnergyCost
				end
				
				-- Put card in discard pile
				local Card = Player1.MatchData.Hand:FindFirstChild(CardName)
				if Card then
					Card.Parent = Player1.MatchData.DiscardPile
				end
				
				plr.MatchData.ActivateCard:FireClient(plr, "Success")
				
				-- Update intent of enemy
				for _,v in pairs(EnemyDataTable) do
					v.Char.Head.Display.UpdateIntent:Fire(v.AiMoveSet.Moves[v.GetIntent()])
				end
			end
		end)
		
		-- Wait till player ends turn or (timer runs out <- create a timer on the server instead of on the client) 
		Player1.MatchData.EndTurn.OnServerEvent:Wait()
		AttackConnection:Disconnect()
		if MatchEnded then break end
		
		-- Discard remaining hand
		for i,v in pairs(Player1.MatchData.Hand:GetChildren()) do
			-- Retain card effect
			if CardData[v.Name].Description ~= nil and SearchForWord(CardData[v.Name].Description.Text, "Retain") ~= true then
				v.Parent = Player1.MatchData.DiscardPile
			end
		end
		
		-- Transfer discard pile to draw pile (No cards in hand or draw)
		if #Player1.MatchData.DrawPile:GetChildren() == 0 then
			for i,v in pairs(Player1.MatchData.DiscardPile:GetChildren()) do
				v.Parent = Player1.MatchData.DrawPile
			end
		end
		
		-- Update status effects
		UpdateStatusEffectTurns(Player1.Character)
		
		-- Reset enemy defense
		for _,EnemyChar in pairs(Enemies) do
			EnemyChar.Humanoid:SetAttribute("Defense", 0)
		end
		
		wait(2) -- Rest time between switching over turns
		
		-- Check if player is dead
		if (Player1.Character.Humanoid.Health <= 0) then
			print("YOU LOST")
			ClearMatchData(Player1)
			break
		end
		
		-- Ai attack
		for i,v in pairs(EnemyDataTable) do
			pcall(function()
				if v.Char.Humanoid.Health > .01 then
					local IntentAttack = CardData[v.GetIntent()]
					if Player1.Character.Humanoid.Health > 0 then
						IntentAttack.Activate(v.Char, Player1.Character, v.AiMoveSet.Moves[v.GetIntent()])
						wait(1.5)
					end
				end
			end)
		end
		
		-- Update enemy status effects after they end turn
		for _,EnemyChar in pairs(Enemies) do
			UpdateStatusEffectTurns(EnemyChar)
		end
		
		-- Reset player defense
		Player1.Character.Humanoid:SetAttribute("Defense", 0)
	end
	
	-- Game is finished
	print("Game over.")
	ClearMatchData(Player1)
	MatchEnded = true
end


-- Combat functions below
function CheckRemainingEnemies(Enemies)
	local Count = 0
	for _,v in pairs(Enemies) do
		if v.Humanoid.Health > 0.01 then
			Count += 1
		end
	end
	return Count
end

function module.InCombatChecker(Player)
	for i,v in pairs(Player.MatchData:GetDescendants()) do -- If there is a value in any pile, player is in combat (Could probably just use a simple boolean value as a DB but whatever)
		if v:IsA("IntValue") and (v.Parent.Name == "DiscardPile" or v.Parent.Name == "DrawPile" or v.Parent.Name == "Hand") then
			--warn("In combat")
			return true
		end
	end
	return false
end

-- For chance based rewards <- Change to a weight based system
function module:RandomChance(Table)
	local Rand = math.random();
	local PastChance = 0;

	for i,v in pairs(Table) do
		if Rand < Table[i].Chance + PastChance then
			return i
		end
		PastChance = PastChance + Table[i].Chance
	end
end	

-- XP/Leveling mechanic <- Will deprectate later
function GiveXP(Player, XP)
	Player.PlayerData.Level:SetAttribute("XP", Player.PlayerData.Level:GetAttribute("XP")+XP)

	local LevelCount = 0
	-- Level up
	while Player.PlayerData.Level:GetAttribute("XP") >= Player.PlayerData.Level.Value*50 do
		Player.PlayerData.Level:SetAttribute("XP", Player.PlayerData.Level:GetAttribute("XP")-Player.PlayerData.Level.Value*50)
		Player.PlayerData.Level.Value += 1
		LevelCount += 1
	end
	return LevelCount
end

-- Status effect updater
function UpdateStatusEffectTurns(chr, Wipe)
	local StatusEffects
	if chr:FindFirstChild("StatusEffects") then
		StatusEffects = chr:FindFirstChild("StatusEffects")
	elseif game.Players:GetPlayerFromCharacter(chr) ~= nil then
		StatusEffects = game.Players:GetPlayerFromCharacter(chr).MatchData.StatusEffects
	else
		return
	end

	for i,v in pairs(StatusEffects:GetChildren()) do
		if v:GetAttribute("TurnBased") == true then
			v.Value = math.clamp(v.Value-1, 0, 100)
		end
		if Wipe then
			v.Value = 0				
		end
	end

	if Wipe then
		chr.Humanoid:SetAttribute("Defense", 0)
		for i,v in pairs(chr.DebrisEffects:GetChildren()) do
			v:Destroy()
		end
	end
end

-- Clears values from all folders
function ClearMatchData(Player)
	Player.MatchData.DrawPile:ClearAllChildren()
	Player.MatchData.DiscardPile:ClearAllChildren()
	Player.MatchData.ExhaustPile:ClearAllChildren()
	Player.MatchData.Hand:ClearAllChildren()
	for _,v in pairs(Player.MatchData.StatusEffects:GetChildren()) do
		v.Value = 0
	end
end

-- Clear all player data
function DeathWipe(plr)
	SwapDeck(plr.PlayerData.Deck, game.ServerScriptService.PlayerHandler.PlayerData.Deck)
	plr.PlayerData.Gold.Value = game.ServerScriptService.PlayerHandler.PlayerData.Gold.Value
	plr.PlayerData.Encounters.Value = 0
	plr.PlayerData.InEncounter.Value = false
	plr.PlayerData.Level.Value = 0 -- Remove leveling mechanic later
	plr.PlayerData.Level:SetAttribute("XP", 0)
end

-- Draw card mechanic (VERY IMPORTANT)
function DrawCards(Player, CardAmount)
	-- Set hand
	for i = 1,math.clamp(CardAmount, 0, #Player.MatchData.DrawPile:GetChildren()) do
		local DrawableCards = Player.MatchData.DrawPile:GetChildren()
		local ChosenNumber = math.random(1,#DrawableCards)
		DrawableCards[ChosenNumber].Parent = Player.MatchData.Hand
	end

	-- Shuffle discard pile back into draw pile and draw missing cards
	if #Player.MatchData.Hand:GetChildren() < CardAmount then
		-- Transfer discard pile into draw pile
		for i,v in pairs(Player.MatchData.DiscardPile:GetChildren()) do
			v.Parent = Player.MatchData.DrawPile
		end

		-- Draw missing cards
		for i = 1,(CardAmount-#Player.MatchData.Hand:GetChildren()) do
			local DrawableCards = Player.MatchData.DrawPile:GetChildren()
			if #DrawableCards > 0 then
				local ChosenNumber = math.random(1,#DrawableCards)
				DrawableCards[ChosenNumber].Parent = Player.MatchData.Hand
			end
		end
	end
end

-- Swaps decks, honestly a lazy function -> Maybe deprecated later unless used in future
function SwapDeck(Deck1, Deck2)
	Deck1:ClearAllChildren()
	for _,v in pairs(Deck2:GetChildren()) do
		v:Clone().Parent = Deck1
	end
end

-- Other functions below
function SearchForWord(Text, Word) -- Used in finding card effects in description (VERY IMPORTANT)
	for CurWord in string.gmatch(Text,"[^%s]+") do
		if CurWord == Word then
			if CurWord == Word then
				return true
			end
		end
	end
	return false
end

function SetCollisionGroup(chr, Name)
	for _,v in pairs(chr:GetChildren()) do
		if v:IsA("Part") or v:IsA("MeshPart") then
			v.CollisionGroup = Name
		end
	end
end

-- Basic tags applied to characters
function module.CreateTag(Parent, TagName)
	local IntTag = Instance.new("StringValue", Parent)
	IntTag.Name = TagName
	return IntTag
end

function module.DestroyTag(Parent, TagName)
	if Parent:FindFirstChild(TagName) then
		Parent[TagName]:Destroy()
	end
end

return module
