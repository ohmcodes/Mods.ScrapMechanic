dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

InteractableBeehive = class( nil )
InteractableBeehive.maxParentCount = 1
InteractableBeehive.maxChildCount = 0

local ProduceTickTime = DAYCYCLE_TIME_TICKS * 0.06

local NumConsumed = 1
local NumProduced = 1
local MaximumStored = 20

local LootSpawnHeightOffset = 0.8
local LootBubbleRadius = 0.3


function InteractableBeehive.server_onCreate( self )
    self:sv_init()
end

function InteractableBeehive.server_onRefresh( self )
    self:sv_init()
end

function InteractableBeehive.sv_init( self )
    self.sv = {}
    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.container = self.shape:getInteractable():addContainer( 0, 1, 20 )
        self.sv.container:setFilters( { obj_resource_flower } )
        self.sv.saved = { 
            progress = 0,
            lastTickUpdate = sm.game.getCurrentTick(),
            beewax = 0
        }
    else
        self.sv.container = self.shape:getInteractable():getContainer(0)
    end
    self.sv.container:bindOnTransaction( "sv_container_onTransaction" )
    
    self.sv.world = self.shape.body:getWorld()
    self.sv.loaded = true
    self.sv.debugState = nil
    self.sv.debugFixedUpdateLogged = false
    -- Cache only storage connected through the pipe graph.
    self.inputContainers = sm.pipeGraph.getInputContainers( self.shape )
    self.itemPullTimer = 0
    -- print( "[Beehive] initialized, input pipe count: " .. #sm.pipeGraph.getInputContainers( self.shape ) )
    -- Perform an initial check when the Beehive is placed or loaded.
    self:sv_updateProgress()
end

function InteractableBeehive.server_onUnload( self )
    if self.sv.loaded then
		self.sv.loaded = false
	end
end

function InteractableBeehive.server_onDestroy( self )
    if self.sv.loaded and self.sv.saved.beewax > 0 and self.position and self.rotation then
        local stackSize = sm.item.getStackSize( ITEMS.obj_resource_beewax )
        while self.sv.saved.beewax > 0 do
            local quant = min( stackSize, self.sv.saved.beewax )
            self.sv.saved.beewax = self.sv.saved.beewax - quant

            local projectileParams = { lootUid = ITEMS.obj_resource_beewax, lootQuantity = quant, epic = false }
            local projectileDirection = self.rotation * ( sm.vec3.new( 0,1,0 ) + ( RandomUnitVector() * 0.1 ) )
            local projectilePosition = self.position + projectileDirection * LootSpawnHeightOffset
            sm.projectile.customProjectileAttack( projectileParams, projectile_loot, 0, projectilePosition, projectileDirection * 4, self.sv.world )
        end
        self.sv.loaded = false
    end
end

function InteractableBeehive.pullItem( self, uuid )
    -- Move one valid flower from a connected input chest into the Beehive container.
    if self.inputContainers == nil or not sm.container.canCollect( self.sv.container, uuid, 1 ) then
        return
    end

    for _, containerShape in ipairs( self.inputContainers ) do
        local container = containerShape:getInteractable():getContainer()
        if container then
            for slot = 0, container:getSize() - 1 do
                local item = container:getItem( slot )
                if item and item.quantity > 0 and item.uuid == uuid then
                    sm.container.beginTransaction()
                    sm.container.collect( self.sv.container, item.uuid, 1, true )
                    sm.container.spend( container, item.uuid, 1, true )
                    if sm.container.endTransaction() then
                        -- print( "[Beehive] pulled pigment from connected container" )
                    end
                    return
                end
            end
        end
    end
end

function InteractableBeehive.sv_container_onTransaction( self, container )
    self:sv_setClientData()
end

function InteractableBeehive.sv_n_collect( self, args, player )
    if self.sv.saved.beewax > 0 then
        if player and sm.exists( player ) then
            local inventory = player:getInventory()
            if sm.container.beginTransaction() then
                local amountCollected = inventory:collect( ITEMS.obj_resource_beewax, self.sv.saved.beewax, false )
                if sm.container.endTransaction() and amountCollected > 0 then
                    self.sv.saved.beewax = self.sv.saved.beewax - amountCollected
                    self.storage:save( self.sv.saved )
                    self:sv_setClientData()

                    local pos = self.shape.worldPosition + ( self.shape.worldRotation * sm.vec3.new( 0, 0.4, 0 ) )
                    local rot = self.shape.worldRotation * sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, -1 ) )
                    sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = ITEMS.obj_resource_beewax, pos = pos, rot = rot } )
                end
            end
        end
    end
end

function InteractableBeehive.sv_setClientData( self )
    local active = self:sv_canSpendFlower()
    self.network:setClientData( { active = active, beewax = self.sv.saved.beewax } )
end

