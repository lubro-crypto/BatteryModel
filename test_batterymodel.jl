using IJulia, CSV, DataFrames, JuMP, YAML, Infiltrator, Dates
include("batterymodel.jl")
include("plot_funcs.jl")

input_data = CSV.read("data/input_data/market12_data.csv", DataFrame)
config_data = YAML.load_file("config.yml")

marketprices1 = input_data.Market_1
marketprices2 = input_data.Market_2
start_point = DateTime.(input_data.time[1], "dd/mm/yyyy HH:MM")
params = BatteryModel.BatteryParams(
            config_data["max_charging_rate"],
            config_data["max_discharging_rate"],
            config_data["max_storage_volume"],
            config_data["charging_efficiency"],
            config_data["discharging_efficiency"],
            config_data["lifetime_years"],
            config_data["lifetime_cycles"],
            config_data["degradation_rate"],
            config_data["capex"], 
            config_data["opex"]
)

N = length(marketprices1)
marketprices = hcat(marketprices1, marketprices2)
marketprices = marketprices[1:Int(round(N/100)),:]
marketprices = marketprices.*0.5
print("market prices: $marketprices")


@time energy_in, energy_out, energies, cycle, maximum_capacities, powers = BatteryModel.optimise_battery_charge(marketprices, params)

PlotFuncs.plot_battery_performance(marketprices, energy_in, energy_out, energies, powers, cycle, maximum_capacities)

PlotFuncs.write_battery_performance(marketprices, energy_in, energy_out, energies, cycle, maximum_capacities, start_point, params)