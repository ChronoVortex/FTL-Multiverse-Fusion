FUSION_INFO = {
  VERSION = {
    MAJOR = 0,
    MINOR = 1,
    FEATURE = 0,
  },
}
if FORGEMASTER_INFO then
  shouldTroll = true
   error("Forgemaster was patched before Fusion! Please re-patch your mods, and make sure to put Fusion first!") 
end

if TCC_INFO then
  shouldTroll = true
  error("Trash Compactor Collection was patched before Fusion! Please re-patch your mods, and make sure to put Fusion first!")
end

if CNC_WEAPONS_INFO then
  shouldTroll = true
  error("C&C Weapons was patched before Fusion! Please re-patch your mods, and make sure to put Fusion first!")
end

if BAG_OF_DUMB_INFO then
  shouldTroll = true
  error("Bag of Dumb was patched before Fusion! Please re-patch your mods, and make sure to put Fusion first!") 
end