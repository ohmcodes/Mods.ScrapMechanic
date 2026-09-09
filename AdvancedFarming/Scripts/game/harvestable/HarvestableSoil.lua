-- HarvestableSoil.lua --
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/managers/RaidManager.lua" )

HarvestableSoil = class( nil )

local MaxSoilFrame = 9
local WaterRetentionTickTime = DAYCYCLE_TIME_TICKS * 1.5
local WetStepTime = WaterRetentionTickTime / MaxSoilFrame

function HarvestableSoil.sv_updatePublicData( self )
	-- The vacuum reads this server-side state before spending and firing water.
    if not self.harvestable or not sm.exists( self.harvestable ) then
        return
    end

    local waterRetentionTickTime = DAYCYCLE_TIME_TICKS * 1.5
    local watered = false

    if self.sv.saved.waterTick then
        local ticksSinceWatered = sm.game.getCurrentTick() - self.sv.saved.waterTick
        watered = ticksSinceWatered < waterRetentionTickTime
    end

    self.harvestable.publicData = {
        fertilized = self.sv.saved.fertilizer == true,
        watered = watered,
        seeded = self.sv.planted == true
    }
end

-- Server
function HarvestableSoil.server_onCreate( self )
	self.sv = {}
	self.sv.planted = false
	self.sv.saved = self.storage:load() or {}
	self.sv.saved.waterTick = self.sv.saved.waterTick or nil
	self.sv.saved.fertilizer = self.sv.saved.fertilizer or false
	if self.params then
		if self.params.waterTick then
			self.sv.saved.waterTick = self.params.waterTick
		end
		if self.params.fertilizer ~= nil then
			self.sv.saved.fertilizer = self.params.fertilizer
		end
		self:sv_saveAndSync()
	else
		self.network:setClientData( { waterTick = self.sv.saved.waterTick, fertilizer = self.sv.saved.fertilizer } )
	end

	self:sv_updatePublicData()
end

function HarvestableSoil.server_onReceiveUpdate( self )
	if WeatherManager.Sv_IsRaining() then
		self.sv.saved.waterTick = self.sv.saved.waterTick or ( sm.game.getCurrentTick() - WaterRetentionTickTime )
		self.sv.saved.waterTick = math.min( self.sv.saved.waterTick + DAYCYCLE_TIME_TICKS * 0.1, sm.game.getCurrentTick() )
		self:sv_saveAndSync()
	end
end

function HarvestableSoil.sv_saveAndSync( self )
	self.storage:save( self.sv.saved )
	self.network:setClientData( { waterTick = self.sv.saved.waterTick, fertilizer = self.sv.saved.fertilizer } )

	self:sv_updatePublicData()
end

function HarvestableSoil.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	-- Record direct water impacts immediately; BaseWorld also sends sv_e_waterSoil for splash contacts.
	if projectileUuid == projectile_water then
		self:sv_e_waterSoil()
	elseif projectileUuid == projectile_fertilizer then
		self.sv.saved.fertilizer = true
		self:sv_saveAndSync()
	end
	if not RaidManager.Sv_AreaHasActiveRaid( self.harvestable.worldPosition, self.harvestable:getWorld().id ) then
		if projectileUuid == projectile_potato then
			self:sv_plant( hvs_growing_potato )
		elseif projectileUuid == projectile_seed then
			self:sv_plant( userData.hvs )
		end
	elseif projectileUuid == projectile_seed and userData and userData.seed then
		local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
		lootHarvestable:setParams( { uuid = userData.seed, quantity = 1, epic = false  } )
	end
end

function HarvestableSoil.sv_e_waterSoil( self )
	self.sv.saved.waterTick = sm.game.getCurrentTick()
	self:sv_saveAndSync()
end

function HarvestableSoil.sv_e_plant( self, params )
	--if RaidManager.Sv_AreaHasActiveRaid( self.harvestable.worldPosition, self.harvestable:getWorld().id ) then
	--	return
	--end
	if not self.sv.planted and sm.exists( self.harvestable ) then
		local plantableData = sm.item.getPlantable( params.plantableUuid )
		local harvestableUid = plantableData.harvestable and sm.uuid.new( plantableData.harvestable ) or nil
		if harvestableUid then
			if sm.container.beginTransaction() then
				sm.container.spendFromSlot( params.playerInventory, params.slot, params.plantableUuid, 1 )
				if sm.container.endTransaction() then
					self:sv_plant( harvestableUid )
				end
			end
		end
	end
