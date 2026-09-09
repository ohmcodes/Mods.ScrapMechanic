dofile( "$SURVIVAL_DATA/Scripts/game/managers/FireManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_spawns.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestEntityManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/LogEntryManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/ElevatorManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$GAME_DATA/Scripts/game/managers/TileStorageManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/RaidManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/AttachedFireManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/CablebotManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/MinerbotWaypointManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_sob.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/MiningManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/AreaReactionManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_explosions.lua" )

---@class BaseWorld : WorldClass
---@field sv table
---@field cl table
---@field fireManager FireManager
---@field waterManager WaterManager
BaseWorld = class( nil )

local TrashSprayResetTime = 20

local ProjectileToNugget = {
	[tostring(projectile_T1)] = ITEMS.obj_nugget_t1,
	[tostring(projectile_T2)] = ITEMS.obj_nugget_t2,
	[tostring(projectile_T3)] = ITEMS.obj_nugget_t3,
	[tostring(projectile_T4)] = ITEMS.obj_nugget_t4,
	[tostring(projectile_T5)] = ITEMS.obj_nugget_t5
}

function BaseWorld.server_onCreate( self )
	self.sv = {}

	self.sv.rayProjectileManager = sm.scriptableObject.createScriptableObject( sm.uuid.new( "8504131e-8f58-4d25-beab-3bc996b7a95e" ), nil, self.world )

	self.fireManager = FireManager()
	self.fireManager:sv_onCreate( self )

	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate()
	self.basicDropChance = {}
	self.depositDropChance = {}
	self.harvestableDropChance = {}
	sm.fire.setFireLimit( FIRE_INSTANCE_LIMIT )

	self.world.publicData = {
		voxelMaterialSetName = "Overworld",
		chunkBoundsMin = sm.vec3.new( self.cellMinX * 4, self.cellMinY * 4, -16 ),
		chunkBoundsMax = sm.vec3.new( ( self.cellMaxX + 1 ) * 4, ( self.cellMaxY + 1 ) * 4, 16 )
 	}
end

function BaseWorld.server_onDestroy( self )
	GlowstickManager.Sv_WorldUnloaded( self.world )
	print( "World", self.world.id, "destroyed" )
end

function BaseWorld.client_onCreate( self )
	self.cl = {}

	self.world.clientPublicData = {
		voxelMaterialSetName = "Overworld",
		musicParameter = 0
	}

	if self.fireManager == nil then
		assert( not sm.isHost )
		self.fireManager = FireManager()
	end
	self.fireManager:cl_onCreate( self )

	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end

	self.waterManager:cl_onCreate()
end

function BaseWorld.server_onFixedUpdate( self )
	self.fireManager:sv_onFixedUpdate()
	self.waterManager:sv_onFixedUpdate()
	AttachedFireManager.Sv_OnWorldFixedUpdate( self.world )
	g_tileStorageManager:sv_onFixedUpdate(self.world)
	CablebotManager.Sv_OnWorldFixedUpdate( self.world )
end

function BaseWorld.client_onFixedUpdate( self )
	self.waterManager:cl_onFixedUpdate()
	AttachedFireManager.Cl_OnWorldFixedUpdate( self.world )
	CablebotManager.Cl_OnWorldFixedUpdate( self.world )

	if self.cl.trashSprayEffect then
		local tick = sm.game.getCurrentTick()
		if not self.cl.trashSprayLastTick or tick > self.cl.trashSprayLastTick + TrashSprayResetTime then
			self.cl.trashSprayEffect:stop()
			self.cl.trashSprayLastTick = nil
		end
	end
end

function BaseWorld.client_onUpdate( self, dt )
end

function BaseWorld.sv_n_fireMsg( self, msg, player )
	self.fireManager:sv_handleMsg( msg, player )
end

function BaseWorld.cl_n_fireMsg( self, msg )
	self.fireManager:cl_handleMsg( msg )
end







function BaseWorld.sv_e_spawnUnit( self, params )
	for i = 1, params.amount do
		sm.unit.createUnit( params.uuid, params.position, params.yaw, params.customParams )
	end
end

function BaseWorld.sv_e_activateFire( self, name )
	self.fireManager:sv_activateInactiveFire( name )
end

function BaseWorld.sv_e_activateFires( self, fireList )
	for _, name in ipairs( fireList ) do
		self.fireManager:sv_activateInactiveFire( name )
	end
end

function BaseWorld.sv_e_removeFiresInCell( self, cell )
	self.fireManager:sv_removeAllFiresInCell( cell.x, cell.y )
end








function BaseWorld.sv_spawnHarvestable( self, params )
	local harvestable = sm.harvestable.createHarvestable( params.uuid, params.position, params.quat )
	if params.harvestableParams then
		harvestable:setParams( params.harvestableParams )
	end
end

function BaseWorld.server_onTerrainCreated( self )
	QuestEntityManager.Sv_OnTerrainLoaded( self.world )
	UndergroundElevatorManager.Sv_OnTerrainLoaded( self.world )
	LogEntryManager.Sv_RefreshLocations()
	DialogManager.Sv_RefreshBondBuilderExclusionTiles()
	GlowstickManager.Sv_WorldReady( self.world )
end

function BaseWorld.server_onTerrainLoaded( self )
	QuestEntityManager.Sv_OnTerrainLoaded( self.world )
	UndergroundElevatorManager.Sv_OnTerrainLoaded( self.world )
	LogEntryManager.Sv_RefreshLocations()
	GlowstickManager.Sv_WorldReady( self.world )
end

