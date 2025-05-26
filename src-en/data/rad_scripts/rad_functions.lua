mods.rad = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------


-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_random_point_in_radius(center, radius)
    r = radius * math.sqrt(math.random())
    theta = math.random() * 2 * math.pi
    return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

local function get_ship_crew_room(shipManager, roomId)
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
end

-- written by kokoro
local function convertMousePositionToEnemyShipPosition(mousePosition)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local combatControl = cApp.gui.combatControl
    local position = 0--combatControl.position -- not exposed yet
    local targetPosition = combatControl.targetPosition
    local enemyShipOriginX = position.x + targetPosition.x
    local enemyShipOriginY = position.y + targetPosition.y
    return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

-----------
-- LOGIC --
-----------

script.on_game_event("RAD_PIRATE_FIGHT_TRIGGER", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for i, crewmem in ipairs(get_ship_crew_room(shipManager, 9)) do
        crewmem.extend:InitiateTeleport(shipManager.iShipId,0,0)
    end
end)

script.on_game_event("RAD_JAILER_RETURN_CREW", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.intruder == true then
            local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
            if teleTable.tpTime then
                teleTable.tpTime = nil
            end
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_game_event("RAD_GHOST_BEFORE_FIGHT", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for i=1,8 do 
        location = shipManager:GetRandomRoomCenter() 
        local damage = Hyperspace.Damage()
        damage.fireChance = 8
        shipManager:DamageArea(location, damage, true)
    end
end)

script.on_game_event("RAD_MIRROR_3", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    for crewmem in vter(shipManager.vCrewList) do
        local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
        if teleTable.tpTime then
            teleTable.tpTime = nil
        end
        if not crewmem:IsDrone() then
            crewmem.extend:InitiateTeleport(1,0,0)
        end
    end
end)

script.on_game_event("DEAD_CREW_RAD_REBELOUT", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
        if teleTable.tpTime then
            teleTable.tpTime = nil
        end
        if not crewmem:IsDrone() then
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_game_event("RAD_MAIN_BOARD", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    --local crewList = shipManager.vCrewList
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1)
    --crewList[0].extend:InitiateTeleport(1,0,0)
    for crewmem in vter(shipManager.vCrewList) do
        if not crewmem:IsDrone() then
            crewmem.extend:InitiateTeleport(1,0,0)
        end
    end
    for crewmem in vter(otherShip.vCrewList) do
        if not crewmem:IsDrone() then
            crewmem.extend:InitiateTeleport(1,11,0)
        end
    end
end)

script.on_game_event("RAD_MAIN_DISABLE_DOORS", false, function()
    if Hyperspace.ships.enemy.myBlueprint.blueprintName == "RAD_MAIN_LAB_WALK" then 
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        --local crewList = shipManager.vCrewList
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager(1)
        --crewList[0].extend:InitiateTeleport(1,0,0)
        for crewmem in vter(shipManager.vCrewList) do
            if not crewmem:IsDrone() then
                crewmem.extend:InitiateTeleport(1,0,0)
            end
        end
    end
end)

script.on_game_event("RAD_CIVILIAN_TRANSFORM", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
        if teleTable.tpTime then
            teleTable.tpTime = nil
        end
        if crewmem.iShipId == 0 and (not crewmem:IsDrone()) then 
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_game_event("RAD_MAIN_RETURN", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
        if teleTable.tpTime then
            teleTable.tpTime = nil
        end
        if crewmem.iShipId == 0 and (not crewmem:IsDrone()) then 
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire) 
    local roomId = get_room_at_location(shipManager, location, true)
    for i, crewmem in ipairs(get_ship_crew_room(shipManager, roomId)) do
        if crewmem:GetSpecies() == "drone_repulsor" and crewmem:Functional() then
            return Defines.Chain.CONTINUE, Defines.Evasion.MISS
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
    if shipManager:HasAugmentation("FLESH_HULL") > 0 and projectile.ownerId == shipManager.iShipId then
        local weaponDamage = weaponBlueprint.damage;
        local hulldamage = weaponDamage.iDamage
        if weaponBlueprint.name == "BOMB_HEAL" then
            shipManager:DamageHull(-1, true)
        elseif weaponBlueprint.name == "ARTILLERY_FLESH" then
            shipManager:DamageHull(-1, true)
            projectile:Kill()
        elseif hulldamage > 1 then
            shipManager:DamageHull(hulldamage, true)
        else
            shipManager:DamageHull(1, true)
        end
    end
    if weaponBlueprint.name == "ARTILLERY_FLESH_ENEMY" then
        shipManager:DamageHull(-1, true)
        projectile:Kill()
    end
    if weaponBlueprint.name == "ARTILLERY_RAD_SWTCH" then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
        for crewmem in vter(shipManager.vCrewList) do
            if not crewmem:IsDrone() then
                local roomCount = Hyperspace.ShipGraph.GetShipInfo(otherShip.iShipId):RoomCount()
                local randomRoom = math.random(0, roomCount-1)
                crewmem.extend:InitiateTeleport(otherShip.iShipId,randomRoom,0)
            end
        end
        for crewmem in vter(otherShip.vCrewList) do
            if not crewmem:IsDrone() then
                local roomCount = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):RoomCount()
                local randomRoom = math.random(0, roomCount-1)
                crewmem.extend:InitiateTeleport(shipManager.iShipId,randomRoom,0)
            end
        end
    end
end)

local lastInCombat = false

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.ships.enemy then 
        local inCombat = Hyperspace.ships.enemy._targetable.hostile

        for artillery in vter(Hyperspace.ships.player.artillerySystems) do 
            if artillery.projectileFactory.blueprint.name == "ARTILLERY_RAD_SWTCH" and inCombat == false and lastInCombat == true then 
                for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
                    local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
                    if teleTable.tpTime then
                        teleTable.tpTime = nil
                    end
                    if crewmem.iShipId == 0 then 
                        crewmem.extend:InitiateTeleport(0,0,0)
                    end
                end
            end
        end
        lastInCombat = inCombat
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_ZS_CHARGE")>0 then

        local shieldPower = shipManager.shieldSystem.shields.power
        if shieldPower.first > 0 then
            shieldPower.first = math.max(0, shieldPower.first - 1)
            shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if shipManager and augName == "SHIELD_RECHARGE" and shipManager:HasAugmentation("RAD_ZS_CHARGE")>0 then
        local shieldPower = shipManager:GetShieldPower()
        augValue = augValue + 0.125 + (shieldPower.second*0.125)
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE,
function(Projectile, Drone)
    if Drone.blueprint.name == "DEFENSE_FOCUS" then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        
        --Spawn beam from drone to target
        spaceManager:CreateBeam(
            Hyperspace.Blueprints:GetWeaponBlueprint("RAD_BEAM_NODAMAGE_1"), 
            Drone.currentLocation, 
            Projectile.currentSpace,
            1 - Projectile.ownerId,
            Projectile.target, 
            Hyperspace.Pointf(Projectile.target.x, Projectile.target.y + 1),
            Projectile.currentSpace, 
            1, 
            -1)
        --Destroy target (Beam is not programmed to do so in base game)
        for target in vter(spaceManager.projectiles) do
            if target:GetSelfId() == Drone.currentTargetId then
                target.death_animation:Start(true)
                break
            end
        end
        
        return Defines.Chain.PREEMPT
    end
    return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
    if weaponBlueprint.name == "BEAM_RAD_ZAPPER" then
        log("RADZAPPER FIRE")
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
        local spaceDrones = nil
        if otherShip:HasSystem(4) then
            log("Has drone system")
            spaceDrones = otherShip.droneSystem.drones
        end
        local dronesList = {}
        local dronesCount = 0
        --[[
        for d in vter(spaceManager.drones) do
            if not d:GetOwnerId() == projectile.ownerId then
                table.insert(dronesList, d)
                dronesCount = dronesCount + 1
                log("ADDED DRONE")
            end
        end]]
        if spaceDrones then
            --log("SpaceDrones exists")
            --log(spaceDrones:Size())
            --log("SpaceDrones size > 0")
            --local randNum = math.random(1, spaceDrones:Size())
            local drone = spaceDrones[0]
            local droneLoc = drone:GetWorldLocation()
            --log(droneLoc.x)
            --log(droneLoc.y)
            --log(drone.type)
            if drone.type == 0 then
                spaceManager:CreateBeam(
                    Hyperspace.Blueprints:GetWeaponBlueprint("RAD_LIGHTNING_BEAM"), 
                    projectile.position, 
                    projectile.currentSpace,
                    projectile.ownerId,
                    Hyperspace.Pointf(droneLoc.x, droneLoc.y), 
                    Hyperspace.Pointf(droneLoc.x, droneLoc.y + 10),
                    ((projectile.currentSpace+1)%2), 
                    10, 
                    projectile.heading)
                drone:BlowUp(false)
            elseif drone.type == 1 then
                spaceManager:CreateBeam(
                    Hyperspace.Blueprints:GetWeaponBlueprint("RAD_LIGHTNING_BEAM"), 
                    projectile.position, 
                    projectile.currentSpace,
                    projectile.ownerId,
                    Hyperspace.Pointf(droneLoc.x, droneLoc.y), 
                    Hyperspace.Pointf(droneLoc.x, droneLoc.y + 10),
                    projectile.currentSpace, 
                    10, 
                    0)
                drone:BlowUp(false)
            else

            end
        end
        projectile:Kill()
    end
end)

script.on_game_event("ATLAS_MENU", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_CREDIT") > 0 then
        shipManager:ModifyScrapCount(200,false)
    end
end)

