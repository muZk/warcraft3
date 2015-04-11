/*
 * Version 2.0
 * Usage:
 *  - Use NewGroup() instead of CreateGroup()
 *  - Use ReleaseGroup(g) instead of DestroyGroup(g)
 *  - When you use groups only for enumeration, use the ENUM_GROUP global instead
 * Changelogs:
 *  2.0:
 *    - Rewritten in vjass
 *    - Added validations to:
 *        - Avoid releasing a group multiple times
 *        - Avoid releasing a null group
 *        - Avoid releasing a destroyed group
 *        - NewGroup now always returns a non-destroyed & empty group
 *  Release (1.0): 
 */

library NewGroup requires IsGroupDestroyed

  globals
    private integer count = 0
    private group array groups
    private hashtable ht = InitHashtable()
    group ENUM_GROUP = CreateGroup()
  endglobals

  function NewGroup takes nothing returns group
    if count == 0 then
      return CreateGroup()
    endif

    loop
        set count = count - 1
    
        if !IsGroupDestroyed(groups[count]) then
            call GroupClear(groups[count]) // Always return an empty group
            call RemoveSavedBoolean(ht, GetHandleId(groups[count]), 0)
            return groups[count]
        endif
        
        debug call BJDebugMsg(SCOPE_PREFIX+"Warning: A null group was found in groups array, at: " + I2S(count))
        
        exitwhen count == 0
    endloop
    
    return CreateGroup()
  endfunction

  function ReleaseGroup takes group g returns boolean
    if IsGroupDestroyed(g) then
        debug call BJDebugMsg(SCOPE_PREFIX+"Error: Destroyed groups cannot be released")
        return false
    elseif HaveSavedBoolean(ht, GetHandleId(g), 0) then
        debug call BJDebugMsg(SCOPE_PREFIX+"Error: Groups cannot be multiply released")
        return false
    elseif count == 8191 then
        debug call BJDebugMsg(SCOPE_PREFIX+"Error: Max recycled groups achieved, destroying group")
        call DestroyGroup(g)
        return false
    endif
    call GroupClear(g)
    set groups[count] = g
    set count = count + 1
    call SaveBoolean(ht, GetHandleId(g), 0, true)
    return true
  endfunction

endlibrary