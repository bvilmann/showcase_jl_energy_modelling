# Modelling
using JuMP, Cbc, CPLEX, Juniper, Ipopt

# Formatting
using Dates
import Random
# Data
using Statistics
using DataFrames
using ExcelFiles
using FileIO

# ========================== FUNCTIONS ==========================
# -------------------------- helper funcs --------------------------
function string_to_float(str)
  try
    convert(Float64, str)
  catch
    return missing
  end
end
function getMinCap(maxcap,form)
  if form == "ng"
    return 0
  elseif form == "nuclear"
    return 0.5*maxcap
  elseif form == "lignite"
    return 0.5*maxcap
  elseif form == "hardcoal"
    return 0.6*maxcap
  elseif form == "biomass"
    return 0.9*maxcap
  else
    return 0
  end
end




# ========================== STRUCTS ==========================
struct Line
  from;
  from_state;
  to;
  to_state;
  loss;
  capacity;
end

struct State
  node;             # Node number
  state;            # State name
  generation;       # Generation
  demand;           # Demand from state
end

struct Plant
  node;             # Node number
  state;            # State name
  capacity;         # capacity
  cap_min;          # Minimum capacity
  cap_max;          # maximum capacity
  cf;               # State-wise capacity factor
  type;             # Energy carrier type
end

