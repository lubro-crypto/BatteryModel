using CSV, DataFrames, Infiltrator, YAML, Plots, Dates
include("batterymodel.jl")
using .BatteryModel

"""
Calculate the total yearly profits of the battery
"""
function calculate_yearly_profits(prices, energies_in, battery_params:BatteryParams, years)
    net_revenue = - sum(prices.*energies_in)
    return (net_revenue - battery_params.opex*years - battery_params.capex) / years
end

"""
plot_battery_performance(prices, charges, del_t=1800)
- This plots 6 graphs 
- Plot of the prices of each of the markets
- Plot of the charges of each of the markets
- Plot of the energy of the battery
- Plot of the cycles of the battery 
- Plot of the maximum capacity of the battery
- Plot of the total costs of each of the markets 
"""
function plot_battery_performance(prices, energies_in, energies, cycles, maximum_capacities, del_t=1800, save_folder="plots/")
    N = length(prices) # Will have to change later
    revenue =  - prices .* energies_in
    time = del_t * enumerate(N) / 86400 # in days

    p_prices = plot(time, prices, xlabel="Time (days)", ylabel="Revenue (£)")
    savefig(p_prices, save_folder*"prices_fig.png")

    p_energies_in = plot(time, energies_in, xlabel="Time (days)", ylabel="Energy into Battery (MWh)")
    savefig(p_energies_in, save_folder*"energies_in_fig.png")

    p_energy = plot(time, energies, xlabel="Time (days)", ylabel="Battery Energy (MWh)")
    savefig(p_energy, save_folder*"battery_energy_fig.png")

    p_cycles = plot(time, cycles, xlabel="Time (days)", ylabel="Cycles (MWh)")
    savefig(p_cycles, save_folder*"battery_cycles_fig.png")

    p_max_cap = plot(time, maximum_capacities, xlabel="Time (days)", ylabel="Max Capacity (MWh)")
    savefig(p_max_cap, save_folder*"battery_max_cap_fig.png")

end

function write_battery_performance(prices, energies_in, energies, cycles, maximum_capacities, start_time, del_t=1800)
    # Write the total revenue to a text file
    N = length(prices)
    years = N * del_t/ 86400
    total_profits = calculate_yearly_profits(prices, energies_in, battery_params, years)
    file = open("data/output_data/total_profits.txt", "w")
    write(file, "The total annual profits (gbp/year) are $total_profits\n")
    close(file)
    # Write the data to a CSV file
    del_timestep = Dates.Second(del_t)
    time_steps = [start_time + i*del_timestep for i in 0:N]
end

market12_df = CSV.read("data/input_data/market12_data.csv", DataFrame)
config_data = YAML.load_file("config.yml")

battery_params = BatteryParams(config_data["max_charge_rate"],
                config_data["max_discharging_rate"],
                config_data["max_storage_volume"],
                config_data["charging_efficiency"],
                config_data["discharging_efficiency"],
                config_data["lifetime_years"],
                config_data["lifetime_cycles"],
                config_data["degradation_rate"],
                config_data["capex"], 
                config_data["opex"])

prices = market12_df.Market_1

charges = optimise_battery_charge(prices, battery_params)

