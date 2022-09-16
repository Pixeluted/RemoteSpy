## Script
```lua
local url = "https://raw.githubusercontent.com/GameGuyThrowaway/RemoteSpy/main/script.lua"
loadstring(syn.request({ Url = url }).Body)()
```

## Script
**WARNING, YOU MUST LEFT CLICK REMOTE ARG LOGS TO VIEW OPTIONS**
```lua
local url = "https://raw.githubusercontent.com/GameGuyThrowaway/RemoteSpy/main/scriptBeta.lua"
loadstring(syn.request({ Url = url }).Body)()
```

# Description
* Custom made Remote Spy for Synapse V3 (try not to leak source to any non v3 users).
* Any and All bugs/detections/suggestions can be reported to me on discord at GameGuy#5286 <@515708480661749770>
* By executing the script a second time, you will clear all traces of it ever being there (GCs the ui, and restores all function hooks), but please wait until the ui disappears before executing it again, as it will throw an error otherwise.

# To Do:
* Redo all functions copied from Hydroxide (most could use some major optimizations for this usecase)
* Implement RenderPopups once they get added properly // started working on this in the beta
* Clean up gui code once RenderPopups get added // started working on this in the beta
* Possibly implement outlines around gui objects, if possible, and when possible
* Implement a condition system (arg guard of sorts), for blocking certain remote calls that were called with: x amount of args, type(arg) == x at index y, etc.  (Basically just implement the Filter api into the RemoteSpy)

# Credits
* Made by GameGuy#5286
* Some functions were "borrowed" and modified + optimized from Hydroxide (pseudocode related functions), these functions are labelled in the source code
