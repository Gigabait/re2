
ENT.enemy = nil
function ENT:SetEnemy(newEnemy)
    self.enemy = newEnemy
end

function ENT:GetEnemy()
    return self.enemy
end
ENT.AttackSounds = {"npc/zombie/zo_attack1.wav","npc/zombie/zo_attack2.wav"}

function ENT:setAttackSounds(newAttackSounds)
    self.AttackSounds = newAttackSounds
end

function ENT:getAttackSounds()
    return self.AttackSounds
end

ENT.AttackAnims = {
    "attackA",
    "attackB",
    "attackC"
}
function ENT:setAttackAnims(newAttackAnims)
    self.AttackAnims = newAttackAnims
end

function ENT:getAttackAnims()
    return self.AttackAnims
end

ENT.InfectionChance = .25
function ENT:setInfectionChance(newInfectionChance)
    self.InfectionChance = newInfectionChance
end

function ENT:getInfectionChance()
    return self.InfectionChance
end

ENT.AttackSpeed = 4
function ENT:setAttackSpeed(attackSpeed)
    self.AttackSpeed = attackSpeed
end

function ENT:getAttackSpeed()
    return self.AttackSpeed
end

ENT.AttackDamage = 10
function ENT:setAttackDamage(attackDamage)
    self.AttackDamage = attackDamage
end

function ENT:getAttackDamage()
    return self.AttackDamage
end

ENT.RunSpeed = 150
function ENT:setRunSpeed(RunSpeed)
    self.RunSpeed = RunSpeed
end

function ENT:getRunSpeed()
    return self.RunSpeed
end

ENT.WalkSpeed = 25
function ENT:setWalkSpeed(WalkSpeed)
    self.WalkSpeed = WalkSpeed
end

function ENT:getWalkSpeed()
    return self.WalkSpeed
end

ENT.Running = false
function ENT:setRunning(newBool)
    self.Running = tobool(newBool)
end

function ENT:getRunning()
    return self.Running
end

ENT.LastAttack = 0
function ENT:setLastAttack(newLastAttack)
    self.LastAttack = newLastAttack
end

function ENT:getLastAttack()
    return self.LastAttack
end

function ENT:shouldTarget(ent)
    if ent:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then return false end
    if ent.dontTarget then return false end
    if ent.isCade then
        return true
    else
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            if phys:GetVolume() > 300 && phys:IsMotionEnabled() then
                return true
            end
        end
    end
    return false
end

function ENT:findEnemy()
    local target = nil
    for key, ply in pairs(player.GetAll()) do
        if ply:GetObserverMode() == OBS_MODE_NONE && ply:Alive() then
            if (!IsValid(target) or ply:GetPos():Distance( self:GetPos() ) < target:GetPos():Distance(self:GetPos())) then
                target = ply
            end
        end
    end

    for key, ent in pairs(ents.FindInSphere(self:GetPos(), 65 * (self.times/2))) do
        if (IsValid(ent) && self:shouldTarget(ent)) then
           self:AttackEntity(ent)
            if self:getRunning() then
                self:StartActivity( ACT_RUN )
            else
                self:StartActivity( ACT_WALK )
            end
        end
    end
    self:SetEnemy( target )
    return target
end

function ENT:MoveToEnemy( options )
    local options = options or {}

    local path = Path( "Chase" )
    path:SetMinLookAheadDistance( options.lookahead or 300 )
    path:SetGoalTolerance( options.tolerance or 20 )

    local enemy = self:findEnemy()
    path:Compute( self, enemy:GetPos() )

    if ( !path:IsValid() ) then return "failed" end

    while ( path:IsValid() && !self:CanAttack( self:GetEnemy() ) ) do

        path:Update( self )

        -- Draw the path (only visible on listen servers or single player)
        if ( options.draw ) then
            path:Draw()
        end

        -- If we're stuck then call the HandleStuck function and abandon
        if ( self.loco:IsStuck() ) then
            self:HandleStuck()
            return "stuck"
        end

        if ( options.maxage ) then
            if ( path:GetAge() > options.maxage ) then return "timeout" end
        end

        if ( options.repath ) then
            if ( path:GetAge() > options.repath ) then
                local updatedEnemy = self:findEnemy()
                if IsValid(updatedEnemy) then
                    path:Compute( self, updatedEnemy:GetPos() )
                else
                    return "failed"
                end
            end
        end
        coroutine.yield()
    end
    return "ok"
end

function ENT:CanAttack( entity )
    if IsValid(entity) && entity:GetPos():Distance(self:GetPos()) < 65 + (65 * (self.times/2)) then
        if entity:IsPlayer() && entity:Alive()  then
            return true
        elseif self:shouldTarget(entity) then
            return true
        end
    end
    return false
end

function ENT:AttackEntity( entity, options )
    while ( self:CanAttack( entity ) ) do
        self.loco:FaceTowards(entity:GetPos())
        local soundPath = table.Random(self:getAttackSounds())

        sound.Play(soundPath, self:GetPos() + Vector(0,0,50), 75, 100, 1 )

        self:PlaySequenceAndWait( table.Random(self:getAttackAnims()), self:getAttackSpeed() )
        self:setLastAttack(CurTime())
        if IsValid(entity) && entity:GetPos():Distance( self:GetPos() ) < 100 then

            local dmginfo = DamageInfo()
            dmginfo:SetDamageType(DMG_SLASH)
            dmginfo:SetDamage(self:getAttackDamage())

            local force = 1
            local phys = entity:GetPhysicsObject()
            if IsValid(phys) then
                force = phys:GetVolume()/phys:GetMass() * 10
            end

            if IsValid(self:GetEnemy()) then
                local dir = (self:GetEnemy():GetPos() - self:GetPos()):Angle()
                dmginfo:SetDamageForce( dir:Forward() * self:getAttackDamage() * force + dir:Up() * force )
            else
                dmginfo:SetDamageForce( self:GetAngles():Forward() * self:getAttackDamage() * force  )
            end
            dmginfo:SetAttacker(self)

            --[[if math.random(1, 1/self:getInfectionChance()) == 1 then
                entity
            end]]--
            entity:TakeDamageInfo(dmginfo)
        end

        if ( self.loco:IsStuck() ) then
            self:HandleStuck()
            return "stuck"
        end
        coroutine.yield()
    end
    return "ok"
end

function ENT:AttackEnemy( options )
    self:AttackEntity(self:GetEnemy(), options)
end