function InteractableBeehive.sv_getFlowerContainer( self )
    -- Follow the same input-container path used by Crafter for connected chests.
    local inputContainers = sm.pipeGraph.getInputContainers( self.shape )
    for _, inputContainer in ipairs( inputContainers ) do
        local container = GetPipeGraphObjectContainer( inputContainer )
        if container and sm.container.canSpend( container, obj_resource_flower, NumConsumed ) then
            return container
        end
    end

    return nil
end

function InteractableBeehive.sv_canSpendFlower( self )
    local flowerContainer = self:sv_getFlowerContainer()
    if flowerContainer and sm.container.canSpend( flowerContainer, obj_resource_flower, NumConsumed ) then
        return true
    end
    return self.sv.container:canSpend( obj_resource_flower, NumConsumed )
end

function InteractableBeehive.sv_spendFlower( self )
    local flowerContainer = self:sv_getFlowerContainer()
    if flowerContainer then
        return sm.container.spend( flowerContainer, obj_resource_flower, NumConsumed, false ) == NumConsumed
    end
    return sm.container.spend( self.sv.container, obj_resource_flower, NumConsumed, false ) == NumConsumed
end

function InteractableBeehive.sv_updateProgress( self )
    local currentTick = sm.game.getCurrentTick()
	local elapsedTicks = currentTick - self.sv.saved.lastTickUpdate
	elapsedTicks = math.max( elapsedTicks, 0 )
	self.sv.saved.lastTickUpdate = currentTick

    local container = self.shape:getInteractable():getContainer(0)
    if not container then
        return
    end

    -- Consume pigment flowers from connected input containers, like Crafter.
    self.sv.saved.progress = self.sv.saved.progress + elapsedTicks
    sm.container.beginTransaction()
    local produced = false
    if self.sv.saved.progress >= ProduceTickTime and NumProduced <= MaximumStored - self.sv.saved.beewax then
        local remainingAmount = NumConsumed
        local flowerContainer = self:sv_getFlowerContainer()
        local inputContainers = sm.pipeGraph.getInputContainers( self.shape )
        local inputCount = #inputContainers
        -- print( "[Beehive] production check, input containers: " .. inputCount .. ", local pigment: " .. sm.container.totalQuantity( self.sv.container, obj_resource_flower ) )
        if flowerContainer then
            -- print( "[Beehive] source pigment: " .. sm.container.totalQuantity( flowerContainer, obj_resource_flower ) )
            remainingAmount = remainingAmount - sm.container.spend( flowerContainer, obj_resource_flower, remainingAmount, false )
        end
        if remainingAmount > 0 then
            remainingAmount = remainingAmount - sm.container.spend( self.sv.container, obj_resource_flower, remainingAmount, false )
        end

        if remainingAmount <= 0 and sm.container.endTransaction() then
            self.sv.saved.progress = self.sv.saved.progress - ProduceTickTime
            produced = true
            -- print( "[Beehive] consumed pigment flower, production completed" )
        else
            sm.container.abortTransaction()
            -- print( "[Beehive] pigment transaction failed, remaining amount: " .. remainingAmount )
        end
    else
        sm.container.abortTransaction()
    end

    local hasFlower = self:sv_canSpendFlower()
    local inputCount = #sm.pipeGraph.getInputContainers( self.shape )
    local debugState = tostring( inputCount ) .. ":" .. tostring( hasFlower )
    if debugState ~= self.sv.debugState then
        self.sv.debugState = debugState
        -- print( "[Beehive] input pipes: " .. inputCount .. ", pigment available: " .. tostring( hasFlower ) .. ", progress: " .. self.sv.saved.progress )
    end

    if produced then
        -- Always launch beeswax as loose loot; the pipe is input-only for pigment flowers.
        local projectileParams = { lootUid = ITEMS.obj_resource_beewax, lootQuantity = NumProduced, epic = false }
        local projectileDirection = self.shape.worldRotation * ( sm.vec3.new( 0,1,0 ) + ( RandomUnitVector() * 0.1 ) )
        local projectilePosition = self.shape.worldPosition + projectileDirection * LootSpawnHeightOffset
        sm.projectile.customProjectileAttack( projectileParams, projectile_loot, 0, projectilePosition, projectileDirection * 4, self.sv.world )
        -- print( "[Beehive] launched beeswax x" .. NumProduced )
    end

    self.storage:save( self.sv.saved )
    self:sv_setClientData()
end

function InteractableBeehive.server_onFixedUpdate( self, timeStep )
    -- Refresh pipe inputs after movement and pull pigment from connected storage.
    -- Run after the pipe graph is initialized so a newly placed chest connection is detected.
    if self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
        self.inputContainers = sm.pipeGraph.getInputContainers( self.shape )
    end
    if self.itemPullTimer > 0 then
        self.itemPullTimer = self.itemPullTimer - timeStep
    end
    if self.itemPullTimer <= 0 then
        self.itemPullTimer = 1
        self:pullItem( obj_resource_flower )
    end
    if not self.sv.debugFixedUpdateLogged then
        self.sv.debugFixedUpdateLogged = true
        -- print( "[Beehive] server fixed update is running" )
    end
    self:sv_updateProgress()
end

