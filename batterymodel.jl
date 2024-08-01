
"""
Battery Params
- capacity - maximum storage volume of the battery - MWh
- max_charge_rate - maximum charging rate of the battery - MW
- max_discharging_rate - maximum discharging rate of the battery - MW 
- degradiation_rate - the rate at which the battery degrades each charge cycle - % 
- charging_efficiency - percentage of energy from the grid that charges the battery - % 
- discharging_efficiency - percentage of energy from the grid that discharges the battery - %
- max_charges - maximum number of charges cycles that the battery can use - cycles 
- max_years - maximum number of years of use before the battery become unusable - yrs
- capex - the total capital cost of the battery storage unit - gbp 
- opex - the yearly cost of running the battery storay unit - gbp
"""
struct BatteryParams
    capacity::Float64 
    max_charge_rate::Float64
    max_discharge_rate::Float64
    degradiation_rate::Float64
    charging_efficiency::Float64
    discharging_efficiency::Float64
    max_charges::Float64
    max_years::Float64
    capex::Float64
    opex::Float64
end

@doc 
"""
optimise_battery_charge(prices, params, del_t=1800)

- computes the optimise battery power going in out of two markets
- Power is defined as the power going INTO the battery
- +ve means charging the battery
- -ve means discharging the battery 
- Using the apple definition of the number of cycles - 
Inputs:
prices: N x 2 matrix representing the two market prices in gbp/MW per half hour
params: parameters of the battery charge
del_t: The time step between each sample - by default 30mins = 1800s
Outputs: 
energies_in: N x 2 matrix representing the amount of power going into the battery from market 1 (col 1) and from market 2 (col 2)
total_profit: float representing the total costs 
""" 
function optimise_battery_charge(prices, params::BatteryParams, del_t=1800)
    N = size(prices)[1]
    overflow = 0.0
    max_samples = Int(params.max_years/del_t)
    if N > max_samples
        overflow = N - max_samples
        N = max_samples
    end
    
    model = Model()

    @variable(model, energy_in1[1:N]) # For market 1
    @variable(model, energy_in2[1:N]) # For market 2
    @variable(model, powers[1:N])
    @variable(model, energies[1:N])
    @variable(model, cycles[1:N])
    @variable(model, maximum_capacities[1:N])
    
    fix(energies[1], 0.0, force=true) # Assume that the battery is not charged at all 
    fix(cycles[1], 0.0, force=true)
    fix(maximum_capacities[1], params.capacity, force=true)

    @constraint(model, power_con, powers == (energy_in1 + energy_in2)./del_t)
    @constraint(model, power_min_max, -params.max_discharge_rate < powers < params.max_charge_rate)
    @constraint(model, energy_min_max, 0.0 < energies < maximum_capacities)
    @constriant(model, cycles_min_max, 0.0 < cycles < params.max_charges)
    @constraint(model, maximum_capacities_min_max, 0.0 < maximum_capacities < params.capacity)

    @constraints(model, energy_con[i=1:N-1], energies[i+1] ==  ) # For now just assume efficieny is the same 

    if overflow > 0.0
        # Add overflow zeros to the end
    end
end