scope Test initializer Init

    function AssertEqual takes boolean b1, boolean b2, string msg returns nothing
        local string red = "|cffff0000"
        local string green = "|cff008000"
        local string end = "|r"
        if b1 == b2 then
            call BJDebugMsg(green + msg + end)
        else
            call BJDebugMsg(red + msg + end)
        endif
    endfunction

    globals
        private group g
        private boolean b
    endglobals
    
    function Test1 takes nothing returns nothing
        set g = NewGroup()
        call AssertEqual(g == null, false, "Test 1: NewGroup() isn't null.")
        call ReleaseGroup(g)
    endfunction
    
    function Test2 takes nothing returns nothing
        set g = NewGroup()
        call DestroyGroup(g)
        call AssertEqual(ReleaseGroup(g), false, "Test 2: ReleaseGroup() on destroyed group shouldn't work.") 
    endfunction
    
    function Test3 takes nothing returns nothing
        call AssertEqual(ReleaseGroup(null), false, "Test 3: ReleaseGroup() on null group shouldn't work.") 
    endfunction
    
    function Test4 takes nothing returns nothing
        call NewGroup() // in case Test3, just "pops" the queue
        set g = NewGroup()
        set b = ReleaseGroup(g)
        call AssertEqual(b, true, "Test 4.1: Correctly released")
        call DestroyGroup(g)
        call AssertEqual(IsGroupDestroyed(g), true, "Test 4.2: Correctly destroyed")
        set g = NewGroup() 
        call AssertEqual(IsGroupDestroyed(g), false, "Test 4: NewGroup shouldn't return a destroyed group")
    endfunction
    
    function Test5 takes nothing returns nothing
        set g = NewGroup()
        call ReleaseGroup(g)
        call AssertEqual(ReleaseGroup(g), false, "Test 5: Releasing a group twice shouldn't work")
    endfunction

    private function Init takes nothing returns nothing
        call Test1()
        call Test2()
        call Test3()
        call Test4()
        call Test5()
    endfunction
endscope