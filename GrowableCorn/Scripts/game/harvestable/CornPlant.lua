dofile("$SURVIVAL_DATA/Scripts/game/survival_loot.lua")

CornPlant = class()

function CornPlant.server_onCreate( self )
	self.sv = {}

	local min, max = self.harvestable:getLocalAabb()
	local bounds = sm.vec3.new( math.abs( max.x - min.x ), math.abs( max.y - min.y ), math.abs( max.z - min.z ) )
	local centerPos = min + bounds * 0.5

	self.sv.areaTrigger = sm.areaTrigger.createBox( bounds * 0.5, self.harvestable:transformLocalPoint( centerPos ), self.harvestable:getRotation(), sm.areaTrigger.filter.dynamicBody )
	self.sv.areaTrigger:bindOnEnter( "trigger_onEnter" )
	self.harvestable.publicData = { drillLevel = 1 }
end

function CornPlant.server_onDestroy( self )
	if self.sv.areaTrigger then
		sm.areaTrigger.destroy( self.sv.areaTrigger )
		self.sv.areaTrigger = nil
	end
end

function CornPlant.sv_onHit( self )
	if not self.destroyed and sm.exists( self.harvestable ) then

		if SurvivalGame then
			local lootList = {}
			local slots = randomStackAmountAvg2()
			for i = 1, slots do
				lootList[i] = { uuid = obj_resource_corn, quantity = 1 }
			end
			lootList[#lootList + 1] = { uuid = obj_seed_corn, quantity = 1 }
			SpawnLoot( self.harvestable, lootList, self.harvestable.worldPosition + sm.vec3.new( 0, 0, 1.0 ) )
		end
		
		sm.effect.playEffect( "Corn - Destruct", self.harvestable.worldPosition, nil, self.harvestable.worldRotation )
		sm.harvestable.createHarvestable( hvs_farmables_growing_cornplant, self.harvestable.worldPosition, self.harvestable.worldRotation )
		
		self.harvestable:destroy()
		self.destroyed = true
	end
end

function CornPlant.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if damage > 0 then
		self:sv_onHit()
	end
end

function CornPlant.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	self:sv_onHit()
end

function CornPlant.server_onExplosion( self, center, destructionLevel )
	self:sv_onHit()
end

function CornPlant.sv_e_plasmaDrill( self, params )
	self:sv_onHit()
end

function CornPlant.trigger_onEnter( self, trigger, results )
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Body" then
				self:sv_onHit()
				break
			end
		end
	end
end