script.on_game_event("START_BEACON_EXPLAIN", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_CREDIT") > 0 then
        shipManager:ModifyScrapCount(100,false)
    end
    if shipManager:HasAugmentation("RAD_CREDIT_2") > 0 then
        shipManager:ModifyScrapCount(2000,false)
    end
    if shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 then
        shipManager:ModifyScrapCount(100,false)
    end
    if shipManager:HasAugmentation("RAD_DRONE_FACTORY") > 0 then 
        for crewmem in vter(shipManager.vCrewList) do 
            if crewmem.iRoomId >= 16 then
                crewmem.extend:InitiateTeleport(0,0,0)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire) 
    local roomId = get_room_at_location(shipManager, location, true)
    --log("damagearea -------------------------------------------------------------------")
    for i, crewmem in ipairs(get_ship_crew_room(shipManager, roomId)) do
        --log(crewmem:GetSpecies())
        if crewmem:GetSpecies() == "drone_repulsor" and crewmem:Functional() then
            --log("projectile miss make")
            return Defines.Chain.CONTINUE, Defines.Evasion.MISS
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager) 
    if shipManager:HasAugmentation("RAD_SYSTEM_DUMB") > 0 then 
        for system in vter(shipManager.vSystemList) do
            --log(system.name)
            --log(system.iActiveManned)
            local manningBonus = system.iActiveManned
            if manningBonus > 0 then
                system.iActiveManned = 4-manningBonus
            end
        end
    end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_SMALL") > 0 then
        for system in vter(shipManager.vSystemList) do
            if system.iSystemType == 0 or system.iSystemType == 3 then
                system:LockSystem(0)
            end
            if system:NeedsRepairing() then
                system:PartialRepair(10,true)
            end
        end
    end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_SCRAM") > 0 then
        local teleTable = userdata_table(shipManager, "mods.scrambler.time")
        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        if teleTable.tpTime and (not commandGui.bPaused) then 
            teleTable.tpTime = math.max(teleTable.tpTime - Hyperspace.FPS.SpeedFactor/16, 0)
            if teleTable.tpTime == 0 then
                 for crewmem in vter(shipManager.vCrewList) do
                    if crewmem.iRoomId > 0 and crewmem.iRoomId < 12 then
                        crewmem.extend:InitiateTeleport(shipManager.iShipId,(crewmem.iRoomId%11)+1,0)
                    end
                end
                teleTable.tpTime = 15
            end
        else
            userdata_table(shipManager, "mods.scrambler.time").tpTime = 15
        end
    end
end)

local lastSuperUp0 = 0
local lastSuperUp1 = 0
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    if shipManager:HasAugmentation("RAD_ZS_UNDER") > 0 and shipManager:HasSystem(0) then
        local lastSuperUp = 0
        if shipManager.iShipId == 0 then 
            lastSuperUp = lastSuperUp0
        else
            lastSuperUp = lastSuperUp1
        end
        local shieldPower = shipManager.shieldSystem.shields.power
        
        local sShieldHP = shieldPower.super.first
        local damageReal = lastSuperUp - sShieldHP

        local pType = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name).typeName
        local sDamage = response.damage
        local superD = response.superDamage
        local sRecover = 0
        if shieldPower.first > 0 and shieldPower.super.first > 0 then
            if pType == "BEAM" and damageReal > 0 then 
                local expectedDamage = damageReal - (math.max(0,shieldPower.first-damage.iShieldPiercing))
                sRecover = damageReal - expectedDamage
            elseif (pType == "LASER" or pType == "BURST") then
                if damage.iShieldPiercing < shieldPower.first then
                    if damage.iDamage > 0 then
                        shieldPower.first = math.max(0, shieldPower.first - 1)
                    end
                    sRecover = superD
                end
            end
            if sRecover > 0 then 
                while sRecover > 0 do 
                    shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
                    sRecover = sRecover - 1
                end
            end
            if damage.iIonDamage > 0 then 
                local ionDamage = damage
                ionDamage.iDamage = 0
                local roomPos = shipManager.shieldSystem.roomId
                shipManager:DamageArea(shipManager:GetRoomCenter(roomPos), ionDamage, true)
            end
        end
        if shipManager.iShipId == 0 then 
            lastSuperUp0 = shieldPower.super.first
        else
            lastSuperUp1 = shieldPower.super.first
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local shieldPower = shipManager.shieldSystem.shields.power
    if shipManager.iShipId == 0 then 
        lastSuperUp0 = shieldPower.super.first
    else
        lastSuperUp1 = shieldPower.super.first
    end
end)

local function createLaserBlast(projectile, weapon)
    local newProj = Hyperspace.LaserBlast(projectile.position, projectile.ownerId, projectile.targetId, projectile.target)
    if projectile.hitSolidSound then newProj.hitSolidSound = projectile.hitSolidSound end
    if projectile.hitShieldSound then newProj.hitShieldSound = projectile.hitShieldSound end
    --[[if projectile.missSound then newProj.missSound = projectile.missSound end]]
    newProj.entryAngle = projectile.entryAngle
    newProj.flight_animation = projectile.flight_animation
    newProj.death_animation = projectile.death_animation
    newProj.heading = projectile.heading
    newProj.speed = projectile.speed
    newProj:SetDamage(projectile.damage)
    newProj.spinAngle = projectile.spinAngle
    newProj.spinSpeed = projectile.spinSpeed
    return newProj
end
local function createLaserBurst(projectile, weapon)
end
local function createMissile(projectile, weapon)
    local spaceManager = Hyperspace.App.world.space
    local missile = spaceManager:CreateMissile(
        weapon.blueprint,
        projectile.position,
        projectile.currentSpace,
        projectile.ownerId,
        projectile.target,
        projectile.destinationSpace,
        projectile.heading)
    return missile
end
local function createBomb(projectile, weapon)
end
local function createBeam(projectile, weapon)
end

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local shipManager = Hyperspace.ships(weapon.iShipId)
    if shipManager:HasAugmentation("RAD_WM_MULTISHOT") > 0 then
        if not userdata_table(projectile, "mods.rad.multishot").wasDuplicated then
            local projectileNew = nil
            if weapon.blueprint.typeName == "LASER" then
                print("CREATE LASER")
                projectileNew = createLaserBlast(projectile, weapon)
            elseif weapon.blueprint.typeName == "BURST" then
                print("CREATE LASER BURST")
                projectileNew = createLaserBurst(projectile, weapon)
            elseif weapon.blueprint.typeName == "MISSILES" then
                print("CREATE MISSILE")
                projectileNew = createMissile(projectile, weapon)
            elseif weapon.blueprint.typeName == "BOMB" then
                print("CREATE BOMB")
                projectileNew = createBomb(projectile, weapon)
            elseif weapon.blueprint.typeName == "BEAM" then
                print("CREATE BEAM")
                projectileNew = createBeam(projectile, weapon)
            end
            if projectileNew then
                print("ADD PROJECTILE")
                userdata_table(projectileNew, "mods.rad.multishot").wasDuplicated = true
                weapon.queuedProjectiles:push_back(projectileNew)
            end
        end
    end
    if shipManager:HasAugmentation("RAD_WM_BIGSHOT") > 0 then
        local damage = projectile.damage
        damage.iDamage = damage.iDamage * 2
        damage.iIonDamage = damage.iIonDamage * 2
        damage.iSystemDamage = damage.iSystemDamage * 2
        projectile:SetDamage(damage)
    end
end)

