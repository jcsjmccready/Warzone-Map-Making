-- Everything that differs between IntermodTesterA and IntermodTesterB lives here. LOCAL_MOD_KEY in IO/ModAuth.lua must match THIS_MOD_KEY.
THIS_MOD_KEY = "IntermodTesterA";
OTHER_MOD_KEY = "IntermodTesterB";

-- These start with the mod key, so each mod only reacts to its own orders even though every mod sees every order.
---Payload of the order made by this mod's menu, it asks this mod to send a test order to the other mod
SEND_ORDER_PAYLOAD = THIS_MOD_KEY .. "_SendTestOrder";
---Payload of the order this mod adds to show what it received or couldn't send
RECEIPT_PAYLOAD = THIS_MOD_KEY .. "_Receipt";