function BaseWorld.server_onCellCreated( self, x, y )
	local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, tags = tags, isStartArea = valueExists( tags, "STARTAREA" ), isPoi = valueExists( tags, "POI" ) }

	AttachedLootManager.Sv_OnCellLoaded( x,y )
	ElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	UndergroundElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	MinidungeonElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	QuestEntityManager.Sv_OnWorldCellLoaded( self.world, x, y )
	NodeSpawnManager.Sv_OnCellCreated( x, y, self.world )
	NodeScriptableManager.Sv_OnCellCreated( x, y, self.world )
	PatrolManager.Sv_OnCellLoaded( x, y, self.world )
	MinerbotWaypointManager.Sv_OnCellLoaded( x, y, self.world )
	EffectManager.Sv_OnCellLoaded( self.world, x, y )
	RespawnManager.Sv_OnCellLoaded( x, y, self.world )
	ExplosionTriggerManager.Sv_OnCellLoaded( x, y, self.world )
	KinematicManager.Sv_OnCellCreated( self.world, x, y )
	AreaReactionManager.Sv_OnCellLoaded( self.world, x, y )
	TileStorageManager.Sv_OnCellLoaded( self.world, x, y) 

	RespawningInteractableOnCellCreated( cell, ITEMS.obj_survivalobject_ruinchest )
	RespawningInteractableOnCellCreated( cell, ITEMS.obj_survivalobject_farmerball )

	SpawnFromNodeOnCellCreated( cell, "LOOTCRATE" )
	SpawnFromNodeOnCellCreated( cell, "EPICLOOTCRATE" )
	SpawnFromNodeOnCellCreated( cell, "LEGENDARYLOOTCRATE" )

	SpawnFromNodeOnCellCreated( cell, "HAYBOT" )
	SpawnFromNodeOnCellCreated( cell, "TOTEBOT_GREEN" )
	SpawnFromNodeOnCellCreated( cell, "TOTEBOT_LEAF" )
	SpawnFromNodeOnCellCreated( cell, "TOTEBOT_BLUE" )
	SpawnFromNodeOnCellCreated( cell, "TOTEBOT_RED" )
	SpawnFromNodeOnCellCreated( cell, "TOTEBOT_YELLOW" )
	SpawnFromNodeOnCellCreated( cell, "SEEDBOT" )
	SpawnFromNodeOnCellCreated( cell, "WOC" )
	SpawnFromNodeOnCellCreated( cell, "GLOWGORP" )
	SpawnFromNodeOnCellCreated( cell, "TAPEBOT_GREEN" )
	SpawnFromNodeOnCellCreated( cell, "TAPEBOT_YELLOW" )
	SpawnFromNodeOnCellCreated( cell, "TAPEBOT_RED" )
	SpawnFromNodeOnCellCreated( cell, "MINERBOT" )
	SpawnFromNodeOnCellCreated( cell, "CABLEBOT" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_SCRAPPER" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_FARMER" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_TOTEBOT" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_GLOWGORP" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_WOC" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_FARMERSLEEPY" )
	SpawnFromNodeOnCellCreated( cell, "BUILDERGUIDE_FARMERKO" )
	SpawnFromNodeOnCellCreated( cell, "CINEMATIC_DRILLBOT" )

	if self.world.publicData.type ~= "WarehouseWorld" then
		SpawnFromNodeOnCellCreated( cell, "TAPEBOT" )
	end
	if self.world.publicData.type ~= "Overworld" or x > -8 or y > -8 or valueExists( tags, "SCRAPYARD" ) then
		SpawnFromNodeOnCellCreated( cell, "FARMBOT" )
	end

	self.fireManager:sv_onCellLoaded( x, y )
	self.waterManager:sv_onCellLoaded( x, y )

	-- Randomize stacks
	local stackedList = sm.cell.getInteractablesByAnyUuid( x, y, {
		ITEMS.obj_consumable_gas, ITEMS.obj_consumable_battery,
		ITEMS.obj_consumable_fertilizer, ITEMS.obj_consumable_chemical,
		ITEMS.obj_consumable_inkammo,
		ITEMS.obj_plantables_potato,
		ITEMS.obj_seed_banana, ITEMS.obj_seed_blueberry, ITEMS.obj_seed_orange, ITEMS.obj_seed_pineapple,
		ITEMS.obj_seed_carrot, ITEMS.obj_seed_redbeet, ITEMS.obj_seed_tomato, ITEMS.obj_seed_broccoli,
		ITEMS.obj_seed_potato, ITEMS.obj_seed_corn
	} )
	local stackFn = {
		[tostring( ITEMS.obj_consumable_fertilizer )] = randomStackAmountAvg10,
		[tostring( ITEMS.obj_consumable_inkammo )] = function() return randomStackAmount( 40, 50, 60 ) end,
		[tostring( ITEMS.obj_plantables_potato )] = randomStackAmount20,
		[tostring( ITEMS.obj_consumable_chemical )] = randomStackAmountAvg5,
	}
	for _,stacked in ipairs( stackedList ) do
		local fn = stackFn[tostring( stacked.shape.uuid )]
		if fn then
			stacked.shape.stackedAmount = fn()
		else
			stacked.shape.stackedAmount = randomStackAmount5()
		end
	end
end

