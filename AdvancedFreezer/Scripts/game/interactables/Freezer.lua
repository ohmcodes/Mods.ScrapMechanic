dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

Freezer = class( nil )
Freezer.poseWeightCount = 1
Freezer.maxParentCount = 1
Freezer.maxChildCount = 0
Freezer.connectionInput = sm.interactable.connectionType.water
Freezer.connectionOutput = sm.interactable.connectionType.none
Freezer.colorNormal = sm.color.new( 0x00acfcff )
Freezer.colorHighlight = sm.color.new( 0x00acfcff )
Freezer.connectIcon = "water"
Freezer.connectIconScale = 0.75

-- Shorter values make the freezer produce ice more often. DAYCYCLE_TIME_TICKS is one in-game day.
local ProduceTickTime = DAYCYCLE_TIME_TICKS * 0.06
local NumConsumed = 1
local NumProduced = 20
local MaximumStored = 500

local LootSpawnHeightOffset = 0.8
local LootBubbleRadius = 0.3


function Freezer.server_onCreate( self )
    self:sv_init()
end

function Freezer.server_onRefresh( self )
    self:sv_init()
end

function Freezer.sv_init( self )
    -- Keep initialization in one place so script refreshes restore the same container and state.
    self.sv = {}
    self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
        self.sv.container = self.shape:getInteractable():addContainer( 0, 1, 20 )
        self.sv.container:setFilters( { obj_consumable_water } )
        self.sv.saved = { 
            progress = 0,
            lastTickUpdate = sm.game.getCurrentTick(),
            ice = 0
        }
    else
        self.sv.container = self.shape:getInteractable():getContainer(0)
    end
    self.sv.container:bindOnTransaction( "sv_container_onTransaction" )

    self.sv.world = self.shape.body:getWorld()
    self.sv.loaded = true
    -- Cache storage connected through the new bottom pipe input.
    self.inputContainers = sm.pipeGraph.getInputContainers( self.shape )
    self.itemPullTimer = 0
    self:sv_updateProgress()
end

function Freezer.server_onUnload( self )
    if self.sv.loaded then
		self.sv.loaded = false
	end
end

function Freezer.server_onDestroy( self )
    if self.sv.loaded and self.sv.saved.ice > 0 and self.position and self.rotation then
        local stackSize = sm.item.getStackSize( ITEMS.blk_ice )
        while self.sv.saved.ice > 0 do
            local quant = min( stackSize, self.sv.saved.ice )
            self.sv.saved.ice = self.sv.saved.ice - quant

            local projectileParams = { lootUid = ITEMS.blk_ice, lootQuantity = quant, epic = false }
            local projectileDirection = self.rotation * ( sm.vec3.new( 0,1,0 ) + ( RandomUnitVector() * 0.1 ) )
            local projectilePosition = self.position + projectileDirection * LootSpawnHeightOffset
            sm.projectile.customProjectileAttack( projectileParams, projectile_loot, 0, projectilePosition, projectileDirection * 4, self.sv.world )
        end
        self.sv.loaded = false
    end
end

function Freezer.pullItem( self, uuid )
    -- Move one water item from a connected container into the Freezer's local container.
    if self.inputContainers == nil or not sm.container.canCollect( self.sv.container, uuid, 1 ) then
        return
    end
    for _, containerShape in ipairs( self.inputContainers ) do
        local sourceContainer = containerShape:getInteractable():getContainer()
        if sourceContainer then
            for slot = 0, sourceContainer:getSize() - 1 do
                local item = sourceContainer:getItem( slot )
                if item and item.quantity > 0 and item.uuid == uuid then
                    sm.container.beginTransaction()
                    sm.container.collect( self.sv.container, item.uuid, 1, true )
                    sm.container.spend( sourceContainer, item.uuid, 1, true )
                    sm.container.endTransaction()
                    return
                end
            end
        end
    end
end

function Freezer.sv_container_onTransaction( self, container )
    self:sv_setClientData()
end

function Freezer.sv_setClientData( self )
    -- The visual effect can be active when water comes from either a pipe or the local container.
    local waterInput = self:sv_getWaterInput()
    local hasWater = CanSpendFromConnectedContainer( waterInput, obj_consumable_water, NumConsumed )
        or self.sv.container:canSpend( obj_consumable_water, NumConsumed )
    self.network:setClientData( { active = hasWater, ice = self.sv.saved.ice } )
end

function Freezer.sv_getWaterInput( self )
    -- Only accept parents connected through the water connection type.
    local parents = self.interactable:getParents( sm.interactable.connectionType.water )
    if parents[1] then
        return parents[1]
    end
    return nil
end