function InteractableBeehive.client_onCreate( self )
    self.cl = {}
    self.cl.beeEffect = sm.effect.createEffect( "Interactive - Beehive_loop", self.interactable )
    self.cl.beewax = nil
end

function InteractableBeehive.client_onDestroy( self )
    self.cl.beeEffect:destroy()
    if self.cl.gui and sm.exists( self.cl.gui ) and self.cl.gui:isActive() then
        self.cl.gui:close()
        self.cl.gui:destroy()
        self.cl.gui = nil
    end
end

function InteractableBeehive.client_onClientDataUpdate( self, data )
    if data.active == true then
        if not self.cl.beeEffect:isPlaying() then
            self.cl.beeEffect:start()
        end
    else
        if self.cl.beeEffect:isPlaying() then
            self.cl.beeEffect:stop()
        end
    end

    if self.cl.beewax ~= nil and data.beewax > self.cl.beewax then
        sm.effect.playEffect( "Interactive - Beehive_done", self.shape.worldPosition + ( self.shape.worldRotation * sm.vec3.new( 0,0.4,0 ) ), nil, self.shape.worldRotation )
    end

    self.cl.beewax = data.beewax

    if self.cl.beewax ~= nil and self.cl.beewax > 0 then
        if not self.cl.beewaxTrigger then
            local offsetPosition = sm.vec3.new( 0,1,0 ) * LootSpawnHeightOffset

            self.cl.beewaxTrigger = sm.areaTrigger.createAttachedSphere( self.interactable, LootBubbleRadius, offsetPosition, nil, nil, nil, sm.areaTrigger.areaTriggerProxyType.interactable  )
            self.cl.beewaxEffect = sm.effect.createEffect( "Loot - GlowItem", self.interactable )
            self.cl.beewaxEffect:setParameter( "uuid", ITEMS.obj_resource_beewax )
		    self.cl.beewaxEffect:setParameter( "Color", sm.shape.getShapeTypeColor( ITEMS.obj_resource_beewax ) )
            self.cl.beewaxEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
            self.cl.beewaxEffect:setOffsetPosition( offsetPosition )

            local randomRotation = sm.quat.angleAxis( math.random() * math.pi * 2, sm.vec3.new( 0, 1, 0 ) )
            self.cl.beewaxEffect:setOffsetRotation( randomRotation * sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, -1 ) ) )
            self.cl.beewaxEffect:start()

            self.cl.beewaxTrigger:bindCanInteract( "cl_trigger_canInteract" )
            self.cl.beewaxTrigger:bindCanErase( "cl_trigger_canErase" )
            self.cl.beewaxTrigger:bindOnInteract( "cl_trigger_onInteract" )
            self.cl.beewaxTrigger:bindOnErase( "cl_trigger_onErase" )

            self.cl.beewaxTrigger:setEraseTime( 0.0 )
            self.cl.beewaxTrigger:setDestroyOnErase( false )
        end
    else
        if self.cl.beewaxTrigger then
            if sm.exists( self.cl.beewaxTrigger ) then
                self.cl.beewaxTrigger:destroy()
            end
            self.cl.beewaxTrigger = nil
        end
        if self.cl.beewaxEffect then
            if sm.exists( self.cl.beewaxEffect ) then
                self.cl.beewaxEffect:destroy()
            end
            self.cl.beewaxEffect = nil
        end
    end
end

function InteractableBeehive.client_onUpdate( self, dt )
    if sm.isHost and self.cl.beewax ~= nil and self.cl.beewax > 0 then
        self.position = self.shape.worldPosition
        self.rotation = self.shape.worldRotation
    end
end

function InteractableBeehive.client_canInteract( self )
    return self.shape:getInteractable():getContainer(0) ~= nil
end

function InteractableBeehive.client_onInteract( self, _, state )
    if self.shape:getInteractable():getContainer(0) then
        if state == true then
            if self.cl.gui == nil or not sm.exists( self.cl.gui ) then
                self.cl.gui = sm.gui.createContainerGui( true )
            end
            self.cl.gui:setText( "UpperName", sm.shape.getShapeUpperCaseTitle( self.shape.uuid ) )
            self.cl.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer(0) )
            self.cl.gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
            self.cl.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
            self.cl.gui:open()
        end
    end
end

function InteractableBeehive.cl_trigger_canInteract( self )
	local keyBindingText =  GetInteractionKeybinding()
	sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PICK_UP} #FFFFC0" .. sm.shape.getShapeTitle( ITEMS.obj_resource_beewax ) .. "#FFFFFF"..( self.cl.beewax > 1 and (" x " .. self.cl.beewax ) or "" ) )
	return true
end

function InteractableBeehive.cl_trigger_canErase( self )
    return true
end

function InteractableBeehive.cl_trigger_onInteract( self, _, state )
    if state then
		self.network:sendToServer( "sv_n_collect" )
	end
end

function InteractableBeehive.cl_trigger_onErase( self )
    self.network:sendToServer( "sv_n_collect" )
end