# ========================== GETTING DATA ==========================
function getData(T_offset,T,path)
    cd(path)
    println("Getting data if not loaded")
    # Line distances for transmission lines in between states
    if ! @isdefined len
        println(" - Loading Line distances of the transmission lines between states, len")
        global len = load("data.xlsx","line len (avg)") |> DataFrame
        len = len[:,2:end]
        len = replace!(convert(Matrix, len), missing=>0)
    end

    # Line capacities of the transmission lines between states
    if ! @isdefined cap
        println(" - Loading Line capacities of the transmission lines between states, cap")
        global cap = load("data.xlsx","line caps") |> DataFrame
        cap = cap[:,2:end]
        cap = replace!(convert(Matrix, cap), missing=>0)
    end

    # Number of lines in between states
    if ! @isdefined num
        println(" - Loading Number of lines in between states, num")
        global num = load("data.xlsx","line num") |> DataFrame
        num = num[:,2:end]
        num = replace!(convert(Matrix, num), missing=>0)
    end

    # Capacity factors for each state
    if ! @isdefined cf
      println(" - Loading capacity factor for each fuel type for each state, cf")
      global cf = load("data.xlsx","State CF") |> DataFrame
      cf = cf[:,3:end]
      cf = replace!(convert(Matrix, cf), missing=>0)
    end

    # Absolute capacities for each fuel type for each state
    if ! @isdefined pcap
        println(" - Loading absolute capacities for each fuel type for each state, pcap")
        global pcap = load("data.xlsx","State C") |> DataFrame
        pcap = pcap[:,3:end]
        pcap = replace!(convert(Matrix, pcap), missing=>0)
    end

    # Consumption data for each state,
    if ! @isdefined con
      println(" - Loading Consumption data for each state, con")
      global con = load("data.xlsx","consumption") |> DataFrame
      con.date = [DateTime(2019,con.month[i],con.day[i],con.hour[i]) for i in 1:length(con.Datum)]
      println(" - Multiplying consumption with 4 to adjust quarterly resolution to hourly, dem")
      global dem = con[con[:,:min] .== 0,:]
      dem = dem[:,10:end]
      dem = replace!(convert(Matrix, dem), missing=>0)
      dem = dem.*4
    end

    if ! @isdefined dfm
        # Generation capacities for each fuel type at each state
        println(" - Loading generation capacities for each fuel type at each state, dfm")
        global dfm = load("data.xlsx","capacities") |> DataFrame
        dfm.date = [DateTime(2019,dfm.month[i],dfm.day[i],dfm.hour[i]) for i in 1:length(dfm.Date)]
        dfm.wonshore = map(string_to_float, dfm.:wonshore)

        # Creating data set representing available capacity for each time step (variable RES)
        println(" - Creating data set representing available capacity for each time step (variable RES), c")
        global c = combine(groupby(dfm, :date),
            [i => mean for i in names(dfm)[9:end-1]]
        )
        c = c[:,2:end]
        c = replace!(convert(Matrix, c), missing=>0) .* 1 .*hcat(ones(1,2), repeat([4],1,3), ones(1,7))
    end

    if ! @isdefined HRparams
        println(" - Loading parameters for non-linear partial load option, HRparams")
        global HRparams = load("data.xlsx","HRparameters") |> DataFrame
    end

    # Get actual generation
    if ! @isdefined gen
        println(" - Loading actual generation for the period, gen")
        global gen = load("data.xlsx","generation") |> DataFrame
        gen = gen[gen[:,:min] .== 0,:]
        gen = gen[:,9:end]
        gen = replace!(convert(Matrix, gen), missing=>0)
    end

    # ========================== CONSTANTS ==========================
    println("\nDefining constants")
    # Assuming dimensions
    N = length(cf[:,1])   # Number of states
    F = length(cf[1,:])   # Number of fuel types
    #T = length(c[:,1])    # Number of time steps

    # Names for matrices
    states = names(con)[10:end]
    energy = names(dfm)[9:end-1]
    # Generating random losses for transmission lines
    #loss = rand(90:280,16,16)
    loss = rand(90:120,16,16)

    global CO2price = 24.6 # €/ton

    # ========================== POPULATING DATA / PREPARING MODEL ==========================

    println(T_offset," ,",T)

    println("\nPreparing model")
    T_up = convert(Array{Int,2},hcat(rand(2:5,N,2), zeros(N,3),rand(2:1:5,N,7)))
    T_down = convert(Array{Int,2},hcat(rand(2:1:5,N,2), zeros(N,3),rand(2:1:5,N,7)))

    for n in 1:N
      for f in 1:F
        T_up[n,f] = floor(Int,T_up[n,f])
        T_down[n,f] = floor(Int,T_down[n,f])

      end
    end

    # Generating capacity for each time step for each plant
    println(" - Generating capacity for each time step for each plant")
    global P_C = zeros(N,F,T)
    for t in 1:T
      P_C[:,:,t] = cf.*repeat(c[t+T_offset,:]',N,1)
    end

    # LINES:
    println(" - Populating structs for transmission lines")
    global Lines = []          # Transmission lines
    for i in 1:N
      for j in 1:N
        if i < j && cap[i,j] > 0
          #push!(Edges,Edg(i,j,(len.*num.*loss)[i,j],cap[i,j]))
          push!(Lines,
            Line(
              i,
              states[i],
              j,
              states[j],
              (len.*num.*loss./10000)[i,j],
              cap[i,j]
            )
          )
        end
      end
    end

    # STATES:
    println(" - Populating structs for states")
    global States = Array{State}(undef, (N,T))
    for n in 1:N
      for t in 1:T
        States[n,t] =
          State(
            n,
            states[n],
            sum(P_C[n,:,t]),
            dem[t,n],
          )
      end
    end

    # POWER PLANTS
    println(" - Populating structs for plants")
    global Plants = Array{Plant}(undef, (N,F,T))
    for n in 1:N
      for f in 1:F
        for t in 1:T
          Plants[n,f,t] =
            Plant(
              n,
              states[n],
              P_C[n,f,t],
              getMinCap(pcap[n,f],energy[f]),
              pcap[n,f],
              cf[n,f],
              #getCO2Cost,
              energy[f]
            )
        end
      end
    end
    return (P_C,Lines,States,Plants,N,F,T_up,T_down)
end
# ============================== MODEL ==============================

function energyModel(
    T=24,
    Flow_loss     = false,
    MIP_runtime   = false,
    MIP_unit      = false,
    nl            = false,
    silent        = true
    )
    # -------------------------- model funcs --------------------------
    function consecutive(T_up,n,f,t,sum=0)
        if T_up > 0
            sum += x[n,f,t + T_up]
            consecutive(T_up - 1,n,f,t,sum)
        else
            return sum
        end
    end
    function consecutive_down(T,n,f,t,sum=0)
        if T > 0
            sum += x_neg[n,f,t + T]
            consecutive_down(T - 1,n,f,t,sum)
        else
            return sum
        end
    end
    function HR(P_G,P_ratio,P_max,n_opt,a,b,C1,C2)
            if P_max == 0
                return P_G*convert(Float64,0)
            else
                return 1/(n_opt*(1+(a*(P_ratio-(P_G/P_max)))+(b*(P_ratio-((P_G/P_max)^2)*C1*C2))))
            end
    end


    println("\n")

    if ! @isdefined len
        if ! @isdefined path
            global path = input("Please provide the directory of the data file: ")
        else
            if path == nothing
                global path = input("Please provide the directory of the data file: ")
            end
        end
    end

    # ======================== Input qualification ========================
    # Model switches
    println("\nRunning input qualification for model options")
    if nl
      MIP_runtime = false
    end

    if MIP_runtime
      MIP_unit = true
    end


    # Time range
    if typeof(T) == Tuple{String,String}
        if length(T) == 2
            date = T
            t0 = Date(2019,01,01)
            t1 = Date(parse(Int64,split(T[1],"-")[1]),parse(Int64,split(T[1],"-")[2]),parse(Int64,split(T[1],"-")[3]))
            t2 = Date(parse(Int64,split(T[2],"-")[1]),parse(Int64,split(T[2],"-")[2]),parse(Int64,split(T[2],"-")[3]))

            T           = ((t2-t1).value+1)*24
            T_offset    = (t1-t0).value*24

            if T <= 0 || T_offset < 0
                error("Negative time range is given: $(date) => $(T)")
            end

        else
            error("The time range must be an integer or a tuple of 2 strings with the date format \"YYYY-mm-dd\"")
        end
    elseif typeof(T) == Int64
        T = T
        T_offset = 0
    else
        error("The time range must be an integer or a tuple of 2 strings with the date format \"YYYY-mm-dd\"")
    end

    P_C, Lines, States, Plants, N, F, T_up, T_down = getData(T_offset,T,path)

    # ======================== Model ========================
    println("\nCreating model")
    if nl
        global m = Model(
                optimizer_with_attributes(
                        Juniper.Optimizer,
                        "nl_solver"=>optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0),
                        "mip_solver"=>optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0),
                        "registered_functions" => [
                                Juniper.register(:HR, 8, HR, autodiff = true),
                                #Juniper.register(:fs1, 8, fs1; autodiff = true)
                                ])
                        )

    else
        global m = Model(CPLEX.Optimizer)
    end

    if silent
        set_silent(m)
    end

    # ======================== MODEL EXPRESSION ========================
    # ------------------------------ NON-LINEAR ------------------------------
    if nl

        # Unit activation
        if MIP_unit
            @variable(m, x[1:N,1:F,1:T], Bin,start=0)
            @variable(m, plant[n in 1:N, f in 1:F, t in 1:T])
            for n in 1:N
                for f in 1:F
                    for t in 1:T
                        @constraint(m, x[n,f,t]*Plants[n,f,t].cap_min <= plant[n,f,t])
                        @constraint(m, plant[n,f,t] <= Plants[n,f,t].capacity*x[n,f,t])
                    end
                end
            end

        else
            @variable(m, Plants[n,f,t].cap_min <= plant[n in 1:N, f in 1:F, t in 1:T] <= Plants[n,f,t].capacity)
        end

        # Load balance
        for t in 1:T
            @constraint(m, sum(plant[:,:,t]) == sum(Plants[n,f,t].cap_min for n in 1:N for f in 1:F))
        end

        # Biomass constraint: Produce less than 41 TWh/year
        for t in 1:T
            @constraint(m,sum(plant[:,1,t]) <= 4683.902026)
            @constraint(m,sum(plant[:,2,t]) <= 1474.405729)
        end

    # ------------------------------ LINEAR & MIP ------------------------------
    else
        # Line variables
        @variable(m, -l.capacity <= flow[l in Lines,1:T] <= l.capacity)
        @variable(m, 0 <= flow_abs[l in Lines,1:T] <= l.capacity)
        @variable(m, 0 <= flow_to_abs[l in Lines,1:T] <= l.capacity)
        @variable(m, dir[l in Lines,1:T], Bin,start=0)
        @variable(m, conducting[l in Lines,1:T], Bin,start=0)
        @variable(m, flow_to[l in Lines,1:T] <= l.capacity)
        if Flow_loss
          @variable(m, flow_loss[l in Lines,1:T] == l.loss)
        end

        # Plant variable
        @variable(m, plant[n in 1:N, f in 1:F, t in 1:T])

        # States
        @variable(m, generation[n in 1:N, t in 1:T])
        @variable(m, demand[n in 1:N, t in 1:T] == sum(s.demand for s in [States[n,t]]))

        # MIP variables
        if MIP_unit
          @variable(m, x[1:N,1:F,1:T], Bin,start=0)                       # Unit activation
          @variable(m, x_up[1:N,1:F,1:T], Bin)                            # Unit activation
          @variable(m, x_down[1:N,1:F,1:T], Bin)                          # Unit activation
        end

        if MIP_runtime
          @variable(m, x_neg[1:N,1:F,1:T], Bin,start=0)                   # Negated unit activation
        end

        # ------------------------------ CONSTRAINTS ------------------------------
        # Generation constraint
        for n in 1:N
          for t in 1:T
          @constraint(m,generation[n,t] == sum(plant[n,:,t]))
          end
        end

        # Load balance
        if Flow_loss
          for t in 1:T
            @constraint(m,
            sum(generation[:,t])
            ==
            sum(demand[:,t])
            + sum(flow_loss[l,t]*conducting[l,t] for l in Lines)
            )
          end
        else
          for t in 1:T
            @constraint(m,
            sum(generation[:,t])
            ==
            sum(demand[:,t])
            )
          end
        end

        # Node balance
        for n in 1:N
          for s in States
            for t in 1:T
              if s.node==n
                @constraint(m,
                  sum(generation[n,t]) +
                  sum(flow_to[l,t] for l in Lines if l.to==n)
                  ==
                  sum(demand[n,t]) +
                  sum(flow[l,t] for l in Lines if l.from==n))
              end
            end
          end
        end

        # Flow balance
        for i in 1:N
          for j in 1:N
            for l in Lines
              if l.from == i && l.to == j
                for t in 1:T
                  if Flow_loss
                    @constraint(m,flow[l,t] == flow_to[l,t] + flow_loss[l,t]*conducting[l,t])
                  else
                    @constraint(m,flow[l,t] == flow_to[l,t])
                  end

                end
              end
            end
          end
        end

        # Direction variable: https://docs.mosek.com/modeling-cookbook/mio.html#implication-of-positivity
        for l in Lines
            for t in 1:T
                # Direction variable (for absolute variables)
                @constraint(m, dir[l,t]*l.capacity>=flow[l,t])
                @constraint(m, !dir[l,t] => {flow_abs[l,t] == -flow_to[l,t]})
                @constraint(m, !dir[l,t] => {flow_to_abs[l,t] == -flow[l,t]})
                @constraint(m, dir[l,t] =>  {flow_abs[l,t]  == flow[l,t]})
                @constraint(m, dir[l,t] =>  {flow_to_abs[l,t]  == flow_to[l,t]})

                # Conducting variable
                @constraint(m, conducting[l,t]*l.capacity>=flow_abs[l,t])
            end
        end

        # Biomass constraint: Produce less than 41 TWh/year
        for t in 1:T
            @constraint(m,sum(plant[:,1,t]) == 4683.902026)
            @constraint(m,sum(plant[:,2,t]) == 1474.405729)
        end


        # for n in 1:N
        #     for f in 1:F
        #         for t in 1:T
        #             @constraint(m, Plants[n,f,t].cap_min <= plant[n,f,t] <= Plants[n,f,t].capacity)
        #         end
        #     end
        # end
        # Time and unit dependent constraints
        for n in 1:N
            for f in 1:F
                for t in 1:T
                    # Unit generation limit
                    if MIP_unit
                        @constraint(m, x[n,f,t]*Plants[n,f,t].cap_min <= plant[n,f,t])
                        @constraint(m, plant[n,f,t] <= Plants[n,f,t].capacity*x[n,f,t])

                        # start up and shut down
                        if t > 1
                            @constraint(m, x_up[n,f,t] >= -x[n,f,t-1] + x[n,f,t])
                            @constraint(m, x_down[n,f,t] >= x[n,f,t-1] - x[n,f,t])
                        else
                            @constraint(m, x_up[n,f,t] >= 0 + x[n,f,t])
                        end
                    else
                        @constraint(m, Plants[n,f,t].cap_min <= plant[n,f,t] <= Plants[n,f,t].capacity)
                    end

                    # Minimum operation time, Indicator constraint for Bins
                    if MIP_runtime
                        if t > T - T_up[n,f]
                            @constraint(m, x_up[n,f,t] => {consecutive(T - t,n,f,t) == T - t})
                        else
                            @constraint(m, x_up[n,f,t] => {consecutive(T_up[n,f],n,f,t) == T_up[n,f]})
                        end

                        # Minimum cool down time, Indicator constraint for Bins
                        if t > T - T_down[n,f]
                            @constraint(m, x_down[n,f,t] => {consecutive_down(T - t,n,f,t) == (T - t)})
                        else
                            @constraint(m, x_down[n,f,t] => {consecutive_down(T_down[n,f],n,f,t) == T_down[n,f]})
                        end

                        # Creating an inverse matrix of the unit activation matrix
                        @constraint(m, x[n,f,t] => {x_neg[n,f,t] == 0})              # x_neg = 0 <=>
                        @constraint(m, !x[n,f,t] => {x_neg[n,f,t] == 1})              # x_neg = 0 <=>
                    end
                end
            end
        end
    end

    # ======================== OBJECTIVE FUNCTION ========================
    println("\nBuilding objective function")
    if nl
        register(m,:HR,8, HR; autodiff=true)
        if MIP_unit
            @NLobjective(
                    m,
                    Min,
                    # Run costs
                    sum(
                    plant[n,1,t]*5 +        # Bio
                    plant[n,2,t]*5 +        # Hydro
                    plant[n,3,t]*0 +        # Wind onshore
                    plant[n,4,t]*0 +        # Wind offshore
                    plant[n,5,t]*0 +        # Photovoltaics
                    plant[n,6,t]*0 +        # Other RES
                    plant[n,7,t]*5*HR(plant[n,7,t],HRparams[1,:Pratio],pcap[n,7],HRparams[1,:nopt],HRparams[1,:a],HRparams[1,:b],HRparams[1,:C1],HRparams[1,:C2]) +      # Lignite
                    plant[n,8,t]*8.9*HR(plant[n,8,t],HRparams[2,:Pratio],pcap[n,8],HRparams[2,:nopt],HRparams[2,:a],HRparams[2,:b],HRparams[2,:C1],HRparams[2,:C2]) +      # Lignite
                    plant[n,9,t]*8.9*HR(plant[n,9,t],HRparams[3,:Pratio],pcap[n,9],HRparams[3,:nopt],HRparams[3,:a],HRparams[3,:b],HRparams[3,:C1],HRparams[3,:C2]) +      # Hard coal
                    plant[n,10,t]*16.3*HR(plant[n,10,t],HRparams[4,:Pratio],pcap[n,10],HRparams[4,:nopt],HRparams[4,:a],HRparams[4,:b],HRparams[4,:C1],HRparams[4,:C2]) +      # Natural gas
                    plant[n,11,t]*5 +       # Pumpspeicher
                    plant[n,12,t]*36.8*HR(plant[n,12,t],HRparams[5,:Pratio],pcap[n,12],HRparams[5,:nopt],HRparams[5,:a],HRparams[5,:b],HRparams[5,:C1],HRparams[5,:C2])      # OtherCONV
                    for n in 1:N for t in 1:T
                    )

                    # # Start-up costs
                    +
                    sum(
                    x_up[n,1,t]*5000 +        # Bio
                    x_up[n,2,t]*5000 +        # Hydro
                    x_up[n,3,t]*0 +           # Wind onshore
                    x_up[n,4,t]*0 +           # Wind offshore
                    x_up[n,5,t]*0 +           # Photovoltaics
                    x_up[n,6,t]*0 +           # Other RES
                    x_up[n,7,t]*5000 +        # Nuclear
                    x_up[n,8,t]*5000 +        # Lignite
                    x_up[n,9,t]*4500 +        # Hard coal
                    x_up[n,10,t]*2500 +       # Natural gas
                    x_up[n,11,t]*5000 +       # Pumpspeicher
                    x_up[n,12,t]*4500         # Other conventional
                    for n in 1:N for t in 1:T
                    )

                    # CO2
                    +
                    sum(
                    plant[n,1,t]*CO2price*0.230 +        # Bio
                    plant[n,2,t]*CO2price*0.024 +        # Hydro
                    plant[n,3,t]*CO2price*0.011 +        # Wind onshore
                    plant[n,4,t]*CO2price*0.012 +        # Wind offshore
                    plant[n,5,t]*CO2price*0.048 +        # Photovoltaics
                    plant[n,6,t]*CO2price*0.038 +        # Other RES
                    plant[n,7,t]*CO2price*0.012 +        # Nuclear
                    plant[n,8,t]*CO2price*0.820 +      # Lignite
                    plant[n,9,t]*CO2price*0.820 +      # Hard coal
                    plant[n,10,t]*CO2price*0.490 +     # Natural gas
                    plant[n,11,t]*CO2price*0.024 +       # Pumpspeicher
                    plant[n,12,t]*CO2price*0.656       # Other conventional
                    for n in 1:N for t in 1:T
                    )
                    )
        else


            @NLobjective(
                m,
                Min,
                # Run costs
                sum(
                plant[n,1,t]*5 +        # Bio
                plant[n,2,t]*5 +        # Hydro
                plant[n,3,t]*0 +        # Wind onshore
                plant[n,4,t]*0 +        # Wind offshore
                plant[n,5,t]*0 +        # Photovoltaics
                plant[n,6,t]*0 +        # Other RES
                plant[n,7,t]*5*HR(plant[n,7,t],HRparams[1,:Pratio],pcap[n,7],HRparams[1,:nopt],HRparams[1,:a],HRparams[1,:b],HRparams[1,:C1],HRparams[1,:C2]) +      # Lignite
                plant[n,8,t]*8.9*HR(plant[n,8,t],HRparams[2,:Pratio],pcap[n,8],HRparams[2,:nopt],HRparams[2,:a],HRparams[2,:b],HRparams[2,:C1],HRparams[2,:C2]) +      # Lignite
                plant[n,9,t]*8.9*HR(plant[n,9,t],HRparams[3,:Pratio],pcap[n,9],HRparams[3,:nopt],HRparams[3,:a],HRparams[3,:b],HRparams[3,:C1],HRparams[3,:C2]) +      # Hard coal
                plant[n,10,t]*16.3*HR(plant[n,10,t],HRparams[4,:Pratio],pcap[n,10],HRparams[4,:nopt],HRparams[4,:a],HRparams[4,:b],HRparams[4,:C1],HRparams[4,:C2]) +      # Natural gas
                plant[n,11,t]*5 +       # Pumpspeicher
                plant[n,12,t]*36.8*HR(plant[n,12,t],HRparams[5,:Pratio],pcap[n,12],HRparams[5,:nopt],HRparams[5,:a],HRparams[5,:b],HRparams[5,:C1],HRparams[5,:C2])      # OtherCONV
                for n in 1:N for t in 1:T
                )

                # CO2 (Lifecycle emissions)
                +
                sum(
                plant[n,1,t]*CO2price*0.230 +        # Bio
                plant[n,2,t]*CO2price*0.024 +        # Hydro
                plant[n,3,t]*CO2price*0.011 +        # Wind onshore
                plant[n,4,t]*CO2price*0.012 +        # Wind offshore
                plant[n,5,t]*CO2price*0.048 +        # Photovoltaics
                plant[n,6,t]*CO2price*0.038 +        # Other RES
                plant[n,7,t]*CO2price*0.012 +        # Nuclear
                plant[n,8,t]*CO2price*0.820 +      # Lignite
                plant[n,9,t]*CO2price*0.820 +      # Hard coal
                plant[n,10,t]*CO2price*0.490 +     # Natural gas
                plant[n,11,t]*CO2price*0.024 +       # Pumpspeicher
                plant[n,12,t]*CO2price*0.656       # Other conventional
                for n in 1:N for t in 1:T
                )
            )
        end

    else
        if MIP_unit
          @objective(m,
            Min,
            # Run costs
            sum(
            plant[:,1,:].*5 +        # Bio
            plant[:,2,:].*5 +        # Hydro
            plant[:,3,:].*0 +        # Wind onshore
            plant[:,4,:].*0 +        # Wind offshore
            plant[:,5,:].*0 +        # Photovoltaics
            plant[:,6,:].*0 +        # Other RES
            plant[:,7,:].*5 +        # Nuclear
            plant[:,8,:].*8.9*(1/0.35) +      # Lignite
            plant[:,9,:].*8.9*(1/0.35) +      # Hard coal
            plant[:,10,:].*16.3*(1/0.5) +           # Natural gas
            plant[:,11,:].*5 +              # Pumpspeicher
            plant[:,12,:].*36.8*(1/0.5)       # Other conventional
            )
            +

            # Start-up costs
            sum(
            x_up[:,1,:].*5000 +        # Bio
            x_up[:,2,:].*5000 +        # Hydro
            x_up[:,3,:].*0 +           # Wind onshore
            x_up[:,4,:].*0 +           # Wind offshore
            x_up[:,5,:].*0 +           # Photovoltaics
            x_up[:,6,:].*0 +           # Other RES
            x_up[:,7,:].*5000 +        # Nuclear
            x_up[:,8,:].*5000 +        # Lignite
            x_up[:,9,:].*4500 +        # Hard coal
            x_up[:,10,:].*2500 +       # Natural gas
            x_up[:,11,:].*5000 +       # Pumpspeicher
            x_up[:,12,:].*4500         # Other conventional
            )

            # CO2
            +
            sum(
            plant[:,1,:].*CO2price*0.230 +        # Bio
            plant[:,2,:].*CO2price*0.024 +        # Hydro
            plant[:,3,:].*CO2price*0.011 +        # Wind onshore
            plant[:,4,:].*CO2price*0.012 +        # Wind offshore
            plant[:,5,:].*CO2price*0.048 +        # Photovoltaics
            plant[:,6,:].*CO2price*0.038 +        # Other RES
            plant[:,7,:].*CO2price*0.012 +        # Nuclear
            plant[:,8,:].*CO2price*0.820 +      # Lignite
            plant[:,9,:].*CO2price*0.820 +      # Hard coal
            plant[:,10,:].*CO2price*0.490 +     # Natural gas
            plant[:,11,:].*CO2price*0.024 +       # Pumpspeicher
            plant[:,12,:].*CO2price*0.656       # Other conventional
            )
          )

        else
          @objective(m,
            Min,
            # Run costs
            sum(
            plant[:,1,:].*5 +        # Bio
            plant[:,2,:].*5 +        # Hydro
            plant[:,3,:].*0 +        # Wind onshore
            plant[:,4,:].*0 +        # Wind offshore
            plant[:,5,:].*0 +        # Photovoltaics
            plant[:,6,:].*0 +        # Other RES
            plant[:,7,:].*5 +        # Nuclear
            plant[:,8,:].*8.9*(1/0.35) +      # Lignite
            plant[:,9,:].*8.9*(1/0.35) +      # Hard coal
            plant[:,10,:].*16.3*(1/0.5) +           # Natural gas
            plant[:,11,:].*5 +              # Pumpspeicher
            plant[:,12,:].*36.8*(1/0.5)       # Other conventional
            )

            # CO2
            +
            sum(
            plant[:,1,:].*CO2price*0.230 +        # Bio
            plant[:,2,:].*CO2price*0.024 +        # Hydro
            plant[:,3,:].*CO2price*0.011 +        # Wind onshore
            plant[:,4,:].*CO2price*0.012 +        # Wind offshore
            plant[:,5,:].*CO2price*0.048 +        # Photovoltaics
            plant[:,6,:].*CO2price*0.038 +        # Other RES
            plant[:,7,:].*CO2price*0.012 +        # Nuclear
            plant[:,8,:].*CO2price*0.820 +      # Lignite
            plant[:,9,:].*CO2price*0.820 +      # Hard coal
            plant[:,10,:].*CO2price*0.490 +     # Natural gas
            plant[:,11,:].*CO2price*0.024 +       # Pumpspeicher
            plant[:,12,:].*CO2price*0.656       # Other conventional
            )
          )
        end

    end

    println("\nOptimizing")
    optimize!(m)

    #return (m, value.(plant), value.(x), value.(x))
    return m
end
