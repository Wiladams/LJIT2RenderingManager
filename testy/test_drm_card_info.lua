package.path = package.path..";../?.lua"

local DRMCard = require("DRMCard")



local function test_version()
	print("==== test_version ====")
	local card, err = DRMCard();

	if (not card) then
		print("Error: ", err);
		return false, err;
	end

	local ver, err = card:getVersion();

	print("-- Version Info --")
	print(ver);
end

local function test_lib_version()
	print("==== test_lib_version ====")
	local card, err = DRMCard();
	if (not card) then
		print("Error: ", err);
		return false, err;
	end

	local ver, err = card:getLibVersion();
	if not ver then
		print("Error: ", err)
		return false, err;
	end

	print("-- Library Version Info --")
	print(ver);
end

local function test_bus_ID()
	print("==== test_bus_ID ====")
	local card, err = DRMCard();
	if (not card) then
		print("Error: ", err);
		return false, err;
	end

	print("-- Bus ID --")
	print(card:getBusId())
end

local function test_get_stats()
	print("==== test_get_stats ====")
	local card, err = DRMCard();
	if (not card) then
		print("Error: ", err);
		return false, err;
	end

	print("-- Stats --")
	local stats = card:getStats();
	
	if not stats then return end

	for _, entry in ipairs(stats) do
		print("===== ===== ===== =====")
		for k,v in pairs(entry) do
			print(k,v)
		end
	end
end



test_version();
test_lib_version();
test_bus_ID();
test_get_stats();
