dofile( "$SURVIVAL_DATA/Scripts/game/util/Curve.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/pipes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

---@class Vacuum : ShapeClass
---@field sv table
---@field cl table
Vacuum = class()
Vacuum.poseWeightCount = 1
Vacuum.connectionInput = sm.interactable.connectionType.logic
Vacuum.maxParentCount = 1
Vacuum.maxChildCount = 0
local ProjectileVelocity = 20
Vacuum.colorNormal = sm.color.new( 0xaf6114ff )
Vacuum.colorHighlight = sm.color.new( 0xaf6114ff )

local RapidFireDelay = 8
local SlowFireDelayTicks = 40
local PackingStationFireDelay = 14
local SuctionDelayTicks = 40
local SuctionDelaySeconds = SuctionDelayTicks / 40

local AcceptedStations = {
	ITEMS.obj_packingstation_screen_fruit,
	ITEMS.obj_packingstation_screen_veggie,
	ITEMS.obj_smelter_deposit
}
local StationRaycastDistance = 4

local VacuumMode = { outgoing = 1, incoming = 2 }

local UuidToProjectile = {

	[tostring( ITEMS.obj_consumable_water )] = { uuid = projectile_water },
	[tostring( ITEMS.obj_consumable_fertilizer )] = { uuid = projectile_fertilizer },
	[tostring( ITEMS.obj_consumable_chemical )] = { uuid = projectile_chemical },
	[tostring( ITEMS.obj_resource_crudeoil )] = { uuid = projectile_oil },

	[tostring( ITEMS.obj_plantables_banana )] = { uuid = projectile_banana },
	[tostring( ITEMS.obj_plantables_blueberry )] = { uuid = projectile_blueberry },
	[tostring( ITEMS.obj_plantables_orange )] = { uuid = projectile_orange },
	[tostring( ITEMS.obj_plantables_pineapple )] = { uuid = projectile_pineapple },
	[tostring( ITEMS.obj_plantables_carrot )] = { uuid = projectile_carrot },
	[tostring( ITEMS.obj_plantables_redbeet )] = { uuid = projectile_redbeet },
	[tostring( ITEMS.obj_plantables_tomato )] = { uuid = projectile_tomato },
	[tostring( ITEMS.obj_plantables_broccoli )] = { uuid = projectile_broccoli },
	[tostring( ITEMS.obj_plantables_potato )] = { uuid = projectile_potato },

	[tostring( ITEMS.obj_seed_banana )] = { uuid = projectile_seed, hvs = hvs_growing_banana },
	[tostring( ITEMS.obj_seed_blueberry )] = { uuid = projectile_seed, hvs = hvs_growing_blueberry },
	[tostring( ITEMS.obj_seed_orange )] = { uuid = projectile_seed, hvs = hvs_growing_orange },
	[tostring( ITEMS.obj_seed_pineapple )] = { uuid = projectile_seed, hvs = hvs_growing_pineapple },
	[tostring( ITEMS.obj_seed_carrot )] = { uuid = projectile_seed, hvs = hvs_growing_carrot, growbed = ITEMS.obj_interactive_growbed_carrot_sprout },
	[tostring( ITEMS.obj_seed_potato )] = { uuid = projectile_seed, hvs = hvs_growing_potato, growbed = ITEMS.obj_interactive_growbed_potato_sprout },
	[tostring( ITEMS.obj_seed_redbeet )] = { uuid = projectile_seed, hvs = hvs_growing_redbeet },
	[tostring( ITEMS.obj_seed_tomato )] = { uuid = projectile_seed, hvs = hvs_growing_tomato, growbed = ITEMS.obj_interactive_growbed_tomato_sprout },
	[tostring( ITEMS.obj_seed_broccoli )] = { uuid = projectile_seed, hvs = hvs_growing_broccoli },
	[tostring( ITEMS.obj_seed_cotton )] = { uuid = projectile_seed, hvs = hvs_growing_cotton, growbed = ITEMS.obj_interactive_growbed_cotton_sprout },
	[tostring( ITEMS.obj_seed_pigmentflower )] = { uuid = projectile_seed, hvs = hvs_growing_pigmentflower, growbed = ITEMS.obj_interactive_growbed_pigmentflower_sprout },
	[tostring( ITEMS.obj_seed_chili )] = { uuid = projectile_seed, hvs = hvs_growing_chili },

	[tostring( ITEMS.obj_nugget_t1 )] = { uuid = projectile_T1 },
	[tostring( ITEMS.obj_nugget_t2 )] = { uuid = projectile_T2 },
	[tostring( ITEMS.obj_nugget_t3 )] = { uuid = projectile_T3 },
	[tostring( ITEMS.obj_nugget_t4 )] = { uuid = projectile_T4 },
	[tostring( ITEMS.obj_nugget_t5 )] = { uuid = projectile_T5 },

	[tostring( ITEMS.obj_interactive_propanetank_small )] = { uuid = projectile_smallexplosive }
}

local function IsSeedItem( itemUuid )
    local projectile = UuidToProjectile[tostring( itemUuid )]

    if not projectile then
        return false
    end

    return projectile.uuid == projectile_seed or projectile.uuid == projectile_potato
end

local function IsSoilItem( itemUuid )
    return itemUuid == ITEMS.obj_consumable_fertilizer
        or itemUuid == ITEMS.obj_consumable_water
        or IsSeedItem( itemUuid )
end

function Vacuum.findSoilTarget( self )
    local start = self.shape:getWorldPosition()
    local stop = start - self.shape.at * 4.625

    local valid, result = sm.physics.raycast(
        start,
        stop,
        self.shape
    )

    if not valid or not result then
        return nil
    end

    if result.type == "harvestable" then
        local harvestable = result:getHarvestable()

        if harvestable and sm.exists( harvestable ) then
            if harvestable:getUuid() == hvs_soil then
                return harvestable.publicData
            end
        end
    elseif result.type == "body" then
        local shape = result:getShape()

        if shape and sm.exists( shape ) then
            if shape:getShapeUuid() == ITEMS.obj_interactive_growbed_soil then
                return shape:getInteractable():getPublicData()
            end
        end
    end

    return nil
end

function Vacuum.canFireSoilItem( self, itemUuid )
    if not IsSoilItem( itemUuid ) then
        return true
    end

    local soilData = self:findSoilTarget()

    if not soilData then
        return false
    end

    if itemUuid == ITEMS.obj_consumable_fertilizer then
        return soilData.fertilized ~= true
    end

    if itemUuid == ITEMS.obj_consumable_water then
        return soilData.watered ~= true
    end

    if IsSeedItem( itemUuid ) then
        return soilData.seeded ~= true
    end

    return true
end

local function ValidatePackingStationInteraction( self )
	local publicData = sm.isServerMode() and self.interactable:getPublicData() or self.interactable:getClientPublicData()
	if publicData and publicData.isInsidePackingStationArea then
		local result = self:findPackingStation( StationRaycastDistance )
		if result then
			local areaTrigger = result:getAreaTrigger()
			local packingStation = areaTrigger and areaTrigger:getHostInteractable()
			local packingStationPublicData = packingStation and sm.isServerMode() and packingStation:getPublicData() or packingStation and packingStation:getClientPublicData()
			local inputUuid = packingStationPublicData and packingStationPublicData.inputUuid
			local acceptingState = packingStationPublicData and packingStationPublicData.state == "filling"
			if acceptingState and inputUuid then
				local projectileEntry = UuidToProjectile[tostring( inputUuid )]
				local projectileUuid = projectileEntry and projectileEntry.uuid or inputUuid
				local start = self.shape:getWorldPosition()
				local dir = (result.pointWorld - start):normalize()
				local projectileRadius =  sm.projectile.getProjectileRadius(projectileUuid)
				local obstructed, _ = sm.physics.spherecast( start + dir * projectileRadius, result.pointWorld, projectileRadius, self.shape,nil,nil )
				if obstructed == false then
					if sm.vec3.dot(self.shape.at,packingStation:getShape().up) > 0  then
						return true, inputUuid,packingStationPublicData
					end
				end
			end
		end
	end
	return false,nil,nil
end


function Vacuum.server_onCreate( self )
	self.sv = {}

	-- client table goes to client
	self.sv.client = {}
	self.sv.client.state = PipeState.off
	self.sv.client.showBlockVisualization = false

	-- storage table goes to storage
	self.sv.storage = self.storage:load()
	if self.sv.storage == nil then
		self.sv.storage = { mode = VacuumMode.incoming } -- Default value
		self.storage:save( self.sv.storage )
	end
	if self.sv.storage.autoTaskActive == nil then
		self.sv.storage.autoTaskActive = false
		self.sv.storage.currentAutoUuid = sm.uuid.getNil()
	end

	self.sv.targetUuid = nil
	self.sv.dirtyClientTable = false
	self.sv.dirtyStorageTable = false

	self.sv.previousFireTick = 0
	self.sv.canFire = true
	self.sv.areaTrigger = nil
	self.sv.foundContainer = nil
	self.sv.foundItem = sm.uuid.getNil()
	self.sv.parentActive = false
	self.sv.toggleParentActive = false
	self:sv_updateStates()

	-- public data used to interface with the packing station
	if self.interactable:getPublicData() == nil then
		-- data may be set inside PackerPumpArea.lua - sv_t_onStay.
		-- when loading into the game and a shape is already inside the packing area, we never get a onEnter we get the stay before the onCreate.
		self.interactable:setPublicData( { isInsidePackingStationArea = false } )
	end
end

function Vacuum.sv_markClientTableAsDirty( self )
	self.sv.dirtyClientTable = true
end

function Vacuum.sv_markStorageTableAsDirty( self )
	self.sv.dirtyStorageTable = true
	self:sv_markClientTableAsDirty()
end

function Vacuum.sv_n_toogle( self )
	if self.sv.storage.mode == VacuumMode.outgoing then
		self:server_outgoingReset()
		self.sv.storage.mode = VacuumMode.incoming
	else
		self.sv.storage.mode = VacuumMode.outgoing
	end

	self:sv_updateStates()
	self:sv_markStorageTableAsDirty()
end

function Vacuum.sv_updateStates( self )
	if self.sv.storage.mode == VacuumMode.incoming then
		if not self.sv.areaTrigger then
			local size = sm.vec3.new( 0.5, 0.5, 0.5 )
			local filter = sm.areaTrigger.filter.staticBody + sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.areaTrigger + sm.areaTrigger.filter.harvestable
			self.sv.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.new( 0.0, -1.0, 0.0 ), sm.quat.identity(), filter )
		end
	else
		if self.sv.areaTrigger then
			sm.areaTrigger.destroy( self.sv.areaTrigger )
			self.sv.areaTrigger = nil
		end
	end
