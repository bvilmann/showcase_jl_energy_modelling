using JuMP, CPLEX, Ipopt
using Plots, LaTeXStrings

function LP(P_C,F)
    # Plant Capacity [Maximim Minimum]

    P_D = LinRange(sum(P_C[:,2]), sum(P_C[:,1]), 100)      # Power demand along time
    T   = length(P_D)                                      # Number of time steps
    N   = length(P_C[:,1])                                 # Number of generators

    m = Model(Cbc.Optimizer)                               # Model

    # generated power P_G defined as a variable in the range of Unit generation limit
    @variable(m, P_C[i,2] <= P_G[i=1:N,1:T] <= P_C[i,1])

    # Linear objective function - minimize sum { F(P) = P_G*F}
    @objective(m,Min,sum((P_G[:,1:T].*F[1:N])))

    for i in 1:T
        @constraint(m, sum(P_G[:,i]) == P_D[i])             # Load balance
    end

    optimize!(m)

    # Output optimal values of generated power for a single time step
    println("Optimal Solutions:")
    for i in 1:N
      println("Pg[$i] = ", JuMP.value(P_G[i,1]))
    end
    labels = ["G1: $(F[1])  €/MWh, [$(P_C[1,2]);$(P_C[1,1])] MW" "G2: $(F[2])  €/MWh, [$(P_C[2,2]);$(P_C[2,1])] MW" "G3: $(F[3]) €/MWh, [$(P_C[3,2]);$(P_C[3,1])] MW" "G4: $(F[4]) €/MWh, [$(P_C[4,2]);$(P_C[4,1])] MW"]
    markercolors = [:blue :orange :red :green]
    plt = plot(
        P_D[:],
        value.(P_G[:,1:T])',
        label =labels,
        xlim=(0,2500),
        ylim=(0,1200),
        legendfontsize=8,
        legend=:topleft,
        color = markercolors,
        title=L"LP",
        #xlab = L"P_{demand} [MW]",
        ylab = L"P_{generation} [MW]",
        dpi = 300)
    return plt
end


function MIP(P_C,F)
    # Plant Capacity [Maximim Minimum]

    P_D  = LinRange(0, sum(P_C[:,1]), 100)              # Power demand along time
    T    = length(P_D)                                  # Number of time steps
    N    = length(P_C[:,1])                             # Number of generators

    m = Model(CPLEX.Optimizer)                          # Model

    # power generation variable
    @variable(m, P_G[i=1:N,1:T])

    # Mixed integer programming binary variable representing unit activation
    @variable(m, x[i=1:N,1:T], Bin,start=0)

    for i in 1:T
        @constraint(m, sum(P_G[:,i]) == P_D[i])         # Load balance
    end

    # Constraint for power generation variable to be between generation limits
    for i in 1:N
        for j in 1:T
            @constraint(m,P_C[i,2]*x[i,j] <= P_G[i,j])
            @constraint(m,P_G[i,j] <= P_C[i,1]*x[i,j])
        end
    end

    # Linear objective function - minimize sum { F(P) = P_G*F*x}
    @objective(m,Min,sum((P_G[:,1:T].*x[1:N,1:T]).*F[1:N]))

    optimize!(m)

    # Output optimal values of generated power for a single time step
    println("Optimal Solutions:")
    for i in 1:N
      println("Pg[$i] = ", JuMP.value(P_G[i,25]))
    end
    #labels = ["G1_Gas   16 €/MWh" "G2_Gas   16 €/MWh" "G3_Coal  09 €/MWh" "G4_Coal  09 €/MWh"]
    markercolors = [:blue :orange :red :green]
    plt = plot(
        P_D[:],
        value.(P_G[:,1:T])',
        label =labels,
        xlim=(0,2500),
        ylim=(0,1200),
        legend=:none,
        color = markercolors,
        title=L"MIP",
        #xlab = L"P_{demand} [MW]",
        ylab = L"P_{generation} [MW]",
        dpi = 300)
    #@show plt
    return plt
    #savefig("MIP52.png")                                 # save the most recent fig
