-- test_framebuffer.lua
package.path = package.path..";../?.lua"

local DRMCard = require("DRMCard")

-- Try to create a connection to a card first
local card, err = DRMCard();

if not card then 
	print("Error creating card: ", err)
	return false;
end


