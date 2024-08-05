module PlotFuncs

using CSV, DataFrames, Infiltrator, YAML, Plots, Dates
using ..BatteryModel
"""
Calculate the total yearly profits of the battery
"""
function calculate_yearly_profits(prices, energies_in, energies_out, battery_params::BatteryParams, years)
    net_revenue = - sum(prices.*(energies_in.-energies_out))
    return (net_revenue - battery_params.opex*years - battery_params.capex) / years, net_revenue
end

"""
plot_battery_performance(prices, charges, del_t=1800)
- This plots 6 graphs 
- Plot of the prices of each of the markets
- Plot of the energies in of each of the markets
- Plot of the energies out of each of the markets
- Plot of the energy of the battery
- Plot of the cycles of the battery 
- Plot of the maximum capacity of the battery
- Plot of the total costs of each of the markets 
"""
function plot_battery_performance(prices, energies_in, energies_out, energies, powers, cycles, maximum_capacities, del_t=1800, save_folder="plots/")
    N = length(prices) # Will have to change later
    revenue =  - prices .* (energies_in .- energies_out)
    time = del_t .* (1:N) ./ 86400 # in days

    p_prices = plot(time, prices, xlabel="Time (days)", ylabel="Prices (£)", legend=false)
    savefig(p_prices, save_folder*"prices_fig.png")

    p_energies_in = plot(time, energies_in, xlabel="Time (days)", ylabel="Energy into Battery (MWh)", legend=false)
    savefig(p_energies_in, save_folder*"energies_in_fig.png")

    p_energy = plot(time, energies, xlabel="Time (days)", ylabel="Battery Energy (MWh)", legend=false)
    savefig(p_energy, save_folder*"battery_energy_fig.png")

    p_cycles = plot(time, cycles, xlabel="Time (days)", ylabel="Cycles (MWh)", legend=false)
    savefig(p_cycles, save_folder*"battery_cycles_fig.png")

    p_max_cap = plot(time, maximum_capacities, xlabel="Time (days)", ylabel="Max Capacity (MWh)", legend=false)
    savefig(p_max_cap, save_folder*"battery_max_cap_fig.png")

    p_max_cap = plot(time, powers, xlabel="Time (days)", ylabel="Power in (MW)", legend=false)
    savefig(p_max_cap, save_folder*"power_fig.png")

    p_energies_out = plot(time, energies_out, xlabel="Time (days)", ylabel="Energy out (MWh)", legend=false)
    savefig(p_energies_out, save_folder*"energies_out_fig.png")

    p_revenues = plot(time, revenue, xlabel="Time (date)", ylabel="Revenue (GBP)", legend=false)
    savefig(p_revenues, save_folder*"revenues_fig.png")
end

function write_battery_performance(prices, energies_in, energies_out, energies, cycles, maximum_capacities, start_time, battery_params::BatteryParams, del_t=1800)
    # Write the total revenue to a text file
    N = length(prices)
    years = N * del_t/ 31536000
    total_profits, net_revenue = calculate_yearly_profits(prices, energies_in, energies_out, battery_params, years)
    file = open("data/output_data/total_profits.txt", "w")
    write(file, "The total revenue (gbp) is $net_revenue\n")
    write(file, "In $years years\n")
    write(file, "The total annual profits (gbp/year) are $total_profits\n")
    close(file)
    # Write the data to a CSV file
    del_timestep = Dates.Second(del_t)
    time_steps = [start_time + i*del_timestep for i in 0:(N-1)]
    output_df = DataFrame(Time=time_steps, Energy_in=energies_in, Energy_out=energies_out, total_energies=energies, battery_cycles=cycles, maximum_capacities=maximum_capacities)
    CSV.write("data/output_data/battery_output_data.cvs", output_df)
end

end