--[[
mods.rad.multiExclusions = {}
local multiExclusions = mods.rad.multiExclusions
multiExclusions["RAD_CLUSTER_MISSILE"] = true
multiExclusions["RAD_CLUSTER_MISSILE_2"] = true
multiExclusions["RAD_CLUSTER_MISSILE_3"] = true
multiExclusions["RAD_LIGHTNING_1"] = true
multiExclusions["RAD_LIGHTNING_2"] = true
multiExclusions["RAD_LIGHTNING_3"] = true
multiExclusions["RAD_LIGHTNING_ION"] = true
multiExclusions["RAD_LIGHTNING_FIRE"] = true
multiExclusions["RAD_BEAM_BURST_1"] = true
multiExclusions["RAD_BEAM_BURST_2"] = true
multiExclusions["RAD_BEAM_BURST_3"] = true
multiExclusions["RAD_LIGHT_BEAM"] = true
multiExclusions["RAD_TRASH_BEAM"] = true
multiExclusions["DRONE_LASER_DEFENSE_INVIS"] = true
multiExclusions["ARTILLERY_FLESH"] = true
multiExclusions["ARTILLERY_RAD_ZS"] = true
multiExclusions["ARTILLERY_RAD_SWTCH"] = true
multiExclusions["ARTILLERY_FLESH_ENEMY"] = true
multiExclusions["ARTILLERY_RAD_CORVETTE"] = true

--local multiProj = {}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    --print(projectile.missed)
    local excludedWeapons = multiExclusions[weaponName]
    if shipManager:HasAugmentation("RAD_WM_BIGSHOT") then
        excludedWeapons = nil
    end
    if (shipManager:HasAugmentation("RAD_WM_MULTISHOT") > 0) and (not excludedWeapons) --[[and (not projectile.missed) then
        --[[print("split")
        if multiProj[projectile:GetSelfId()] then
            print("END multiProj")
            multiProj[projectile:GetSelfId()] = nil
            return
        end
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local weaponType = weapon.blueprint.typeName
        --log(weaponType)
        local damage = projectile.damage
        local newDamage = Hyperspace.Damage()
        if (shipManager:HasAugmentation("RAD_WM_BIGSHOT") > 0 ) then
            newDamage.iDamage = damage.iDamage
            newDamage.iIonDamage = damage.iIonDamage
            newDamage.iSystemDamage = damage.iSystemDamage
        else
            --print("round down")
            newDamage.iDamage = math.floor(damage.iDamage/2)
            newDamage.iIonDamage = math.floor(damage.iIonDamage/2)
            newDamage.iSystemDamage = math.floor(damage.iSystemDamage/2)
        end

        newDamage.fireChance = damage.fireChance
        newDamage.breachChance = damage.breachChance
        newDamage.stunChance = damage.stunChance
        newDamage.iPersDamage = damage.iPersDamage
        newDamage.iStun = damage.iStun
        newDamage.iShieldPiercing = damage.iShieldPiercing

        newDamage.ownerId = damage.ownerId
        newDamage.selfId = damage.selfId

        newDamage.bHullBuster = damage.bHullBuster
        newDamage.bLockdown = damage.bLockdown
        newDamage.crystalShard = damage.crystalShard
        newDamage.bFriendlyFire = damage.bFriendlyFire
        --log(newDamage.iDamage)
        

        --log("AAAAAAAA")
        damage = projectile.damage
        local newDamage2 = projectile.damage
        --log(newDamage2.iDamage)
        if (shipManager:HasAugmentation("RAD_WM_BIGSHOT") > 0 ) then
            newDamage2.iDamage = damage.iDamage
            newDamage2.iIonDamage = damage.iIonDamage
            newDamage2.iSystemDamage = damage.iSystemDamage
        else
            --print("round up")
            newDamage2.iDamage = math.ceil(damage.iDamage/2)
            newDamage2.iIonDamage = math.ceil(damage.iIonDamage/2)
            newDamage2.iSystemDamage = math.ceil(damage.iSystemDamage/2)
        end

        newDamage.fireChance = damage.fireChance
        newDamage.breachChance = damage.breachChance
        newDamage.stunChance = damage.stunChance
        newDamage.iPersDamage = damage.iPersDamage
        newDamage.iStun = damage.iStun
        newDamage.iShieldPiercing = damage.iShieldPiercing

        newDamage2.ownerId = damage.ownerId
        newDamage2.selfId = damage.selfId

        newDamage2.bHullBuster = damage.bHullBuster
        newDamage2.bLockdown = damage.bLockdown
        newDamage2.crystalShard = damage.crystalShard
        newDamage2.bFriendlyFire = damage.bFriendlyFire

        --log(newDamage2.iDamage)
        if weaponType == "LASER" or weaponType == "BURST" then 
            local laser = spaceManager:CreateLaserBlast(
                weapon.blueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace,
                projectile.heading)
            laser:SetDamage(newDamage2)
            --laser.missed = true
            --multiProj[laser:GetSelfId()] = true
        elseif weaponType == "MISSILES" then 
            local missile = spaceManager:CreateMissile(
                weapon.blueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace,
                projectile.heading)
            missile:SetDamage(newDamage2)
            --missile.missed = true
            --multiProj[missile:GetSelfId()] = true
        elseif weaponType == "BOMB" then 
            local bomb = spaceManager:CreateBomb(
                weapon.blueprint,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace)
            bomb:SetDamage(newDamage2)
            --bomb.missed = true
            --multiProj[bomb:GetSelfId()] = true
        elseif weaponType == "BEAM" then 
            --log("BEAM")
            local beam = spaceManager:CreateBeam(
                weapon.blueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target2,
                projectile.target1,
                projectile.destinationSpace,
                projectile.length,
                projectile.heading)
            beam:SetDamage(newDamage2)
            --beam.missed = true
            --multiProj[beam:GetSelfId()] = true
        end
        projectile:SetDamage(newDamage)
    --[[elseif projectile.missed then
        projectile.missed = false
    end
end)]]

--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

--[[script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    --print((projectile.destinationSpace+1)%2)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
    if (shipManager:HasAugmentation("RAD_WM_BIGSHOT") > 0) and (shipManager:HasAugmentation("RAD_WM_MULTISHOT") <= 0) then
        local damage = projectile.damage
        local newDamage = Hyperspace.Damage()
        newDamage.iDamage = (damage.iDamage*2)
        newDamage.fireChance = damage.fireChance
        newDamage.breachChance = damage.breachChance
        newDamage.stunChance = damage.stunChance
        newDamage.iIonDamage = (damage.iIonDamage*2)
        newDamage.iSystemDamage = (damage.iSystemDamage*2)
        newDamage.iPersDamage = damage.iPersDamage
        newDamage.iStun = damage.iStun

        newDamage.ownerId = damage.ownerId
        newDamage.selfId = damage.selfId
        newDamage.iShieldPiercing = damage.iShieldPiercing

        newDamage.bHullBuster = damage.bHullBuster
        newDamage.bLockdown = damage.bLockdown
        newDamage.crystalShard = damage.crystalShard
        newDamage.bFriendlyFire = damage.bFriendlyFire
        
        projectile:SetDamage(newDamage)
    end
end)]]

--[[script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if augName == "AUTO_COOLDOWN" and shipManager:HasAugmentation("RAD_WM_BIGSHOT")>0 then
        augValue = augValue / 2
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)]]--

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)

end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile,weapon) 

end)

--[[script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL,function() end, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local weaponlist = nil
        if shipManager:HasSystem(3) then
            weaponlist = shipManager:GetWeaponList()
            local weaponSlot = 0
            for weapon in vter(weaponlist) do
                if weapon.blueprint.name == "RAD_SHIELD_CHAINER" then
                    local slot1X = 141
                    local slotY = 643
                    local weaponlist = {}
                    if shipManager then
                        for system in vter(shipManager.vSystemList) do
                            if (system.iSystemType == 0 or system.iSystemType == 1 or system.iSystemType == 2 or system.iSystemType == 5 or system.iSystemType == 13) then
                                slot1X = slot1X + 36
                            elseif (system.iSystemType == 9 or system.iSystemType == 10 or system.iSystemType == 11 or system.iSystemType == 14) then
                                slot1X = slot1X + 54
                            elseif system.iSystemType >= 15 then
                                slot1X = slot1X + 36
                            end
                        end
                    end
                    local slot1X = slot1X + (weaponSlot * 97)

                    Graphics.freetype.easy_print(0, slot1X, slotY, "ahhhah")
                end
                weaponSlot = weaponSlot + 1
            end
        end
    end
end)


script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile.extend.name == "RAD_TRASH_BEAM" then 
        log("TRASH FIRE")
        local pointLoc = Hyperspace.Point(math.Round(location.x,0),math.Round(location.y,0))
        local roomSlot = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetClosestSlot(pointLoc)
        local projData = userdata_table(projectile, "mods.rad.trashbeam")
        if projData.slotId then 
            log("SLOTID EXISTS")
            log(roomSlot.slotId)
            local oldSlot = projData.slotId
            log(oldSlot)
            if not roomSlot.slotId == oldSlot then 
                log("CREATE ASTEROID")
                local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
                local asteroid = spaceManager:CreateAsteroid(Hyperspace.Pointf(0,0), ((projectile.currentSpace+1)%2), projectile.ownerId, location, projectile.currentSpace, projectile.heading);
            end
            projData.slotId = roomSlot.slotId
        else
            log("CREATE ASTEROID FIRST")
            projData.slotId = roomSlot.slotId
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local asteroid = spaceManager:CreateAsteroid(Hyperspace.Pointf(0,0), ((projectile.currentSpace+1)%2), projectile.ownerId, location, projectile.currentSpace, projectile.heading);
        end
    end
end)]]

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if projectile.extend.name == "RAD_TRASH_BEAM" and realNewTile then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local asteroid = spaceManager:CreateAsteroid(Hyperspace.Pointf(1000,1000), projectile.currentSpace, projectile.ownerId, location, ((projectile.currentSpace+1)%2), projectile.heading)
    end 
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
    if shipManager:HasAugmentation("RAD_SUPERHULL") > 0   then
        hullData.tempHp = math.floor(shipManager:GetAugmentationValue("RAD_SUPERHULL"))
    else
        hullData.tempHp = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --log(beamHitType)
    if shipManager:HasAugmentation("RAD_SUPER_HULL") > 0 and beamHitType == 2 then
       local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - 1
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end) 


script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --log(beamHitType)
    if shipManager:HasAugmentation("RAD_REFLECT_HULL") > 0 and beamHitType == 2 then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local WeaponBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId+1)%2)
        local randomRoom = otherShip:GetRandomRoomCenter()
        local beam = spaceManager:CreateBeam(WeaponBlueprint, 
            location, 
            shipManager.iShipId, 
            shipManager.iShipId, 
            Hyperspace.Pointf(randomRoom.x,randomRoom.y-5), 
            Hyperspace.Pointf(randomRoom.x,randomRoom.y+5), 
            otherShip.iShipId, 
            10, 
            (math.random()-0.5))

        local beam = spaceManager:CreateBeam(WeaponBlueprint, 
            location, 
            shipManager.iShipId, 
            ((shipManager.iShipId+1)%2), 
            Hyperspace.Pointf(location.x+1000,location.y), 
            Hyperspace.Pointf(location.x+1010,location.y), 
            shipManager.iShipId, 
            10, 
            (math.random()-0.5))
        beam.speed_magnitude = 1

        shipManager:DamageHull((math.ceil(damage.iDamage/2) * -1), true)

        local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - 1
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if shipManager:HasAugmentation("RAD_TIME_HULL") > 0 and beamHitType == 2 then
        local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - 1
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
        local temporalSystem = shipManager:GetSystem(20)
        temporalSystem.lockTimer:Stop()
        temporalSystem.iLockCount = 0
        temporalSystem.iTempPowerLoss = 0
        --temporalSystem:Restart()
        local weaponList = {}
        local weaponCount = 0
        for weapon in vter(shipManager:GetWeaponList()) do
            --log(weapon.name)
            if (not weapon:IsChargedGoal()) and weapon.powered then
                log("Add weapon")
                table.insert(weaponList, weapon)
                weaponCount = weaponCount + 1
            end
        end
        --log(weaponCount)
        if weaponCount > 0 then
            local randomNum = math.random(1, weaponCount)
            for k,v in pairs(weaponList) do 
                if k == randomNum then
                    v:ForceCoolup()
                end
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("RAD_REFLECT_HULL") > 0 or shipManager:HasAugmentation("RAD_TIME_HULL") > 0 or shipManager:HasAugmentation("RAD_SUPER_HULL") then
        local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - 1
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
        if shipManager:HasAugmentation("RAD_TIME_HULL") > 0 then
            local temporalSystem = shipManager:GetSystem(20)
            temporalSystem.lockTimer:Stop()
            temporalSystem.iLockCount = 0
            temporalSystem.iTempPowerLoss = 0
            --temporalSystem:Restart()
            local weaponList = {}
            local weaponCount = 0
            for weapon in vter(shipManager:GetWeaponList()) do
                --log(weapon.name)
                if not weapon:IsChargedGoal() then 
                    log("Add weapon")
                    table.insert(weaponList, weapon)
                    weaponCount = weaponCount + 1
                end
            end
            --log(weaponCount)
            if weaponCount > 0 then
                local randomNum = math.random(1, weaponCount)
                for k,v in pairs(weaponList) do 
                    if k == randomNum then
                        v:ForceCoolup()
                    end
                end
            end
        end
    end
