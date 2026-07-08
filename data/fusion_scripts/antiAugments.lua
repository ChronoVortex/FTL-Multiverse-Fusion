script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE,
function(ShipManager, AugName, AugValue)
  --For some reason, Hyperspace.ships(1) crashes when AugName == "CARGO_SLOT"
  if AugName == "CARGO_SLOT" or AugName == nil or ShipManager == nil or AugValue == nil then return Defines.Chain.CONTINUE, AugValue end
  if AugName:sub(0, 8) ~= "ANTIAUG_" and ShipManager then
    local OtherShipManager = Hyperspace.ships(1 - ShipManager.iShipId)
    if OtherShipManager then
      --Subtract other ship's ANTIAUG value from calculated value.
        AugValue = AugValue - OtherShipManager:GetAugmentationValue("ANTIAUG_"..AugName) 
    end
  end
  return Defines.Chain.CONTINUE, AugValue
end)

