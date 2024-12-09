-- This is one of the core modules for this tool

local module = {}

-- Variables

local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ToolSettings = require(script.Parent.ToolSettings)
local StunHandler = require(game.ServerScriptService.Modules.StunHandlerV2)

local CombatData = ToolSettings.Combat
local SkillData1 = ToolSettings.Skills[1]
local SkillData2 = ToolSettings.Skills[2]
local SkillData3 = ToolSettings.Skills[3]
local SkillData4 = ToolSettings.Skills[4]
local SkillData5 = ToolSettings.Skills[5]

local MaterialConversionList = {
	[Enum.Material.Rock] = Enum.Material.Slate,
	[Enum.Material.Ground] = Enum.Material.Grass,
	[Enum.Material.LeafyGrass] = Enum.Material.Grass,
}

-- Utility Functions

function module.DealDamage(Victim, Amount)
	if (game.Players:GetPlayerFromCharacter(Victim) == nil) then
		Victim.Humanoid:TakeDamage(Amount)
	else
		Victim.Humanoid.Health = math.clamp(Victim.Humanoid.Health-Amount, 1, Victim.Humanoid.MaxHealth)
	end
end

function module.RoundNumber(num, numPlaces)
	return math.floor(num*(10^numPlaces))/(10^numPlaces)
end

function module.CreateAnimation(Id)
	local IntAnim = Instance.new("Animation", nil)
	IntAnim.AnimationId = "rbxassetid://"..Id
	return IntAnim
end

function module.Infront(plr, plr2)
	local DirToOtherPlayer: (Vector3) = (plr2.PrimaryPart.Position - plr.PrimaryPart.Position).unit
	return (plr.PrimaryPart.CFrame.LookVector:Dot(DirToOtherPlayer) > 0)
end

function module.Behind(plr, plr2)
	local DirToOtherPlayer: (Vector3) = (plr.PrimaryPart.Position - plr2.PrimaryPart.Position).unit
	return plr2.PrimaryPart.CFrame.LookVector:Dot(DirToOtherPlayer) < 0
end

function module.CreateTag(Parent, TagName, PlrName)
	local IntTag = Instance.new("StringValue", Parent)
	IntTag.Name = TagName
	IntTag.Value = PlrName
	return IntTag
end

function module.DestroyTag(Parent, TagName)
	if Parent:FindFirstChild(TagName) then
		Parent[TagName]:Destroy()
	end
end

function module.CreateCharge(Parent, Time)
	local ChargeFX = game.ReplicatedStorage.Effects.ChargeFX.Attachment:Clone()
	ChargeFX.Parent = Parent
	ChargeFX.ChargeParticle.Lifetime = NumberRange.new(Time+1.5)
	ChargeFX.ChargeParticle:Emit(1)
	return ChargeFX
end

function module.SetWsJp(chr, Speed, JumpPower)
	local Humanoid = chr.Humanoid
	Humanoid.WalkSpeed = Speed
	Humanoid.JumpPower = JumpPower
end

function module.SetNetwork(chr, NewOwner)
	for _,v in pairs(chr:GetChildren()) do
		if v:IsA("BasePart") and v.Anchored == false then
			v:SetNetworkOwner(NewOwner)
		end
	end
end

function module.CheckIfCharging()
	local Charging = false
	for _,v in pairs(ToolSettings.Skills) do
		if v["Charging"] then
			if v.Charging == true then
				Charging = true
			end			
		end
		if v["MinCharging"] then
			if v.MinCharging == true then 
				Charging = true 
			end
		end
	end
	return Charging
end

function module.ScaleModel(Model, SizeScale, PositionScale)
	local Primary = Model.PrimaryPart
	local PrimaryCF = Primary.CFrame

	for _,v in pairs(Model:GetDescendants()) do
		if (v:IsA("BasePart")) then
			v.Size = (v.Size * SizeScale)
			if (v ~= Primary) then
				v.CFrame = (PrimaryCF + (PrimaryCF:inverse() * v.Position * PositionScale))
			end
		end
	end
	return Model
end

function module.RandomChance(Table)
	local Rand = math.random();
	local PastChance = 0;

	for i,v in pairs(Table) do
		if Rand < Table[i].Chance + PastChance then
			return i
		end
		PastChance = PastChance + Table[i].Chance
	end
end

function module.LookAt(chr, Target)
	if chr.PrimaryPart then
		local BodyGyro = Instance.new("BodyGyro", chr.PrimaryPart)
		BodyGyro.MaxTorque = Vector3.new(0, 100000, 0)
		BodyGyro.D = 0
		BodyGyro.P = 100000
		BodyGyro.CFrame = CFrame.new(chr.PrimaryPart.Position, Target.Position) --BodyGyro.CFrame * CFrame.Angles(Target.Orientation.X,Target.Orientation.Y,Target.Orientation.Z)
		spawn(function()
			wait(.1)
			BodyGyro:Destroy()
		end)
	end
end

--[[
function module.AreaScreenShake(plr, Part, Range, ScreenShakeTable)
	for i,v in pairs(game.Workspace:GetDescendants()) do
		if v:IsA("Model") and v:FindFirstChild("Humanoid") then
			if (Part.Position - v.Humanoid.RootPart.Position).magnitude <= Range then
				game.ReplicatedStorage.Events.ScreenShake:FireClient(plr, ScreenShakeTable)

				if game.Players:GetPlayerFromCharacter(v) ~= nil then
					local Victimplr = game.Players:GetPlayerFromCharacter(v)
					game.ReplicatedStorage.Events.ScreenShake:FireClient(Victimplr, ScreenShakeTable)
				end
			end
		end	
	end	
end]]

-- Model functions
function module.WeaponEdit(plr, WeaponName, Condition)
	local plrData = plr.PlayerData
	
	if Condition == "Spawned" then
		local IdleWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName].Idle

		-- Skin
		local SkinName = plrData.Inventory.Equipped[WeaponName]:GetAttribute("Skin")
		if SkinName ~= "" then
			IdleWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName][SkinName].Idle
		end

		IdleWeapon = IdleWeapon:Clone()
		plr.Character:WaitForChild("Humanoid"):AddAccessory(IdleWeapon)
		
	elseif Condition == "Equipped" then
		local FindIdle = plr.Character:FindFirstChild("Idle")
		if FindIdle and FindIdle:IsA("Accessory") then
			FindIdle:Destroy()
		end

		local ActiveWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName].Active
		
		-- Skin
		local SkinName = plrData.Inventory.Equipped[WeaponName]:GetAttribute("Skin")
		if SkinName ~= "" then
			ActiveWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName][SkinName].Active
		end
		
		ActiveWeapon = ActiveWeapon:Clone()
		plr.Character:WaitForChild("Humanoid"):AddAccessory(ActiveWeapon)
		
	elseif Condition == "Unequipped" then
		local FindActive = plr.Character:FindFirstChild("Active")
		if FindActive then
			FindActive:Destroy()
		end

		local IdleWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName].Idle
		
		-- Skin
		local SkinName = plrData.Inventory.Equipped[WeaponName]:GetAttribute("Skin")
		if SkinName ~= "" then
			IdleWeapon = game.ReplicatedStorage.Models.Weapons[WeaponName][SkinName].Idle
		end
		
		IdleWeapon = IdleWeapon:Clone()
		plr.Character:WaitForChild("Humanoid"):AddAccessory(IdleWeapon)
	end
end

function module.ApplyTexture(Part, Texture)
	for i = 1,6 do
		local Texture = Texture:Clone()

		if i == 1 then
			Texture.Face = "Top"
		elseif i == 2 then
			Texture.Face = "Bottom"
		elseif i == 3 then
			Texture.Face = "Left"
		elseif i == 4 then
			Texture.Face = "Right"
		elseif i == 5 then
			Texture.Face = "Front"	
		elseif i == 6 then
			Texture.Face = "Back"
		end
		Texture.Parent = Part						
	end
end

