-- LOCAL_MOD_KEY in IO/ModAuth.lua must match THIS_MOD_KEY.
THIS_MOD_KEY = "IntermodTestBench";

-- This starts with the mod key, so this mod only reacts to its own orders even though every mod sees every order.
---Prefix of the order made by this mod's menu, followed by the serialized {TargetModKey, Data} the player entered
SEND_ORDER_PREFIX = THIS_MOD_KEY .. "_SendSimulatedOrder~";
---Payload of the order this mod adds to show what it received or couldn't send
RECEIPT_PAYLOAD = THIS_MOD_KEY .. "_Receipt";