end


function NLP(P_C,Cfuel)
    # Data

    P_D = LinRange(sum(P_C[:,2]), sum(P_C[:,1]), 100)# Power demand along time
    T = length(P_D)                                  # Number of time steps
    N = length(P_C[:,1])                             # Number of generators

    Pr    = [1 1 0.85 0.85]                          # power ratio
    a     = [-0.052 -0.052 0.051 0.051 ]             # Power plant parameter
    b     = [-0.602 -0.602 -0.611 -0.611]            # Power plant parameter
    c1    = 1.012                                    # ambient temperature constant
    c2    = [0.9821 0.9821 0.9594 0.9594]            # plant age constant
    nopt  = [0.275 0.275 0.38 0.38]                  # optimal efficieny of plant

    k1 = Array{Float64}(undef,N)
    k2 = Array{Float64}(undef,N)
    k3 = Array{Float64}(undef,N)
    k4 = Array{Float64}(undef,N)
    # computation of heating rate coefficients
    for i in 1:N
        k1[i] = Cfuel[i]/(nopt[i]*c1*c2[i])
        k2[i] = 1+(a[i]*Pr[i])+(b[i]*Pr[i]*Pr[i])
        k3[i] = b[i]/(P_C[i,1]^2)
        k4[i] = (a[i]-(2*b[i]*Pr[i]))/P_C[i,1]
    end

    #Model
    m = Model(Ipopt.Optimizer)

    # generated power Pg must be between minimum and maximum limints
    @variable(m, P_C[i,2] <= P_G[i=1:N,1:T] <= P_C[i,1])

    # Non - linear Objective function - minimize F(P) = k1 /((k2/P) + k3*p +k4); for n-generators
    @NLobjective(m,Min, sum(k1[i]/((k2[i]/P_G[i,j])+(k3[i]*P_G[i,j])+k4[i]) for i = 1:N for j = 1:T))

    # Load balance constraint, generation = demand
    for i in 1:T
        @constraint(m, sum(P_G[:,i]) == P_D[i])
    end

    optimize!(m)

    # Output optimal values of generated power
    println("Optimal Solutions:")
    for i=1:N
     println("Pg[$i] = ", JuMP.value(P_G[i,25]))
    end
    labels = ["G1_Gas   16 €/MWh" "G2_Gas   16 €/MWh" "G3_Coal  09 €/MWh" "G4_Coal  09 €/MWh"]
    markercolors = [:blue :orange :red :green]
    plt = plot(
        P_D[:],
        value.(P_G[:,1:T])',
        label =labels,
        xlim=(0,2500),
        ylim=(0,1200),
        legend=:none,
        title=L"NLP",
        color = markercolors,
        xlab = L"P_{demand} [MW]",
        ylab = L"P_{generation} [MW]",
        dpi = 300)
    return plt
end

# Plant Capacity [Maximim Minimum]
P_C  = [
    800 200;                                    # Coal plant
    1000 200;
    500 250;                                    # Gas plant
    200 25;                                     # Gas plant
    ]                                  # Coal plant

F    = [5 6 15 16]                                  # Fuel prices in EUR/MWh

p1 = LP(P_C,F)
p2 = MIP(P_C,F)
p3 = NLP(P_C,F)


using Plots
using LaTeXStrings
using StatsPlots
using Compose # adds px
#plot(p1,p2,p3, layout = @layout [grid(3,1, heights=[0.333,0.333,0.333], widths=[1])])
p = plot(p1,p2,p3,
    size=(600,900),
    dpi = 300,
    right_margin=10px,
    layout = @layout[a{0.333h,1w}; b{0.333h,1w}; c{0.333h,1w}])
#@show p
savefig("model_validation.png")
