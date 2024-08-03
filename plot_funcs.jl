module PlotFuncs

using CSV, DataFrames, Infiltrator, YAML, Plots, Dates
include("batterymodel.jl")
using .BatteryModel

"""
Calculate the total yearly profits of the battery
"""
function calculate_yearly_profits(prices, energies_in, energies_out, battery_params::BatteryParams, years)
    net_revenue = - sum(prices.*(energies_in.-energies_out))
    return (net_revenue - battery_params.opex*years - battery_params.capex) / years
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
function plot_battery_performance(prices, energies_in, energies_out, energies, cycles, maximum_capacities, del_t=1800)
    N = length(prices) # Will have to change later
    revenue =  - prices .* (energies_in .- energies_out)
    time = del_t * enumerate(N) / 86400 # in days

    plot(time, prices, xlabel="Time (days)", ylabel="Revenue (£)")

    plot(time, energies_in, xlabel="Time (days)", ylabel="Energy into Battery (MWh)")

    plot(time, energies_out, xlabel="Time (days)", ylabel="Energy out of Battery (MWh)")

    plot(time, energies, xlabel="Time (days)", ylabel="Battery Energy (MWh)")

    plot(time, cycles, xlabel="Time (days)", ylabel="Cycles (MWh)")

    plot(time, maximum_capacities, xlabel="Time (days)", ylabel="Max Capacity (MWh)")

    plot(time, revenue, xlabel="Time (days)", ylabel="Revenue (GBP)")

end

function write_battery_performance(prices, energies_in, energies_out, energies, cycles, maximum_capacities, start_time, del_t=1800)
    # Write the total revenue to a text file
    N = length(prices)
    years = N * del_t/ 86400
    total_profits = calculate_yearly_profits(prices, energies_in, energies_out, battery_params, years)
    file = open("data/output_data/total_profits.txt", "w")
    write(file, "The total annual profits (gbp/year) are $total_profits\n")
    close(file)
    # Write the data to a CSV file
    del_timestep = Dates.Second(del_t)
    time_steps = [start_time + i*del_timestep for i in 0:N]
    output_df = DataFrame(Time=time_steps, Energy_in=energies_in, Energy_out=energies_out, total_energies=energies, battery_cycles=cycles, maximum_capacities=maximum_capacities)
    CSV.write("data/output_data/battery_output_data.cvs", output_df)
end

end