end)

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local hullData = userdata_table(shipManager, "mods.rad.reflecthull")
        if hullData.tempHp then
            local hullHP = hullData.tempHp
            local xPos = 380
            local yPos = 47
            local xText = 413
            local yText = 58
            local tempHpImage = Hyperspace.Resources:CreateImagePrimitiveString(
                "statusUI/rad_tempHull.png",
                xPos,
                yPos,
                0,
                Graphics.GL_Color(1, 1, 1, 1),
                1.0,
                false)
            Graphics.CSurface.GL_RenderPrimitive(tempHpImage)
            Graphics.freetype.easy_print(0, xText, yText, hullHP)
        end
    end
end, function() end)



--[[script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if augName == "UPG_CLONEBAY_DNA" and shipManager:HasAugmentation("RAD_BULLET_HELL")>0 then
        augValue = 1
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)]]

--[[local repairData = userdata_table(system, "mods.rad.repairRate")
                local crewInRoom = get_ship_crew_room(shipManager, system.roomId)
                local crewRoomBool = false
                for k,v in pairs(crewInRoom) do
                    crewRoomBool = true
                end
                if crewRoomBool then
                    repairData.repairFloat = system.fRepairOverTime
                elseif repairData.repairFloat then
                    system.fRepairOverTime = repairData.repairFloat
                end
            else
                local repairData = userdata_table(system, "mods.rad.repairRate")
                if repairData.repairFloat then
                    repairData.repairFloat = nil
                end]]
local lastBoolCloak = {false,false}

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    --log(shipManager.iShipId)
    if shipManager:HasAugmentation("RAD_CREVERSAL") > 0 then 
        local cloakSystem = shipManager.cloakSystem
        
        --log(cloakSystem.timer.currTime)
        --log(cloakSystem.timer.currGoal)
        if cloakSystem.timer:Running() and cloakSystem.timer.currTime >= (cloakSystem.timer.currGoal/2) then 
            --cloakSystem.timer:Stop()
            cloakSystem.timer.currTime = cloakSystem.timer.currGoal
        end
        if cloakSystem.bTurnedOn and (not lastBoolCloak[shipManager.iShipId]) then 
            --log("CLOAK START")
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2) 
            --cloakSystem.timer.currGoal = cloakSystem.timer.currGoal/2
            for projectile in vter(spaceManager.projectiles) do
                if projectile.ownerId == ((shipManager.iShipId+1)%2) then
                    local pType = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name).typeName
                    if pType == "LASER" or pType == "BURST" or pType == "MISSILES" or pType == "BOMB" then 
                        projectile.ownerId = shipManager.iShipId
                        projectile:SetDestinationSpace(otherShip.iShipId)
                        projectile.target = otherShip:GetRandomRoomCenter()
                        projectile:ComputeHeading()
                    end
                end
            end
        end
        lastBoolCloak[shipManager.iShipId] = cloakSystem.bTurnedOn
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    --log(shipManager.iShipId)
    if shipManager:HasAugmentation("RAD_CBEAM") > 0 then 
        local cloakSystem = shipManager.cloakSystem
        --log(lastBoolCloak[shipManager.iShipId])
        --log(cloakSystem.bTurnedOn)
        --log(cloakSystem.timer.currTime)
        --log(cloakSystem.timer.currGoal)
        if cloakSystem.timer:Running() and cloakSystem.timer.currTime >= (cloakSystem.timer.currGoal/2) then 
            --cloakSystem.timer:Stop()
            cloakSystem.timer.currTime = cloakSystem.timer.currGoal
        end
        if cloakSystem.bTurnedOn and (not lastBoolCloak[shipManager.iShipId]) then 
            --log("CLOAK START")
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2) 
            local shieldRoom = 0
            if otherShip:HasSystem(0) then
                shieldRoom = otherShip.shieldSystem.roomId
            end
            local weaponRoom = 1
            if otherShip:HasSystem(3) then
                weaponRoom = otherShip.weaponSystem.roomId
            end
            local beam = spaceManager:CreateBeam(
                Hyperspace.Blueprints:GetWeaponBlueprint("RAD_CLOAKBEAM"),
                Hyperspace.Pointf(426,174),
                shipManager.iShipId,
                shipManager.iShipId,
                otherShip:GetRoomCenter(shieldRoom),
                otherShip:GetRoomCenter(weaponRoom),
                otherShip.iShipId,
                1000,
                0)
            local damageNew = beam.damage
            local power = shipManager.weaponSystem.powerState.first
            damageNew.iDamage = damageNew.iDamage + math.floor(power/2)
            beam:SetDamage(damageNew)
        end
        lastBoolCloak[shipManager.iShipId] = cloakSystem.bTurnedOn
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    --log(shipManager.iShipId)
    if shipManager:HasAugmentation("RAD_CHACK") > 0 then 
        local cloakSystem = shipManager.cloakSystem
        
        if cloakSystem.bTurnedOn and (not lastBoolCloak[shipManager.iShipId]) then 
            --log("CLOAK START")
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2) 
            --cloakSystem.timer.currGoal = cloakSystem.timer.currGoal*1.5
            local hackWeapon = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_HACK1")
            if shipManager.cloakSystem.powerState.first == 2 then 
                --log("2")
                hackWeapon = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_HACK2")
            elseif shipManager.cloakSystem.powerState.first == 3 then 
                --log("2")
                hackWeapon = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_HACK3")
            end
            shipManager.weaponSystem:SetHackingLevel(1)
            spaceManager:CreateBomb(
                    hackWeapon,
                    otherShip.iShipId,
                    shipManager:GetRoomCenter(shipManager.weaponSystem.roomId),
                    shipManager.iShipId)

            if otherShip:HasSystem(0) then 
                local shieldSystem = otherShip.shieldSystem
                shieldSystem:SetHackingLevel(1)
                spaceManager:CreateBomb(
                    hackWeapon,
                    shipManager.iShipId,
                    otherShip:GetRoomCenter(otherShip.shieldSystem.roomId),
                    otherShip.iShipId)
            end

            --for drones
        end
        if (not cloakSystem.bTurnedOn) and lastBoolCloak[shipManager.iShipId] then 
            --log("CLOAK END")
            local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
            local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
            shipManager.weaponSystem:SetHackingLevel(0)
            if otherShip:HasSystem(0) then 
                local shieldSystem = otherShip.shieldSystem
                shieldSystem:SetHackingLevel(0)
            end
        end
        lastBoolCloak[shipManager.iShipId] = cloakSystem.bTurnedOn
    end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_LOW_WEAPON") > 0 then 
        for weapon in vter(shipManager:GetWeaponList()) do 
            if weapon.requiredPower > 1 then 
                weapon:SetCooldownModifier(-1)
            end
        end 
    end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_CUTTER_OXY") > 0 then 
        shipManager.oxygenSystem:AddDamage(1)
    end
end)

--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_LOW_SHIELD") > 0 then 
        local shieldPower = shipManager.shieldSystem.shields.power
        log(shieldPower.first)
        log(shieldPower.second)
        log(shipManager.shieldSystem.powerState.first)
        shieldPower.second = (math.max(1, math.floor(shipManager.shieldSystem.powerState.first/4)))
    end
end)]]

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if shipManager and augName == "SHIELD_RECHARGE" and shipManager:HasAugmentation("RAD_LOW_SHIELD")>0 then
        local shieldPower = shipManager:GetShieldPower()
        augValue = augValue + (0.25 * math.floor(shipManager.shieldSystem.powerState.first/2))
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)


------------------------
-- CUSTOM DRONE ORBIT --
------------------------
local escortEllipse = {
    center = {
        x = 281,
        y = 176
    }, 
    a = 402.5,
    b = 253
}
local droneSpeedFactor = 1.6
local activeProjectileIds = {}

