#this function can be used to modify the P and Q values at buses from a network case read in by the PowerModels.jl parser. currently, both the P and Q are multiplied by the same value. 
#call this function inline, after defining a case using "case = parse_file(case_path)"
#the coordinates describe a rectangle around an area. any bus in this geographic region will be adjusted. 

function modify_loads(case::Dict, lat_min::Float64, lat_max::Float64, long_min::Float64, long_max::Float64, multiplier::Float64)
    println("Adjusted buses:")
    for (bus_num, bus_data) in case["bus"]
        lat = bus_data["lat"]
        lon = bus_data["lon"]

        if lat_min <= lat <= lat_max && long_min <= lon <= long_max
            if haskey(case["load"], bus_num)
                bus_load = case["load"][bus_num]
                bus_load["pd"] *= multiplier
                bus_load["qd"] *= multiplier
                println(bus_num)
            end
        end
    end
end