end

function Vacuum.constructionRayCast( self )
	local start = self.shape:getWorldPosition()
	local stop = self.shape:getWorldPosition() - self.shape.at * 4.625
	local valid, result = sm.physics.raycast( start, stop, self.shape )
	if valid then
		local groundPointOffset = -(sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005)
		local pointLocal = result.pointLocal
		if result.type ~= "body" and result.type ~= "joint" then
			pointLocal = pointLocal + result.normalLocal * groundPointOffset
		end

		local n = sm.vec3.closestAxis( result.normalLocal )
		local a = pointLocal * sm.construction.constants.subdivisions - n * 0.5
		local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), math.floor( a.z ) ) + n

		local function getTypeData()
			local shapeOffset = sm.vec3.new( sm.construction.constants.subdivideRatio_2, sm.construction.constants.subdivideRatio_2, sm.construction.constants.subdivideRatio_2 )
			local localPos = gridPos * sm.construction.constants.subdivideRatio + shapeOffset
			if result.type == "body" then
				local shape = result:getShape()
				if shape and sm.exists( shape ) then
					return shape:getBody():transformPoint( localPos ), shape
				else
					valid = false
				end
			elseif result.type == "joint" then
				local joint = result:getJoint()
				if joint and sm.exists( joint ) then
					return joint:getShapeA():getBody():transformPoint( localPos ), joint
				else
					valid = false
				end
			elseif result.type == "lift" then
				local lift, topShape = result:getLiftData()
				if lift and (not topShape or lift:hasBodies()) then
					valid = false
				end
				return localPos, lift
			elseif result.type == "character" then
				valid = false
			elseif result.type == "harvestable" then
				valid = false
			end
			return localPos
		end

		local worldPos, obj = getTypeData()
		return valid, gridPos, result.normalLocal, worldPos, obj
	end
	return valid
