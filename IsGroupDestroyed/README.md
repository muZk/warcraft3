# IsGroupDestroyed

Checks whenever a group is destroyed or not.

## Usage

``` 
local group g = CreateGroup()
call DestroyGroup(g)
if g == null then
	call BJDebugMsg("Nope, I will not be executed")
endif
if GetHandleId(g) == 0 then
	call BJDebugMsg("Nope, I will not be executed")
endif
if IsGroupDestroyed(g) then
	call BJDebugMsg("Yeah, I will be executed!")
endif
```

## Install
1. Create a trigger in your map called IsGroupDestroyed
2. Copy IsGroupDestroyed.j file content in your created trigger.
3. Save map.