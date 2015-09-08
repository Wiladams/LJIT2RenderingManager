package.path = package.path..";../?.lua"

local DRMCard = require("DRMCard")

local card, err = DRMCard();

if not card then 
	print("Error creating card: ", err)
	return false;
end


local function test_version()
	print("==== test_version ====")

	local ver, err = card:getVersion();

	print("-- Version Info --")
	print(ver);
end

local function test_lib_version()
	print("==== test_lib_version ====")

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

	print("-- Bus ID --")
	print(card:getBusId())
end

local function test_get_stats()
	print("==== test_get_stats ====")

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

local function show_connections()
	for _, conn in card:connections() do
		print("==== Connection ====")
		conn:print()
	end
end

local function show_all()
	test_version();
--	test_lib_version();
--	test_bus_ID();
--	test_get_stats();
--	card:print();
	show_connections();
end


--test_version();
--test_lib_version();
--test_bus_ID();
--test_get_stats();
show_all();