function BaseWorld.client_onCellLoaded( self, x, y )
	self.fireManager:cl_onCellLoaded( x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	AmbienceManager.Cl_OnCellLoaded( self.world, x, y )
	EffectManager.Cl_AlertOnWorldLoadCell( self.world, x, y )
	UndergroundElevatorManager.Cl_OnCellLoaded( self.world, x, y )
	QuestEntityManager.Cl_OnWorldCellLoaded( self.world, x, y )
	RenderSettingsManager.Cl_onCellLoaded( x, y )
	GlowstickManager.Cl_WorldReady( self.world )
end

function BaseWorld.server_onCellLoaded( self, x, y )
	local tags = sm.cell.getTags( x, y )
	local cell = { x = x, y = y, worldId = self.world.id, isStartArea = valueExists( tags, "STARTAREA" ), isPoi = valueExists( tags, "POI" ) }
	
	AttachedLootManager.Sv_OnCellLoaded( x,y )
	ElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	UndergroundElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	MinidungeonElevatorManager.Sv_OnCellLoaded( self.world, x, y )
	QuestEntityManager.Sv_OnWorldCellLoaded( self.world, x, y )
	NodeSpawnManager.Sv_OnCellLoaded( x, y, self.world )
	PatrolManager.Sv_OnCellLoaded( x, y, self.world )
	MinerbotWaypointManager.Sv_OnCellLoaded( x, y, self.world )
	EffectManager.Sv_OnCellLoaded( self.world, x, y )
	RespawnManager.Sv_OnCellLoaded( x, y, self.world )
	ExplosionTriggerManager.Sv_OnCellLoaded( x, y, self.world )
	AreaReactionManager.Sv_OnCellLoaded( self.world, x, y )
	TileStorageManager.Sv_OnCellLoaded( self.world, x, y) 

	self.fireManager:sv_onCellReloaded( x, y )
	self.waterManager:sv_onCellReloaded( x, y )

	if not cell.isStartArea then
		TryRespawnInteractableOnCellLoaded( cell, obj_survivalobject_ruinchest )
		TryRespawnInteractableOnCellLoaded( cell, obj_survivalobject_farmerball )

		RespawnFromNodeOnCellLoaded( cell, "LOOTCRATE")
		RespawnFromNodeOnCellLoaded( cell, "EPICLOOTCRATE" )
		RespawnFromNodeOnCellLoaded( cell, "LEGENDARYLOOTCRATE" )

		RespawnFromNodeOnCellLoaded( cell, "HAYBOT" )
		RespawnFromNodeOnCellLoaded( cell, "TOTEBOT_LEAF" )
		RespawnFromNodeOnCellLoaded( cell, "TOTEBOT_BLUE" )
		RespawnFromNodeOnCellLoaded( cell, "TOTEBOT_RED" )
		RespawnFromNodeOnCellLoaded( cell, "TOTEBOT_YELLOW" )
		RespawnFromNodeOnCellLoaded( cell, "SEEDBOT" )
		RespawnFromNodeOnCellLoaded( cell, "WOC" )
		RespawnFromNodeOnCellLoaded( cell, "GLOWGORP" )
		RespawnFromNodeOnCellLoaded( cell, "TAPEBOT_GREEN" )
		RespawnFromNodeOnCellLoaded( cell, "TAPEBOT_YELLOW" )
		RespawnFromNodeOnCellLoaded( cell, "TAPEBOT_RED" )
		RespawnFromNodeOnCellLoaded( cell, "MINERBOT" )
		RespawnFromNodeOnCellLoaded( cell, "CABLEBOT" )

		if self.world.publicData.type ~= "WarehouseWorld" then
			RespawnFromNodeOnCellLoaded( cell, "TOTEBOT_GREEN" )
			RespawnFromNodeOnCellLoaded( cell, "TAPEBOT" )
		end
		if self.world.publicData.type ~= "Overworld" or x > -8 or y > -8 or valueExists( tags, "SCRAPYARD" ) then
			RespawnFromNodeOnCellLoaded( cell, "FARMBOT" )
		end
	end
end

function BaseWorld.server_onCellUnloaded( self, x, y )
	ElevatorManager.Sv_OnCellUnloaded( self.world, x, y )
	UndergroundElevatorManager.Sv_OnCellUnloaded( self.world, x, y )
	MinidungeonElevatorManager.Sv_OnCellUnloaded( self.world, x, y )
	QuestEntityManager.Sv_OnWorldCellUnloaded( self.world, x, y )
	NodeSpawnManager.Sv_OnCellUnloaded( x, y, self.world )
	self.fireManager:sv_onCellUnloaded( x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
	MinerbotWaypointManager.Sv_OnCellUnloaded( x, y, self.world )
	RespawnManager.Sv_OnCellUnloaded( x, y, self.world )
	ExplosionTriggerManager.Sv_OnCellUnloaded( x, y, self.world )
	AreaReactionManager.Sv_OnCellUnloaded( self.world, x, y )
	PatrolManager.Sv_OnCellUnloaded( x, y, self.world )
	TileStorageManager.Sv_OnCellUnLoaded( self.world, x, y )
end

function BaseWorld.client_onCellUnloaded( self, x, y )
	AmbienceManager.Cl_OnCellUnloaded( self.world, x, y )
	EffectManager.Cl_AlertOnWorldUnloadCell( self.world, x, y )
	QuestEntityManager.Cl_OnWorldCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
	RenderSettingsManager.Cl_onCellUnloaded( x, y )
end

-- Beacons
function BaseWorld.sv_e_createBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_createBeacon", params )
	else
		self.network:sendToClients( "cl_n_createBeacon", params )
	end
end

function BaseWorld.cl_n_createBeacon( self, params )
	g_beaconManager:cl_createBeacon( params )
end

function BaseWorld.sv_e_destroyBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_destroyBeacon", params )
	else
		self.network:sendToClients( "cl_n_destroyBeacon", params )
	end
end

function BaseWorld.cl_n_destroyBeacon( self, params )
	g_beaconManager:cl_destroyBeacon( params )
end

function BaseWorld.sv_e_unloadBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_unloadBeacon", params )
	else
		self.network:sendToClients( "cl_n_unloadBeacon", params )
	end
end

function BaseWorld.cl_n_unloadBeacon( self, params )
	g_beaconManager:cl_unloadBeacon( params )
end

function BaseWorld.server_onProjectileFire( self, firePos, fireVelocity, _, attacker, projectileUuid )
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		sm.message.send( MESSAGE_TYPES.GENERAL.ProjectileFire, { world = self.world, position = firePos, attacker = attacker } )
	end
end

function BaseWorld.server_onInteractableCreated( self, interactable )
	g_unitManager:sv_onInteractableCreated( interactable )
	QuestEntityManager.Sv_OnInteractableCreated( interactable )
	QuestPinManager.Sv_InteractableCreated( interactable )
end

function BaseWorld.server_onInteractableDestroyed( self, interactable )
	g_unitManager:sv_onInteractableDestroyed( interactable )
	QuestEntityManager.Sv_OnInteractableDestroyed( interactable )
	if g_questPinManagerServer then
		QuestPinManager.Sv_InteractableDestroyed( interactable )
	end
end

local WaterSplashableSet = {
	[tostring( hvs_soil )] = true,
	[tostring( hvs_growing_blueberry )] = true,
	[tostring( hvs_growing_banana )] = true,
	[tostring( hvs_growing_redbeet )] = true,
	[tostring( hvs_growing_carrot )] = true,
	[tostring( hvs_growing_tomato )] = true,
	[tostring( hvs_growing_orange )] = true,
	[tostring( hvs_growing_potato )] = true,
	[tostring( hvs_growing_pineapple )] = true,
	[tostring( hvs_growing_broccoli )] = true,
	[tostring( hvs_growing_cotton )] = true,
	[tostring( hvs_growing_chili )] = true,
	[tostring( hvs_growing_pigmentflower )] = true,
}

local NuggetProjectiles = {
	projectile_T1,
	projectile_T2,
	projectile_T3,
	projectile_T4,
	projectile_T5
}

function BaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	-- Spawn loot from projectiles with loot user data
	if userData then
		if userData.lootUid and userData.limitedLoot then
			local normal = -hitVelocity:normalize()
			local zSignOffset = math.min( sign( normal.z ), 0 ) * 0.5
			local offset = sm.vec3.new( 0, 0, zSignOffset )
			local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot_limited, hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
			lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic, limitedLoot = userData.limitedLoot } )
		elseif userData.lootUid then
			local normal = -hitVelocity:normalize()
			local zSignOffset = math.min( sign( normal.z ), 0 ) * 0.5
			local offset = sm.vec3.new( 0, 0, zSignOffset )

			if sm.exists( target ) and type( target ) == "Harvestable" and target:isKinematic() then
				AttachedLootManager.Sv_CreateAttachedLoot( { pos = hitPos, normal = hitNormal, target = target, uid = userData.lootUid, qty = userData.lootQuantity } )
			else
				if userData.questItem then
					local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot_bigger, hitPos + hitNormal * 0.5, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
					lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic, questItem = userData.questItem  } )
				else
					local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot, hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
					lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity, epic = userData.epic  } )
				end
			end
		elseif userData.logUuid then
			local normal = -hitVelocity:normalize()
			local logHarvestable = sm.harvestable.createHarvestable( hvs_loot_logbook_entry, hitPos + normal * 0.5, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
            logHarvestable:setParams(  userData )
		end
	end

	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		-- Notify units about projectile hit
		sm.message.send( MESSAGE_TYPES.GENERAL.ProjectileHit, { world = self.world, position = hitPos, attacker = attacker } )
	elseif projectileUuid == projectile_clay then
		local clayMaterial = 0
		self.world:voxelDensityAddition( hitPos, hitNormal, 2.5, 5, clayMaterial, sm.world.voxelFilter.all, attacker )
	elseif projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.rad( math.random( 0, 359 ) ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		sm.scriptableObject.createScriptableObject( sob_pesticide_cloud, { position = effectPos, rotation = sm.vec3.getRotation( forward, randomDir ) }, self.world )
	elseif projectileUuid == projectile_glowstick or projectileUuid == projectile_glowstick_detach then
		if target then
			local targetType = type( target )
			if not (targetType == "Shape" or targetType == "Harvestable" or targetType == "VoxelTerrain" ) then
				sm.effect.playEffect( "GlowstickProjectile - Bounce", hitPos )
				return
			end
		end
		local inputLifetime = nil
		if userData then
			inputLifetime = userData.lifetime
		end
		GlowstickManager.Sv_CreateGlowstick( { hitPos = hitPos, hitTime = hitTime, hitNormal = hitNormal, target = target, world = self.world, lifetime = inputLifetime, projectileUuid = projectileUuid } )
	elseif projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit", nil, nil, nil, 35 )
	elseif projectileUuid == projectile_smallexplosive then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "PropaneTank - ExplosionSmall", nil, nil, nil, 35 )
	elseif projectileUuid == projectile_cornade_explosive then
		sm.physics.explode( hitPos, 5, 3.0, 6.0, 25.0, "Cornnade - Explosion", nil, nil, nil, 35, attacker, EXPLOSIONS.explosion_cornade )
	elseif projectileUuid == projectile_water then
		AttachedFireManager.Sv_Quench( hitPos )
		local contacts = sm.physics.getSphereContacts( hitPos, 0.4 )
		if contacts.harvestables then
			for _,harvestable in ipairs( contacts.harvestables ) do
				if WaterSplashableSet[tostring( harvestable.uuid )] then
					sm.event.sendToHarvestable( harvestable, "sv_e_waterSoil" )
				end
			end
		end
	elseif projectileUuid == projectile_flame then
		if attacker and type( attacker ) == "Player" and sm.exists( attacker ) then
			PotatoLauncherSplash( self.world, hitPos )
		else
			sm.fire.igniteSphere( hitPos, 0.25, true )
		end
	elseif projectileUuid == projectile_foam then
		AttachedFireManager.Sv_Quench( hitPos )
	elseif projectileUuid == projectile_cablebot then
		CablebotManager.Sv_AttachCablebot( hitPos, hitVelocity:safeNormalize( sm.vec3.new( 0, 1, 0 ) ) )
	elseif projectileUuid == projectile_trashbomb_green or projectileUuid == projectile_trashbomb_purple then
		sm.physics.explode( hitPos, 0, 3.0, 2.0, 0, nil, nil, nil, nil, 15 )
		local spawnChance = math.random()
		if spawnChance <= 0.25 and attacker and type( attacker ) == "Unit" and sm.exists( attacker ) then -- 25% chance
			self:sv_spawnTrashbubbleLoot( hitPos, attacker )
		end
	elseif projectileUuid == projectile_trashbomb_mass_green or projectileUuid == projectile_trashbomb_mass_purple then
		local spawnChance = math.random()
		if spawnChance <= 0.05 and attacker and type( attacker ) == "Unit" and sm.exists( attacker ) then -- 5% chance
			self:sv_spawnTrashbubbleLoot( hitPos, attacker )
		end
	elseif projectileUuid == projectile_trashbubble_green or projectileUuid ==  projectile_trashbubble_purple then
		self.network:sendToClients( "cl_n_updateTrashSpray", { hitPos = hitPos } )
	elseif isAnyOf( projectileUuid, g_spawnerProjectiles ) then
		if userData and userData.unit then
			local yaw = math.random() * 2 * math.pi
			if self.world:getWeightedVoxelDensityInWorldPoint( hitPos ) > 0 then
				hitPos = hitPos + hitNormal * 1.5 -- move out of terrain in case of hitting area with high voxel density
			end
			sm.unit.createUnit( userData.unit, hitPos, yaw, { aggressive = true } )
		end
	elseif isAnyOf( projectileUuid, NuggetProjectiles ) then
		sm.shape.createPart( ProjectileToNugget[tostring(projectileUuid)], hitPos + sm.vec3.new( 0, 0, 0.5 ), sm.quat.identity(), true )
	end

	if type( target ) == "Shape" and sm.exists( target ) and target.interactable and target.interactable:hasSeat() then
		-- pass on damage from projectiles that hit a seat
		if type( attacker ) == "Unit" or ( type( attacker ) == "Shape" and isTrapProjectile( projectileUuid ) ) or ( userData and userData.damagePlayer ) then
			local source = "shock"
			if projectileUuid == projectile_tape or projectileUuid == projectile_bubblewrap then
				source = "tapebotprojectile"
			end
			local targetCharacter = target.interactable:getSeatCharacter()
			local targetPlayer = targetCharacter and targetCharacter:getPlayer() or nil
			if targetPlayer then
				sm.event.sendToPlayer( targetPlayer, "sv_e_receiveDamage", { damage = damage, source = source } )
			end
		end
	end
end

function BaseWorld.sv_spawnTrashbubbleLoot( self, hitPos, unit )
	local distance = sm.vec3.getDistance( hitPos, unit.character.worldPosition )
	if distance > 10 and distance < 50 then
		if CanDropLimitedLoot( self.world, hitPos, "trashbubble" ) then
			local loot = SelectLoot( "lootsource_trashbubble" )
			for i = 1, #loot do
				local offset = sm.vec3.new( 0, 0, i * 0.5 )
				loot[i].limitedLoot = "trashbubble"
				local lootHarvestable = sm.harvestable.createHarvestable( hvs_loot_limited, hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
				lootHarvestable:setParams( { uuid = loot[i].uuid, quantity = loot[i].quantity, epic = loot[i].epic, limitedLoot = "trashbubble" } )
			end
		end
	end
end

function BaseWorld.server_onMelee( self, hitPos, attacker, target, damage, power, hitDirection, hitNormal )
	if attacker and sm.exists( attacker ) and target and sm.exists( target ) then
		if type( target ) == "Shape" and type( attacker) == "Unit" then
			local targetPlayer = nil
			if target.interactable and target.interactable:hasSeat() then
				local targetCharacter = target.interactable:getSeatCharacter()
				if targetCharacter then
					targetPlayer = targetCharacter:getPlayer()
				end
			end
			if targetPlayer then
				sm.event.sendToPlayer( targetPlayer, "sv_e_receiveDamage", { damage = damage, source = "impact" } )
			end
		elseif type( target ) == "VoxelTerrain" and type( attacker ) == "Player" then
			local radius = 2
			local world = attacker:getCharacter():getWorld()
			local meleeParams = MiningManager.Sv_GetMeleeParams( world, "Player")
			local meleeVoxelResultCallback = not TutorialManager.Cl_HasWatched( TutorialEvent.PlasmaDrill ) and "sv_e_meleeVoxelResult" or nil
			self.world:voxelDensitySubtraction( hitPos, sm.vec3.zero(), radius, meleeParams.maxDensities, meleeParams.voxelMaterialMask, false, meleeVoxelResultCallback, { attacker = attacker } )
		end
	end
end

function BaseWorld.sv_e_meleeVoxelResult( self, destruction, params )
	if self.world.publicData.type == "UndergroundWorld" then
		for i = 1, #destruction.densities do
			if destruction.densities[i] > 0 then
				TutorialManager.Sv_TutorialEvent( TutorialEvent.PlasmaDrill, params.attacker )
				return
			end
		end
	end
end

function BaseWorld.server_onMining( self, spawns )
	MiningManager.Sv_OnMining( self.world, spawns )
end

function BaseWorld.server_onExplosion( self, center, destructionLevel, radius, uDamage, src, srcTypeUid )
	self.world:sphereVoxelDensitySubtraction( center, radius, bit.bor( sm.world.voxelFilter.material0, sm.world.voxelFilter.material1, sm.world.voxelFilter.material2, sm.world.voxelFilter.material3 ), 10.0 )
	CablebotManager.Sv_Explosion( center, radius )
end

function BaseWorld.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end

function BaseWorld.sv_e_onChatCommand( self, params )

	if params[1] == "/starterkit" then

		if params[2] == nil or params[2] == "start" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 1, 0.5, 0 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, blk_scrapwood, 100 )
			sm.container.collect( container, jnt_bearing, 6 )
			sm.container.collect( container, obj_scrap_smallwheel, 4 )
			sm.container.collect( container, obj_scrap_driverseat, 1 )
			sm.container.collect( container, tool_connect, 1 )
			sm.container.collect( container, obj_scrap_gasengine, 1 )
			sm.container.collect( container, obj_consumable_gas, 10 )
	
			sm.container.endTransaction()
			
		elseif params[2] == "trashbot" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 1, 0.5, 0 )
			local container = chest.interactable:getContainer()
			sm.event.sendToGame("sv_setLimitedInventory", true )
			sm.container.beginTransaction()
			sm.container.collect( container, tool_spudgun, 1 )
			sm.container.collect( container, obj_plantables_potato, 400 )
			sm.container.collect( container, obj_consumable_sunshake, 40 )
			sm.container.collect( container, obj_scrap_driverseat, 1 )
			sm.container.collect( container, obj_interactive_comfybed, 1 )
			
			sm.container.endTransaction()
		elseif params[2] == "mechanic" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 0, 0, 0 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, obj_consumable_sunshake, 5 )
	
			sm.container.collect( container, blk_scrapwood, 256 )
			sm.container.collect( container, blk_scrapwood, 256 )
			sm.container.collect( container, blk_scrapmetal, 256 )
			sm.container.collect( container, blk_glass, 20 )
	
			sm.container.collect( container, obj_consumable_component, 10 )
			sm.container.collect( container, obj_consumable_gas, 20 )
			sm.container.collect( container, obj_resource_circuitboard, 10 )
			sm.container.collect( container, obj_resource_circuitboard, 10 )
			sm.container.collect( container, obj_consumable_chemical, 20 )
			sm.container.collect( container, obj_resource_corn, 20 )
			sm.container.collect( container, obj_resource_flower, 20 )
	
			sm.container.collect( container, obj_consumable_soilbag, 10 )
			sm.container.collect( container, obj_plantables_carrot, 10 )
			sm.container.collect( container, obj_plantables_tomato, 10 )
			sm.container.collect( container, obj_seed_tomato, 20 )
			sm.container.collect( container, obj_seed_carrot, 20 )
			sm.container.collect( container, obj_seed_redbeet, 10 )
			sm.container.endTransaction()

		elseif params[2] == "tutorial" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 1, 1, 1 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, sm.uuid.new( "e83a22c5-8783-413f-a199-46bc30ca8dac"), 1 ) -- Tutorial part
			sm.container.collect( container, blk_scrapwood, 38 )
			sm.container.collect( container, jnt_bearing, 6 )
			sm.container.collect( container, obj_scrap_smallwheel, 4 )
			sm.container.collect( container, obj_scrap_driverseat, 1 )
			sm.container.collect( container, obj_scrap_gasengine, 1 )
	
			sm.container.collect( container, tool_connect, 1 )
			sm.container.collect( container, obj_consumable_gas, 4 )
	
			sm.container.endTransaction()

		elseif params[2] == "pipe" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 0, 0, 1 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, obj_pneumatic_pump, 1 )
			sm.container.collect( container, obj_pneumatic_pipe_03, 10 )
			sm.container.collect( container, obj_pneumatic_pipe_bend, 5 )
			sm.container.endTransaction()

		elseif params[2] == "food" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 1, 1, 0 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, obj_plantables_banana, 10 )
			sm.container.collect( container, obj_plantables_blueberry, 10 )
			sm.container.collect( container, obj_plantables_orange, 10 )
			sm.container.collect( container, obj_plantables_pineapple, 10 )
			sm.container.collect( container, obj_plantables_carrot, 10 )
			sm.container.collect( container, obj_plantables_redbeet, 10 )
			sm.container.collect( container, obj_plantables_tomato, 10 )
			sm.container.collect( container, obj_plantables_broccoli, 10 )
			sm.container.collect( container, obj_consumable_sunshake, 5 )
			sm.container.collect( container, obj_consumable_carrotburger, 5 )
			sm.container.collect( container, obj_consumable_pizzaburger, 5 )
			sm.container.collect( container, obj_consumable_longsandwich, 5 )
			sm.container.collect( container, obj_consumable_milk, 5 )
			sm.container.collect( container, obj_resource_steak, 5 )
			sm.container.endTransaction()

		elseif params[2] == "seed" then
			local chest = sm.shape.createPart( obj_container_smallchest, params.player.character.worldPosition + sm.vec3.new( 0, 0, 2 ), sm.quat.identity() )
			chest.color = sm.color.new( 0, 1, 0 )
			local container = chest.interactable:getContainer()
	
			sm.container.beginTransaction()
			sm.container.collect( container, obj_seed_banana, 20 )
			sm.container.collect( container, obj_seed_blueberry, 20 )
			sm.container.collect( container, obj_seed_orange, 20 )
			sm.container.collect( container, obj_seed_pineapple, 20 )
			sm.container.collect( container, obj_seed_carrot, 20 )
			sm.container.collect( container, obj_seed_redbeet, 20 )
			sm.container.collect( container, obj_seed_tomato, 20 )
			sm.container.collect( container, obj_seed_broccoli, 20 )
			sm.container.collect( container, obj_seed_potato, 20 )
			sm.container.collect( container, obj_consumable_soilbag, 50 )
			sm.container.endTransaction()
		end
	elseif params[1] == "/aggroall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			sm.event.sendToUnit( unit, "sv_e_receiveTarget", { targetCharacter = params.player.character } )
		end
		sm.gui.chatMessage( "Units in overworld are aware of PLAYER" .. tostring( params.player.id ) .. " position." )
	elseif params[1] == "/printtilevalues" then
		if g_tileStorageManager then
			local tileStorageKey = TileStorageManager.Sv_GetTileStorageKeyFromPosition( self.world, params.player.character.worldPosition )
			if tileStorageKey then
				local tileStorage = TileStorageManager.Sv_GetTileStorage( tileStorageKey )
				print( "Tile storage values:" )
				print( tileStorage )
				sm.gui.chatMessage( "Tile values printed to console" )
			else
				sm.log.error( "No tile storage key found!" )
			end
		end

	elseif params[1] == "/killall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			unit:destroy()
		end
	elseif params[1] == "/stopraid" then
		print( "Cancelling all raids" )
		RaidManager.Sv_CancelRaids( self.world )

	elseif params[1] == "/disableraids" then
		print( "Disable raids set to", params[2] )
		g_disableRaids = params[2]









































































	end
