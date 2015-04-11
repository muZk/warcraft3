library proj requires KT, NewGroup, Alloc, TerrainPathability

    define
        private PERIOD = 0.03125
        private ALTURA_PROMEDIO = 50
        private DEFAULT_TARGET_COLISION = 50
        private DEFAULT_AOE_COLISION = 250
        private HT_COUNT_KEY = 0
    enddefine

    private function interface interfaceFunc takes proj m returns nothing
    private function interface colisionFunc takes proj m,unit who returns nothing

    globals
        private proj array projAll [8190]
        private integer array projIndex [8190]
        private integer projSize = 0
        private hashtable ht = InitHashtable()
    endglobals

    function GetUnitBullets takes unit whichUnit returns integer
        return LoadInteger(ht, GetHandleId(whichUnit), HT_COUNT_KEY)
    endfunction

    function UnitRemoveBullet takes unit whichUnit returns nothing
        call SaveInteger(ht, GetHandleId(whichUnit), HT_COUNT_KEY, GetUnitBullets(whichUnit) - 1)
    endfunction

    function UnitAddBullet takes unit whichUnit returns nothing
        call SaveInteger(ht, GetHandleId(whichUnit), HT_COUNT_KEY, GetUnitBullets(whichUnit) + 1)
    endfunction

    function RemoveProjectiles takes unit target returns nothing
        local integer index = projSize
        loop
            set index=index-1
            exitwhen index<0
            if projAll[index] != 0 and projAll[index].targetUnit!= null then
                debug call BJDebugMsg("RemoveProjectiles - eval")
                if projAll[index].targetUnit == target then
                    debug call BJDebugMsg("RemoveProjectiles - removing "+GetUnitName(projAll[index].caster))
                    call projAll[index].Stop()
                endif
            endif
        endloop
    endfunction

    struct proj extends array
        implement Alloc
//=========================================================
        // Para trabajar con spells
        real     distance        // ----> distancia recorrida por el misil, se va actualizando a medida que avanza.
        readonly integer ticks             // ----> cantidad de periodos ejecutados, se va acuatlizando a medida que avanza.
        integer  level          // ----> variable integer a dispocion del usuario
        player   owner          // ----> variable de player a disposicion del usuario. 
        effect   efecto        // ----> variable de efecto a disposicion del usuario.
        real     damage         // ----> variable real a disposicion del usuario.
        group    damaged             // ----> grupo de unidad a disposicion del uuario.
        real     unitCollision          // ----> rango de colision para el evento onunitCollision .
        real     targetCollision        // ----> rango en el cual debe entrar el misil para considerar que choco con el target unit.
//=========================================================
        // Unidades relacionadas con el movimiento
        private  unit m              // ----> misil      
        private  unit source         // ----> dueño del misil
//=========================================================
        // Control del movimienzo
        readonly real time
        readonly real angle
        // xy
        private real mvx
        private real mvy
        private real mvxy 
        // z
        private real mz
        private real mvz 
        private real maz
        private boolean arcing
        boolean pathing
        // target
        private real tx 
        private real ty 
        private real tz 
        private unit tu 
        // control
        boolean finish       
        boolean rotate
        boolean stopOnDead
        boolean allowDead
        boolean pause
        real distanceLeft
//=========================================================
        readonly real origenX
        readonly real origenY
        readonly real origenZ
//=========================================================
        static method create takes unit m returns thistype
             local thistype this=thistype.allocate()
                set this.m  = m
                set this.mz = GetUnitFlyHeight(m)
                call UnitAddAbility(m,'Amrf')
                call UnitRemoveAbility(m,'Amrf')
                set finish  = false
                set lock    = false
                set running = false
                set arcing  = false
                set pathing = false
                set allowDead = false
                set targetCollision  = DEFAULT_TARGET_COLISION
                set LoopEnumColision = DEFAULT_AOE_COLISION
                set HitEnumColision  = DEFAULT_AOE_COLISION
                set damaged = NewGroup()
                //----------------------------
                set projAll[projSize]=this
                set projIndex[this]=projSize
                set projSize=projSize+1
                //----------------------------
                call UnitAddBullet(m)
             return this
        endmethod