local calculate_coord_offset = function(angleFromCenter)
    local angleCos = escortEllipse.b*math.cos(angleFromCenter)
    local angleSin = escortEllipse.a*math.sin(angleFromCenter)
    local denom = math.sqrt(angleCos^2 + angleSin^2)
    return (escortEllipse.a*angleCos)/denom, (escortEllipse.b*angleSin)/denom
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local hasChaffGun = false
    --local artilleryPower = 0
    for artillery in vter(Hyperspace.ships.player.artillerySystems) do 
        if artillery.projectileFactory.blueprint.name == "ARTILLERY_RAD_CORVETTE" then 
            hasChaffGun = true
            artillery.projectileFactory:ForceCoolup()
        end
    end
    if hasChaffGun then 
        log("start")
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        for i=1, 10 do
            log("debris_large")
            local debrisL = spaceManager:CreateBurstProjectile(
                Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_RAD_CORVETTE"),
                "debris_large",
                false,
                Hyperspace.Pointf(0,0)
                ,0
                ,0
                ,Hyperspace.Pointf(-1,0),
                0,
                0)
        end
        for i=1, 6 do
            log("debris_med")
            local debrisM = spaceManager:CreateBurstProjectile(Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_RAD_CORVETTE"),"debris_med",false,Hyperspace.Pointf(0,0),0,0,Hyperspace.Pointf(-1,0),0,0)
        end
        for i=1, 4 do
            log("debris_small")
            local debrisS = spaceManager:CreateBurstProjectile(Hyperspace.Blueprints:GetWeaponBlueprint("ARTILLERY_RAD_CORVETTE"),"debris_small",false,Hyperspace.Pointf(0,0),0,0,Hyperspace.Pointf(-1,0),0,0)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    -- Iterate through all defense drones if the ship is escort duty
    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
    local stillActiveProj = {}
    local projCount = 0
    --[[for artillery in vter(Hyperspace.ships.player.artillerySystems) do 
        if artillery.projectileFactory.blueprint.name == "ARTILLERY_RAD_CORVETTE" and artillery.projectileFactory:IsChargedGoal() then 
            artillery.projectileFactory:Fire({Hyperspace.Pointf(0,0)},1)
        end
    end]]
    for projectile in vter(spaceManager.projectiles) do
        if projectile.extend.name == "ARTILLERY_RAD_CORVETTE" then 
            projCount = projCount + 1
            if projCount > 250 then
                projectile:Kill()
                return
            end
            stillActiveProj[projectile.selfId] = true
            local xOffset = nil
            local yOffset = nil

            if not activeProjectileIds[projectile.selfId] then
                --projectile.ownerId = 1
                projectile.destinationSpace = projectile.currentSpace
                projectile.speed_magnitude = projectile.speed_magnitude * ((math.random()/2)+0.75)
                activeProjectileIds[projectile.selfId] = true
                xOffset, yOffset = calculate_coord_offset((Hyperspace.random32()%360)*(math.pi/180))
                projectile.position = (Hyperspace.Pointf(
                    escortEllipse.center.x + xOffset,
                    escortEllipse.center.y + yOffset))
                projectile.target = (Hyperspace.Pointf(
                    escortEllipse.center.x + xOffset,
                    escortEllipse.center.y + yOffset))
            end
            --log(Hyperspace.FPS.SpeedFactor)

            local lookAhead = projectile.speed_magnitude*Hyperspace.FPS.SpeedFactor
            xOffset, yOffset = calculate_coord_offset(math.atan(
                projectile.position.y - escortEllipse.center.y,
                projectile.position.x - escortEllipse.center.x))
            local xIntersect = escortEllipse.center.x + xOffset
            local yIntersect = escortEllipse.center.y + yOffset
            local tanAngle = math.atan((escortEllipse.b^2/escortEllipse.a^2)*(xOffset/yOffset))
            if (projectile.position.y < escortEllipse.center.y) then
                --[[projectile.position = Hyperspace.Pointf(
                    xIntersect + lookAhead*math.cos(tanAngle),
                    yIntersect - lookAhead*math.sin(tanAngle))]]
                projectile.target = Hyperspace.Pointf(
                    xIntersect + 2*lookAhead*math.cos(tanAngle),
                    yIntersect - 2*lookAhead*math.sin(tanAngle))
            else
                --[[projectile.position = Hyperspace.Pointf(
                    xIntersect - lookAhead*math.cos(tanAngle),
                    yIntersect + lookAhead*math.sin(tanAngle))]]
                projectile.target = Hyperspace.Pointf(
                    xIntersect - 2*lookAhead*math.cos(tanAngle),
                    yIntersect + 2*lookAhead*math.sin(tanAngle))
            end
            projectile:ComputeHeading()
        end
    end
    -- Clean out inactive drone IDs

    for projId in pairs(activeProjectileIds) do
        if not stillActiveProj[projId] then
            activeProjectileIds[projId] = nil
        end
    end
end)

script.on_game_event("COMBAT_CHECK_REAL", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_LOW_SHIELD") > 0 then 
        Hyperspace.playerVariables.rad_n_replace = 0
        local weaponList = shipManager:GetWeaponList()
        if not weaponList then return end
        for weapon in vter(weaponList) do
            if weapon and weapon.blueprint then
                shipManager:RemoveItem(weapon.blueprint.name)
                Hyperspace.playerVariables.rad_n_replace = Hyperspace.playerVariables.rad_n_replace + 1
            end
        end
    end
    if shipManager:HasAugmentation("RAD_SUPER_RANDOM") > 0 then
        Hyperspace.playerVariables.rad_n_replace_d = 0
        Hyperspace.playerVariables.rad_n_replace_c = 0
        local droneList = shipManager:GetDroneList()
        if not droneList then return end
        for drone in vter(droneList) do
            if drone and drone.blueprint then
                shipManager:RemoveItem(drone.blueprint.name)
                Hyperspace.playerVariables.rad_n_replace_d = Hyperspace.playerVariables.rad_n_replace_d + 1
            end
        end
        for crew in vter(shipManager.vCrewList) do
            if crew and crew.iShipId == 0 and (not crew:IsDrone()) and crew.blueprint then
                --userdata_table(crew, "mods.rad.killtime").killTime = 0.15
                --print(crew.blueprint.name)
                crew:Kill(true)
                Hyperspace.playerVariables.rad_n_replace_c = Hyperspace.playerVariables.rad_n_replace_c + 1
            end
        end
    end
end)

script.on_game_event("RAD_POWER_ROLL", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_SUPER_RANDOM") > 0 then 
        for weapon in vter(shipManager:GetWeaponList()) do
            weapon.requiredPower = math.floor(math.random(1, 8)/2)
        end
        for drone in vter(shipManager:GetDroneList()) do
            drone.powerRequired = math.floor(math.random(1, 8)/2)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local teleTable = userdata_table(crewmem, "mods.rad.killtime")
    if teleTable.killTime then
        if crewmem.bDead then
            teleTable.killTime = nil
        else
            local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
            if not commandGui.bPaused then 
                teleTable.killTime = math.max(teleTable.killTime - Hyperspace.FPS.SpeedFactor/16, 0)
                if teleTable.killTime == 0 then
                    crewmem:Kill(true)
                    teleTable.killTime = nil
                end
            end
        end
    end
end)

script.on_game_event("COMBAT_CHECK_FAIL_REAL", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_LOW_SHIELD") > 0 then 
        Hyperspace.playerVariables.rad_n_replace = 0
        local weaponList = shipManager:GetWeaponList()
        if not weaponList then return end
        for weapon in vter(weaponList) do
            if weapon and weapon.blueprint then
                shipManager:RemoveItem(weapon.blueprint.name)
                Hyperspace.playerVariables.rad_n_replace = Hyperspace.playerVariables.rad_n_replace + 1
            end
        end
    end
    if shipManager:HasAugmentation("RAD_SUPER_RANDOM") > 0 then
        Hyperspace.playerVariables.rad_n_replace_d = 0
        local droneList = shipManager:GetDroneList()
        if not droneList then return end
        for drone in vter(droneList) do
            if drone and drone.blueprint then
                shipManager:RemoveItem(drone.blueprint.name)
                Hyperspace.playerVariables.rad_n_replace_d = Hyperspace.playerVariables.rad_n_replace_d + 1
            end
        end
    end
    if shipManager:HasAugmentation("RAD_SUPER_RANDOM") > 0 then
        --Hyperspace.playerVariables.rad_n_replace_c = 0
        local crewList = shipManager.vCrewList
        if not crewList then return end
        for crew in vter(crewList) do
            if crew and crew.iShipId == 0 and crew.blueprint then
                crew:Kill(true)
                local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_REPLACEMENT_WEAPONS",false,-1)
                --Hyperspace.playerVariables.rad_n_replace_c = Hyperspace.playerVariables.rad_n_replace_c + 1
            end
        end
    end
end)

--[[script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local excludedWeapons = multiExclusions[weaponName]
    if shipManager:HasAugmentation("RAD_LOW_WEAPON") > 0 and (not excludedWeapons) then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local weaponType = weaponBlueprint.typeName
        if weaponType == "LASER" or weaponType == "BURST" then 
            local laser = spaceManager:CreateLaserBlast(
                weaponBlueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace,
                projectile.heading)
        elseif weaponType == "MISSILES" then 
            local missile = spaceManager:CreateMissile(
                weaponBlueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace,
                projectile.heading)
        elseif weaponType == "BOMB" then 
            local bomb = spaceManager:CreateBomb(
                weaponBlueprint,
                projectile.ownerId,
                projectile.target,
                projectile.destinationSpace)
        elseif weaponType == "BEAM" then 
            --log("BEAM")
            local beam = spaceManager:CreateBeam(
                weaponBlueprint,
                projectile.position,
                projectile.currentSpace,
                projectile.ownerId,
                projectile.target2,
                projectile.target1,
                projectile.destinationSpace,
                projectile.length,
                projectile.heading)
        end
    end
end)]]

--[[script.on_game_event("RAD_MAIN_RETURN2", false, function()
    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
    worldManager:ClearLocation()
    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_1",false,-1)
end)

script.on_game_event("RAD_MAIN_2", false, function()
    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
    worldManager:ClearLocation()
    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_2_SHIP",false,-1)

    --local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    --commandGui:RunCommand("EVENT RAD_MAIN_2_SHIP")
end)

script.on_game_event("RAD_MAIN_3", false, function()
    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
    worldManager:ClearLocation()
    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_3_SHIP",false,-1)
    
    --local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    --commandGui:RunCommand("EVENT RAD_MAIN_3_SHIP")

    --local EventGenerator = Hyperspace.Global.GetInstance():GetEventGenerator()
    --local shipEvent = EventGenerator:GetShipEvent("RAD_MAIN_3_SHIP")
    --local locationEvent = EventGenerator:CreateEvent("PIRATE",worldManager.currentDifficulty,true)
    --worldManager:CreateShip(shipEvent, false)
    --worldManager:UpdateLocation(locationEvent)
    --Hyperspace.CommandGui:RunCommand("EVENT PIRATE")
    --Hyperspace.EventGenerator:CreateEvent("EVENT PIRATE",0,true)
    --Hyperspace.CommandConsole.GetInstance():RunCommand(commandGui,"EVENT RAD_MAIN_3_SHIP")
end)

script.on_game_event("DESTROYED_RAD_SCIENCE_REBELAUTO_2", false, function()
    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
    worldManager:ClearLocation()
    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SCIENCE_QUEST_FIGHT_2",false,-1)
    local shipManager = Hyperspace.ships.enemy
    print(shipManager.bDestroyed)
    print(shipManager.bInvincible)
    print(shipManager.bWasSafe)
    print(shipManager.myBlueprint.blueprintName)
    shipManager.bDestroyed = false
    shipManager.bInvincible = false
    shipManager.bWasSafe = false
    local playerShipManager = Hyperspace.ships.player
    print(playerShipManager.bDestroyed)
    print(playerShipManager.bInvincible)
    print(playerShipManager.bWasSafe)
    playerShipManager.bDestroyed = false
    playerShipManager.bInvincible = false
    playerShipManager.bWasSafe = false
    --local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    --commandGui:RunCommand("EVENT RAD_SCIENCE_QUEST_FIGHT_2")
end)]]