end

function Vacuum.server_outgoingReload( self, container, item )
	self.sv.foundContainer, self.sv.foundItem = container, item

	local isBlock = sm.item.isBlock( self.sv.foundItem )
	if self.sv.client.showBlockVisualization ~= isBlock then
		self.sv.client.showBlockVisualization = isBlock
		self:sv_markClientTableAsDirty()
	end
	if self.sv.foundContainer then
		self.network:sendToClients( "cl_n_onOutgoingReload", { targetContainer = self.sv.foundContainer, item = self.sv.foundItem,parentActive = self.sv.parentActive } )
	end
end

function Vacuum.server_outgoingReset( self )
	self.sv.canFire = false
	self.sv.foundContainer = nil
	self.sv.foundItem = sm.uuid.getNil()
	self.sv.canFire = false

	if self.sv.client.showBlockVisualization then
		self.sv.client.showBlockVisualization = false
		self:sv_markClientTableAsDirty()
	end
end

function Vacuum.server_outgoingLoaded( self )
	return self.sv.foundContainer and self.sv.foundItem ~= sm.uuid.getNil()
end

function Vacuum.server_outgoingShouldReload( self, item )
	return self.sv.foundItem ~= item
end

function Vacuum.sv_setAutomatedTask( self, uuid, autoTaskRepeat, autoTaskAmount )
	sm.pipeGraph.removeAutomatedTasks( self.shape )
	self.sv.storage.currentAutoUuid = uuid
	self.sv.storage.autoTaskActive = true
	sm.pipeGraph.setAutomatedTask( self.shape, { craftTime = autoTaskRepeat, quantity = autoTaskAmount, itemId = tostring( uuid ) } )
	self:sv_markStorageTableAsDirty()
end

function Vacuum.sv_removeAutomatedTasks( self )
	self.sv.targetUuid = nil
	self.sv.storage.currentAutoUuid = sm.uuid.getNil()
	self.sv.storage.autoTaskActive = false
	sm.pipeGraph.removeAutomatedTasks( self.shape )
	self:sv_markStorageTableAsDirty()
end

function Vacuum.setVacuumState( self, state, containerShape )
	if self.sv.client.state ~= state then
		self.sv.client.state = state
		self.sv.foundContainer = containerShape
		self:sv_markClientTableAsDirty()
	end
	local parent = self.shape:getInteractable():getSingleParent()
	if parent and self.sv.parentActive ~= parent.active then
		self.sv.parentActive = parent.active
		self.sv.foundContainer = containerShape

		self:sv_markClientTableAsDirty()
	else
		if parent == nil and self.sv.parentActive then
			self.sv.parentActive = false
			self:sv_markClientTableAsDirty()
		end
	end
end

