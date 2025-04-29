#skyler reid
#test adjusting generator outputs until some kind of voltage collapse occurs

#use mld formulation for figuring out how low qg can go
#or use powermodels opf 

using PowerModels, PowerModelsGMD
PowerModels.silence()
PowerModelsGMD.silence()

include("state_plot.jl")
include("modify_loads.jl")
include("modify_gens.jl")
include("find_qg_limit.jl")
case_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\150_sync\\uiuc150bus_10.m"
shp_path = "C:\\Users\\skyle\\OneDrive - Montana State University\\EELE 491\\data\\ne_110m_admin_1_states_provinces.shp"


case1 = PowerModelsGMD.parse_file(case_path)

gens_list = [1,2,3,4,5,6,7,8,9,10,12,14,16]

result = find_qg_limit(case1, gens_list, 0.01)
# solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-4, "print_level" => 0, "sb" => "yes")
# result1 = solve_ac_opf(case1, solver)