local hasWeapon = true
local hasShield = true
local hasEngine = true
--local hasPilot = true
local hasHack = true
local hasClone = true

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager.iShipId == 1 and shipManager.myBlueprint.blueprintName == "RAD_MAIN_LAB_WALK" then
        local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
        --local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        local crewInTeleRoom = false
        for crewmem in vter(shipManager.vCrewList) do
            --log(crewmem.iRoomId)

            if crewmem.iRoomId == 2 and crewmem.iShipId == 0 then
                crewInTeleRoom = true
            elseif crewmem.iRoomId == 1 and hasWeapon and crewmem.iShipId == 0 then 
                hasWeapon = false
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_WEAPON",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_WEAPON")
            elseif crewmem.iRoomId == 6 and hasShield and crewmem.iShipId == 0 then 
                hasShield = false
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_SHIELD",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_SHIELD")
            elseif crewmem.iRoomId == 5 and hasEngine and crewmem.iShipId == 0 then 
                hasEngine = false
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_ENGINE",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_ENGINE")
            elseif crewmem.iRoomId == 4 and hasClone and crewmem.iShipId == 0 then 
                hasClone = false
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_CLONE",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_CLONE")
            elseif crewmem.iRoomId == 12 and Hyperspace.playerVariables.loc_rad_board_pilot == 0 and (not hasHack) and crewmem.iShipId == 0 then 
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_PILOT",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_PILOT")
            elseif crewmem.iRoomId == 7 and hasHack and crewmem.iShipId == 0 then 
                hasHack = false
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MAIN_HACK",false,-1)
                --commandGui:RunCommand("LOADEVENT RAD_MAIN_HACK")
            end
        end
        if crewInTeleRoom then
            Hyperspace.playerVariables.loc_rad_board_charged = 1
        else
            Hyperspace.playerVariables.loc_rad_board_charged = 0
        end
    end
end)


--[[script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    print("PROJECTILE_FIRE")
    print(projectile.extend.name)
    print(weapon.name)
    if modifiedWeaponCooldown[weapon.name] then
        weapon:SetCooldownModifier(1 + (modifiedWeaponCooldown[weapon.name] * math.min((weapon.shotsFiredAtTarget/weapon.numShots), 5)))
    end
end)]]


--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("AUGNAME") then 
        for weapon in vter(shipManager:GetWeaponList()) do
            if weapon.blueprint.power > 0 then
                weapon.requiredPower = math.max(1, weapon.blueprint.power - 1)
            end
        end
    end
end)]]--



--[[script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    if shipManager.iShipId == 0 then 
        local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
        for crewmem in vter(shipManager.vCrewList) do
            if crewmem.type == "rad_civilian" then 
                crewmem:Kill(true)
                commandGui:RunCommand("CREW human")
            end
            --[[if crewmem.type == "unique_rad_scientist_tele" then 
                crewmem:Kill(true)
                commandGui:RunCommand("CREW unique_rad_scientist")
            end
        end
    end
end)]]


script.on_game_event("COMBAT_CHECK_REAL", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    for crewmem in vter(shipManager.vCrewList) do
        log(crewmem.type)
        if crewmem.type == "rad_civilian" or crewmem.type == "unique_rad_scientist_tele" then 
            crewmem.extend:InitiateTeleport(1,0,0)
        end
    end
end)

script.on_game_event("COMBAT_CHECK_FAIL_REAL", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    for crewmem in vter(shipManager.vCrewList) do
        log(crewmem.type)
        if crewmem.type == "rad_civilian" or crewmem.type == "unique_rad_scientist_tele" then 
            crewmem.extend:InitiateTeleport(1,0,0)
        end
    end
end)

script.on_game_event("RAD_SCIENCE_GHOST_SUR", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        log(crewmem.type)
        if crewmem.type == "unique_rad_scientist_tele" then 
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_MOD_SUS") > 0 or shipManager:HasAugmentation("IN_RAD_MOD_SUS") > 0 then
        for system in vter(shipManager.vSystemList) do
            if system:NeedsRepairing() then
                system:PartialRepair(0,true)
            end
        end
    end
end)

--[[script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_DOOR_LOCKS") > 0 then
        local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
        for door in vter(shipGraph.doors) do
            log("DOOR")
            log(door.iHacked)
            door.iHacked = 1
        end
    end
end)]]--

local radProjectileWarnings = {}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
    local currentProjectiles = {}
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        if shipManager:HasAugmentation("RAD_BULLET_HELL") > 0 then
            log("ON_TICK") 
            for projectile in vter(spaceManager.projectiles) do
                log("PROJECTILEPRE VALID")
                local weaponType = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name).typeName
                if weaponType ~= "BEAM" and projectile.destinationSpace == 0 and projectile.extend.name ~= "DRONE_LASER_DEFENSE" and projectile.extend.name ~= "DRONE_MISSILE_DEFENSE" and projectile.extend.name ~= "DRONE_ION_DEFENSE" and projectile.extend.name ~= "ANCIENT_DRONE_DEFENSE" and projectile.extend.name ~= "ROYAL_DRONE_DEFENSE" and projectile.extend.name ~= "DRONE_LASER_ENGI_DEFENSE_LOOT" then    
                    log("PROJECTILE VALID")
                    currentProjectiles[projectile.selfId] = true
                    if not radProjectileWarnings[projectile.selfId] then
                        if projectile.damage.iIonDamage > 0 then 
                            radProjectileWarnings[projectile.selfId] = {projectile.target, true}
                        else
                            radProjectileWarnings[projectile.selfId] = {projectile.target, false}
                        end
                    end
                end
            end


            for projId in pairs(radProjectileWarnings) do
                log("PROJECTILE")
                if not currentProjectiles[projId] then
                    radProjectileWarnings[projId] = nil
                end
            end
        end
    end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and ship.iShipId == 0 then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        if radProjectileWarnings then

            for k,v in pairs(radProjectileWarnings) do 
                --log("RENDER WARNING")
                local xPos = v[1].x
                local yPos = v[1].y
                local ion = v[2]
                local warningImageRed = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                local warningImageBlue = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning2.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                if ion then
                    Graphics.CSurface.GL_RenderPrimitive(warningImageBlue)
                else
                    Graphics.CSurface.GL_RenderPrimitive(warningImageRed)
                end
            end
        end
    end
end, function() end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
    local warningData = userdata_table(shipManager, "mods.rad.warnings")
    if warningData.warnings then 
        warningData.warnings = nil
        warningData.warnings = {}
    end
end)

--[[
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_BULLET_HELL") > 0 then 

    end
end)

local function addWarning(projectile, warningData)
    if projectile.damage.iIonDamage > 0 then 
        table.insert(warningData.warnings, {projectile.target.x, projectile.target.y, true, 120})
    else
        table.insert(warningData.warnings, {projectile.target.x, projectile.target.y, false, 120})
    end
end]]

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local weaponType = weaponBlueprint.typeName
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    if shipManager:HasAugmentation("RAD_BULLET_HELL") > 0 then 
        if projectile.extend.name ~= "DRONE_LASER_DEFENSE" and projectile.extend.name ~= "DRONE_MISSILE_DEFENSE" and projectile.extend.name ~= "DRONE_ION_DEFENSE" and projectile.extend.name ~= "ANCIENT_DRONE_DEFENSE" and projectile.extend.name ~= "ROYAL_DRONE_DEFENSE" and projectile.extend.name ~= "DRONE_LASER_ENGI_DEFENSE_LOOT" then    
            if weaponType == "BEAM" then
                local damageNew = projectile.damage
                damageNew.iPersDamage = 0
                projectile:SetDamage(damageNew)
            else
                if projectile.currentSpace == projectile.destinationSpace then 
                    projectile.speed_magnitude = (projectile.speed_magnitude / 8)
                else
                    projectile.speed_magnitude = (projectile.speed_magnitude / 4)
                end

                local damageNew = projectile.damage
                damageNew.iPersDamage = math.min(projectile.damage.iPersDamage + 3,5)
                projectile:SetDamage(damageNew)
            end
        else
            projectile.speed_magnitude = (projectile.speed_magnitude / 3)
        end
    end
end)


--[[
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and ship.iShipId == 0 then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local warningData = userdata_table(shipManager, "mods.rad.warnings")
        if warningData.warnings then

            for k,v in pairs(warningData.warnings) do 
                --log("RENDER WARNING")
                local xPos = v[1]
                local yPos = v[2]
                local ion = v[3]
                local timeLeft = v[4]
                local warningImageRed = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                local warningImageBlue = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning2.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                if ion then
                    Graphics.CSurface.GL_RenderPrimitive(warningImageBlue)
                else
                    Graphics.CSurface.GL_RenderPrimitive(warningImageRed)
                end
                warningData.warnings[k][4] = math.max(0, timeLeft - Hyperspace.FPS.SpeedFactor/16)
                if warningData.warnings[k][4] == 0 then
                    table.remove(warningData.warnings, k)
                end
            end
        end
    end
end, function() end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_COLLISION, function(thisProjectile, otherProjectile, damage, response)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    local warningData = userdata_table(shipManager, "mods.rad.warnings")
    local x = thisProjectile.target.x
    local y = thisProjectile.target.y 
    if warningData.warnings then
        for k,v in pairs(warningData.warnings) do 
            local xPos = v[1]
            local yPos = v[2]
            if math.abs(xPos - x) < 3 and math.abs(yPos - y) < 3 then
                table.remove(warningData.warnings, k)
            end
        end
    end
    return Defines.Chain.CONTINUE
end)



script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire)
    if shipManager.iShipId == 0 then 
        local x = location.x
        local y = location.y 
        local warningData = userdata_table(shipManager, "mods.rad.warnings")
        if warningData.warnings then
            for k,v in pairs(warningData.warnings) do 
                local xPos = v[1]
                local yPos = v[2]
                if math.abs(xPos - x) < 3 and math.abs(yPos - y) < 3 then
                    table.remove(warningData.warnings, k)
                end
            end
        end
    end