end

function BaseWorld.sv_e_spawnCombatEncounterUnit( self, params )
	local center = params.center
	local aggressive = true
	if params.roaming then
		center = nil
		aggressive = false
	end
	local unitSpawnParams = { aggressive = aggressive, tetherPoint = center, deathEvent = params.deathEvent, targetPlayerOnly = true, temporary = false, roaming = params.roaming, marked = params.marked }
	
	if params.spawnPoint then
		local spawnDirection = params.rotation * sm.vec3.new( 0, 0, 1 )
		local yaw = math.atan2( spawnDirection.y, spawnDirection.x ) - math.pi / 2
		sm.unit.createUnit( params.uuid, params.spawnPoint, yaw, unitSpawnParams )
		return
	end

	local playerDirectionData = {}
	for i,player in ipairs( sm.player.getAllPlayers() ) do
		playerDirectionData[i] = {}
		playerDirectionData[i].position = player.character:getWorldPosition()
		playerDirectionData[i].direction = player.character:getDirection() 
	end

	local maxSpawnAttempts = 32
	local attemptsBeforeVisionIgnore = math.floor( maxSpawnAttempts * 0.7 )
	local spawnAttempts = 0
	local spawnSuccess = false
	local acceptedPosition = nil
	while spawnAttempts < maxSpawnAttempts do
		spawnAttempts = spawnAttempts + 1
		local distanceFromCenter = math.random( params.minRange, params.maxRange )
		local spawnDirection = sm.vec3.new( 0, 1, 0 )
		spawnDirection = spawnDirection:rotateZ( math.rad( math.random() * 360 ) )
		local unitPos = center + spawnDirection * distanceFromCenter
		local enemySpawnFilter = bit.bor( sm.physics.filter.default, sm.physics.filter.waterArea )
		local success, result = sm.physics.raycast( unitPos + sm.vec3.new( 0, 0, 128 ), unitPos + sm.vec3.new( 0, 0, -128 ), nil, enemySpawnFilter )

		if acceptedPosition ~= nil and spawnAttempts >= attemptsBeforeVisionIgnore then
			local direction = center - acceptedPosition
			local yaw = math.atan2( direction.y, direction.x ) - math.pi / 2
			sm.unit.createUnit( params.uuid, acceptedPosition, yaw, unitSpawnParams )
			spawnSuccess = true
			break
		end

		if success and ( isAnyOf( result.type, { "terrainSurface", "terrainAsset" } ) ) then
			local direction = center - unitPos
			local yaw = math.atan2( direction.y, direction.x ) - math.pi / 2
			unitPos = result.pointWorld

			local isInView = false
			if spawnAttempts < attemptsBeforeVisionIgnore then
				isInView = self:sv_isPointInPlayerView( unitPos + sm.vec3.new( 0, 0, 1 ), playerDirectionData )
			end

			if not isInView then
				sm.unit.createUnit( params.uuid, unitPos, yaw, unitSpawnParams )
				spawnSuccess = true
				break
			else
				acceptedPosition = unitPos
			end
		end
	end
	if not spawnSuccess then
		QuestManager.Sv_SendEvent( params.deathEvent ) -- count enemy as defeated if spawning failed due to terrain
	end
