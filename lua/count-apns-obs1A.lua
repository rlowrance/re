-- count number of APNs in obs set 1A

require "csv"
require "set"

unique_apns = Set:new()

dataDir = "../../data/"
obs1Dir = dataDir .. "generated-v4/obs1A/"
csv = Csv:new(obs1Dir .. "features/apns.csv", "r")
header = csv:read()  -- ignore header
data_line_count = 0
for apn in csv:lines() do
   apn_number = apn + 0 -- convert string to number
   data_line_count = data_line_count + 1
   if not unique_apns:contains(apn_number) then
      unique_apns:add(apn_number)
   end
end

print(string.format("found %d data rows containing %d unique apns",
		    data_line_count, unique_apns:size()))