function Freezer.sv_updateProgress( self )
    local currentTick = sm.game.getCurrentTick()
	local elapsedTicks = currentTick - self.sv.saved.lastTickUpdate
	elapsedTicks = math.max( elapsedTicks, 0 )
	self.sv.saved.lastTickUpdate = currentTick

    local container = self.shape:getInteractable():getContainer(0)
    if not container then
        return
    end

    local waterInput = self:sv_getWaterInput()
    local canProduce = function()
        return ( CanSpendFromConnectedContainer( waterInput, obj_consumable_water, NumConsumed ) or container:canSpend( obj_consumable_water, NumConsumed ) )
            and NumProduced <= MaximumStored - self.sv.saved.ice
    end
    
    -- Consume one water unit and produce one ice batch when the timer is ready.
    self.sv.saved.progress = self.sv.saved.progress + elapsedTicks
    sm.container.beginTransaction()
    local produced = false
    if self.sv.saved.progress >= ProduceTickTime and canProduce() then
        -- This helper returns the amount still needed, not the amount spent.
        local remainingAmount = TrySpendFromConnectedContainer( waterInput, obj_consumable_water, NumConsumed )
        if remainingAmount > 0 then
            remainingAmount = remainingAmount - sm.container.spend( container, obj_consumable_water, remainingAmount, false )
        end
        if remainingAmount <= 0 and sm.container.endTransaction() then
            self.sv.saved.progress = self.sv.saved.progress - ProduceTickTime
            produced = true
        else
            sm.container.abortTransaction()
        end
    else
        sm.container.abortTransaction()
    end

    if produced then
        -- Spawn the newly produced ice as loose loot instead of storing it in the freezer.
        local projectileParams = { lootUid = ITEMS.blk_ice, lootQuantity = NumProduced, epic = false }
        local projectileDirection = self.shape.worldRotation * ( sm.vec3.new( 0,1,0 ) + ( RandomUnitVector() * 0.1 ) )
        local projectilePosition = self.shape.worldPosition + projectileDirection * LootSpawnHeightOffset
        sm.projectile.customProjectileAttack( projectileParams, projectile_loot, 0, projectilePosition, projectileDirection * 4, self.sv.world )
    end

    self.storage:save( self.sv.saved )
    self:sv_setClientData()
end

function Freezer.server_onFixedUpdate( self, timeStep )
    -- Refresh the pipe list after movement and pull water periodically from connected storage.
    if self.shape:getBody():hasChanged( sm.game.getCurrentTick() - 1 ) then
        self.inputContainers = sm.pipeGraph.getInputContainers( self.shape )
    end
    if self.itemPullTimer > 0 then
        self.itemPullTimer = self.itemPullTimer - timeStep
    end
    if self.itemPullTimer <= 0 then
        self.itemPullTimer = 1
        self:pullItem( obj_consumable_water )
    end
    self:sv_updateProgress()
end

function Freezer.client_getAvailableParentConnectionCount( self, connectionType )
    -- Tell the connection tool that this shape has one water input socket.
    if bit.band( connectionType, sm.interactable.connectionType.water ) ~= 0 then
        return 1 - #self.interactable:getParents( sm.interactable.connectionType.water )
    end
    return 0
end

function Freezer.sv_n_collect( self, args, player )
    if self.sv.saved.ice > 0 then
        if player and sm.exists( player ) then
            local inventory = player:getInventory()
            if sm.container.beginTransaction() then
                local amountCollected = inventory:collect( ITEMS.blk_ice, self.sv.saved.ice, false )
                if sm.container.endTransaction() and amountCollected > 0 then
                    self.sv.saved.ice = self.sv.saved.ice - amountCollected
                    self.storage:save( self.sv.saved )
                    self:sv_setClientData()

                    local pos = self.shape.worldPosition + ( self.shape.worldRotation * sm.vec3.new( 0, 0.4, 0 ) )
                    local rot = self.shape.worldRotation * sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, -1 ) )
                    sm.event.sendToPlayer( player, "sv_e_onLoot", { uuid = ITEMS.blk_ice, pos = pos, rot = rot } )
                end
            end
        end
    end
end

function Freezer.client_onCreate( self )
    self.cl = {}
    self.cl.freezingEffect = sm.effect.createEffect( "Interactive - Freezer_loop", self.interactable )
    self.cl.pose = 0
    self.cl.targetPose = 0
    self.cl.ice = nil
    -- Used to detect a new pipe connection without waiting for server production updates.
    self.cl.waterConnected = false
end

function Freezer.client_onDestroy( self )
    self.cl.freezingEffect:destroy()
    if self.cl.gui and sm.exists( self.cl.gui ) and self.cl.gui:isActive() then
        self.cl.gui:close()
        self.cl.gui:destroy()
        self.cl.gui = nil
    end
end

