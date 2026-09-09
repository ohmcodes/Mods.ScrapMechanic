dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

---@class Growbed : ShapeClass
---@field sv table
---@field cl table
Growbed = class( nil )
Growbed.maxParentCount = 1
Growbed.connectionInput = sm.interactable.connectionType.electricity
Growbed.maxChildCount = 0
Growbed.connectionOutput = sm.interactable.connectionType.none
Growbed.poseWeightCount = 3
Growbed.colorNormal = sm.color.new( 0xffca1aff )
Growbed.colorHighlight = sm.color.new( 0xffca1aff )
Growbed.connectIcon = "electrical"
Growbed.connectIconScale = 0.75


local UVLightPoseIndex = 0
local GrowPoseSmallIndex = 1
local GrowPoseLargeIndex = 2





local GrowbedData = {
	[tostring(obj_interactive_growbed_soil)] = {
		type = "soil"
	},
	-- Potato
	[tostring(obj_interactive_growbed_potato_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_potato_mature
	},
	[tostring(obj_interactive_growbed_potato_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_potato,
		seed = obj_seed_potato
	},
	-- banana
	[tostring(obj_interactive_growbed_banana_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_banana_mature
	},
	[tostring(obj_interactive_growbed_banana_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_banana,
		seed = obj_seed_banana
	},
	-- blueberry
	[tostring(obj_interactive_growbed_blueberry_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_blueberry_mature
	},
	[tostring(obj_interactive_growbed_blueberry_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_blueberry,
		seed = obj_seed_blueberry
	},
	-- broccoli
	[tostring(obj_interactive_growbed_broccoli_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_broccoli_mature
	},
	[tostring(obj_interactive_growbed_broccoli_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_broccoli,
		seed = obj_seed_broccoli
	},
	-- carrot
	[tostring(obj_interactive_growbed_carrot_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_carrot_mature
	},
	[tostring(obj_interactive_growbed_carrot_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_carrot,
		seed = obj_seed_carrot
	},
	-- chili
	[tostring(obj_interactive_growbed_chili_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_chili_mature
	},
	[tostring(obj_interactive_growbed_chili_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_chili,
		seed = obj_seed_chili
	},
	-- cotton
	[tostring(obj_interactive_growbed_cotton_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_cotton_mature
	},
	[tostring(obj_interactive_growbed_cotton_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_resource_cotton,
		seed = obj_seed_cotton
	},
	-- orange
	[tostring(obj_interactive_growbed_orange_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_orange_mature
	},
	[tostring(obj_interactive_growbed_orange_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_orange,
		seed = obj_seed_orange
	},
	-- pigmentflower
	[tostring(obj_interactive_growbed_pigmentflower_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_pigmentflower_mature
	},
	[tostring(obj_interactive_growbed_pigmentflower_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_resource_flower,
		seed = obj_seed_pigmentflower
	},
	-- pineapple
	[tostring(obj_interactive_growbed_pineapple_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_pineapple_mature
	},
	[tostring(obj_interactive_growbed_pineapple_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_pineapple,
		seed = obj_seed_pineapple
	},
	-- redbeet
	[tostring(obj_interactive_growbed_redbeet_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_redbeet_mature
	},
	[tostring(obj_interactive_growbed_redbeet_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_redbeet,
		seed = obj_seed_redbeet
	},
	-- tomato
	[tostring(obj_interactive_growbed_tomato_sprout)] = {
		type = "sprout",
		growTickTime = 40 * DAYCYCLE_TIME * 0.875,
		mature = obj_interactive_growbed_tomato_mature
	},
	[tostring(obj_interactive_growbed_tomato_mature)] = {
		type = "mature",
		amount = 5,
		harvest = obj_plantables_tomato,
		seed = obj_seed_tomato
	}
	
}

local SoilFrames = 10
local UvLightPoseSpeed = 3
local WaterRetentionTickTime = 40 * DAYCYCLE_TIME * 1.5
local ElectricityRetentionTickTime = 40 * DAYCYCLE_TIME * 0.25
local TimeStep = 0.025

function Growbed.sv_updatePublicData( self )
	local data = self:getData()

	self.interactable.publicData = self.interactable.publicData or {}

    local watered = self.sv.saved.waterTicks > 0

    self.interactable.publicData.fertilized =
        self.sv.saved.fertilizer == true

    self.interactable.publicData.watered = watered
    self.interactable.publicData.seeded =
        data.type ~= "soil"
end

-- Server
function Growbed.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then self.sv.saved = {}	end
	if self.sv.saved.waterTicks == nil then self.sv.saved.waterTicks = 0 end
	if self.sv.saved.fertilizer == nil then self.sv.saved.fertilizer = false end
	if self.sv.saved.lastTickUpdate == nil then self.sv.saved.lastTickUpdate = sm.game.getCurrentTick() end
	if self.sv.saved.growTicks == nil then self.sv.saved.growTicks = 0 end
	if self.sv.saved.electricityTicks == nil then self.sv.saved.electricityTicks = 0 end
	self.sv.replaceTick= 0

	self:sv_performUpdate()
	self:sv_saveAndSynch( true )

	self.interactable.publicData = {}

	self:sv_updatePublicData()
end

function Growbed.server_onReceiveUpdate( self )
	self:sv_performUpdate()
	self:sv_saveAndSynch()
end

function Growbed.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	local data = self:getData()
	if data.type == "sprout" then
		if self:sv_canReplace() then
			sm.effect.playEffect( "Plants - Destroyed", self.shape.worldPosition )
			self:sv_replace( obj_interactive_growbed_soil )
			self.sv.saved.fertilizer = false
			self.sv.saved.growTicks = 0
			self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
			self:sv_saveAndSynch()
		end
	elseif data.type == "mature" then
		if not self.interactable.publicData.harvested then
			if self:sv_canReplace() then
				if type( attacker ) == "Unit" then
					sm.effect.playEffect( "Plants - Destroyed", self.shape.worldPosition )
				elseif type( attacker ) == "Player" then
					sm.effect.playEffect( "Plants - Picked", self.shape.worldPosition )
					local harvest = {
						lootUid = data.harvest,
						lootQuantity = data.amount
					}
					local seed = {
						lootUid = data.seed,
						lootQuantity = PlantSeedDropAmount( data.seed )
					}
					local offsetPos = sm.vec3.new( 0.0, 0.75, 0.0 )
					sm.projectile.shapeCustomProjectileAttack( harvest, projectile_loot, 0, offsetPos, sm.noise.gunSpread( sm.vec3.new( 0, 1, 0 ), 20 ) * 5, self.shape, 0 )
					if seed.lootQuantity > 0 then
						sm.projectile.shapeCustomProjectileAttack( seed, projectile_loot, 0, offsetPos, sm.noise.gunSpread( sm.vec3.new( 0, 1, 0 ), 20 ) * 5, self.shape, 0 )
					end
				end
				self:sv_replace( obj_interactive_growbed_soil )
				self.interactable.publicData.harvested = true
				self.sv.saved.fertilizer = false
				self.sv.saved.growTicks = 0
				self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
				self:sv_saveAndSynch()
			end
		end
	end
end

function Growbed.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if projectileUuid == projectile_water then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.saved.waterTicks = WaterRetentionTickTime
		self:sv_saveAndSynch() -- Save and synch water
	elseif projectileUuid == projectile_fertilizer then
		self:sv_performUpdate() -- Catch up to current time
		self.sv.saved.fertilizer = true
		self:sv_saveAndSynch() -- Save and synch fertilizer
	end

	local data = self:getData()
	if data.type == "soil" then
		if projectileUuid == projectile_potato then
			self:sv_plant( { sproutUuid = obj_interactive_growbed_potato_sprout } )
		elseif projectileUuid == projectile_seed then
			self:sv_plant( { sproutUuid = userData.growbed } )
		end
	elseif data.type == "sprout" or data.type == "mature" then
		if type( attacker ) == "Unit" then
			if self:sv_canReplace() then
				sm.effect.playEffect( "Plants - Destroyed", self.shape.worldPosition )
				self:sv_replace( obj_interactive_growbed_soil )
				if data.type == "mature" then
					self.interactable.publicData.harvested = true
					self.sv.saved.fertilizer = false
				end
				self.sv.saved.growTicks = 0
				self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
				self:sv_saveAndSynch()
			end
		end
	end











end

function Growbed.sv_performUpdate( self )
	local currentTick = sm.game.getCurrentTick()
	local elapsedTicks = currentTick - self.sv.saved.lastTickUpdate
	self.sv.saved.lastTickUpdate = currentTick
	elapsedTicks = math.max( elapsedTicks, 0 )




	local data = self:getData()
	if data.type == "sprout" then
		local elapsedActiveTicks = 0
		local possibleGrowthTicks = math.min( elapsedTicks, math.max( data.growTickTime - self.sv.saved.growTicks, 0 ) )
		local batteriesToSpend, batteryFractionToSpend = math.modf( possibleGrowthTicks / ElectricityRetentionTickTime )
		local electricityTicksToSpend = batteryFractionToSpend * ElectricityRetentionTickTime
		if electricityTicksToSpend > self.sv.saved.electricityTicks - 1 then
			batteriesToSpend = batteriesToSpend + 1
		end

		local consumeResult, consumeAmount = TryConsumePowerResource( self.interactable, ITEMS.obj_consumable_battery, sm.interactable.connectionType.electricity, batteriesToSpend )
		if consumeResult == PowerConsumeType.resource then
			self.sv.saved.electricityTicks = self.sv.saved.electricityTicks + consumeAmount * ElectricityRetentionTickTime
			elapsedActiveTicks = math.min( self.sv.saved.electricityTicks, possibleGrowthTicks )
		end

		if self.sv.saved.waterTicks > 0 and self.sv.saved.electricityTicks > 0 then
			self.sv.saved.growTicks = math.min( self.sv.saved.growTicks + elapsedActiveTicks * ( self.sv.saved.fertilizer and 20 or 1 ), data.growTickTime )
		end
		self.sv.saved.electricityTicks = math.max( self.sv.saved.electricityTicks - elapsedActiveTicks, 0 )

		self.interactable:setPublicData( { isActive = self.sv.saved.electricityTicks > 0 } )

		if self:sv_canReplace() then
			local growFraction = self.sv.saved.growTicks / data.growTickTime
			if growFraction >= 1.0 then
				sm.effect.playEffect( "Plants - Done", self.shape.worldPosition )
				self:sv_replace( data.mature )
				self.sv.saved.growTicks = 0
			end
		end
	else
		self.interactable:setPublicData( { isActive = false } )
	end
	self.sv.saved.waterTicks = math.max( self.sv.saved.waterTicks - elapsedTicks, 0 )
	self:sv_updatePublicData()
end

function Growbed.sv_saveAndSynch( self, fromCreate )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { waterTicks = self.sv.saved.waterTicks, fertilizer = self.sv.saved.fertilizer, growTicks = self.sv.saved.growTicks, electricityTicks = self.sv.saved.electricityTicks, fromCreate = fromCreate } )
end

function Growbed.sv_replace( self, shapeUuid )
	self.shape:replaceShape( shapeUuid )
	self.sv.replaceTick= sm.game.getCurrentTick()
end

function Growbed.sv_canReplace( self )
	return self.sv.replaceTick< sm.game.getCurrentTick()
end

function Growbed.sv_e_plant( self, params )
	local data = self:getData()
	if data.type == "soil" then
		if self:sv_canReplace() then
			local plantableData = sm.item.getPlantable( params.plantableUuid )
			if plantableData.allowInGrowbed == false then
				return
			end

			local sproutUuid = plantableData.growbed and sm.uuid.new( plantableData.growbed ) or nil
			if sproutUuid then
				if sm.container.beginTransaction() then
					sm.container.spendFromSlot( params.playerInventory, params.slot, params.plantableUuid, 1 )
					if sm.container.endTransaction() then
						self:sv_plant( { sproutUuid = sproutUuid } )
					end
				end
			end
		end
	end
end

function Growbed.sv_plant( self, params )
	local data = self:getData()
	if data.type == "soil" then
		if self:sv_canReplace() then
			sm.effect.playEffect( "Plants - Planted", self.shape.worldPosition )
			if params.sproutUuid then
				self:sv_replace( params.sproutUuid )
				self.sv.saved.growTicks = 0
				self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
				self:sv_saveAndSynch()
			end
		end
	end
end

function Growbed.sv_e_fertilize( self, params )
	if not self.sv.saved.fertilizer then
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.playerInventory, params.slot, ITEMS.obj_consumable_fertilizer, 1 )
			if sm.container.endTransaction() then
				self:sv_performUpdate() -- Catch up to current time
				self.sv.saved.fertilizer = true
				self:sv_saveAndSynch() -- Save and synch fertilizer
			end
		end
	end
end

function Growbed.server_canErase( self )
	local data = self:getData()
	if data.type == "soil" then
		return true
	end
	return false
end

function Growbed.client_canErase( self )
	local data = self:getData()
	if data.type == "soil" then
		return true
	end
	return false
end

function Growbed.sv_n_harvest( self, _, player )
	local data = self:getData()
	if data.type == "mature" then
		if not self.interactable.publicData.harvested then
			if self:sv_canReplace() then
				local container = player:getInventory()
				if sm.container.beginTransaction() then
					sm.container.collect( container, data.harvest, data.amount, true )
					local seedAmount = PlantSeedDropAmount( data.seed )
					local seedsCollected = sm.container.collect( container, data.seed, seedAmount, false )
					if sm.container.endTransaction() then
						sm.effect.playEffect( "Plants - Picked", self.shape.worldPosition )
						self:sv_replace( obj_interactive_growbed_soil )
						self.interactable.publicData.harvested = true
						self.sv.saved.fertilizer = false
						self.sv.saved.growTicks = 0
						self.sv.saved.lastTickUpdate = sm.game.getCurrentTick()
						self:sv_saveAndSynch()
						if seedsCollected < seedAmount then
							self.network:sendToClient( player, "cl_n_onInventoryFull" )
							local loot = { lootUid = data.seed, lootQuantity = seedAmount - seedsCollected }
							local offsetPos = sm.vec3.new( 0.0, 0.75, 0.0 )
							sm.projectile.shapeCustomProjectileAttack( loot, projectile_loot, 0, offsetPos, sm.noise.gunSpread( sm.vec3.new( 0, 1, 0 ), 20 ) * 5, self.shape, 0 )
						end
					else
						self.network:sendToClient( player, "cl_n_onInventoryFull" )
					end
				end
			end
		end
	end
end

-- Client
function Growbed.client_onCreate( self )
	self.cl = {}
	self.cl.waterTicks = 0
	self.cl.fertilizer = false
	self.cl.fakeTickElapsedTime = 0
	self.cl.uvlightEffect = sm.effect.createEffect( "Interactive - Growbed_active", self.interactable )
	self.cl.fertilizerLoopEffect = sm.effect.createEffect( "Plants - Fertilizer_loop", self.interactable )
	self.cl.fertilizerLoopEffect:setOffsetRotation( sm.quat.fromEuler( sm.vec3.new( -90, 0, 0 ) ) )

	self.cl.fertilizerEffect = sm.effect.createEffect( "Plants - Fertilizer_impact", self.interactable )
	self.cl.fertilizerEffect:setOffsetRotation( sm.quat.fromEuler( sm.vec3.new( -90, 0, 0 ) ) )
	
	self.cl.uvLightPoseWeight = 0.0

	self.interactable.clientPublicData = {}
end

function Growbed.client_onDestroy( self )
	if sm.exists( self.cl.fertilizerLoopEffect ) then
		self.cl.fertilizerLoopEffect:destroy()
	end
	if sm.exists( self.cl.uvlightEffect ) then
		self.cl.uvlightEffect:destroy()
	end
	if sm.exists( self.cl.fertilizerEffect ) then
		self.cl.fertilizerEffect:destroy()
	end
end

function Growbed.client_onUpdate( self, dt )










	local data = self:getData()
	local availableElectricityTicks = 0
	local parent = self.interactable:getSingleParent()
	if parent and parent:getClientPublicData() and parent:getClientPublicData().isActive then
		local parentPublicData = parent:getClientPublicData()
		if parentPublicData.isActive then
			availableElectricityTicks = ElectricityRetentionTickTime
		else
			availableElectricityTicks = 0
		end
	else
		local batteryContainer = parent and parent:getContainer()
		if batteryContainer then
			local availableBatteries = sm.container.totalQuantity( batteryContainer, obj_consumable_battery )
			availableElectricityTicks = self.cl.electricityTicks + availableBatteries * ElectricityRetentionTickTime
		end
	end

	self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime + dt
	while self.cl.fakeTickElapsedTime > TimeStep do
		if data.type == "sprout" then
			if availableElectricityTicks > 0 then
				self.cl.electricityTicks = self.cl.electricityTicks - 1
				if self.cl.waterTicks > 0 then
					self.cl.growTicks = math.min( self.cl.growTicks + ( self.cl.fertilizer and 15 or 1 ), data.growTickTime )
				end
			end
		end
		self.cl.fakeTickElapsedTime = self.cl.fakeTickElapsedTime - TimeStep
		self.cl.waterTicks = math.max( self.cl.waterTicks - 1, 0 )
	end

	-- Visual UV scroll wetness
	local waterFraction = self.cl.waterTicks / WaterRetentionTickTime
	local soilFrameIndex = math.ceil( waterFraction * ( SoilFrames - 1 ) )
	self.interactable:setUvFrameIndex( soilFrameIndex )

	-- UV light pose
	self.cl.uvLightPoseWeight = data.type == "sprout" and availableElectricityTicks > 0 and math.min( self.cl.uvLightPoseWeight + dt * UvLightPoseSpeed, 1.0 ) or math.max( self.cl.uvLightPoseWeight - dt * UvLightPoseSpeed, 0 )
	self.interactable:setPoseWeight( UVLightPoseIndex, self.cl.uvLightPoseWeight )

	if availableElectricityTicks > 0 and data.type == "sprout" then
        if not self.cl.uvlightEffect:isPlaying() or self.cl.uvlightEffect:isBreakSustaining() then
            self.cl.uvlightEffect:start()
        end
    else
        if self.cl.uvlightEffect:isPlaying() and not self.cl.uvlightEffect:isBreakSustaining() then
            self.cl.uvlightEffect:stopBreakSustain()
        end
    end

	-- Visual growth progress
	if data.type == "sprout" then
		local growFraction = self.cl.growTicks / data.growTickTime
		--Blend from 1.0 to 0.0 over the course of 0 to 0.5 of the growth progress
		local firstWeight = 1.0 - math.min( math.max( growFraction * 2, 0 ), 1 )
		--Blend from 0.0 to 1.0 over the course of 0.5 to 1.0 of the growth progress
		local secondWeight = math.min( math.max( growFraction - 0.5, 0 ), 0.5 ) * 2
		self.interactable:setPoseWeight( GrowPoseSmallIndex, firstWeight )
		self.interactable:setPoseWeight( GrowPoseLargeIndex, secondWeight )
	end
end

function Growbed.client_onInteract( self, state )
	local data = self:getData()
	if data.type == "mature" then
		self.network:sendToServer( "sv_n_harvest" )
	end
end

function Growbed.client_canInteract( self )
	local data = self:getData()
	if data.type == "mature" then
		sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Use", true ), "#{INTERACTION_HARVEST}" )
		return true
	end
	return false
end

function Growbed.client_onClientDataUpdate( self, clientData )
	if self.cl == nil then self.cl = {} end
	self.cl.waterTicks = clientData.waterTicks
	if self.cl.fertilizer ~= clientData.fertilizer then
		if clientData.fertilizer then
			if not clientData.fromCreate then
				self.cl.fertilizerEffect:start()
			end
			if not self.cl.fertilizerLoopEffect:isPlaying() then
				self.cl.fertilizerLoopEffect:start()
			end
		else
			if self.cl.fertilizerLoopEffect:isPlaying() then
				self.cl.fertilizerLoopEffect:stop()
			end
		end
	end
	self.cl.fertilizer = clientData.fertilizer
	self.cl.growTicks = clientData.growTicks
	self.cl.electricityTicks = clientData.electricityTicks
	self.cl.fakeTickElapsedTime = 0
	self.interactable.clientPublicData.fertilizer = self.cl.fertilizer
end

function Growbed.cl_n_onInventoryFull( self )
	NotificationManager.Cl_AddGenericNotification( "#{INFO_INVENTORY_FULL}", 4 )
end

function Growbed.getData( self )
	if sm.exists( self.shape ) then
		local growbedData = GrowbedData[tostring(self.shape.uuid)]
		if growbedData == nil then
			sm.log.warning( "Growbed.getData couldn't find data for a shape: {"..tostring( self.shape.uuid ).."}" )
		end
		return growbedData or {}
	end
	return {}
end