function module:GetPartBelow(Part)
	-- Raycasting
	local IgnoreList = {}
	for i,v in pairs(game.Workspace:GetDescendants()) do
		if v:GetAttribute("Effects") == true or v:IsA("SpawnLocation") or v.Parent:IsA("Accessory") or (v:IsA("Model") and v:FindFirstChildOfClass("Humanoid")) then
			table.insert(IgnoreList, v)
		end
	end
	table.insert(IgnoreList, Part)
	
	-- Ray parameters
	local RayParams = RaycastParams.new()
	RayParams.IgnoreWater = true
	RayParams.FilterType = Enum.RaycastFilterType.Blacklist	
	
	RayParams.FilterDescendantsInstances = {IgnoreList}
	
	local RaycastResult = workspace:Raycast(Part.Position+Vector3.new(0,10,0), Vector3.new(0, -30, 0), RayParams)
	return RaycastResult
end

function FlingDebri(MainPart, RayCast, Amount, Size, Power)
	local FloorPart = RayCast.Instance
	for i = 1,Amount do
		local IntPart = game.ReplicatedStorage.Models.RockSpirit.Rock:Clone()
		IntPart.Parent = game.Workspace
		
		-- No freeze if lagging
		IntPart.Anchored = false
		IntPart:SetNetworkOwner(nil)
		
		IntPart.CanCollide = true
		IntPart.Size = Size*(math.random(100,250)/100)
		IntPart.Orientation = Vector3.new(math.random(-180,180),math.random(-180,180),math.random(-180,180))
		IntPart.Position = MainPart.Position+Vector3.new(math.random(-3,3),math.random(2,3),math.random(-3,3))

		Debris:AddItem(IntPart, 5)
		PhysicsService:SetPartCollisionGroup(IntPart, "Dead")

		if FloorPart == nil then
			IntPart:Destroy()
		else
			if FloorPart == game.Workspace.Terrain then
				local Material = RayCast.Material
				local Color = game.Workspace.Terrain:GetMaterialColor(Material)
				
				if MaterialConversionList[Material] ~= nil then
					Material = MaterialConversionList[Material]
				end
				
				IntPart.Color = Color
				IntPart.Material = Material
			else
				IntPart.Color = FloorPart.Color
				IntPart.Material = FloorPart.Material
			end

			if FloorPart:FindFirstChildOfClass("Texture") then
				module.ApplyTexture(IntPart, FloorPart:FindFirstChildOfClass("Texture"))						
			end
		end

		local FlingVector = Vector3.new(-math.sin(math.rad(math.random(-180,180)))*Power[1], Power[2], -math.cos(math.rad(math.random(-180,180)))*Power[1])

		IntPart.Velocity = IntPart.Velocity+FlingVector

		coroutine.wrap(function()
			wait(4)
			TS:Create(IntPart, TweenInfo.new(.25, Enum.EasingStyle.Sine), {Size = Vector3.new(0,0,0), Position = IntPart.Position - Vector3.new(0,3,0)}):play()
		end)()
	end
end

-- Combat Functions
function changeWeight(animationTrack, weight, fadeTime)
	animationTrack:AdjustWeight(weight, fadeTime)
	local startTime = tick()
	coroutine.wrap(function()
		while math.abs(animationTrack.WeightCurrent - weight) > 0.001 do
			wait()
		end
		--print("Time taken to change weight "..tostring(tick() - startTime))
	end)()
end

function CheckTableTags(Table)
	for i,v in pairs(Table) do
		if v == true then
			return true
		end
	end
end

function CheckIfUnequipped(plr)
	local FindActiveTool = plr.Character:FindFirstChild(script.Parent.Parent.Name)
	if FindActiveTool and FindActiveTool:IsA("Tool") then
		return false
	else
		return true
	end
end

function ReturnTerrainResults(RayCast)
	local FloorPart = RayCast.Instance
	if FloorPart == game.Workspace.Terrain then
		local Material = RayCast.Material
		local Color = game.Workspace.Terrain:GetMaterialColor(Material)

		return {Color, Material}
	end	
	return false
end

function CancelM1Effects(plr, Anim)
	local chr = plr.Character
	
	CombatData.OnResetCooldown = true
	CombatData.OnCooldown = false
	CombatData.CurCombo = 0
	
	if Anim ~= nil then
		wait(.15)
		Anim:stop()
	end		

	local FindActive = plr.Character:FindFirstChild("Active")
	if FindActive then
		FindActive.Handle.Blade.Attachment.SlashTrail.Enabled = false
	end	
	
	wait(.1)
	
	if plr.Character.HumanoidRootPart:FindFirstChild("SlashFXAttachment") then
		chr.HumanoidRootPart.SlashFXAttachment:Destroy()
		print("Destroyed SlashFXAttachment")
	end
	
	if chr.HumanoidRootPart:FindFirstChild("CombatDash") then
		chr.HumanoidRootPart.CombatDash:Destroy()
	end
	
	-- Something about this is broken
	wait(CombatData.ComboResetTime/3)
	print("1. Reset Cooldown in m1 effects cancel - "..plr.Name.. " / Combo: "..CombatData.CurCombo)
	CombatData.OnResetCooldown = false
	CombatData.FeintActive = false
end