end	

function HarvestableSoil.sv_plant( self, plantedHarvestableUuid )
	if not self.sv.planted and sm.exists( self.harvestable ) then
		local waterTick = nil
		if self.sv.saved.waterTick then
			local ticksSinceWatered = sm.game.getCurrentTick() - self.sv.saved.waterTick
			if ticksSinceWatered < WaterRetentionTickTime then
				waterTick = self.sv.saved.waterTick
			end
		end
		local plantedHarvestable = sm.harvestable.createHarvestable( plantedHarvestableUuid, self.harvestable:getPosition(), self.harvestable:getRotation() )
		plantedHarvestable:setParams( { waterTick = waterTick, fertilizer = self.sv.saved.fertilizer, plantedByPlayer = true } )
		sm.effect.playEffect( "Plants - Planted", self.harvestable:getPosition() )
		self.sv.planted = true
        self:sv_updatePublicData()
		self.harvestable:destroy()
		self.sv.planted = true
		local world = self.harvestable:getWorld()
		if world.publicData and world.publicData.type == "Overworld" then
			RaidManager.Sv_DetectCrop( plantedHarvestable )
		end
	end
end

function HarvestableSoil.sv_e_fertilize( self, params )
	if not self.sv.saved.fertilizer then
		if sm.container.beginTransaction() then
			sm.container.spendFromSlot( params.playerInventory, params.slot, ITEMS.obj_consumable_fertilizer, 1 )
			if sm.container.endTransaction() then
				self.sv.saved.fertilizer = true
				self:sv_saveAndSync()
			end
		end
	end
end

function HarvestableSoil.server_canErase( self ) return true end
function HarvestableSoil.client_canErase( self ) return true end

function HarvestableSoil.server_onRemoved( self, player )
	if not self.harvested and sm.exists( self.harvestable ) then
		local container = player:getInventory()
		if sm.container.beginTransaction() then
			sm.container.collect( container, ITEMS.obj_consumable_soilbag, 1 )
			if sm.container.endTransaction() then
				self.harvestable:destroy()
				self.harvested = true
			else
				self.network:sendToClient( player, "cl_n_onInventoryFull" )
			end
		end
	end
end

function HarvestableSoil.cl_n_onInventoryFull( self )
	NotificationManager.Cl_AddGenericNotification( "#{INFO_INVENTORY_FULL}", 4 )
end


-- Client
function HarvestableSoil.client_onCreate( self )
	self.cl = {}
	self.cl.waterTick = nil
	self.cl.fertilizer = false
	self.cl.createTick = sm.game.getCurrentTick()
	self.harvestable.clientPublicData = {}
	self.harvestable.clientPublicData.fertilizer = false
end

function HarvestableSoil.client_onUpdate( self, dt )
	local soilFrameIndex = 0
	if self.cl.waterTick then
		local serverTick = sm.game.getServerTick()
		local ticksSinceWatered = serverTick - self.cl.waterTick
		if ticksSinceWatered < WaterRetentionTickTime then
			soilFrameIndex = clamp( MaxSoilFrame - math.floor( ticksSinceWatered / WetStepTime ), 1, MaxSoilFrame )
		else
			soilFrameIndex = 0
		end
	end
	self.harvestable:setUvFrameIndex( soilFrameIndex )
end

function HarvestableSoil.client_onClientDataUpdate( self, clientData )
	self.cl.waterTick = clientData.waterTick
	if not self.cl.fertilizer and clientData.fertilizer then
		if sm.game.getCurrentTick() > self.cl.createTick then
			sm.effect.playEffect( "Plants - Fertilizer_impact", self.harvestable:getPosition() )
		end
		sm.effect.playHostedEffect( "Plants - Fertilizer_loop", self.harvestable )
		self.cl.fertilizer = clientData.fertilizer
	end
	self.harvestable.clientPublicData.fertilizer = self.cl.fertilizer
end

function HarvestableSoil.client_canInteract( self )
	local pickUpPromptsEnabled = sm.game.getSettingBoolean( "PickUpPrompts" )
	if pickUpPromptsEnabled and not sm.localPlayer.secondaryInteractBusy() then
		sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Attack", true ), "#{INTERACTION_PICK_UP}" )
	end
	return false
end
