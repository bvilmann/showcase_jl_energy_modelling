

using DataFrames
using ExcelFiles


# =========== State ===========

df = DataFrame(
)

node = []
stats = []
capacity = []
cap_min = []
cap_max = []
cf = []
type = []
for plant in Plants[:,:,1]
    push!(node,plant.node)
    push!(stats,plant.state)
    push!(capacity,plant.capacity)
    push!(cap_min,plant.cap_min)
    push!(cap_max,plant.cap_max)
    push!(cf,plant.cf)
    push!(type,plant.type)
end

df[!,:node] = node
df[!,:state] = stats
df[!,:capacity] = capacity
df[!,:cap_min] = cap_min
df[!,:cap_max] = cap_max
df[!,:cf] = cf
df[!,:type] = type

save("Plants.xlsx", df)     # Time dependent


# =========== State ===========

df = DataFrame(
)

node = []
stats = []
generation = []
demand = []
for state in States
    push!(node,state.node)
    push!(stats,state.state)
    push!(generation,state.generation)
    push!(demand,state.demand)

end

df[!,:node] = node
df[!,:state] = stats
df[!,:generation] = generation
df[!,:demand] = demand

save("States.xlsx", df)     # Time dependent

# =========== LINES ===========
# df = DataFrame(
# )
# to = []
# to_state = []
# from = []
# from_state = []
# loss = []
# capacity = []
# for line in Lines
#
#     push!(to,line.to)
#     push!(to_state,line.to_state)
#     push!(from,line.from)
#     push!(from_state,line.from_state)
#     push!(loss,line.loss)
#     push!(capacity,line.capacity)
#
# end
# df[!,:to] = to
# df[!,:from] = from
# df[!,:to_state] = to_state
# df[!,:from_state] = from_state
# df[!,:loss] = loss
# df[!,:capacity] = capacity


save("Lines.xlsx", df)