function Freezer.client_onClientDataUpdate( self, data )
    if data.active == true then
        if not self.cl.freezingEffect:isPlaying() or self.cl.freezingEffect:isBreakSustaining() then
            self.cl.freezingEffect:start()
        end
    else
        if self.cl.freezingEffect:isPlaying() and not self.cl.freezingEffect:isBreakSustaining() then
            self.cl.freezingEffect:stopBreakSustain()
        end
    end

    if self.cl.ice ~= nil and data.ice > self.cl.ice then
        sm.effect.playEffect( "Interactive - Freezer_done", self.shape.worldPosition + ( self.shape.worldRotation * sm.vec3.new( 0,0.4,0 ) ), nil, self.shape.worldRotation )
    end

    self.cl.ice = data.ice

    if self.cl.ice ~= nil and self.cl.ice > 0 then
        if not self.cl.iceTrigger then
            local offsetPosition = sm.vec3.new( 0,1,0 ) * LootSpawnHeightOffset

            self.cl.iceTrigger = sm.areaTrigger.createAttachedSphere( self.interactable, LootBubbleRadius, offsetPosition, nil, nil, nil, sm.areaTrigger.areaTriggerProxyType.interactable  )
            self.cl.iceLootEffect = sm.effect.createEffect( "Loot - GlowItem", self.interactable )
            self.cl.iceLootEffect:setParameter( "uuid", ITEMS.blk_ice )
		    self.cl.iceLootEffect:setParameter( "Color", sm.shape.getShapeTypeColor( ITEMS.blk_ice ) )
            self.cl.iceLootEffect:setScale( sm.vec3.new( 0.25, 0.25, 0.25 ) )
            self.cl.iceLootEffect:setOffsetPosition( offsetPosition )

            local randomRotation = sm.quat.angleAxis( math.random() * math.pi * 2, sm.vec3.new( 0, 1, 0 ) )
            self.cl.iceLootEffect:setOffsetRotation( randomRotation * sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, -1 ) ) )
            self.cl.iceLootEffect:start()

            self.cl.iceTrigger:bindCanInteract( "cl_trigger_canInteract" )
            self.cl.iceTrigger:bindCanErase( "cl_trigger_canErase" )
            self.cl.iceTrigger:bindOnInteract( "cl_trigger_onInteract" )
            self.cl.iceTrigger:bindOnErase( "cl_trigger_onErase" )

            self.cl.iceTrigger:setEraseTime( 0.0 )
            self.cl.iceTrigger:setDestroyOnErase( false )
        end
    else
        if self.cl.iceTrigger then
            if sm.exists( self.cl.iceTrigger ) then
                self.cl.iceTrigger:destroy()
            end
            self.cl.iceTrigger = nil
        end
        if self.cl.iceLootEffect then
            if sm.exists( self.cl.iceLootEffect ) then
                self.cl.iceLootEffect:destroy()
            end
            self.cl.iceLootEffect = nil
        end
    end
end

function Freezer.client_onUpdate( self, dt )
    -- Start the freezer effect immediately when a water connection is made.
    local waterConnected = #self.interactable:getParents( sm.interactable.connectionType.water ) > 0
    if waterConnected and not self.cl.waterConnected then
        if not self.cl.freezingEffect:isPlaying() or self.cl.freezingEffect:isBreakSustaining() then
            self.cl.freezingEffect:start()
        end
    elseif not waterConnected and self.cl.waterConnected then
        -- Stop the freezer effect immediately when its water connection is removed.
        if self.cl.freezingEffect:isPlaying() and not self.cl.freezingEffect:isBreakSustaining() then
            self.cl.freezingEffect:stopBreakSustain()
        end
    end
    self.cl.waterConnected = waterConnected

    if self.cl.gui and sm.exists(self.cl.gui) and self.cl.gui:isActive() then
        self.cl.targetPose = 1
    else
        self.cl.targetPose = 0
    end

    if self.cl.pose ~= self.cl.targetPose then
        self.cl.pose = lerp( self.cl.pose or 0, self.cl.targetPose, dt * 10)
        self.cl.pose = clamp( self.cl.pose, 0, 1 )
        self.interactable:setPoseWeight( 0, self.cl.pose )
    end

    if sm.isHost and self.cl.ice ~= nil and self.cl.ice > 0 then
        self.position = self.shape.worldPosition
        self.rotation = self.shape.worldRotation
    end
end

function Freezer.client_canInteract( self )
    return self.shape:getInteractable():getContainer(0) ~= nil
end

function Freezer.client_onInteract( self, _, state )
    if self.shape:getInteractable():getContainer(0) then
        if state == true then
            if self.cl.gui == nil or not sm.exists( self.cl.gui ) then
                self.cl.gui = sm.gui.createContainerGui( true )
            end
            self.cl.gui:setText( "UpperName", sm.shape.getShapeUpperCaseTitle( self.shape.uuid ) )
            self.cl.gui:setContainer( "UpperGrid", self.shape:getInteractable():getContainer(0) )
            self.cl.gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
            self.cl.gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
            self.cl.gui:setOpenCloseEffect( "Gui - ChestOpen", "Gui - ChestClose" );
            self.cl.gui:open()
        end
    end
end

function Freezer.cl_trigger_canInteract( self )
	local keyBindingText = GetInteractionKeybinding()
	sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_PICK_UP} #FFFFC0" .. sm.shape.getShapeTitle( ITEMS.blk_ice ) .. "#FFFFFF"..( self.cl.ice > 1 and (" x " .. self.cl.ice ) or "" ) )
	return true
end

function Freezer.cl_trigger_canErase( self )
    return true
end

function Freezer.cl_trigger_onInteract( self, _, state )
    if state then
		self.network:sendToServer( "sv_n_collect" )
	end
end

function Freezer.cl_trigger_onErase( self )
    self.network:sendToServer( "sv_n_collect" )
end