function module.Combo(plr)
	local plrData = plr.PlayerData
	local chr = plr.Character
	local chrData = chr.CharacterData
	
	if CombatData.FeintActive or chr:FindFirstChild("HitTag") or CombatData.OnCooldown or CombatData.OnResetCooldown or CombatData.BlockActive or chr:FindFirstChild("Stunned") or ToolSettings.Skills.SkillActive == true or chr.Humanoid.Health <= 1 then return end
	--print(ToolSettings.Skills.SkillActive)
	
	CombatData.OnCooldown = true
	CombatData.CurCombo = math.clamp(CombatData.CurCombo+1, 0, #CombatData.Animations)
	
	if CombatData.CurCombo ~= #CombatData.Animations then
		CombatData.FeintWindow = true	
	end
	
	-- Slow
	local SlowTag = module.CreateTag(chr, "Slowed", chr.Name)
	Debris:AddItem(SlowTag, 3)
	
	if CombatData.CurCombo == #CombatData.Animations then
		module.SetWsJp(chr, 0, 0)
	else
		module.SetWsJp(chr, 5, 0)	
	end
	
	-- Sound
	local SwooshSound = game.ReplicatedStorage.Audio.HeavySlash:Clone()
	SwooshSound.Parent = chr.HumanoidRootPart
	SwooshSound.PlaybackSpeed = math.random(8, 12)/10
	SwooshSound:play()
	Debris:AddItem(SwooshSound, 1)
	
	-- Animation
	local Anim = plr.Character.Humanoid:LoadAnimation(module.CreateAnimation(CombatData.Animations[CombatData.CurCombo]))
	Anim:play()
	Anim:AdjustSpeed(0)
	Anim.Priority = Enum.AnimationPriority.Action
	changeWeight(Anim, 2, .125)
	--print(Anim.Length)
	
	-- Scaling
	local AtkSpeed = 1+(math.clamp(plrData.Stats.Dexterity.Value/100, 0, 1))
	
	-- Trail
	coroutine.wrap(function()
		local FindActive = plr.Character:FindFirstChild("Active")
		if FindActive then
			FindActive.Handle.Blade.Attachment.SlashTrail.Enabled = true
			wait(.7)
			local FindActive2 = plr.Character:FindFirstChild("Active")
			if FindActive2 then
				FindActive2.Handle.Blade.Attachment.SlashTrail.Enabled = false		
			end
		end				
	end)()
	
	coroutine.wrap(function()
		wait(.15)
		Anim:AdjustSpeed(AtkSpeed) -- AtkSpeed
		
		-- Attack delay and effects
		if CombatData.CurCombo == #CombatData.Animations then
			wait(.4725)
			--wait(Anim.Length*.35)
			--print(CombatData.CurCombo)
			
			-- 3rd attack character directional freeze
			chr.Humanoid.AutoRotate = false
			
			-- 3rd attack effects / Smoke
			local DebrisFX = game.ReplicatedStorage.Effects.DebrisFX:Clone()
			DebrisFX.Parent = workspace
			DebrisFX.CFrame = CFrame.new(chr.HumanoidRootPart.CFrame.Position+(10*chr.HumanoidRootPart.CFrame.lookVector)+Vector3.new(0,-3,0))	
			
			local RayCastResult = module:GetPartBelow(DebrisFX)
			if RayCastResult == nil then
				DebrisFX:Destroy()
			else
				local FloorPart = RayCastResult.Instance

				DebrisFX.Position = RayCastResult.Position

				local NewColor = Color3.new(FloorPart.Color.R, FloorPart.Color.G, FloorPart.Color.B)

				if FloorPart == game.Workspace.Terrain then
					local Material = RayCastResult.Material
					local Color = game.Workspace.Terrain:GetMaterialColor(Material)

					NewColor = Color
				end

				DebrisFX.Smoke.Color = ColorSequence.new(NewColor)
				DebrisFX.Smoke:Emit(75)

				Debris:AddItem(DebrisFX, 3)				
			end
			
			-- Sound
			local CrashSound = game.ReplicatedStorage.Audio.HeavyCrash:Clone()			
			CrashSound.PlaybackSpeed = math.random(9,11)/10
			CrashSound:Play()
			Debris:AddItem(CrashSound, 3.5)
			if chr:FindFirstChild("Active") then
				CrashSound.Parent = chr["Active"].Handle.Blade
				
				-- Fling Debri
				if RayCastResult ~= nil then
					FlingDebri(chr["Active"].Handle.Blade, RayCastResult, 8, Vector3.new(.5,.5,.5), {50, 30})
				end
			else
				CrashSound.Parent = chr.HumanoidRootPart
			end
			
			-- Ground Effects
			local LinearFX = game.ServerStorage.GroundFX.Linear3:Clone()
			LinearFX.Parent = workspace
			Debris:AddItem(LinearFX, 4.5)

			local OriginPos = plr.Character.HumanoidRootPart.Position + (chr.HumanoidRootPart.CFrame.LookVector*8.5) --+ (chr.HumanoidRootPart.CFrame.RightVector*1.5)
			local TargetPos = plr.Character.HumanoidRootPart.Position + (chr.HumanoidRootPart.CFrame.LookVector*15) --+ (chr.HumanoidRootPart.CFrame.RightVector*1.5)
			LinearFX:SetPrimaryPartCFrame(CFrame.new(OriginPos, TargetPos) * CFrame.Angles(0, math.rad(0), 0))
			
			for i,v in pairs(LinearFX:GetChildren()) do
				local NewRayCastResult = module:GetPartBelow(v)
				
				if NewRayCastResult == nil then
					v:Destroy()
				else
					local FloorPart = NewRayCastResult.Instance
					local NewPos = NewRayCastResult.Position
					
					if FloorPart == game.Workspace.Terrain then
						local Material = NewRayCastResult.Material						
						local Color = game.Workspace.Terrain:GetMaterialColor(Material)

						if MaterialConversionList[Material] ~= nil then
							Material = MaterialConversionList[Material]
						end
						
						v.Color = Color
						v.Material = Material
					else
						v.Color = FloorPart.Color
						v.Material = FloorPart.Material
					end
					
					v.Position = NewPos-Vector3.new(0,.1,0)
					v.Orientation = Vector3.new(math.random(-180,180),math.random(-180,180),math.random(-180,180))
					v.Size = v.Size*(math.random(100,150)/100)*(1+(i/25))

					if FloorPart:FindFirstChildOfClass("Texture") then
						module.ApplyTexture(v, FloorPart:FindFirstChildOfClass("Texture"))						
					end

					Debris:AddItem(v, 4.1)

					coroutine.wrap(function()
						wait(3)
						TS:Create(v, TweenInfo.new(.25, Enum.EasingStyle.Sine), {Size = Vector3.new(0,0,0), Position = v.Position - Vector3.new(0,3,0)}):play()
					end)()
				end
			end
		else
			--wait(Anim.Length*.55)
			wait(.3)
		end
		
		CombatData.FeintWindow = false
		
		if CombatData.FeintActive then
			CancelM1Effects(plr, Anim)	
			return
		end
		
		-- Attack
		module.MagnitudeAttack(plr, chr.HumanoidRootPart, CombatData)			
		
		-- Cancel M1 effects
		if (chr:FindFirstChild("Stunned") or chr:FindFirstChild("HitTag") or (plr.Character:FindFirstChild("Active") == nil)) and CombatData.CurCombo ~= 3 then
			CancelM1Effects(plr, Anim)	
			if CombatData.FeintActive then
				--CombatData.FeintActive = false
			end
			--print("Canceled m1")
			return
		end			
		
		-- Slow down anim after attack
		if CombatData.CurCombo == 3 then
			-- Screen Shake 3rd attack
			game.ReplicatedStorage.Events.ScreenShake2:FireClient(plr, CombatData.ScreenShakeTable.Power+1, CombatData.ScreenShakeTable.Amount+2, CombatData.ScreenShakeTable.FadeIn+.05, CombatData.ScreenShakeTable.FadeOut+.1)
			
			--wait(Anim.Length*.375)
			wait(.5)
			Anim:AdjustSpeed(.5)
		end
	end)()
	
	-- Cancel M1 effects
	if (chr:FindFirstChild("Stunned") or chr:FindFirstChild("HitTag") or (plr.Character:FindFirstChild("Active") == nil)) and CombatData.CurCombo ~= 3 then
		CancelM1Effects(plr, Anim)	
		if CombatData.FeintActive then
			--ToolSettings.FeintActive = false
			print("feint was set to false")
		end
		--print("Canceled m1")
		return
	end
	
	-- M1 Body force	
	local Dash = Instance.new("BodyVelocity")
	Dash.Name = "CombatDash"
	Dash.MaxForce = Vector3.new(40000,60000,40000)
	Dash.P = 10000
	
	coroutine.wrap(function()	
		local Dist = plr.Character.HumanoidRootPart.CFrame.LookVector * 5
		if CombatData.CurCombo == 1 then
			Dist = Dist + plr.Character.HumanoidRootPart.CFrame.RightVector * -11			
			wait(.45)
			--wait(Anim.Length*.75)
			
		elseif CombatData.CurCombo == 2 then
			Dist = Dist + plr.Character.HumanoidRootPart.CFrame.RightVector * 14
			wait(.375)
			--wait(Anim.Length*.75)			
			
		elseif CombatData.CurCombo == #CombatData.Animations then
			Dist = Dist*4.5
			
			-- Hyper Armor effect
			-- Sound
			local HyperArmorSound = game.ReplicatedStorage.Audio.Hyperarmor:Clone()
			HyperArmorSound.Parent = chr.UpperTorso
			HyperArmorSound:play()
			Debris:AddItem(HyperArmorSound, 4)

			-- Highlight
			local Highlight = game.ReplicatedStorage.Effects.Highlight:Clone()
			Highlight.Parent = chr
			Highlight.Adornee = chr
			TS:Create(Highlight, TweenInfo.new(2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut), {FillTransparency = 1}):play()
			Debris:AddItem(Highlight, 4)

			-- Text display
			local TextDisplay = game.ServerStorage.Gui.DamageBoard:Clone()
			TextDisplay.Parent = chr.UpperTorso
			TextDisplay.Name = "TextDisplay"
			
			TextDisplay.Size = UDim2.new(10,0,6,0)
			TextDisplay.BackgroundText.DamageText.TextColor3 = Color3.fromRGB(155,50,255)

			TextDisplay.BackgroundText.Text = "Unstoppable!"
			TextDisplay.BackgroundText.DamageText.Text = TextDisplay.BackgroundText.Text
			TextDisplay.BackgroundText.Rotation = math.random(-25,25)
			TextDisplay.StudsOffset = Vector3.new(math.random(-1,1), math.random(-1,3), math.random(-1,1))

			local XRand = math.random(-5,5)
			local YRand = math.random(-6,2)
			local ZRand = math.random(-5,5)
			
			TS:Create(TextDisplay, TweenInfo.new(2, Enum.EasingStyle.Cubic), {Size = UDim2.new(0,0,0,0), StudsOffset = TextDisplay.StudsOffset + Vector3.new(XRand, YRand, ZRand)}):play()
			TS:Create(TextDisplay.BackgroundText, TweenInfo.new(2, Enum.EasingStyle.Cubic),{TextTransparency = 1}):play()
			TS:Create(TextDisplay.BackgroundText.DamageText, TweenInfo.new(2, Enum.EasingStyle.Cubic),{TextTransparency = 1}):play()
			Debris:AddItem(TextDisplay, 3)
		end
		
		-- Cancel M1 effects
		if (chr:FindFirstChild("Stunned") or chr:FindFirstChild("HitTag") or (plr.Character:FindFirstChild("Active") == nil)) and CombatData.CurCombo ~= 3 then
			CancelM1Effects(plr, Anim)	
			Dash:Destroy()
			
			--[[if CombatData.FeintActive then
				ToolSettings.FeintActive = false
			end]]
			--print("Canceled m1")
			return
		end
		
		Dash.Parent = plr.Character.HumanoidRootPart
		Dash.Velocity = Dist + Vector3.new(0,0,0)

		Debris:AddItem(Dash, .25)
		
		wait(.2)
		
		-- Feint
		if CombatData.FeintActive then
			Dash:Destroy()
			CombatData.FeintActive = false
			return
		end
		
		-- Cancel M1 effects
		if (chr:FindFirstChild("Stunned") or chr:FindFirstChild("HitTag") or (plr.Character:FindFirstChild("Active") == nil)) and CombatData.CurCombo ~= 3 then
			CancelM1Effects(plr, Anim)	
			--print("Canceled m1")
			return
		end			
		
		-- M1 Effects
		local SlashFX = game.ReplicatedStorage.Effects.SlashFX:Clone()
		local Attachment = SlashFX.Attachment
		Attachment.Name = "SlashFXAttachment"
		Attachment.Parent = chr.HumanoidRootPart
		
		Debris:AddItem(SlashFX, 2)
		Debris:AddItem(Attachment, 1)
		
		if CombatData.CurCombo == 1 or CombatData.CurCombo == 0 then
			-- 1st slash effect
			Attachment.Orientation = Vector3.new(10,0,185)
			Attachment.Slash3.RotSpeed = NumberRange.new(-600, -600)
			Attachment.Slash3.Rotation = NumberRange.new(-110,-110)
			Attachment.Slash3:Emit(2)
			
			Attachment.Slash4.RotSpeed = NumberRange.new(-600, -600)
			Attachment.Slash4.Rotation = NumberRange.new(-110,-110)
			Attachment.Slash4:Emit(2)
			
		elseif CombatData.CurCombo == 2 then
			-- 2nd slash effect
			Attachment.Position = Vector3.new(0,1,0)
			Attachment.Orientation = Vector3.new(-7.5,0,-5)
			Attachment.Slash3.Rotation = NumberRange.new(50,50)
			Attachment.Slash3:Emit(2)
			
			Attachment.Slash4.Rotation = NumberRange.new(50,50)
			Attachment.Slash4:Emit(2)
			
			Debris:AddItem(SlashFX, 2)
			
		elseif CombatData.CurCombo == 3 then
			--wait(Anim.Length*.3)
			wait(.405)
			
			-- 3rd slash effect
			Attachment.Orientation = Vector3.new(0,0,-105)
			Attachment.Slash3.Rotation = NumberRange.new(-170,-170)
			Attachment.Slash3:Emit(2)
			
			Attachment.Slash4.Rotation = NumberRange.new(-170,-170)
			Attachment.Slash4:Emit(2)
			
			wait(.15)
			local Attachment2 = SlashFX.Attachment2
			Attachment2.Parent = chr.HumanoidRootPart
			Attachment2.Orientation = Vector3.new(0,0,-105)
			Attachment2.MiniSparks:Emit(150)
			
			Debris:AddItem(Attachment2, 1)
		end
	end)()
	
	-- Temp variable
	local CurComboTemp = CombatData.CurCombo
	
	Anim.Stopped:wait()
	CombatData.OnCooldown = false
	module.SetWsJp(chr, chrData.DefaultWalkSpeed.Value, 50)
	SlowTag:Destroy()

	-- 3rd attack character directional unfreeze
	if CombatData.CurCombo == #CombatData.Animations then
		chr.Humanoid.AutoRotate = true			
	end

	-- Max combo reset
	if CombatData.CurCombo == #CombatData.Animations then
		CombatData.OnResetCooldown = true
		wait(CombatData.ComboResetTime)
		CombatData.OnResetCooldown = false
		CombatData.CurCombo = 0
	end

	-- Combo cancel 
	if CombatData.FeintActive then
		wait(CombatData.ComboResetTime/3)
	else
		wait(CombatData.ComboResetTime)
	end
	
	--if CurComboTemp == CombatData.CurCombo and ToolSettings.Combat.RecentlyParried == false and CombatData.FeintActive ~= true then
		--CombatData.OnResetCooldown = true
	--wait(CombatData.ComboResetTime)
	--wait(1)
	if CurComboTemp == CombatData.CurCombo and ToolSettings.Combat.RecentlyParried == false and CombatData.FeintActive == false then
		print("2. RESET M1 in combo cancel - "..plr.Name.. " / Combo: "..CombatData.CurCombo)
		CombatData.OnResetCooldown = false
		CombatData.CurCombo = 0
		chr.Humanoid.AutoRotate = true
	--elseif ToolSettings.Combat.RecentlyParried then
		
	--elseif CurComboTemp == CombatData.CurCombo and CombatData.FeintActive == false then
		--CombatData.CurCombo = 0
		--chr.Humanoid.AutoRotate = true
		--print("Recently parried is true")
	end
	--end
end

function module.Block(plr, Blocking)
	local chr = plr.Character
	local chrData = chr.CharacterData
	
	if Blocking == true then
		-- Holdable block
		--wait(.1)
		if (ToolSettings.Combat.OnCooldown or chr:FindFirstChild("Stunned") or ToolSettings.Skills.SkillActive) and ToolSettings.Combat.BlockActive == false then
			ToolSettings.Combat.BlockActive = true
			
			repeat wait()
				--print("Waiting")
				if ToolSettings.Combat.BlockActive == false then
					return --print("Stopped")
				end
			until (ToolSettings.Combat.OnCooldown == false and chr:FindFirstChild("HitTag") ~= true and chr:FindFirstChild("Stunned") ~= true and ToolSettings.Skills.SkillActive == false)
			
			if chr:FindFirstChild("HitTag") then
				wait(.1)	
			end
			
			if ToolSettings.Combat.BlockActive == false then
				return --print("Block was false")
			end
		else
			--print(ToolSettings.Combat.OnCooldown)
			--print(chr:FindFirstChild("Stunned"))
			--print(ToolSettings.Skills.SkillActive)
			--print(ToolSettings.Combat.RecentlyParried)
		end
		
		if ToolSettings.Combat.BlockDB or chr:FindFirstChild("HitTag") or ToolSettings.Combat.OnCooldown or ToolSettings.Skills.SkillActive == true or chr.Humanoid.Health <= 1 then return end
		ToolSettings.Combat.BlockActive = true
		ToolSettings.Combat.BlockDB = true
		
		-- Animation
		local ParryAnim = plr.Character.Humanoid:LoadAnimation(module.CreateAnimation(CombatData.ParryAnim))
		local Anim = plr.Character.Humanoid:LoadAnimation(module.CreateAnimation(CombatData.Block))
		
		coroutine.wrap(function()
			ParryAnim:play()
			ParryAnim.Priority = Enum.AnimationPriority.Action
			
			wait(.1)
			
			if ToolSettings.Combat.BlockActive == false then
				return
			end
			
			Anim:play()
			Anim:AdjustSpeed(0)
			Anim.Priority = Enum.AnimationPriority.Action
			changeWeight(Anim, 2, .125)
		end)()
		
		-- Speed
		local SlowTag = module.CreateTag(chr, "Slowed", chr.Name)
		module.SetWsJp(chr, 5, 0)
		
		-- Tags
		module.CreateTag(chr, "BlockTag", plr.Name)
		module.CreateTag(chr, "ParryTag", plr.Name)
		
		coroutine.wrap(function()
			wait(ToolSettings.Combat.ParryLinger)
			module.DestroyTag(chr, "ParryTag")
			wait(.1)
			if ToolSettings.Combat.BlockActive ~= false then
				chr.UpperTorso.BlockAttachment.ParticleEmitter.Color = ColorSequence.new(Color3.fromRGB(155, 100, 255))
				chr.UpperTorso.BlockAttachment.Ring.Color = ColorSequence.new(Color3.fromRGB(155, 100, 255))
			end
		end)()
		
		-- Effects
		local BlockFX = game.ReplicatedStorage.Effects.BlockFX.BlockAttachment:Clone()
		BlockFX.Parent = chr.UpperTorso
		
		-- Parry color
		chr.UpperTorso.BlockAttachment.ParticleEmitter.Color = ColorSequence.new(Color3.fromRGB(255,255,100))
		chr.UpperTorso.BlockAttachment.Ring.Color = ColorSequence.new(Color3.fromRGB(255,255,100))		

		-- Emit particle
		BlockFX.ParticleEmitter.Enabled = true
		coroutine.wrap(function()
			pcall(function()
				BlockFX.ParticleEmitter:Emit(2)
				wait(.05)
				BlockFX.ParticleEmitter:Emit(2)
				wait(.1)
				BlockFX.ParticleEmitter:Emit(2)				
			end)
		end)()
		
		-- Gui
		--local BlockBar = ServerStorage.Gui.BlockBar:Clone()
		--BlockBar.Parent = chr.UpperTorso
		
		while ToolSettings.Combat.BlockActive == true do wait()
			module.SetWsJp(chr, 5, 0)
			if chrData.BlockHealth.Value <= 0 then
				ToolSettings.Combat.BlockActive = false
				print("Block broken on client")
				break
			end
			if chr:FindFirstChild("Stunned") then
				ToolSettings.Combat.BlockActive = false
			end
		end
		
		-- Reset to normal
		BlockFX:Destroy()
		if chr:FindFirstChild("HitTag") ~= true then
			module.SetWsJp(chr, chrData.DefaultWalkSpeed.Value, 50)	
		end
		Anim:stop()
		print("stopped anim")
		ParryAnim:stop()
		module.DestroyTag(chr, "BlockTag")
		SlowTag:Destroy()
		
		-- Debounce
		wait(ToolSettings.Combat.BlockCooldown)
		ToolSettings.Combat.BlockDB = false
	else
		ToolSettings.Combat.BlockActive = false
	end
end

function module.Skill(plr, SkillNumber)
	local chr = plr.Character
	local plrData = plr.PlayerData
	local SkillName
	local SkillClass
	
	if ToolSettings.Skills.SkillActive == true or ToolSettings.Skills[SkillNumber].DB == true or ToolSettings.Combat.OnCooldown or ToolSettings.Combat.BlockActive or chr.Humanoid.Health <= 1 then return end
	
	ToolSettings.Skills.SkillActive = true
	ToolSettings.Skills[SkillNumber].DB = true
	
	for _,v in pairs(plrData.EquippedSkills:GetChildren()) do
		if v.Value == SkillNumber then
			SkillName = v.Name
			SkillClass = v:GetAttribute("SkillClass")
			
			if v:GetAttribute("IgnoreHit") ~= true and chr:FindFirstChild("HitTag") then
				ToolSettings.Skills.SkillActive = false
				ToolSettings.Skills[SkillNumber].DB = false
				return
			end
		end
	end
	
	if SkillClass == "BuildSkills" then
		SkillClass = require(game.ServerScriptService.Modules.BuildSkills)
	elseif SkillClass == "Signatures" then
		SkillClass = require(game.ServerScriptService.Modules.Signatures)
	elseif SkillClass == "CustomSkills" then
		SkillClass = require(game.ServerScriptService.Modules.CustomSkills)
	end
	
	local SkillReturn = SkillClass[SkillName](plr, CombatData)
	
	repeat wait()
	until SkillReturn[1] == false
	--print("Skill return")
	
	coroutine.wrap(function()
		wait(1)
		ToolSettings.Skills.SkillActive = false
		--print("Skill isn't active")
	end)()
	
	wait(SkillReturn[2])
	ToolSettings.Skills[SkillNumber].DB = false
end

function module.Feint(plr)
	local chr = plr.Character
	
	if ToolSettings.Skills.SkillActive == true or chr:FindFirstChild("HitTag") then return end
	
	if ToolSettings.Combat.FeintWindow then
		CombatData.FeintActive = true
	end
end

function module.Clash(plr)
	local chr = plr.Character
	local chrData = chr.CharacterData
	
	if ToolSettings.Combat.FeintActive or ToolSettings.Skills.SkillActive or chr:FindFirstChild("Stunned") or chr:FindFirstChild("HitTag") == nil then return end
	
	-- Block drain
	if chrData.BlockHealth.Value <= chrData.BlockMaxHealth.Value*ToolSettings.Combat.ClashDrain then return end
	chrData.BlockHealth.Value -= (chrData.BlockMaxHealth.Value*ToolSettings.Combat.ClashDrain)
	
	module.CreateTag(chr, "ClashTag", plr.Name)
	
	print("YO")
end

function module.MagnitudeAttack(plr, Part, Skill)	
	local Range = Skill.Range
	local InfrontCheck = Skill.Infront
	
	--if plr.Character.Humanoid.Health <= 1 then return end

	for i,v in pairs(game.Workspace:GetDescendants()) do
		if v:IsA("Model") and v:FindFirstChild("Humanoid") and v ~= plr.Character and v.Humanoid.Health > 0 then
			if (Part.Position - v.Humanoid.RootPart.Position).magnitude <= Range then
				if InfrontCheck then
					if module.Infront(plr.Character, v) then
						module.AttackEffects(plr, v, Skill, Part)
					end
				else
					module.AttackEffects(plr, v, Skill, Part)
				end
			end
		end	
	end	
end

function module.AttackEffects(plr, Victim, Skill, Part)
	if Victim:FindFirstChild("IFrames") or (plr.Character:FindFirstChild("HitTag") and CombatData.CurCombo ~= 3) --[[or plr.Character:FindFirstChild("Stunned")]] then return end

	local chr = plr.Character
	local chrData = chr.CharacterData
	local VictimChrData = Victim:FindFirstChild("CharacterData")
	local VictimDistanceFromChr = (chr.HumanoidRootPart.Position - Victim.Humanoid.RootPart.Position).magnitude
	
	local Strength = 0
	local LifeForce = 5

	local TotalDamage = Strength * (1 + (Skill.BaseDmg/100)) + Skill.BaseDmg

	local Checks = {["CriticalHit"] = false, ["VictimBlocking"] = false, ["VictimParrying"] = false, ["VictimBlockBroke"] = false, ["VictimClashing"] = false, ["VictimIsPlayer"] = false}

	if game.Players:GetPlayerFromCharacter(Victim) ~= nil then
		Checks.VictimIsPlayer = true
		if Victim.Humanoid.Health <= 1 then return end
	end
	if Victim:FindFirstChild("BlockTag") then
		Checks.VictimBlocking = true
	end
	if Victim:FindFirstChild("ParryTag") then
		Checks.VictimParrying = true
	end
	if Victim:FindFirstChild("ClashTag") then
		Checks.VictimClashing = true
	end
	
	-- Unblockable skill
	if Skill.Unblockable == true then
		module.DestroyTag(Victim, "BlockTag")
		module.DestroyTag(Victim, "ParryTag")
	end
	
	-- Clashing
	if Checks.VictimClashing then
		local ClashStun = module.CreateTag(chr, "Stunned", Victim.Name)
		local ClashStun2 = module.CreateTag(Victim, "Stunned", Victim.Name)
		Debris:AddItem(ClashStun, 1.5)
		Debris:AddItem(ClashStun2, 1.5)
		
		if Checks.VictimIsPlayer then
			
		end
		return
	end
	
	--[[ M1 Clashing
	if Checks.VictimM1Clashing and chr:FindFirstChild("M1ClashTag") and CombatData.CurCombo ~= 3 and Checks.VictimParrying == false then
		-- DestroyTag
		module.DestroyTag(chr, "M1ClashTag")
		module.DestroyTag(Victim, "M1ClashTag")
		
		-- Sound
		local SwordClashAudio = ReplicatedStorage.Audio.SwordClash:Clone()
		SwordClashAudio.Parent = chr
		SwordClashAudio:play()
		Debris:AddItem(SwordClashAudio, 2.3)
		
		-- Look at
		if (Skill == CombatData) and (Checks.VictimIsPlayer == false) and (CombatData.CurCombo ~= #CombatData.Animations or Checks.VictimBlockBroke) and Checks.VictimBlocking == false then
			module.LookAt(Victim, chr.HumanoidRootPart)
		end
		
		-- Knockback
		local function KnockBack(Parent, Power, Forces, Dist, Extra, DespawnTime)
			if Parent.HumanoidRootPart:FindFirstChild("KnockBack") then
				Parent.HumanoidRootPart.KnockBack:Destroy()
			end
			
			local KnockBack = Instance.new("BodyVelocity", Parent.HumanoidRootPart)
			KnockBack.Name = "KnockBack"

			-- Knockback settings
			KnockBack.MaxForce = Vector3.new(15000,5000,15000)
			KnockBack.P = 10000
			KnockBack.Velocity = Dist + Extra
			
			TS:Create(KnockBack, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {P = 0, MaxForce = Vector3.new(0,0,0)}):play()
			
			Debris:AddItem(KnockBack, 1+DespawnTime)			
		end
		
		coroutine.wrap(function()
			if chr.HumanoidRootPart:FindFirstChild("CombatDash") then
				chr.HumanoidRootPart.CombatDash:Destroy()
			end
			if Victim.HumanoidRootPart:FindFirstChild("CombatDash") then
				Victim.HumanoidRootPart.CombatDash:Destroy()
			end
		end)()
		
		-- Tags to cancel m1 effects
		local StunnedTag = module.CreateTag(Victim, "Stunned", chr.Name)
		Debris:AddItem(StunnedTag, 1.25)
		
		StunHandler.Stun(Victim.Humanoid, 1.25)
		
		local StunnedTag2 = module.CreateTag(chr, "Stunned", chr.Name)
		Debris:AddItem(StunnedTag2, 1.25)
		
		StunHandler.Stun(chr.Humanoid, 1.25)
		
		-- Intial Clash effects		
		local EffectsCFrame = CFrame.new(chr.HumanoidRootPart.Position+((VictimDistanceFromChr/2)*chr.HumanoidRootPart.CFrame.LookVector), chr.HumanoidRootPart.Position+(VictimDistanceFromChr*chr.HumanoidRootPart.CFrame.LookVector))
		
		local SparkFX2 = ReplicatedStorage.Effects.SparkFX2:Clone()
		SparkFX2.Parent = workspace
		SparkFX2.CFrame = EffectsCFrame
		SparkFX2.Attachment2.MiniSparks:Emit("50")
		Debris:AddItem(SparkFX2, 1)
		
		local ClashFX = ReplicatedStorage.Effects.ClashFX:Clone()
		ClashFX.Parent = workspace
		ClashFX.CFrame = EffectsCFrame
		
		for _,v in pairs(ClashFX.Attachment:GetChildren()) do
			if v.Name == "Dots" then
				v:emit(15)
			elseif v.Name == "Lines [1]" then
				v:emit(6)
			elseif v.Name == "Lines [2]" then
				v:emit(6)
			elseif v.Name == "Barrage 2" then
				v:emit(3)
			elseif v.Name == "Barrage" then
				v:emit(3)
			end
		end
		
		Debris:AddItem(ClashFX, 1)
		
		-- Animation
		local function PlayAnim(Parent)
			local Anim = Parent:LoadAnimation(module.CreateAnimation(CombatData.ClashAnim))
			Anim:play()
			Anim:AdjustWeight(0)
			Anim.Priority = Enum.AnimationPriority.Action
			changeWeight(Anim, 2, .125)	
			coroutine.wrap(function()
				wait(1.75)
				Anim:stop()
			end)()
		end
		
		PlayAnim(chr.Humanoid)
		PlayAnim(Victim.Humanoid)
		
		-- Dirt
		local function DirtEffects(Parent)				
			local DirtFX = ReplicatedStorage.Effects.DirtFX:Clone()
			local ParticleEmitter = DirtFX.ParticleEmitter
			ParticleEmitter.Enabled = true
			ParticleEmitter.Parent = Parent
			Debris:AddItem(DirtFX, .5)
			Debris:AddItem(ParticleEmitter, 2.5)
			
			coroutine.wrap(function()
				while ParticleEmitter do wait()
					local RayBelow = module:GetPartBelow(Parent.Parent.HumanoidRootPart)
					local FloorPart = RayBelow.Instance
					ParticleEmitter.Color = ColorSequence.new(FloorPart.Color)
				end
			end)()
			coroutine.wrap(function()
				wait(1)
				ParticleEmitter.Enabled = false
			end)()
		end
		
		DirtEffects(chr.LeftFoot)
		DirtEffects(chr.RightFoot)
		
		DirtEffects(Victim.LeftFoot)
		DirtEffects(Victim.RightFoot)
		
		-- Body Velocity / Knockback
		wait(.2)
		
		local Dist = (chr.HumanoidRootPart.CFrame.LookVector * 50)
		KnockBack(Victim, 1000, Vector3.new(50000, 50000, 50000), Dist, Vector3.new(0,0,0), .25)
		
		local Dist = (chr.HumanoidRootPart.CFrame.LookVector * -50)
		KnockBack(chr, 1000, Vector3.new(50000, 50000, 50000), Dist, Vector3.new(0,0,0), .25)
		
		return
	end]]
	
	local function BlockBreak()
		-- Variable
		local StunTime = CombatData.BlockBreakStunTime
		
		-- Tags
		module.DestroyTag(Victim, "BlockTag")
		module.DestroyTag(Victim, "ParryTag")	
		
		-- Set Health
		coroutine.wrap(function()
			VictimChrData.BlockHealth.Value = 0
			wait(.25)
			VictimChrData.BlockHealth.Value = VictimChrData.BlockMaxHealth.Value
		end)()
		
		-- Checks
		Checks.VictimBlocking = false
		Checks.VictimParrying = false
		Checks.VictimBlockBroke = true
		
		-- Effects
		local BlockBreakFX = game.ReplicatedStorage.Effects.BlockBreakFX.Attachment:Clone()
		BlockBreakFX.Parent = Victim.UpperTorso
		BlockBreakFX.Position = Vector3.new(0,0,-2)
		BlockBreakFX.Shield:Emit(1)
		BlockBreakFX.Smoke:Emit(2)
		BlockBreakFX.Triangles:Emit(15)

		Debris:AddItem(BlockBreakFX, 2.5)
		
		-- Sounds		
		local BlockBreakSound = game.ReplicatedStorage.Audio.BlockBreak:Clone()
		BlockBreakSound.Parent = Victim.HumanoidRootPart
		BlockBreakSound:Play()
		Debris:AddItem(BlockBreakSound, 2.35)
		
		-- Animation
		local Anim = Victim.Humanoid:LoadAnimation(module.CreateAnimation(CombatData.BlockBreak))
		Anim:play()
		Anim.Priority = Enum.AnimationPriority.Action
		changeWeight(Anim, 2, .125)
		
		-- Stunned
		if Skill == CombatData and CombatData.CurCombo == #CombatData.Animations then
			StunTime = StunTime + 1
		end
		
		module.CreateTag(Victim, "Stunned", plr.Name)
		StunHandler.Stun(Victim.Humanoid, StunTime)
		
		-- Reset
		coroutine.wrap(function()
			wait(StunTime)
			module.DestroyTag(Victim, "Stunned", plr.Name)
		end)()
	end
	
	local function BlockEffects()
		local SparkFX = game.ReplicatedStorage.Effects.SparkFX.Attachment:Clone()
		SparkFX.Parent = Victim.UpperTorso
		SparkFX.MiniSparks:Emit(25)
		Debris:AddItem(SparkFX, 4)
	end
	
	-- Block break
	if Skill.BlockBreak == true then
		BlockBreak()
	
		-- Block break from behind
	elseif module.Behind(chr, Victim) and Checks.VictimBlocking then
		BlockBreak()
		
	elseif (Skill == CombatData and CombatData.CurCombo == #CombatData.Animations) and (Checks.VictimBlocking and Checks.VictimParrying == false) then
		BlockBreak()
		
		-- Parried
	elseif Checks.VictimParrying and (Skill == CombatData and CombatData.CurCombo ~= #CombatData.Animations) then
		-- Sound
		local PerfectBlockSound = game.ReplicatedStorage.Audio.PerfectBlock:Clone()
		PerfectBlockSound.Parent = Victim.UpperTorso
		PerfectBlockSound:Play()
		Debris:AddItem(PerfectBlockSound, 2)
		
		-- Stun
		module.CreateTag(chr, "Stunned", Victim.Name)
		StunHandler.Stun(chr.Humanoid, CombatData.ParryStun)
		
		local VictimStunTag = module.CreateTag(Victim, "Stunned", Victim.Name)
		Debris:AddItem(VictimStunTag, .1)
		
		-- Screen shake
		game.ReplicatedStorage.Events.ScreenShake2:FireClient(plr, 7, 15, .25, .6)
		
		-- Particle
		local RingParticle = Victim.UpperTorso:FindFirstChild("Ring", true)
		if RingParticle then
			RingParticle:Emit(3)
		end
		
		-- Parry particles
		local ParryParticles = game.ReplicatedStorage.Effects.ParryEffects:Clone()
		local ParryAttachment = ParryParticles.ParryAttachment
		ParryAttachment.Parent = Victim.UpperTorso
		ParryAttachment.Position = Vector3.new(math.random(-100,100)/100, math.random(-100,100)/100, -2)
		
		for _,v in pairs(ParryAttachment:GetChildren()) do
			if v.Name == "Dots" then
				v:Emit(20)
			elseif v.Name == "Light1" then
				v:Emit(3)
			elseif v.Name == "Light2" then
				v:Emit(2)
			elseif v.Name == "Lines [1]" then
				v:Emit(10)
			elseif v.Name == "Waves" then
				v:Emit(3)
			end
		end
		
		Debris:AddItem(ParryParticles, 3)
		Debris:AddItem(ParryAttachment, 3)
		
		-- Spark particles
		local SparkFX = game.ReplicatedStorage.Effects.SparkFX.Attachment:Clone()
		SparkFX.Parent = Victim.UpperTorso
		SparkFX.MiniSparks:Emit(25)
		Debris:AddItem(SparkFX, 4)
		
		-- Auto rotate on
		chr.Humanoid.AutoRotate = true
		
		-- Reset player <- Something about this is broken
		print("3. Reset M1 in Attack effects - "..plr.Name.. " / Combo: "..CombatData.CurCombo)
		--ToolSettings.Combat.OnResetCooldown = false
		ToolSettings.Combat.CurCombo = 0
		ToolSettings.Combat.RecentlyParried = true
		coroutine.wrap(function()
			local TimeStamp = tick()
			local SkillWasActive = false
			wait(1)
			while true do wait()
				if ToolSettings.Skills.SkillActive then
					SkillWasActive = true
				end
				if chr:FindFirstChild("Stunned") and SkillWasActive == false then
					--print("STUNNED WILL BREAK THEN RETURN")
					--print(ToolSettings.Skills.SkillActive)
					break
				end
				if tick() - TimeStamp >= 1.5 --[[1.75??]] then
					if CombatData.RecentlyParried ~= false then
						CombatData.RecentlyParried = false	
						print("RECENTLY PARRIED IS OFF "..plr.Name)
						break
					else
						break
					end
				end
			end
		end)()
		
		-- Reset
		coroutine.wrap(function()
			wait(ToolSettings.Combat.ParryStun)
			module.DestroyTag(chr, "Stunned", plr.Name)
		end)()
		return
	end

	-- Critical
	local CritChance = Skill.CritChance+chrData.CritChance.Value
	local ChanceTable = {
		["Critical"] = {Chance = CritChance},
		["Normal"] = {Chance = 1-CritChance}
	}
	if module.RandomChance(ChanceTable) == "Critical" then
		TotalDamage = TotalDamage*(CombatData.CritDamage+chrData.CritDmgMulti.Value)
		Checks.CriticalHit = true
	end

	-- Charge
	if Skill["CurChargeTime"] ~= nil then
		TotalDamage = TotalDamage * (1+ (Skill.CurChargeTime/(Skill.MaxCharge*2)))
	end

	-- Damage
	if Checks.VictimBlocking == false then
		local HitTag = module.CreateTag(Victim, "HitTag", plr.Name)
		if Skill == CombatData then
			-- Stun
			if CombatData.CurCombo == #CombatData.Animations then
				Debris:AddItem(HitTag, CombatData.HitTagLinger*.75)
				StunHandler.Stun(Victim.Humanoid, CombatData.HitTagLinger*.75)
			elseif CombatData.CurCombo == 2 then
				Debris:AddItem(HitTag, CombatData.HitTagLinger*1.25)
				StunHandler.Stun(Victim.Humanoid, CombatData.HitTagLinger*1.25)
			else
				Debris:AddItem(HitTag, CombatData.HitTagLinger)
				StunHandler.Stun(Victim.Humanoid, CombatData.HitTagLinger)
			end
		else
			Debris:AddItem(HitTag, .3)
		end
		
		module.DealDamage(Victim, TotalDamage)
		--Victim.Humanoid:TakeDamage(TotalDamage)
	else
		-- Half damage on 3rd hit to block if parried
		if Skill == CombatData and CombatData.CurCombo == #CombatData.Animations and Checks.VictimParrying then
			TotalDamage = TotalDamage/2
		end	
		
		-- Deal damage to Block health
		VictimChrData.BlockHealth.Value = VictimChrData.BlockHealth.Value - TotalDamage
		
		if VictimChrData.BlockHealth.Value <= 0 then
			BlockBreak()
		end
	end
	
	-- Hit effects
	local HitEffect = CombatData.HitEffect.Attachment:Clone()
	HitEffect.Parent = Victim.UpperTorso
	
	for _,v in pairs(HitEffect:GetChildren()) do
		if Checks.VictimParrying == true then
			v.Color = ColorSequence.new(Color3.fromRGB(255,255,100))
		elseif Checks.CriticalHit == true then
			v.Color = ColorSequence.new(Color3.fromRGB(255,255, 100))
		elseif Checks.VictimBlocking == true then
			v.Color = ColorSequence.new(Color3.fromRGB(155, 100, 255))
		end

		if v.Name == "Dots" then
			v:emit(7)
		elseif v.Name == "Lines [1]" then
			v:emit(5)
		elseif v.Name == "Lines [2]" then
			v:emit(5)
		elseif v.Name == "Blood [1]" then
			v:emit(4)
		else
			if Checks.VictimBlocking == false then
				v:emit(1)
				if Skill == CombatData then
					if CombatData.CurCombo == 1 then
						v.Rotation = NumberRange.new(110)
					elseif CombatData.CurCombo == 2 then
						v.Rotation = NumberRange.new(-100)
					else
						v.Rotation = NumberRange.new(0)
					end
				end
			end
		end
	end
	Debris:AddItem(HitEffect, 5)
	
	-- Block effects
	if (Checks.VictimBlocking) and Skill == CombatData then
		BlockEffects()
	end
	
	-- Damage display
	local DamageDisplay = game.ServerStorage.Gui.DamageBoard:Clone()
	DamageDisplay.Parent = Victim.UpperTorso
	
	if Checks.VictimBlocking then
		DamageDisplay.BackgroundText.DamageText.TextColor3 = Color3.fromRGB(155, 100, 255)
	end
	
	if Checks.CriticalHit == true then
		DamageDisplay.Size = UDim2.new(6,0,4,0)
		DamageDisplay.BackgroundText.DamageText.TextColor3 = Color3.fromRGB(255,255,100)
	end

	DamageDisplay.BackgroundText.Text = module.RoundNumber(TotalDamage, 1)
	DamageDisplay.BackgroundText.DamageText.Text = DamageDisplay.BackgroundText.Text
	DamageDisplay.BackgroundText.Rotation = math.random(-25,25)
	DamageDisplay.StudsOffset = Vector3.new(math.random(-1,1), math.random(-1,1), math.random(-1,1))

	local XRand = math.random(-5,5)
	local YRand = math.random(-7.5,2)
	local ZRand = math.random(-5,5)

	TS:Create(DamageDisplay, TweenInfo.new(1),{Size = UDim2.new(0,0,0,0), StudsOffset = DamageDisplay.StudsOffset + Vector3.new(XRand, YRand, ZRand)}):play()
	Debris:AddItem(DamageDisplay, 2)
	
	-- Sound
	coroutine.wrap(function()
		if Skill == CombatData then
			local Hit = nil

			if Checks.VictimBlocking == true then
				Hit = game.ReplicatedStorage.Audio["SwordParry"..math.random(1,2)]:Clone()
			else
				if CombatData.CurCombo == 0 then
					Hit = game.ReplicatedStorage.Audio["HeavySlice"..1]:Clone()
				else
					Hit = game.ReplicatedStorage.Audio["HeavySlice"..CombatData.CurCombo]:Clone()
				end
			end

			Hit.Parent = Victim.UpperTorso
			Hit.PlaybackSpeed = math.random(9,11)/10
			Hit:Play()
			Debris:AddItem(Hit, 3)
		end
	end)()
	
	-- Animation
	if (Skill == CombatData) and (CombatData.CurCombo ~= #CombatData.Animations) and (Checks.VictimBlocking == false) then
		local Anim = Victim.Humanoid:LoadAnimation(module.CreateAnimation(CombatData.VictimHitAnimations[math.clamp(CombatData.CurCombo, 1, 3)]))
		Anim:play()
		--Anim:AdjustSpeed(0)
		Anim.Priority = Enum.AnimationPriority.Action
		changeWeight(Anim, 2, .125)
	end
	
	-- Gui update
	game.ReplicatedStorage.Events.UpdateCombo:FireClient(plr)

	-- Look at
	if (Skill == CombatData) and (Checks.VictimIsPlayer == false) and (CombatData.CurCombo ~= #CombatData.Animations or Checks.VictimBlockBroke) and Checks.VictimBlocking == false then
		module.LookAt(Victim, chr.HumanoidRootPart)
	end

	-- Knockback
	if (Skill == CombatData) and (CombatData.CurCombo == #CombatData.Animations) and Checks.VictimBlocking == false and Checks.VictimBlockBroke == false then
		local KnockBack = Instance.new("BodyVelocity", Victim.HumanoidRootPart)
		KnockBack.Name = "KnockBack"
		
		-- Knockback settings
		KnockBack.MaxForce = Vector3.new(80000,100000,80000)
		KnockBack.P = 100000
		local Dist = (chr.HumanoidRootPart.CFrame.LookVector * 55)
		KnockBack.Velocity = Dist + Vector3.new(0,20,0)
		
		Debris:AddItem(KnockBack, .25)

	elseif (Skill == CombatData) and (CombatData.CurCombo == 2 or CombatData.CurCombo == 1) and Checks.VictimBlocking == false then
		local KnockBack = Instance.new("BodyVelocity", Victim.HumanoidRootPart)
		KnockBack.Name = "KnockBack"

		KnockBack.MaxForce = Vector3.new(50000,50000,50000)
		KnockBack.P = 1500
		local Dist = (chr.HumanoidRootPart.CFrame.LookVector * 15)
		KnockBack.Velocity = Dist

		Debris:AddItem(KnockBack, .1)
	end

	-- Ragdoll
	if (CombatData.CurCombo == #CombatData.Animations) and Skill.Ragdoll[1] == true and Checks.VictimBlocking == false and Checks.VictimBlockBroke == false and ((Victim:FindFirstChild("AntiRagdoll")) ~= true) and Victim then
		Victim.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		
		coroutine.wrap(function()
			wait(Skill.Ragdoll[2])
			Victim.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)()
		
		if Checks.VictimIsPlayer then
			game.ReplicatedStorage.Events.ClientRagdoll:FireClient(game.Players:GetPlayerFromCharacter(Victim), Skill.Ragdoll[2])
		end
	end

	-- Screen shake	
	if Skill == CombatData and CombatData.CurCombo == #CombatData.Animations then
		if Checks.VictimIsPlayer == true then
			game.ReplicatedStorage.Events.ScreenShake2:FireClient(game.Players:GetPlayerFromCharacter(Victim), CombatData.ScreenShakeTable.Power+1, CombatData.ScreenShakeTable.Amount+2, CombatData.ScreenShakeTable.FadeIn, CombatData.ScreenShakeTable.FadeOut+.1)
		end
	else
		game.ReplicatedStorage.Events.ScreenShake2:FireClient(plr, CombatData.ScreenShakeTable.Power, CombatData.ScreenShakeTable.Amount, CombatData.ScreenShakeTable.FadeIn, CombatData.ScreenShakeTable.FadeOut)
		if Checks.VictimIsPlayer == true then
			game.ReplicatedStorage.Events.ScreenShake2:FireClient(game.Players:GetPlayerFromCharacter(Victim), CombatData.ScreenShakeTable.Power, CombatData.ScreenShakeTable.Amount, CombatData.ScreenShakeTable.FadeIn, CombatData.ScreenShakeTable.FadeOut)
		end
	end

	--[[ On Hit effects (Meshes and stuff)
	if Skill == ZSkillData then
		local SlapFX = game.ReplicatedStorage.Models.RockSpirit.SlapFX:Clone()
		SlapFX.Parent = game.Workspace

		SlapFX:SetPrimaryPartCFrame(CFrame.new(chr.PrimaryPart.CFrame.Position+(5*chr.PrimaryPart.CFrame.LookVector), chr.HumanoidRootPart.Position)*CFrame.Angles(math.rad(0), math.rad(180), math.rad(math.random(-90, 90))))

		TS:Create(SlapFX.Shock1, TweenInfo.new(.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = (SlapFX.Shock1.Size*1.1)*(1+(Skill.CurChargeTime/(Skill.MaxCharge*2))), Transparency = 1}):play()
		TS:Create(SlapFX.Shock2, TweenInfo.new(.75, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = (SlapFX.Shock2.Size*1.35)*(1+(Skill.CurChargeTime/(Skill.MaxCharge*2))), Transparency = 1}):play()
		TS:Create(SlapFX.Shock3, TweenInfo.new(.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = (SlapFX.Shock2.Size*1.85)*(1+(Skill.CurChargeTime/(Skill.MaxCharge*2))), Transparency = 1}):play()

		TS:Create(SlapFX.Airwave1, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = (SlapFX.Airwave1.Size*1.6)*(1+(Skill.CurChargeTime/(Skill.MaxCharge*2))), Transparency = 1}):play()
		TS:Create(SlapFX.Airwave2, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = (SlapFX.Airwave2.Size*1.85)*(1+(Skill.CurChargeTime/(Skill.MaxCharge*2))), Transparency = 1}):play()

		Debris:AddItem(SlapFX, 3)
	end]]
end

return module
