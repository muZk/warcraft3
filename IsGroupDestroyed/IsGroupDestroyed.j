library IsGroupDestroyed

  globals
    private unit dummy
  endglobals
  
  function IsGroupDestroyed takes group g returns boolean
    if g == null then
      return true
    endif
    call GroupAddUnit(g, dummy)
    if IsUnitInGroup(dummy, g) then
      call GroupRemoveUnit(g, dummy)
      return false
    endif
    return true
  endfunction
  
  private module InitModule
    private static method onInit takes nothing returns nothing
      set dummy = CreateUnit(Player(15), 'hfoo', 0, 0, 0)
      call UnitAddAbility(dummy, 'Aloc')
    endmethod
  endmodule
  
  private struct Init
    implement InitModule
  endstruct

endlibrary