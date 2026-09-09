dofile "$SURVIVAL_DATA/Scripts/game/characters/TotebotCharacter.lua"

SeedbotCharacter = class( TotebotCharacter )

local alertRenderableTp = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_alert.rend"
local roamingRenderableTp = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_roaming.rend"
sm.character.preloadRenderables( { alertRenderableTp, roamingRenderableTp } )

local animationSets = {
	alert = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_alert.rend",
	roaming = "$SURVIVAL_DATA/Character/Char_Totebot/char_totebot_roaming.rend"
}

function SeedbotCharacter.sv_e_setSeedType( self, seedType )
	self.network:setClientData( { seedType = seedType }, 1  )
end

function SeedbotCharacter.client_onClientDataUpdate( self, data, channel )
	self.cl.seedType = data.seedType
	self:cl_updateSeedType()
end

function SeedbotCharacter.cl_updateSeedType( self )
	if self.graphicsLoaded then
		if self.cl.effects.seedCrate then
			self.cl.effects.seedCrate:destroy()
			self.cl.effects.seedCrate = nil
		end
		local SeedCrateEffect = {
			["tomato"] = "Seedbot - Crate_tomato",
			["carrot"] = "Seedbot - Crate_carrot",
			["redbeet"] = "Seedbot - Crate_redbeet",
			["cotton"] = "Seedbot - Crate_cotton",
			["banana"] = "Seedbot - Crate_banana",
			["blueberry"] = "Seedbot - Crate_blueberry",
			["orange"] = "Seedbot - Crate_orange",
			["potato"] = "Seedbot - Crate_potato",
			["pineapple"] = "Seedbot - Crate_pineapplecrate",
			["broccoli"] = "Seedbot - Crate_broccoli",
			["chili"] = "Seedbot - Crate_chilli",
			["pigmentflower"] = "Seedbot - Crate_pigmentflower",
			["corn"] = "Seedbot - Crate_corn",
		}
		local effectName = SeedCrateEffect[self.cl.seedType]
		if effectName then
			self.cl.effects.seedCrate = sm.effect.createEffect( effectName, self.character, "jnt_head" )
			self.cl.effects.seedCrate:setOffsetPosition( sm.vec3.new( 0, 0.45, 0 ) )
			self.cl.effects.seedCrate:start()
		end
	end
end

function SeedbotCharacter.client_onGraphicsLoaded( self )

	self.character:addRenderable( animationSets[self.cl.currentAnimationSet] )
	self:cl_initGraphics()
	self:cl_initAnimationSwitch()
	self.character:setGlowMultiplier( 1 )
	self.graphicsLoaded = true

	self.cl.effects = {}
	if self.cl.seedType then
		self:cl_updateSeedType()
	end
end

function SeedbotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false

	if self.cl.effects.seedCrate then
		self.cl.effects.seedCrate:destroy()
		self.cl.effects.seedCrate = nil
	end
end

function SeedbotCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if sm.exists( self.character ) then

		if event == "death" then
			SpawnDebris( self.character, "jnt_spine1", "Robotparts - TotebotBody" )
			SpawnDebris( self.character, "jnt_01_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_02_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_03_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_04_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_05_upperleg", "Robotparts - TotebotLeg" )
			SpawnDebris( self.character, "jnt_06_upperleg", "Robotparts - TotebotLeg" )

			SpawnDebris( self.character, "jnt_head", "ToteBot - DestroyedParts" )
			SpawnDebris( self.character, "jnt_head", "Seedbot - Crate_destruction", sm.vec3.new( 0, 0.45, 0 ) )
		else
			self.cl.currentAnimation = ""
		end
	end
end