end)]]

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_BULLET_HELL") > 0 then
        for system in vter(shipManager.vSystemList) do
            if system:NeedsRepairing() then
                system:PartialRepair(0,true)
            end
        end
        shipManager.cloneSystem.fTimeToClone = shipManager.cloneSystem.fTimeGoal
    end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        if crewmem.iShipId == 0 and crewmem.intruder == false and shipManager:HasAugmentation("RAD_BULLET_HELL")>0 then 
            if crewmem.bCloned then 
                crewmem:Kill(true)
            end
        end
    end
end)



script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if augName == "SCRAP_COLLECTOR" and shipManager:HasAugmentation("RAD_LOW_SCRAP") > 0 and shipManager.currentScrap > 74 then
        augValue=-1
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)


script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
    if shipManager:HasAugmentation("RAD_WM_RAILGUN") > 0 or shipManager:HasAugmentation("IN_RAD_WM_RAILGUN") > 0 then 
        projectile.speed_magnitude = projectile.speed_magnitude*4
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
    if weaponBlueprint.name == "RAD_COINGUN" then 
        shipManager:ModifyScrapCount(-2,false)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    if pcall(function() weaponName = projectile.extend.name end) and weaponName == "RAD_COINGUN" then 
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
        otherShip:ModifyScrapCount(3,false)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 and damage.iDamage + damage.iSystemDamage > 0 then 
        local hullDamage = damage.iDamage
        local scrap = shipManager.currentScrap
        local scrapLoss = (-1) * math.max(math.floor(0.1 * scrap), 10)
        shipManager:ModifyScrapCount(scrapLoss,false)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    if shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 and beamHitType == Defines.BeamHit.NEW_ROOM and damage.iDamage + damage.iSystemDamage > 0 then 
        local hullDamage = damage.iDamage
        local scrap = shipManager.currentScrap
        local scrapLoss = (-1) * math.max(math.floor(0.1 * scrap), 10)
        shipManager:ModifyScrapCount(scrapLoss,false)
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

local scrapEnabled = false
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 and shipManager.currentScrap <= 0 and scrapEnabled then
        shipManager:DamageHull(100,true)
    elseif shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 and shipManager.ship.hullIntegrity.first < 20 then
        shipManager:DamageHull(-1,true)
    elseif shipManager:HasAugmentation("RAD_SCRAP_HULL") > 0 and shipManager.ship.hullIntegrity.first > 20 then
        shipManager:DamageHull(1,true)
        shipManager:ModifyScrapCount(2,false)
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and scrapEnabled then 
        scrapEnabled = false
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    scrapEnabled = true
end)

--[[script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if augName == "RAD_DOOR_OFF" and shipManager:HasAugmentation("RAD_NO_DOOR") > 0 and shipManager.weaponSystem.powerState.first >= 1 then
        augValue=1
    end
    return Defines.Chain.CONTINUE, augValue
end, -100)]]
local def = Hyperspace.StatBoostDefinition()
def.stat = Hyperspace.CrewStat.TELEPORT_MOVE
def.value = false
def.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
def.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
def.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
def.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALLIES
def.duration = 2
def.priority = 100
def.cloneClear = false
def.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(def)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    local doorDisableTable = userdata_table(shipManager, "mods.rad.disableTeleporters")
    if doorDisableTable.statTime and shipManager:HasAugmentation("RAD_NO_DOOR") then
        doorDisableTable.statTime = math.max(doorDisableTable.statTime - Hyperspace.FPS.SpeedFactor/16, 0)
        if doorDisableTable.statTime == 0 then
            
            local crewList = shipManager.vCrewList
            if shipManager:HasAugmentation("RAD_NO_DOOR") > 0 then
                if shipManager.weaponSystem.powerState.first >= 1 then 
                    def.value = false
                else
                    def.value = true 
                end
                for i = 0, crewList:size() - 1 do
                    local crew = crewList[i]
                    Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(def), crew)
                end
            end
            doorDisableTable.statTime = 1
        end
    elseif shipManager:HasAugmentation("RAD_NO_DOOR") then
        doorDisableTable.statTime = 1
    end
end)

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, augName, augValue)
    if augName == "TELEPORT_HEAL" and shipManager:HasAugmentation("RAD_DOCKING_DRILL") > 0 and Hyperspace.playerVariables.rad_docking_drilled == 1 then
        --print("TELEPORT HEAL BLOCKED")
        augValue=0
    end
    return Defines.Chain.CONTINUE, augValue
end, -101)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if Hyperspace.playerVariables.rad_docking_drilled == 1 then
        --log("UN-ION")
        shipManager.teleportSystem:LockSystem(0)
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire) 
    local playerShip = Hyperspace.ships.player
    if playerShip:HasAugmentation("RAD_DOCKING_DRILL") > 0 and Hyperspace.playerVariables.rad_docking_drilled == 1 then
        --print("FORCE HIT DOCK")
        return Defines.Chain.CONTINUE, Defines.Evasion.HIT
    end
end)


--[[script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    print(commandGui.bPaused)
end)
mods.rad.popUpTooltips = {}
local tooltips = mods.rad.popUpTooltips
tooltips[""]
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
end)]]


script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.weaponBlueprint.name == "RAD_DRONE_BEAM_COMBAT" then 
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

        local missilePoint = get_point_local_offset(projectile.position,projectile.target1, 20, 0)
        local beamPoint = get_point_local_offset(projectile.position,projectile.target1, 0, 19)
        local ionPoint = get_point_local_offset(projectile.position,projectile.target1, 5, -12)
        local laserPoint = get_point_local_offset(projectile.position,projectile.target1, -20, -19)

        local beamBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_BEAM_COMBAT")
        local ionBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_ION")
        local laserBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER") 
        local missileBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("MISSILES_1")

        --projectile.position = beamPoint
        --projectile:ComputeHeading()

        local missile = spaceManager:CreateMissile(
            missileBlueprint,
            missilePoint,
            projectile.currentSpace,
            projectile.ownerId,
            projectile.target1,
            projectile.destinationSpace,
            projectile.heading)
        missile:ComputeHeading()

        local ion = spaceManager:CreateLaserBlast(
            ionBlueprint,
            ionPoint,
            projectile.currentSpace,
            projectile.ownerId,
            projectile.target1,
            projectile.destinationSpace,
            projectile.heading)
        ion:ComputeHeading()
        ion.speed_magnitude = ion.speed_magnitude*2

        local laser = spaceManager:CreateLaserBlast(
            laserBlueprint,
            laserPoint,
            projectile.currentSpace,
            projectile.ownerId,
            projectile.target1,
            projectile.destinationSpace,
            projectile.heading)
        laser:ComputeHeading()
        laser.speed_magnitude = math.ceil(laser.speed_magnitude/2)

        local beam = spaceManager:CreateBeam(
            beamBlueprint,
            beamPoint,
            projectile.currentSpace,
            projectile.ownerId,
            projectile.target1,
            projectile.target2,
            projectile.destinationSpace,
            projectile.length,
            projectile.heading)
        beam:ComputeHeading()

        projectile:Kill()
    end
end)

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.weaponBlueprint.name == "RAD_DRONE_BEAM_COMBAT2" then 
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space

        local target1 = get_point_local_offset(projectile.target1,projectile.target2, 0, 0)
        local target2 = get_point_local_offset(projectile.target1,projectile.target2, 50, 0)
        local target3 = get_point_local_offset(projectile.target1,projectile.target2, 100, 0)
        local target4 = get_point_local_offset(projectile.target1,projectile.target2, 150, 0)

        local laserBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint("DRONE_LASER") 

        local laser1 = spaceManager:CreateLaserBlast(
            laserBlueprint,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            target1,
            projectile.destinationSpace,
            projectile.heading)
        laser1:ComputeHeading()

        local laser2 = spaceManager:CreateLaserBlast(
            laserBlueprint,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            target2,
            projectile.destinationSpace,
            projectile.heading)
        laser2:ComputeHeading()
        laser2.speed_magnitude = laser2.speed_magnitude-2

        local laser3 = spaceManager:CreateLaserBlast(
            laserBlueprint,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            target3,
            projectile.destinationSpace,
            projectile.heading)
        laser3:ComputeHeading()
        laser3.speed_magnitude = laser3.speed_magnitude-4

        local laser4 = spaceManager:CreateLaserBlast(
            laserBlueprint,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            target4,
            projectile.destinationSpace,
            projectile.heading)
        laser4:ComputeHeading()
        laser4.speed_magnitude = laser4.speed_magnitude-6

        --projectile:Kill()
    end