//=========================================================
        method destroy takes nothing returns nothing
            call SetUnitFlyHeight(m,GetUnitDefaultFlyHeight(m),0)
            call UnitRemoveBullet(m)
            set onHit=0  
            set onLoop=0
            set onLoopEnum=0
            set onHitEnum=0
            set ticks=0
            set distance=0
            set efecto= null
            set m=null
            set tu=null
            set caster=null
            set lock=false
            set running=false
            set pause=false
            set CollideLoopRange=0
            set CollideHitRange=0
            set CollideHit=null
            if CollideLoop!=null then
                //call DestroyBoolExpr(CollideLoop)
                set CollideLoop=null
            endif
            if damaged!=null then
                call ReleaseGroup(damaged)
                set damaged=null
            endif
            //----------------------------
            set projSize=projSize-1 // disminuir stack
            set projAll[projIndex[this]]=projAll[projSize] // pasar ultimo a posicion liberada
            set projIndex[projAll[projSize]]=projIndex[this]  // cambiar Index del ultimo al Index nuevo
            set projAll[projSize]=0 // nullear ultimo
            //----------------------------
            call this.deallocate()
        endmethod
//=========================================================
        // Mecanismo para cerrar
        private boolean running 
        private boolean lock
//=========================================================
        method Lock takes boolean value returns nothing
            set lock = value
        endmethod
//=========================================================
        method IsLocked takes nothing returns boolean
            return lock == true
        endmethod
//=========================================================
        method operator caster takes nothing returns unit
            return source
        endmethod
//=========================================================
         method operator caster= takes unit value returns nothing
            set this.source = value
            set this.owner = GetOwningPlayer(this.caster)
        endmethod
//=========================================================
         method operator projUnit takes nothing returns unit
            return m
        endmethod
//=========================================================
         method operator x takes nothing returns real
            return GetUnitX(m)
        endmethod
//=========================================================
         method operator y takes nothing returns real
            return GetUnitY(m)
        endmethod
//=========================================================
         method operator z takes nothing returns real
            return GetUnitFlyHeight(m)
        endmethod
//=========================================================
        method operator targetX takes nothing returns real
            return tx
        endmethod
//=========================================================
        method operator targetY takes nothing returns real
            return ty
        endmethod
//=========================================================
        // Targets
         method operator targetUnit takes nothing returns unit
            return this.tu
        endmethod
//=========================================================
         method setTargetUnit takes unit u returns nothing
            set tu = u
            set tx = GetUnitX(u)
            set ty = GetUnitY(u)
            set tz = GetUnitFlyHeight(u)+ALTURA_PROMEDIO
        endmethod
//=========================================================
        method setTargetPoint takes real newX, real newY, real newZ returns nothing
            local real dx
            local real dy
            set tu=null
            set tx=newX
            set ty=newY
            set tz=newZ
            if mvxy != 0 then
                set dx=newX-x
                set dy=newY-y
                set time=RMaxBJ(SquareRoot(dx*dx+dy*dy)*PERIOD/mvxy,PERIOD)
                set angle=Atan2(dy,dx)
                set mvx=Cos(angle)*mvxy
                set mvy=Sin(angle)*mvxy
                set finish=false
            endif
        endmethod
//=========================================================
        interfaceFunc onHit
        interfaceFunc onLoop
//=========================================================
        method onHitAction takes interfaceFunc action returns nothing
            set onHit=action
        endmethod
//=========================================================
        method onLoopAction takes interfaceFunc action returns nothing
            set onLoop=action
        endmethod
//=========================================================
// Collide
    real CollideLoopRange
    real CollideHitRange
    boolexpr CollideHit
    boolexpr CollideLoop
    static thistype CollidingProj
//=========================================================
        private unit colidedUnit
        private colisionFunc onLoopEnum
        private colisionFunc onHitEnum
        real LoopEnumColision
        real HitEnumColision
        
//=========================================================
        method onLoopEnumAction takes colisionFunc action returns nothing
            set onLoopEnum=action
            set LoopEnumColision=DEFAULT_AOE_COLISION
        endmethod
