# NewGroup 2.0

Provides two functions: _NewGroup_ and _ReleaseGroup_. Both can be found in the famous library called _GroupUtils_ in this link: http://www.wc3c.net/showthread.php?t=104464

NewGroup takes care only of group recycling, so its like a lighweight version. 

## Requeriments
- Requires https://github.com/muZk/warcraft3/tree/master/IsGroupDestroyed

## Usage

- Just replace your calls of ```CreateGroup()``` with ```NewGroup()``` and ```DestroyGroup(g)``` with ```ReleaseGroup(g)```.
- Use ```ENUM_GROUP``` when you're using a group only for enumeration (not for persistence).

## Install
1. Make sure you have installed the dependencies:
	- https://github.com/muZk/warcraft3/tree/master/IsGroupDestroyed
2. Create a trigger in your map called NewGroup
3. Copy NewGroup.j file content in your created trigger.
4. Save map.

## GroupUtils VS NewGroup

1. Both implements NewGroup and ReleaseGroup functions.
2. GroupUtils is broken:
	- One can save destroyed groups in GroupUtils, while in NewGroup you can't.
	- One can retrieve a destroyed group from GroupUtils, while in NewGroup you can't.
3. Both checks for max saved groups.
4. Both validates multiple stored groups.
5. GroupUtils have more functionalities, such a better group enumeration and ENUM_GROUP destroy hook.
6. Both includes ENUM_GROUP global.