function Vacuum.server_onFixedUpdate( self )

	local foundValidContainer = false
	local parent = self.shape:getInteractable():getSingleParent()
	if parent then
		self.sv.toggleParentActive = parent.active and self.sv.parentActive ~= parent.active
	end
	local interfacingWithPackingStation, inputUuid, packingStationPublicData = ValidatePackingStationInteraction( self )
	-- Update fire delay progress
	if not self.sv.canFire then
		local currentTick = sm.game.getCurrentTick()
		local requiredDelay = not self.sv.toggleParentActive and self.sv.parentActive and SlowFireDelayTicks or RapidFireDelay
		if interfacingWithPackingStation then
			requiredDelay = PackingStationFireDelay
		end
		if currentTick - self.sv.previousFireTick >= requiredDelay then
			self.sv.canFire = true
		end
	end

	self.sv.targetUuid = nil
	local inputContainers = sm.pipeGraph.getInputContainers( self.shape )
	if self.sv.storage.mode == VacuumMode.outgoing and #inputContainers > 0 then
		local function findFirstContainerAndItem()
			for _, container in ipairs( sm.pipeGraph.getInputContainers( self.shape ) ) do
				if sm.exists( container ) then
					if not container:getInteractable():getContainer():isEmpty() then
						for slot = 0, container:getInteractable():getContainer():getSize() - 1 do
							local item = container:getInteractable():getContainer():getItem( slot )
							if UuidToProjectile[tostring( item.uuid )] or sm.item.isBlock( item.uuid ) then
								return container, item.uuid
							end
						end
					end
				end
			end
			return nil, sm.uuid.getNil()
		end
		if interfacingWithPackingStation then
				local foundContainerToSpendFrom = sm.pipeGraph.getContainerShapeToSpendFrom( self.shape, inputUuid, 1 )
				if foundContainerToSpendFrom then
					if self:server_outgoingShouldReload(inputUuid) then
						self:server_outgoingReload( foundContainerToSpendFrom, inputUuid )
					end
					self:setVacuumState( PipeState.valid, foundContainerToSpendFrom )
				else
					if self:server_outgoingShouldReload( sm.uuid.getNil() ) then
						self:server_outgoingReset()
					end
					self:setVacuumState( PipeState.connected, inputContainers[1] )
				end
				packingStationPublicData.lastConnectedTick = sm.game.getCurrentTick()
		else
				local container, item = findFirstContainerAndItem()
				self:setVacuumState( PipeState.connected, inputContainers[1] )
				if self:server_outgoingShouldReload( item ) then
					self:server_outgoingReload( container, item )
				end
		end

		local function isValidPlacement()
			if sm.item.isBlock( self.sv.foundItem ) then
				local hit, gridPos, normalLocal, worldPos, obj = self:constructionRayCast()
				if hit then

					local function buildingOnLift()
						if type( obj ) == "Shape" then
							return obj:getBody():isOnLift()
						end
						return false
					end

					local function buildingOnDynamic()
						if type( obj ) == "Shape" then
							return obj:getBody():isDynamic()
						end
						return false
					end

					local function getBuildMask( eIntent )
						local iMask = 0
						if eIntent == "Static" then
							iMask = bit.band(
								bit.bor(
									sm.physics.filter.dynamicBody,
									sm.physics.filter.staticBody,
									sm.physics.filter.joints,
									sm.physics.filter.character,
									sm.physics.filter.portalArea
								),
								bit.bnot( sm.physics.filter.allTerrain )
							)
						elseif eIntent == "Lift" then
							iMask = bit.band(
								bit.bor(
									sm.physics.filter.dynamicBody,
									sm.physics.filter.staticBody,
									sm.physics.filter.joints,
									sm.physics.filter.character
								),
								bit.bnot( sm.physics.filter.allTerrain )
							)
						elseif eIntent == "Dynamic" then
							iMask = bit.bor(
								sm.physics.filter.dynamicBody,
								sm.physics.filter.staticBody,
								sm.physics.filter.joints,
								sm.physics.filter.character
							)
						end
						return iMask
					end

					local filter
					if buildingOnLift() then
						filter = getBuildMask( "Lift" )
					elseif buildingOnDynamic() then
						filter = getBuildMask( "Dynamic" )
					else
						filter = getBuildMask( "Static" )
					end

					return not sm.physics.sphereHasContact( worldPos, 0.125, nil, nil, filter ) and
						sm.construction.validateLocalPosition( self.sv.foundItem, gridPos, normalLocal, obj ), gridPos, worldPos, obj
				end
			end
		end
		local valid, gridPos, worldPos, obj = isValidPlacement()

		if parent then
			if (parent.active or self.sv.toggleParentActive) and self.sv.canFire then
				local projectile = UuidToProjectile[tostring( self.sv.foundItem )]
				if projectile and not interfacingWithPackingStation and isAnyOf( self.sv.foundItem ,{ITEMS.obj_nugget_t1,ITEMS.obj_nugget_t2,ITEMS.obj_nugget_t3,ITEMS.obj_nugget_t4,ITEMS.obj_nugget_t5}) then
					self:setVacuumState( PipeState.invalid )
				end

				local canFireSoilItem =
				not IsSoilItem( self.sv.foundItem )
				or interfacingWithPackingStation
				or self:canFireSoilItem( self.sv.foundItem )

				if projectile and self.sv.foundContainer and canFireSoilItem then
					sm.container.beginTransaction()
					sm.container.spend( self.sv.foundContainer:getInteractable():getContainer(), self.sv.foundItem, 1, true )
					if sm.container.endTransaction() then
						-- If successful spend, fire an projectile
						if projectile.hvs or projectile.growbed then
							sm.projectile.shapeCustomProjectileAttack(
								{ hvs = projectile.hvs, growbed = projectile.growbed, seed = self.sv.foundItem },
								projectile.uuid,
								0,
								sm.vec3.new( 0.0, 0.25, 0.0 ),
								sm.vec3.new( 0, -ProjectileVelocity, 0 ),
								self.shape )
						else
							sm.projectile.shapeFire(
								self.shape,
								projectile.uuid,
								sm.vec3.new( 0.0, 0.25, 0.0 ),
								sm.vec3.new( 0, -ProjectileVelocity, 0 ) )
						end
						self.network:sendToClients( "cl_n_onOutgoingFire" )
					end
					self:server_outgoingReset()
				elseif projectile and self.sv.foundContainer and not canFireSoilItem then
    				self:setVacuumState( PipeState.invalid )
				elseif valid then
					sm.container.beginTransaction()
					sm.container.spend( self.sv.foundContainer:getInteractable():getContainer(), self.sv.foundItem, 1, true )
					if sm.container.endTransaction() then
						local material = sm.item.getMaterialId( self.sv.foundItem )
						sm.construction.buildBlock( self.sv.foundItem, gridPos, obj )
						sm.effect.playEffect( "Vacuumpipe - Build", worldPos, nil, nil, nil, { ["Material"] = material } )
						self.network:sendToClients( "cl_n_onOutgoingFire" )
					end
					self:server_outgoingReset()
				else
					local targetContainer = self.sv.foundContainer
					if targetContainer == nil then
						local connectedContainers = sm.pipeGraph.getInputContainers( self.shape )
						if #connectedContainers > 0 then
							targetContainer = connectedContainers[1]
						end
					end
					self.network:sendToClients( "cl_n_onError", { targetContainer = targetContainer } )
				end
				self.sv.previousFireTick = sm.game.getCurrentTick()
				self.sv.canFire = false
			end
			self.sv.toggleParentActive = parent.active
			if valid == false then
				self:setVacuumState( PipeState.invalid )
			end
		else
			self:setVacuumState( PipeState.connected )
		end
	elseif self.sv.storage.mode == VacuumMode.incoming and #sm.pipeGraph.getOutputContainers( self.shape ) > 0 then
		local incomingObjects = {}
		local areaContent = self.sv.areaTrigger:getContents()

		local autoTaskRepeat = SuctionDelaySeconds
		local autoTaskAmount = 1
		local stopLiquidSuction = false
		for _, result in ipairs( areaContent ) do
			if type( result ) == "Harvestable" and sm.exists( result ) then
				local pubData = result.publicData
				if result:getUuid() == hvs_farmables_growing_oilgeyser then
					stopLiquidSuction = true
				elseif result:getUuid() == hvs_farmables_oilgeyser then
					if pubData and not pubData.harvested then
						local quantity = randomStackAmount( 1, 2, 4 )
						self.sv.targetUuid = ITEMS.obj_resource_crudeoil
						autoTaskRepeat = 30
						autoTaskAmount = 2
						local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { ITEMS.obj_resource_crudeoil }, { quantity } )
						if container then
							table.insert( incomingObjects, { container = container, harvestable = result, uuid = ITEMS.obj_resource_crudeoil, amount = quantity } )
						end
					end
					stopLiquidSuction = true
				elseif result:getUuid() == hvs_farmables_cottonplant then
					if pubData and not pubData.harvested then
						local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { ITEMS.obj_resource_cotton }, { 1 } )
						if container then
							local seedIncomingObj = nil
							local seedAmount = PlantSeedDropAmount( ITEMS.obj_seed_cotton )
							if seedAmount > 0 then
								local seedContainer = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { ITEMS.obj_seed_cotton }, { seedAmount } )
								if seedContainer then
									seedIncomingObj = { container = seedContainer, uuid = ITEMS.obj_seed_cotton, amount = seedAmount }
								end
							end
							table.insert( incomingObjects, { container = container, harvestable = result, uuid = ITEMS.obj_resource_cotton, amount = 1, seedIncomingObj = seedIncomingObj } )
						end
					end
				elseif result:getUuid() == hvs_farmables_pigmentflower then
					if pubData and not pubData.harvested then
						local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { ITEMS.obj_resource_flower }, { 1 } )
						if container then
							local seedIncomingObj = nil
							local seedAmount = PlantSeedDropAmount( ITEMS.obj_seed_pigmentflower )
							if seedAmount > 0 then
								local seedContainer = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { ITEMS.obj_seed_pigmentflower }, { seedAmount } )
								if seedContainer then
									seedIncomingObj = { container = seedContainer, uuid = ITEMS.obj_seed_pigmentflower, amount = seedAmount }
								end
							end
							table.insert( incomingObjects, { container = container, harvestable = result, uuid = ITEMS.obj_resource_flower, amount = 1, seedIncomingObj = seedIncomingObj } )
						end
					end
				elseif pubData and pubData.vacuumable then
					local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { pubData.uuid }, { pubData.quantity } )
					if container then
						table.insert( incomingObjects, { container = container, harvestable = result, uuid = pubData.uuid, amount = pubData.quantity } )
					end
				elseif result:getType() == "mature" then
					local data = result:getData()
					if data then
						local harvestUuid = data["harvest"]
						local amount = data["amount"]
						if harvestUuid and amount then
							harvestUuid = sm.uuid.new( harvestUuid )
							local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { harvestUuid }, { amount } )
							if container then
								-- Collect seeds from harvestable
								local seedUuid = data["seed"]
								local seedIncomingObj = nil
								if seedUuid then
									seedUuid = sm.uuid.new( seedUuid )
									local seedAmount = PlantSeedDropAmount( seedUuid )
									if seedAmount > 0 then
										local seedContainer = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { seedUuid }, { seedAmount } )
										if seedContainer then
											seedIncomingObj = { container = seedContainer, uuid = seedUuid, amount = seedAmount }
										end
									end
								end
								table.insert( incomingObjects, { container = container, harvestable = result, uuid = harvestUuid, amount = amount, seedIncomingObj = seedIncomingObj } )
							end
						end
					end
				end
			end
		end

		if not stopLiquidSuction then
			-- Check for liquids
			for _, result in ipairs( areaContent ) do
				if type( result ) == "AreaTrigger" and sm.exists( result ) then
					local userData = result:getUserData()
					if userData and (userData.water == true or userData.chemical == true or userData.oil == true) then
						local uidLiquidType = ITEMS.obj_consumable_water
						if userData.chemical == true then
							uidLiquidType = ITEMS.obj_consumable_chemical
						elseif userData.oil == true then
							uidLiquidType = ITEMS.obj_resource_crudeoil
						end
						local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { uidLiquidType }, { 1 } )
						if container then
							foundValidContainer = true
							self.sv.targetUuid = uidLiquidType
							local waterZ = result:getWorldMax().z
							local raycastStart = self.shape:getWorldPosition() + self.shape.at
							if raycastStart.z > waterZ then
								local raycastEnd = self.shape:getWorldPosition() - self.shape.at * 4
								local hit, result = sm.physics.raycast( raycastStart, raycastEnd, self.shape:getBody(), sm.physics.filter.static + sm.physics.filter.areaTrigger )
								if hit and result.type == "areaTrigger" then
									table.insert( incomingObjects, { container = container, uuid = uidLiquidType, amount = 1 } )
								end
							else
								table.insert( incomingObjects, { container = container, uuid = uidLiquidType, amount = 1 } )
							end
						end
						break -- stop on first hit
					end
				end
			end
		end

		--if #incomingObjects == 0 and self.sv.storage.autoTaskActive then
		--	local container = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { self.sv.storage.currentAutoUuid }, { 1 } )
		--	table.insert( incomingObjects, { container = container, uuid = self.sv.storage.currentAutoUuid, amount = 1 } )
		--end

		-- If active
		local parent = self.shape:getInteractable():getSingleParent()
		local parentActiveAndCanFire = parent and parent.active and self.sv.canFire
		if parentActiveAndCanFire then
			for _, incomingObject in ipairs( incomingObjects ) do
				if incomingObject.container then
					sm.container.beginTransaction()

					sm.container.collect( incomingObject.container:getInteractable():getContainer(), incomingObject.uuid, incomingObject.amount, true )
					if incomingObject.seedIncomingObj then
						sm.container.collect( incomingObject.seedIncomingObj.container:getInteractable():getContainer(), incomingObject.seedIncomingObj.uuid, incomingObject.seedIncomingObj.amount, true )
					end

					if sm.container.endTransaction() then
						self.network:sendToClients( "cl_n_onIncomingFire", { targetContainer = incomingObject.container, item = incomingObject.uuid } )
						if incomingObject.shape then
							incomingObject.shape:destroyShape()
						end
						if incomingObject.harvestable then
							local pubData = incomingObject.harvestable.publicData
							if pubData then
								pubData.harvested = true
							end

							if incomingObject.harvestable:getType() == "mature" then
								sm.effect.playEffect( "Plants - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_soil, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_pigmentflower then
								sm.effect.playEffect( "Pigmentflower - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_pigmentflower, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_cottonplant then
								sm.effect.playEffect( "Cotton - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_cottonplant, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							elseif incomingObject.harvestable:getUuid() == hvs_farmables_oilgeyser then
								sm.effect.playEffect( "Oilgeyser - Picked", sm.harvestable.getPosition( incomingObject.harvestable ) )
								sm.harvestable.createHarvestable( hvs_farmables_growing_oilgeyser, sm.harvestable.getPosition( incomingObject.harvestable ), sm.harvestable.getRotation( incomingObject.harvestable ) )
							end

							if incomingObject.harvestable:getUuid() ~= hvs_farmables_growing_oilgeyser then
								sm.harvestable.destroy( incomingObject.harvestable )
							end
						end
					end
				else
					local targetContainer = self.sv.foundContainer
					if targetContainer == nil then
						local containers = sm.pipeGraph.getInputContainers( self.shape )
						if #containers > 0 then
							targetContainer = containers[1]
						end
					end
					self.network:sendToClients( "cl_n_onError", { targetContainer = targetContainer } )
				end
			end

			if #incomingObjects == 0 then
				local targetContainer = self.sv.foundContainer
				if targetContainer == nil then
					local containers = sm.pipeGraph.getInputContainers( self.shape )
					if #containers > 0 then
						targetContainer = containers[1]
					end
				end
			end

			self.sv.canFire = false
			self.sv.previousFireTick = sm.game.getCurrentTick()

			if self.sv.targetUuid ~= nil and self.sv.targetUuid ~= self.sv.storage.currentAutoUuid and not self.shape.body:isDynamic() and self.sv.storage.autoTaskActive == false then
				self:sv_setAutomatedTask( self.sv.targetUuid, autoTaskRepeat, autoTaskAmount )
			end
		elseif (not parent or (parent and not parent.active)) and self.sv.storage.autoTaskActive then
			self:sv_removeAutomatedTasks()
		end
		local active = parent and parent.active
		-- Synch visual feedback

		if #incomingObjects > 0 and active and foundValidContainer then
			-- Highlight the path furthest container or target container
			local containers = sm.pipeGraph.getInputContainers( self.shape )
			local targetContainer = sm.pipeGraph.getContainerShapeToCollectTo( self.shape, { incomingObjects[1].uuid }, { incomingObjects[1].amount } )
			if targetContainer == nil then
				if #containers > 0 then
					targetContainer = containers[#containers]
				end
			end
			if targetContainer then
				local container = targetContainer:getInteractable():getContainer( 0 )
				if container:canCollect( incomingObjects[1].uuid, 1 ) then
					self:setVacuumState( PipeState.valid, targetContainer )
				else
					self:setVacuumState( PipeState.invalid, targetContainer )
				end
			end
		else
			local containers = sm.pipeGraph.getInputContainers( self.shape )
			local containersFull = true
			for _, shape in ipairs( containers ) do
				local container = shape:getInteractable():getContainer()
				if not container:isFull() then
					containersFull = false
					break
				end
			end
			if containersFull and active then
				self:setVacuumState( PipeState.invalid )
			else
				self:setVacuumState( PipeState.connected )
			end
		end
	elseif self.sv.client.state ~= PipeState.off then
		self:setVacuumState( PipeState.off )
	end

	-- Storage table dirty
	if self.sv.dirtyStorageTable then
		self.storage:save( self.sv.storage )
		self.sv.dirtyStorageTable = false
	end

	-- Client table dirty
	if self.sv.dirtyClientTable then
		local targetContainer = self.sv.foundContainer
		if targetContainer == nil then
			local containers = sm.pipeGraph.getInputContainers( self.shape )
			if #containers > 0 then
				targetContainer = containers[1]
			end
		end
		self.network:setClientData( { targetContainer = targetContainer, mode = self.sv.storage.mode, state = self.sv.client.state, showBlockVisualization = self.sv.client.showBlockVisualization } )
		self.sv.dirtyClientTable = false
	end
end

function Vacuum.findPackingStation(self,distance)
	local start = self.shape:getWorldPosition()
	local stop = start - self.shape.at * distance
	local valid, result = sm.physics.raycast( start, stop, self.shape:getBody(), sm.physics.filter.areaTrigger )
	if not valid then
		return false
	end
	if result.type ~= "areaTrigger" then
		return false
	end

	local areaTrigger = result:getAreaTrigger()
	if not sm.exists( areaTrigger ) then
		return false
	end
	if not sm.exists(areaTrigger:getHostInteractable()) then 
		return false
	end

	local shape = areaTrigger:getHostInteractable():getShape()
	if isAnyOf( shape:getShapeUuid(), AcceptedStations ) then
		return result
	end
	return nil,nil
end

-- Client
function Vacuum.client_onCreate( self )
	self.cl = {}

	-- Update from onClientDataUpdate
	self.cl.mode = VacuumMode.outgoing
	self.cl.state = PipeState.off
	self.cl.showBlockVisualization = false

	self.cl.overrideUvFrameIndexTask = nil
	self.cl.poseAnimTask = nil
	self.cl.vacuumEffect = nil

	self.cl.previousPipeState = PipeState.off
	self.cl.previousPipeGlow = 1.0
	self.cl.overrideState = PipeState.off
	self.cl.targetContainer = nil
	self.cl.previousTargetContainer = nil

	self.cl.pipeEffectPlayer = PipeEffectPlayer()
	self.cl.pipeEffectPlayer:onCreate()
	if self.shape:getInteractable():getClientPublicData() == nil then
		-- data may be set inside PackerPumpArea.lua - cl_t_onStay.
		-- when loading into the game and a shape is already inside the packing area, we never get a onEnter we get the stay before the onCreate.
		self.shape:getInteractable():setClientPublicData( { isInsidePackingStationArea = false } )
	end
end

function Vacuum.client_onClientDataUpdate( self, clientData )
	assert( clientData.mode )
	assert( clientData.state )
	self.cl.mode = clientData.mode
	self.cl.state = clientData.state
	self.cl.targetContainer = clientData.targetContainer
	self.cl.showBlockVisualization = clientData.showBlockVisualization
end

function Vacuum.client_onInteract( self, character, state )
	if state == true then
		self.network:sendToServer( "sv_n_toogle" )
	end
end

function Vacuum.client_onUpdate( self, dt )
	-- Update pose anims
	self:cl_updatePoseAnims( dt )

	-- Update Uv Index frames
	self:cl_updateUvIndexFrames( dt )

	-- Update effects through pipes
	self.cl.pipeEffectPlayer:update( dt )

	-- Visualize block if a block is loaded
	if self.cl.state == PipeState.connected and self.cl.showBlockVisualization then
		local valid, gridPos, localNormal, worldPos, obj = self:constructionRayCast()
		if valid then
			local function countTerrain()
				if type( obj ) == "Shape" then
					return obj:getBody():isDynamic()
				end
				return false
			end
			local legalPosition = sm.physics.sphereHasContact( worldPos, sm.construction.constants.subdivideRatio_2, countTerrain() ) or not sm.construction.validateLocalPosition( blk_cardboard, gridPos, localNormal, obj )
			sm.visualization.setBlockVisualization( gridPos, legalPosition, obj )
		end
	end
end

function Vacuum.client_onFixedUpdate( self )
	if self.cl.mode and self.cl.mode ~= VacuumMode.outgoing then
		return
	end

	local interfacingWithPackingStation, inputUuid, packingStationPublicData = ValidatePackingStationInteraction( self )
	if  interfacingWithPackingStation then
		local containerToSpendForm = sm.pipeGraph.getContainerShapeToSpendFrom( self.shape, inputUuid , 1 )
		packingStationPublicData.connectionType = containerToSpendForm and "approved" or "connected"
		packingStationPublicData.lastConnectedTick = sm.game.getCurrentTick()
	end
end

-- Events
function Vacuum.cl_n_onOutgoingReload( self, data )
	local path = sm.pipeGraph.getContainerPath( self.shape, data.targetContainer )
	local reversed = {}

	for _, shape in reverse_ipairs( path ) do
		table.insert( reversed, shape )
	end
	table.insert( reversed, #reversed + 1, self.shape )

	self.cl.pipeEffectPlayer:pushShapeEffectTask( reversed, data.item, nil, DURATION_PER_PIPE )
	self.cl.targetContainer = data.targetContainer
	if data.parentActive then
		self.cl.overrideState = PipeState.valid
		self.cl.overrideUvFrameIndexTask = { state = PipeState.valid, progress = 0 }
	else
		self.cl.overrideState = PipeState.connected
		self.cl.overrideUvFrameIndexTask = { state = PipeState.connected, progress = 0 }
	end
end

function Vacuum.cl_n_onOutgoingFire( self )
	self.cl.overrideState = PipeState.valid
	self.cl.overrideUvFrameIndexTask = { state = PipeState.valid, progress = 0 }
	self:cl_setPoseAnimTask( "outgoingFire" )

	self.cl.vacuumEffect = sm.effect.createEffect( "Vacuumpipe - Blowout", self.interactable )
	self.cl.vacuumEffect:setOffsetRotation( sm.quat.rotX90() )
	self.cl.vacuumEffect:setOffsetPosition( sm.vec3.new( 0, -0.4, 0 ) )
	self.cl.vacuumEffect:start()
end

function Vacuum.cl_n_onIncomingFire( self, data )
	local path = sm.pipeGraph.getContainerPath( self.shape, data.targetContainer )
	table.insert( path, 1, self.shape )

	self.cl.pipeEffectPlayer:pushShapeEffectTask( path, data.item )
	self.cl.targetContainer = data.targetContainer
	self.cl.overrideState = PipeState.valid
	self.cl.overrideUvFrameIndexTask = { state = PipeState.valid, progress = 0 }
	self:cl_setPoseAnimTask( "incomingFire" )

	self.cl.vacuumEffect = sm.effect.createEffect( "Vacuumpipe - Suction", self.interactable )
		self.cl.vacuumEffect:setOffsetRotation( sm.quat.rotX90() )
	self.cl.vacuumEffect:setOffsetPosition( sm.vec3.new( 0, -0.4, 0 ) )
	self.cl.vacuumEffect:start()
end

function Vacuum.cl_n_onError( self, data )
	self.cl.targetContainer = data.targetContainer
	self.cl.overrideState = PipeState.invalid
	self.cl.overrideUvFrameIndexTask = { state = PipeState.invalid, progress = 0 }
end

-- State sets

function Vacuum.cl_setPoseAnimTask( self, name )
	self.cl.poseAnimTask = { name = name, progress = 0 }
end

-- Updates

PoseCurves = {}
PoseCurves["outgoingFire"] = Curve()
PoseCurves["outgoingFire"]:init( { { v = 0.5, t = 0.0 }, { v = 1.0, t = 0.1 }, { v = 0.5, t = 0.2 }, { v = 0.0, t = 0.3 }, { v = 0.5, t = 0.6 } } )

PoseCurves["incomingFire"] = Curve()
PoseCurves["incomingFire"]:init( { { v = 0.5, t = 0.0 }, { v = 0.0, t = 0.1 }, { v = 0.5, t = 0.2 }, { v = 1.0, t = 0.3 }, { v = 0.5, t = 0.6 } } )

function Vacuum.cl_updatePoseAnims( self, dt )
	if self.cl.poseAnimTask then
		self.cl.poseAnimTask.progress = self.cl.poseAnimTask.progress + dt

		local curve = PoseCurves[self.cl.poseAnimTask.name]
		if curve then
			self.shape:getInteractable():setPoseWeight( 0, curve:getValue( self.cl.poseAnimTask.progress ) )

			if self.cl.poseAnimTask.progress > curve:duration() then
				self.cl.poseAnimTask = nil
			end
		else
			self.cl.poseAnimTask = nil
		end
	end
end

local GlowCurve = Curve()
GlowCurve:init( { { v = 1.0, t = 0.0 }, { v = 0.5, t = 0.05 }, { v = 0.0, t = 0.1 }, { v = 0.5, t = 0.3 }, { v = 1.0, t = 0.4 }, { v = 0.5, t = 0.5 }, { v = 0.0, t = 0.7 }, { v = 0.5, t = 0.75 }, { v = 1.0, t = 1.1 } } )

function Vacuum.cl_updateUvIndexFrames( self, dt )
	local glowMultiplier = 1.0

	-- Events allow for overriding the uv index frames, time it out
	if self.cl.overrideUvFrameIndexTask then
		self.cl.overrideUvFrameIndexTask.progress = self.cl.overrideUvFrameIndexTask.progress + dt
		glowMultiplier = GlowCurve:getValue( self.cl.overrideUvFrameIndexTask.progress )
		if self.cl.overrideUvFrameIndexTask.progress > GlowCurve:duration() then
			self.cl.overrideUvFrameIndexTask.progress = 0
			self.cl.overrideUvFrameIndexTask = nil
		end
	end

	-- Light up vacuum
	local state = self.cl.state
	if self.cl.overrideUvFrameIndexTask then
		state = self.cl.overrideUvFrameIndexTask.state
	end

	VacuumFrameIndexTable = {
		[VacuumMode.outgoing] = {
			[PipeState.off] = 0,
			[PipeState.invalid] = 1,
			[PipeState.connected] = 3,
			[PipeState.valid] = 5
		},
		[VacuumMode.incoming] = {
			[PipeState.off] = 0,
			[PipeState.invalid] = 2,
			[PipeState.connected] = 4,
			[PipeState.valid] = 6
		}
	}
	assert( self.cl.mode > 0 and self.cl.mode <= 2 )
	assert( state > 0 and state <= 4 )

	local vacuumFrameIndex = VacuumFrameIndexTable[self.cl.mode][state]
	self.interactable:setUvFrameIndex( vacuumFrameIndex )
	if self.cl.overrideUvFrameIndexTask then
		self.interactable:setGlowMultiplier( glowMultiplier )
	else
		self.interactable:setGlowMultiplier( 1.0 )
	end

	if self.cl.targetContainer and sm.exists( self.cl.targetContainer ) then
		if self.cl.previousPipeState ~= state or self.cl.previousPipeGlow ~= glowMultiplier then
			self.cl.previousPipeState = state
			self.cl.previousPipeGlow = glowMultiplier
			self.interactable.clientPublicData.lightingOverride = { state = state, glow = glowMultiplier }
			if self.cl.previousTargetContainer == nil then
				self.cl.previousTargetContainer = self.cl.targetContainer
			end
			local validShape = self.shape and sm.exists( self.shape )
			if not sm.exists( self.cl.previousTargetContainer ) or self.cl.previousTargetContainer ~= self.cl.targetContainer then
				self.cl.previousTargetContainer = self.cl.targetContainer
				if validShape then
					sm.pipeGraph.releaseLightingOverride( self.shape )
				end
			end
			if self.cl.targetContainer and validShape then
				sm.pipeGraph.requestLightingOverride( self.shape, self.cl.targetContainer, state - 1, glowMultiplier )
			end
		end
	end
end

function Vacuum.client_onDestroy( self )
	if self.cl.pipeEffectPlayer then
		self.cl.pipeEffectPlayer:onDestroy()
	end
end