//=========================================================
        method onHitEnumAction takes colisionFunc action returns nothing
            set onHitEnum=action
            set HitEnumColision=DEFAULT_AOE_COLISION
        endmethod
//=========================================================
        method DoEnum takes colisionFunc action,real collision returns nothing
            call GroupEnumUnitsInRange(ENUM_GROUP,x,y,collision,null)
            loop
                set colidedUnit = FirstOfGroup(ENUM_GROUP)
                exitwhen colidedUnit == null
                call action.execute(this,colidedUnit)
                call GroupRemoveUnit(ENUM_GROUP,colidedUnit)
            endloop
        endmethod
//=========================================================
        method operator Hit takes nothing returns boolean
            return tu!=null and IsUnitType(tu,UNIT_TYPE_DEAD)==false and GetUnitTypeId(tu)!=0 and IsUnitInRange(tu,m,targetCollision)
        endmethod
//=========================================================        
        private method targetHit takes nothing returns nothing
            set finish = true
            if onHit != 0 then
                call onHit.execute(this)
                set onHit=0
            endif
            if onHitEnum != 0 then
                call DoEnum(onHitEnum,HitEnumColision)
                set onHitEnum=0
            endif
            if CollideHit != null then
                set thistype.CollidingProj=this
                call GroupEnumUnitsInRange(ENUM_GROUP,x,y,CollideHitRange,CollideHit)
                call DestroyBoolExpr(CollideHit)
                set CollideHit=null
            endif
        endmethod
//=========================================================    
        private static method periodic takes nothing returns boolean
            local thistype this = KT_GetData()
            local real dx
            local real dy
            local boolean canMove=true
            if IsUnitType(m,UNIT_TYPE_DEAD)==true and allowDead==false then
                set this.finish = true // STOP WHEN PROJECTILE IS DEAD
            endif
            if not finish then // MISIL HOMMING
                if tu!=null and GetUnitTypeId(tu)!=0 then
                    if IsUnitType(tu,UNIT_TYPE_DEAD)==false then
                        set tx=GetUnitX(tu)
                        set ty=GetUnitY(tu)
                        set tz=GetUnitFlyHeight(tu)+ALTURA_PROMEDIO
                        set dx=tx-x
                        set dy=ty-y
                        set distanceLeft=SquareRoot(dx*dx+dy*dy)
                        set angle=Atan2(dy,dx)
                        if distanceLeft>targetCollision then
                            set time = distanceLeft/mvxy*PERIOD
                        else
                            call this.targetHit()
                        endif
                        set mvx = Cos(angle)*mvxy
                        set mvy = Sin(angle)*mvxy
                    else
                        if stopOnDead then
                            call Stop()
                        endif
                    endif
                endif
                // Calculate next unit Position
                set dx=GetUnitX(m)+mvx
                set dy=GetUnitY(m)+mvy
                // Finish if its an unsafe position
                if not SafePosition.isSafe(dx, dy)
                    finish = true
                endif
                if arcing then
                    set maz = 2*((tz-mz)/time/time*PERIOD*PERIOD-(mvz*PERIOD)/time)
                    set mvz  = mvz + maz/2.0
                    set mz   = mz + mvz
                    set mvz  = mvz + maz/2.0    
                    call SetUnitFlyHeight(m,mz,0)
                endif
                if pathing then
                    if IsTerrainWalkable(dx,dy)==false then
                        set canMove=false
                    endif
                endif
                if not(finish) then
                    set time = time - PERIOD
                    if pause then
                        call SetUnitPosition(m,dx,dy)
                    elseif canMove then
                        call SetUnitX(m,dx)
                        call SetUnitY(m,dy)
                        call IssueImmediateOrder(m,"stop")
                    endif
                    if rotate then
                        call SetUnitFacing(m,angle*bj_RADTODEG)
                    endif
                    set distance = distance + mvxy
                    set ticks = ticks + 1
                    // LOOP EVENTS
                    if onLoop > 0 then
                        call onLoop.execute(this)
                    endif
                    if onLoopEnum > 0 then
                        call DoEnum(onLoopEnum,LoopEnumColision)
                    endif
                    if CollideLoop != null then
                        set thistype.CollidingProj=this
                        call GroupEnumUnitsInRange(ENUM_GROUP,x,y,CollideLoopRange,CollideLoop)
                    endif
                    if time <= 0.0 then
                        call Stop()
                    endif
                endif
            endif
            if finish then
                if lock==false then
                    call targetHit()
                    call destroy()
                    return true
                else
                    call targetHit()
                endif
            endif
            return false
        endmethod
