library KT
    ///////////////
    // Constants //
    ////////////////////////////////////////////////////////////////////////////
    // That bit that users may play with if they know what they're doing.
    // Not touching these at all is recommended.
    globals
        // Period Threshold is the point at which Key Timers 2 will switch from
        // using the single timer per period mechanism to using TAZO, which is
        // better for higher periods due to the first tick being accurate.
        private constant real PERIODTHRESHOLD=0.3 // MUST be below 10.24 seconds.
        
        // Tazo's number of precached instances. You can go over this during
        // your map at runtime, but it will probably do some small background
        // processing. Precaching just speeds things up a bit.
        private constant integer TAZO_PRECACHE=64
        
        // Tazo uses the low period part of Key Timers 2 to construct triggers
        // over time when precached ones run out. Here you can set the period used.
        private constant real TAZO_CONSTRUCT_PERIOD=0.03125
        
        public constant real PERIOD=0.03125
        
    endglobals
    
    //////////////////////////
    // Previous KT2 Globals //
    ////////////////////////////////////////////////////////////////////////////
    // These needed to be moved here for TAZO to hook GetData.
    globals
        private timer array KeyTimer
        private trigger array TimerTrigger
        private integer array KeyTimerListPointer
        private integer array KeyTimerListEndPointer
        private triggercondition array TriggerCond
        private boolexpr array Boolexpr
        private integer array Data
        private integer array Next
        private integer array Prev
        private integer TrigMax=0
        private integer array NextMem
        private integer NextMemMaxPlusOne=1
        private integer array ToAddMem
        private triggercondition array ToRemove
        private boolexpr array ToDestroy
        private boolean array IsAdd
        private integer AddRemoveMax=0
        
        // Locals
        private integer t_id=-1
        private integer t_mem
        private integer t_lastmem
        private integer a_id
        private integer a_mem
        
        // Code Chunks
        private conditionfunc RemoveInstanceCond
    endglobals
    
    //////////////////
    // Previous KT2 //
    ////////////////////////////////////////////////////////////////////////////
    // The KT2 implementation
    private function KeyTimerLoop takes nothing returns nothing
        set t_id=R2I(TimerGetTimeout(GetExpiredTimer())*800)
        set t_mem=KeyTimerListEndPointer[t_id]
        call TriggerEvaluate(TimerTrigger[t_id])
        set t_mem=0
        loop
            exitwhen t_mem==AddRemoveMax
            set t_mem=t_mem+1
            if IsAdd[t_mem] then
                set TriggerCond[ToAddMem[t_mem]]=TriggerAddCondition(TimerTrigger[t_id],Boolexpr[ToAddMem[t_mem]])
            else
                call TriggerRemoveCondition(TimerTrigger[t_id],ToRemove[t_mem])
                call DestroyBoolExpr(ToDestroy[t_mem])
            endif
        endloop
        set AddRemoveMax=0
        set t_id=-1
    endfunction
    
    private function RemoveInstance takes nothing returns boolean
        // Will only fire if code returns true.
        set AddRemoveMax=AddRemoveMax+1
        set IsAdd[AddRemoveMax]=false
        set ToRemove[AddRemoveMax]=TriggerCond[t_lastmem]
        set ToDestroy[AddRemoveMax]=Boolexpr[t_lastmem]
        if Next[t_lastmem]==0 then
            set KeyTimerListEndPointer[t_id]=Prev[t_lastmem]
        endif
        set Prev[Next[t_lastmem]]=Prev[t_lastmem]
        if Prev[t_lastmem]==0 then
            set KeyTimerListPointer[t_id]=Next[t_lastmem]
            if KeyTimerListPointer[t_id]<1 then
                call PauseTimer(KeyTimer[t_id])
            endif
        else
            set Next[Prev[t_lastmem]]=Next[t_lastmem]
        endif
        set NextMem[NextMemMaxPlusOne]=t_lastmem
        set NextMemMaxPlusOne=NextMemMaxPlusOne+1
        return false
    endfunction
    
    private function KTadd takes code func, integer data, real period returns nothing
        set a_id=R2I(period*800)
        
        if KeyTimer[a_id]==null then
            set KeyTimer[a_id]=CreateTimer()
            set TimerTrigger[a_id]=CreateTrigger()
        endif
        
        if NextMemMaxPlusOne==1 then
            set TrigMax=TrigMax+1
            set a_mem=TrigMax
        else
            set NextMemMaxPlusOne=NextMemMaxPlusOne-1
            set a_mem=NextMem[NextMemMaxPlusOne]
        endif
        
        set Boolexpr[a_mem]=And(Condition(func),RemoveInstanceCond)
        if t_id==a_id then
            set AddRemoveMax=AddRemoveMax+1
            set IsAdd[AddRemoveMax]=true
            set ToAddMem[AddRemoveMax]=a_mem
        else
            if KeyTimerListPointer[a_id]<1 then
                call TimerStart(KeyTimer[a_id],a_id/800.0,true,function KeyTimerLoop)
                set KeyTimerListEndPointer[a_id]=a_mem
            endif
            
            set TriggerCond[a_mem]=TriggerAddCondition(TimerTrigger[a_id],Boolexpr[a_mem])
        endif
        set Data[a_mem]=data
        
        set Prev[a_mem]=0
        set Next[a_mem]=KeyTimerListPointer[a_id]
        set Prev[KeyTimerListPointer[a_id]]=a_mem
        set KeyTimerListPointer[a_id]=a_mem
    endfunction
    
    public function GetData takes nothing returns integer // Gets hooked by TAZO.
        set t_lastmem=t_mem
        set t_mem=Prev[t_mem]
        return Data[t_lastmem]
    endfunction
    
    private function KTinit takes nothing returns nothing
        set RemoveInstanceCond=Condition(function RemoveInstance)
    endfunction
    
    //////////
    // TAZO //
    ////////////////////////////////////////////////////////////////////////////
    // KT2 implementation for higher periods (low frequency).
    globals
        private constant integer TAZO_DATAMEM=8190 // Added for KT2 hook. Don't change.
    endglobals
    
    globals
        private conditionfunc TAZO_LoadDataCond
        private conditionfunc TAZO_RemoveInstanceCond
        
        private timer   array TAZO_TrigTimer
        private integer array TAZO_Data
        private boolexpr array TAZO_Boolexpr
        
        private trigger array TAZO_AvailableTrig
        private integer       TAZO_Max=0
        
        private integer       TAZO_ConstructNext=0
        private trigger array TAZO_ConstructTrig
        private integer array TAZO_ConstructCount
    endglobals
    
    globals//locals
        private integer TAZO_ConKey
    endglobals
    private function TAZO_Constructer takes nothing returns boolean
        set TAZO_ConKey=GetData()
        call TriggerExecute(TAZO_ConstructTrig[TAZO_ConKey])
        set TAZO_ConstructCount[TAZO_ConKey]=TAZO_ConstructCount[TAZO_ConKey]-1
        if TAZO_ConstructCount[TAZO_ConKey]==0 then
            set TAZO_Max=TAZO_Max+1
            set TAZO_AvailableTrig[TAZO_Max]=TAZO_ConstructTrig[TAZO_ConKey]
            set TAZO_TrigTimer[TAZO_ConKey]=CreateTimer()
            call TriggerRegisterTimerExpireEvent(TAZO_AvailableTrig[TAZO_Max],TAZO_TrigTimer[TAZO_ConKey])
            return true
        endif
        return false
    endfunction
    
    globals//locals
        private trigger TAZO_DeadTrig
        private integer TAZO_DeadCount
    endglobals
    private function TAZO_Recycle takes nothing returns boolean
        set TAZO_DeadTrig=GetTriggeringTrigger()
        set TAZO_DeadCount=GetTriggerExecCount(TAZO_DeadTrig)
        call TriggerClearConditions(TAZO_DeadTrig)
        call DestroyBoolExpr(TAZO_Boolexpr[TAZO_DeadCount])
        call PauseTimer(TAZO_TrigTimer[TAZO_DeadCount])
        set TAZO_Max=TAZO_Max+1
        set TAZO_AvailableTrig[TAZO_Max]=TAZO_DeadTrig
        return false
    endfunction
    
    private function TAZO_LoadData takes nothing returns boolean
        // KT2 Data Hook
        set t_mem=TAZO_DATAMEM
        set Data[TAZO_DATAMEM]=TAZO_Data[GetTriggerExecCount(GetTriggeringTrigger())]
        // End KT2 Data Hook
        return false
    endfunction
    
    private function InitTrigExecCount takes trigger t, integer d returns nothing
        if d>128 then
            call InitTrigExecCount.execute(t,d-128)
            set d=128
        endif
        loop
            exitwhen d==0
            set d=d-1
            call TriggerExecute(t)
        endloop
    endfunction
    
    globals//locals
        private integer TAZO_AddKey
        private trigger TAZO_AddTrigger
    endglobals
    public function TAZOadd takes code func, integer data, real period returns nothing
        if TAZO_Max==0 then
            // Failsafe.
            set TAZO_ConstructNext=TAZO_ConstructNext+1
            set TAZO_AddTrigger=CreateTrigger()
            set TAZO_AddKey=TAZO_ConstructNext
            call InitTrigExecCount.execute(TAZO_AddTrigger,TAZO_AddKey)
            set TAZO_TrigTimer[TAZO_AddKey]=CreateTimer()
            call TriggerRegisterTimerExpireEvent(TAZO_AddTrigger,TAZO_TrigTimer[TAZO_AddKey])
        else
            set TAZO_AddTrigger=TAZO_AvailableTrig[TAZO_Max]
            set TAZO_AddKey=GetTriggerExecCount(TAZO_AddTrigger)
            set TAZO_Max=TAZO_Max-1
        endif
        set TAZO_Data[TAZO_AddKey]=data
        set TAZO_Boolexpr[TAZO_AddKey]=And(Condition(func),TAZO_RemoveInstanceCond)
        call TriggerAddCondition(TAZO_AddTrigger,TAZO_LoadDataCond)
        call TriggerAddCondition(TAZO_AddTrigger,TAZO_Boolexpr[TAZO_AddKey])
        call TimerStart(TAZO_TrigTimer[TAZO_AddKey],period,true,null)
        if TAZO_Max<10 then
            set TAZO_ConstructNext=TAZO_ConstructNext+1
            set TAZO_ConstructTrig[TAZO_ConstructNext]=CreateTrigger()
            set TAZO_ConstructCount[TAZO_ConstructNext]=TAZO_ConstructNext
            call KTadd(function TAZO_Constructer,TAZO_ConstructNext,TAZO_CONSTRUCT_PERIOD)
        endif
    endfunction
    
    private function TAZOinit takes nothing returns nothing
        set TAZO_LoadDataCond=Condition(function TAZO_LoadData)
        set TAZO_RemoveInstanceCond=Condition(function TAZO_Recycle)
        // Allow for GetData
        set Next[TAZO_DATAMEM]=TAZO_DATAMEM
        set Prev[TAZO_DATAMEM]=TAZO_DATAMEM
        // End allow for GetData
        loop
            exitwhen TAZO_Max==TAZO_PRECACHE
            set TAZO_ConstructNext=TAZO_ConstructNext+1 // The index.
            set TAZO_Max=TAZO_Max+1 // Will be the same in the initialiser as ConstructNext.
            set TAZO_AvailableTrig[TAZO_Max]=CreateTrigger()
            call InitTrigExecCount.execute(TAZO_AvailableTrig[TAZO_Max],TAZO_ConstructNext)
            set TAZO_TrigTimer[TAZO_ConstructNext]=CreateTimer()
            call TriggerRegisterTimerExpireEvent(TAZO_AvailableTrig[TAZO_Max],TAZO_TrigTimer[TAZO_ConstructNext])
        endloop
    endfunction
    
    ///////////////
    // Interface //
    ////////////////////////////////////////////////////////////////////////////
    // Stitches it all together neatly.
    public function Add takes code func, integer data, real period returns nothing
        if period<PERIODTHRESHOLD then
            call KTadd(func,data,period)
        else
            call TAZOadd(func,data,period)
        endif
    endfunction
    
    private module InitModule
        private static method onInit takes nothing returns nothing
            call KTinit()
            call TAZOinit()
        endmethod
    endmodule
    
    private struct InitStruct extends array
        implement InitModule
    endstruct
endlibrary