end

function BaseWorld.sv_e_spawnRaiders( self, params )
	local attackPos = params.attackPos
	local raiders = params.raiders

	print( #raiders, "raiders incoming" )

	for i = 1, #raiders do
		local spawnAttempts = 0
		spawnAttempts = spawnAttempts + 1
		local spawnDirection = sm.vec3.new( 0, 1, 0 )
		spawnDirection = spawnDirection:rotateZ( math.rad( math.random() * 360 ) )
		local unitPos = params.spawnPos

		local direction = attackPos - unitPos
		local yaw = math.atan2( direction.y, direction.x ) - math.pi / 2
		local unitSpawnParams = { raider = true, tetherPoint = attackPos }
		unitSpawnParams.lootType = "farmraid"
		unitSpawnParams.raidKey = params.raidKey
		unitSpawnParams.marked = true
		unitSpawnParams.raidCenter = params.raidCenter
		local unit = sm.unit.createUnit( raiders[i], unitPos, yaw, unitSpawnParams )
		if not unit then
			print("raid unit failed to spawn")
		end
	end
end

function BaseWorld.sv_isPointInPlayerView( self, point, playerDataList )

	for i,playerData in ipairs( playerDataList ) do
		local dirFromPlayer = ( point - playerData.position ):safeNormalize( sm.vec3.new( 0, 0, 1 ) )
		local playerDir = playerData.direction:safeNormalize( sm.vec3.new( 0, 0, -1 ) )
		local dotVal = sm.vec3.dot( dirFromPlayer, playerDir )
		if dotVal > 0.4 then -- aproximation of player view in first person on max fps
			local visionFilter = bit.band( sm.physics.filter.default, bit.bnot( sm.physics.filter.character ) )
			local success,_ = sm.physics.raycast( point, playerData.position, nil, visionFilter )
			if not success then
				return true
			end
		end
	end
	return false
end

function BaseWorld.sv_e_spawnNodeUnit( self, params )
	for _,tag in ipairs( params.node.tags ) do
		if tag ~= "SPAWNABLE_UNIT" then
			CreateUnit( tag, params.node, params.spawnParams )
		end
	end
end

function BaseWorld.sv_e_spawnCablebotPocket( self, node )
	local spawnParams = node.params or {}
	spawnParams.radius = node.scale.x
	local harvestable = sm.harvestable.createHarvestable( hvs_cablebot_pocket, node.position, node.rotation )
	harvestable:setParams( spawnParams )
end

function BaseWorld.sv_e_spawnQuestShape( self, params )
	local spawnPos
	local spawnRotation

	if params.spawnPosition ~= nil and params.spawnRotation ~= nil then
		spawnPos = params.spawnPosition
		spawnRotation = params.spawnRotation
	else
		sm.log.warning( "Aborting quest spawn: spawnPos =", spawnPos )
		return
	end

	local shapeUuid = params.shapeUuid

	sm.shape.createPart( shapeUuid, spawnPos, spawnRotation, false )
end

function BaseWorld.sv_e_dropCarryShape( self, params )
	Sv_DropCarry( params )
end

function BaseWorld.server_onVoxelConstruction( self, constructions )

	local glowstickIds = {}
	for _, construction in ipairs( constructions ) do
		for i = 1, 8 do
			if construction.densities[i] > 0 then
				GlowstickManager.Sv_GetGlowstickIds( construction.aabbsMin[i] - 1, construction.aabbsMax[i] + 1, glowstickIds )
			end
		end
	end

	if not IsEmptyTable( glowstickIds ) then
		GlowstickManager.Sv_CheckVoxelContact( glowstickIds )
	end

	RespawnManager.Sv_CheckBedsVoxelCovered( self.world, constructions )
	
end

function BaseWorld.server_onVoxelDestruction( self, destructions )
	local glowstickIds = {}
	local voxelChunks = {}
	for _, destruction in ipairs( destructions ) do
		local densities = destruction.densities
		local aabbsMin = destruction.aabbsMin
		local aabbsMax = destruction.aabbsMax
		local indirect = destruction.indirect
		for i = 1, 8 do
			local density = densities[i]
			if density > 0 then
				local position = ( aabbsMin[i] + aabbsMax[i] ) / 2
				AreaReactionManager.Sv_AlertVoxelDestruction( self.world, aabbsMin[i], aabbsMax[i] )
				GlowstickManager.Sv_GetGlowstickIds( aabbsMin[i] - 1, aabbsMax[i] + 1, glowstickIds )

				if indirect then
					--sm.debugDraw.flashBox( aabbsMin[i] + 0.05, aabbsMax[i] - 0.05, sm.vec3.zero(), nil, sm.color.new( "ffff00" ), 30 )
					local itemUuid = MiningManager.Sv_GetVoxelMaterialItemUuid( self.world, i )
					if itemUuid ~= nil then
						voxelChunks[#voxelChunks + 1] = {
							position = position,
							idx = i,
							density = density,
						}
					end
				end
			end
		end
	end

	if not IsEmptyTable( glowstickIds ) then
		GlowstickManager.Sv_CheckVoxelContact( glowstickIds )
	end

	-- Merge chunks
	for i = #voxelChunks, 1, -1 do
		local voxelChunk = voxelChunks[i]
		if voxelChunk.density < 1500 then
			local closestDistance2 = 4
			local closestChunkIndex = nil
			for j = i - 1, 1, -1 do
				local distance2 = sm.vec3.getDistanceSquared( voxelChunk.position, voxelChunks[j].position )
				if distance2 < closestDistance2 and ( voxelChunk.density + voxelChunks[j].density ) <= 1500 then
					closestDistance2 = distance2
					closestChunkIndex = j
				end
			end
			if closestChunkIndex then
				local otherChunk = voxelChunks[closestChunkIndex]
				local ratio = otherChunk.density / ( voxelChunk.density + otherChunk.density )
				otherChunk.density = voxelChunk.density + otherChunk.density
				--sm.debugDraw.flashArrow( voxelChunk.position, sm.vec3.lerp( voxelChunk.position, otherChunk.position, ratio ), sm.color.new( "00ffff" ), 30 )
				--sm.debugDraw.flashArrow( otherChunk.position, sm.vec3.lerp( voxelChunk.position, otherChunk.position, ratio ), sm.color.new( "ff00ff" ), 30 )
				otherChunk.position = sm.vec3.lerp( voxelChunk.position, otherChunk.position, ratio )
				voxelChunks[i] = voxelChunks[#voxelChunks]
				table.remove( voxelChunks )
			end
		end
	end

	for i = #voxelChunks, 1, -1 do
		local voxelChunk = voxelChunks[i]
		local itemUuid = MiningManager.Sv_GetVoxelMaterialItemUuid( self.world, voxelChunk.idx )
		local chunkUuid = MiningManager.Sv_GetVoxelMaterialChunkItemUuid( self.world, voxelChunk.idx, voxelChunk.density )
		if chunkUuid == nil then
			chunkUuid = ITEMS.obj_voxelmaterialchunk_t1_small
		end
		local part = sm.shape.createPart( chunkUuid, voxelChunk.position, sm.quat.identity(), true, true )
		part:getInteractable():setParams( { uuid = itemUuid, quantity = voxelChunk.density } )
	end
end

function BaseWorld.cl_n_updateTrashSpray( self, params )
	self.cl.trashSprayLastTick = sm.game.getCurrentTick()
	if not self.cl.trashSprayEffect then
		self.cl.trashSprayEffect = sm.effect.createEffect( "audio:event:/char/npc/bots/enemies/trashbot/spray_impact_loop" )
	end

	self.cl.trashSprayEffect:setPosition( params.hitPos )
	if not self.cl.trashSprayEffect:isPlaying() then
		self.cl.trashSprayEffect:start()
	end
end