//=========================================================
         method Lanzar takes real speed, real arc returns nothing
            local real dx=tx-GetUnitX(m)
            local real dy=ty-GetUnitY(m)
            local real d=SquareRoot(dx*dx+dy*dy)
            local real dz=tz-GetUnitFlyHeight(m)
            set this.origenX=x
            set this.origenY=y
            set this.origenZ=GetUnitFlyHeight(m)
            set this.mvxy=speed*PERIOD
            set angle=Atan2(dy,dx)
            set time=RMaxBJ(d/speed,PERIOD)
            if arc > 0 then
                set mvz=( (d*arc)/(time/4) + dz/time )*PERIOD
                set arcing=true
            endif
            set mvx=Cos(angle)*mvxy
            set mvy=Sin(angle)*mvxy
            set finish=false
            // Verificar si está "al lado"
            if tu!=null then
                if d<=this.targetCollision then
                    call this.targetHit()
                    call this.destroy()
                    return
                endif
            endif
            if running == false then
                call KT_Add(function thistype.periodic,this,PERIOD)
                set running = true
            endif
        endmethod
//=========================================================
         method Stop takes nothing returns nothing
            set this.finish = true
        endmethod
//=========================================================
    endstruct
    
    //! textmacro PROJ_ACTION
        local proj this = proj.create(m)
        set this.caster = caster
        call this.onHitAction(onHit)
        call this.onLoopAction(onLoop)
        call this.onLoopEnumAction(onLoopEnum)
        call this.onHitEnumAction(onHitEnum)
    //! endtextmacro
    
    function GetTriggerProj takes nothing returns proj
        return proj.CollidingProj
    endfunction
    
    function CreateProj takes unit caster,unit m,real x,real y,real z,real speed,real arc,boolean rotate,interfaceFunc onLoop,colisionFunc onLoopEnum,interfaceFunc onHit,colisionFunc onHitEnum returns proj
        //! runtextmacro PROJ_ACTION()
        call this.setTargetPoint(x,y,z)
        set this.rotate = rotate
        call this.Lanzar(speed,arc)
        return this
    endfunction
    
    function CreateProjTarget takes unit caster,unit m,unit tu,real speed,real arc,boolean rotate,boolean stopOnDead,real colision,interfaceFunc onLoop,colisionFunc onLoopEnum,interfaceFunc onHit,colisionFunc onHitEnum returns proj
        //! runtextmacro PROJ_ACTION()
        call this.setTargetUnit(tu)
        set this.targetCollision=colision
        set this.rotate=rotate
        set this.stopOnDead=stopOnDead
        call this.Lanzar(speed,arc)
        return this
    endfunction
    
    function ProjGround takes unit caster,unit bullet,real x,real y,real z,real speed,real arc,real LoopCollision,real HitCollision,boolean rotate,boolean stopOnDead,interfaceFunc onLoop,interfaceFunc onHit,boolexpr LoopEnum,boolexpr HitEnum returns proj
        local proj this = proj.create(bullet)
        set this.caster = caster
        set this.CollideLoop=LoopEnum
        set this.CollideLoopRange=LoopCollision
        set this.CollideHit=HitEnum
        set this.CollideHitRange=HitCollision
        set this.stopOnDead=stopOnDead
        set this.rotate=rotate
        call this.onHitAction(onHit)
        call this.onLoopAction(onLoop)
        call this.setTargetPoint(x,y,z)
        call this.Lanzar(speed,arc)
        return this
    endfunction
    
endlibrary