end)
--[[local roomAtMouse = nil
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables.rad_arti_targetting == 0 then 
        --print(holdinglmb)
        local shipManager = Hyperspace.ships.player
        local mousePos = Hyperspace.Mouse.position
        --print(x)
        --print(y)
        local mousePosLocal = convertMousePositionToEnemyShipPosition(mousePos)
        --print(mousePosLocal.x)
        --print(mousePosLocal.y)
        roomAtMouse = get_room_at_location(Hyperspace.ships.enemy, mousePosLocal, true)
        if roomAtMouse == -1 then 
            roomAtMouse = nil
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y) 
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and Hyperspace.playerVariables.rad_arti_targetting == 0 then 
        local shipManager = Hyperspace.ships.player
        local mousePos = Hyperspace.Mouse.position
        local mousePosLocal = convertMousePositionToEnemyShipPosition(mousePos)
        roomAtMouse = get_room_at_location(Hyperspace.ships.enemy, mousePosLocal, true)
        if roomAtMouse == -1 then 
            roomAtMouse = nil
        end
        Hyperspace.playerVariables.rad_arti_targetting = 1
        if roomAtMouse then 
            Hyperspace.playerVariables.rad_arti_targeted = 1
        else 
            Hyperspace.playerVariables.rad_arti_targeted = 0
        end 
    end
    return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then 
        local shipManager = Hyperspace.ships.player
        if shipManager:HasAugmentation("RAD_UP_ARTI") then
            for artillery in vter(Hyperspace.ships.player.artillerySystems) do 
                local cApp = Hyperspace.Global.GetInstance():GetCApp()
                --local weaponControl = cApp.gui.combatControl.weapControl
                if Hyperspace.playerVariables.rad_arti_targeted == 0 then
                    --print(artillery.projectileFactory.cooldown.first)
                    --print(artillery.projectileFactory.cooldown.second)
                    if artillery.projectileFactory.cooldown.first >= artillery.projectileFactory.cooldown.second - 0.25 then
                        artillery.projectileFactory.cooldown.first = artillery.projectileFactory.cooldown.second - 0.25

                    end
                elseif artillery.projectileFactory.cooldown.first <= 0.25 and not weaponControl.autoFiring then
                    roomAtMouse = nil 
                    Hyperspace.playerVariables.rad_arti_targeted = 0
                end
            end
        end
    end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
    if roomAtMouse and ship.iShipId == 1 then
        local roomLoc = ship:GetRoomCenter(roomAtMouse)
        local shipTargetImage = Hyperspace.Resources:CreateImagePrimitiveString(
            "misc/crosshairs_placed_rad_arti.png",
            roomLoc.x-20,
            roomLoc.y-20,
            0,
            Graphics.GL_Color(1, 1, 1, 1),
            1.0,
            false)
        Graphics.CSurface.GL_RenderPrimitive(shipTargetImage)
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
    if weaponBlueprint.name == "RAD_BIG_ARTI" and roomAtMouse then 
        projectile.target = Hyperspace.ships.enemy:GetRoomCenter(roomAtMouse)
        --projectile:ComputeHeading()
    end
end)]]


--[[script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and ship.iShipId == 0 then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        if radProjectileWarnings then

            for k,v in pairs(radProjectileWarnings) do 
                --log("RENDER WARNING")
                local xPos = v[1].x
                local yPos = v[1].y
                local ion = v[2]
                local warningImageRed = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                local warningImageBlue = Hyperspace.Resources:CreateImagePrimitiveString(
                    "statusUI/rad_warning2.png",
                    xPos-11,
                    yPos-11,
                    0,
                    Graphics.GL_Color(1, 1, 1, 1),
                    1.0,
                    false)
                if ion then
                    Graphics.CSurface.GL_RenderPrimitive(warningImageBlue)
                else
                    Graphics.CSurface.GL_RenderPrimitive(warningImageRed)
                end
            end
        end
    end
end, function() end)]]


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RAD_HIGH_WEAPON") > 0 and Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then 
        for weapon in vter(shipManager:GetWeaponList()) do 
            if weapon.blueprint.power >= 4 then
                if weapon.requiredPower == weapon.blueprint.power and weapon.powered then 
                    --shipManager.weaponSystem:LockSystem(8)
                    local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                    Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_DISABLE_PWEAPONS",false,-1)
                end
                weapon.requiredPower = 2
            end
            if weapon.blueprint.power < 3 then 
                weapon:SetCooldownModifier(-1)
            end
        end 
    end
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    for weapon in vter(shipManager:GetWeaponList()) do
        if (not weapon.powered) and weapon.blueprint.name == "WEAPON_NAME" then
            weapon.cooldown.first = math.min(weapon.cooldown.first + (Hyperspace.FPS.SpeedFactor*(6 + (1*weapon.cooldownModifier)))/16, weapon.cooldown.second-0.01)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then 
        if shipManager:HasAugmentation("RAD_DRONE_FACTORY") > 0 then 
            local droneSys = shipManager.droneSystem
            if droneSys:CompletelyDestroyed() then
                droneSys:PartialRepair(1,true)
            end
        end
    end
end)


script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    if weaponBlueprint.name == "ARTILLERY_RAD_DD" then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
        local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
        if Hyperspace.playerVariables.rad_time_bomb == 1 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_1",false,-1)
        elseif Hyperspace.playerVariables.rad_time_bomb == 2 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_2",false,-1)
        elseif Hyperspace.playerVariables.rad_time_bomb == 3 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_3",false,-1)
        end
        projectile:Kill()
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    if weaponBlueprint.name == "ARTILLERY_RAD_DD_2" then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
        local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
        if Hyperspace.playerVariables.rad_time_bomb_2 == 1 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_1",false,-1)
        elseif Hyperspace.playerVariables.rad_time_bomb_2 == 2 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_2",false,-1)
        elseif Hyperspace.playerVariables.rad_time_bomb_2 == 3 then 
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_3",false,-1)
        end
        projectile:Kill()
    end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        --local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        if crewmem.blueprint.name == "drone_rad_bomb" or crewmem.blueprint.name == "drone_rad_bomb_2" or crewmem.blueprint.name == "drone_rad_bomb_3" then 
            --print(crewmem.blueprint.name)
            if Hyperspace.ships.player:HasAugmentation("RAD_DRONE_FACTORY_2") > 0 then
                if crewmem.iRoomId < 20 and crewmem.intruder == false then 
                    crewmem:SetRoom(23)
                end
            else
                if crewmem.iRoomId < 16 and crewmem.intruder == false then 
                    crewmem:SetRoom(18)
                end
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "drone_rad_bomb" or crewmem.blueprint.name == "drone_rad_bomb_2" or crewmem.blueprint.name == "drone_rad_bomb_3" then 
            crewmem:Kill(true)
        end
    end
end)
local lastHitRoomMissile = 0
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if projectile then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((projectile.destinationSpace+1)%2)
        if otherShip:HasAugmentation("RAD_MISSILE_BOMBS") > 0 then
            if Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name).typeName == "MISSILES" or Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name).typeName == "BOMB" then
                local room = get_room_at_location(shipManager,location,true)
                lastHitRoomMissile = room
                local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_SPAWN_BOMB_MISSILE",false,-1)
            end
        end
    end
end)

script.on_game_event("RAD_SPAWN_BOMB_MISSILE_DELAY", false, function()
    local shipManager = Hyperspace.ships.player
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.blueprint.name == "drone_rad_missile" then
            --crewmem:SetCurrentShip(1)
            --crewmem:SetRoom(lastHitRoomMissile)
            
            if pcall(function() crewmem.extend:InitiateTeleport(1, lastHitRoomMissile, 0) end) then
                --print("teleport")
            else
                crewmem:Kill(true)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    if weaponBlueprint.name == "RAD_MINELAYER" and Hyperspace.playerVariables.rad_minelayer_check == 1 then 
        Hyperspace.playerVariables.rad_minelayer_fire = Hyperspace.playerVariables.rad_minelayer_fire + 1
        if Hyperspace.playerVariables.rad_minelayer_fire >= 30 then
            Hyperspace.playerVariables.rad_minelayer_check = 0
            local worldManager = Hyperspace.Global.GetInstance():GetCApp().world
            Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"RAD_MINES_2",false,-1)
        end
    end
end)

--[[mods.arc.teleportProj = {}
local teleportProj = mods.arc.teleportProj
teleportProj["GUN_NAME"] = {
    delay = 1,
    distance = 20
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
    for projectile in vter(spaceManager.projectiles) do
        local projectileData = teleportProj[projectile.extend.name]
        if projectileData then
            local projectileTable = userdata_table(projectile, "mods.arc.teleportProj")
            if projectileTable.delay then
                projectileTable.delay = math.max(projectileTable.delay - Hyperspace.FPS.SpeedFactor/16, 0)
                if projectileTable.delay == 0 then
                    projectileTable.delay = projectileData.delay
                    if projectile.currentSpace == 1 then
                        projectile.position = Hyperspace.Pointf(projectile.position.x + projectileData.distance, projectile.position.y)
                    else
                        projectile.position = get_point_local_offset(projectile.position, projectile.target, projectileData.distance, 0)
                    end
                end
            else
                projectileTable.delay = projectileData.delay
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
        local valueAdd = 0
        if dodgeTable.addDodge then
            valueAdd = math.Round(dodgeTable.addDodge, 0)
        end
        value = math.max(value - 5 + valueAdd, 0)
    end
    return Defines.Chain.CONTINUE, value
end)

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        if response.damage > 0 or response.superDamage > 0 then
            local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
            if dodgeTable.addDodge then
                dodgeTable.addDodge = math.min(dodgeTable.addDodge + 5, 40)
            else
                dodgeTable.addDodge = 5
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    if shipManager:HasAugmentation("RVS_ANTI_GRAVITY_ENGINE") > 0 then
        local dodgeTable = userdata_table(shipManager, "mods.ai.grav_engine")
        if dodgeTable.addDodge then
            dodgeTable.addDodge = math.max(dodgeTable.addDodge - Hyperspace.FPS.SpeedFactor/16, 0)
            if dodgeTable.addDodge == 0 then
                dodgeTable.addDodge = nil
            end
        end
    end
end)]]

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local hullData = userdata_table(shipManager, "mods.arc.hullData")
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0   then
        hullData.tempHp = math.floor(shipManager:GetAugmentationValue("ARC_SUPER_HULL"))
    else
        hullData.tempHp = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --log(beamHitType)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 and beamHitType == 2 then
       local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end 
    return Defines.Chain.CONTINUE, beamHitType
end) 

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    if shipManager:HasAugmentation("ARC_SUPER_HULL") > 0 then
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then 
            if hullData.tempHp > 0 and damage.iDamage > 0 then
                hullData.tempHp = hullData.tempHp - damage.iDamage
                shipManager:DamageHull((-1 * damage.iDamage), true)
            end
        end
    end
end)

local xPos = 380
local yPos = 47
local xText = 413
local yText = 58
local tempHpImage = Hyperspace.Resources:CreateImagePrimitiveString(
    "statusUI/arc_tempHull.png",
    xPos,
    yPos,
    0,
    Graphics.GL_Color(1, 1, 1, 1),
    1.0,
    false)
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    if Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
        local hullData = userdata_table(shipManager, "mods.arc.hullData")
        if hullData.tempHp then
            local hullHP = math.floor(hullData.tempHp)
            Graphics.CSurface.GL_RenderPrimitive(tempHpImage)
            Graphics.freetype.easy_print(0, xText, yText, hullHP)
        end
    end
end, function() end)