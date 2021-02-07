using JuMP, Cbc, CPLEX
using LightGraphs   # SimpleGraph
using GraphPlot
import Random
using Colors
using Plots, LaTeXStrings

using Cairo, Compose          # For saving graphplot

struct Edg
  from; to; cost; capacity; loss;
end

struct Vert
  node; generation; demand;
end

# ============================== DATA ==============================
Edges = [
Edg(1,2,100,10,1.5),
Edg(1,3,4,10,2),
Edg(2,4,3,10,1),
Edg(3,4,1,10,1),
Edg(3,5,2,10,1.3),
Edg(4,6,2,10,1.1),
Edg(5,6,3,10,1.2)]

Verts = [
Vert(1,100,10),
Vert(2,10,15),
Vert(3,2,0),
Vert(4,2,0),
Vert(5,0,1),
Vert(6,0,2)]

node_min = minimum([minimum([e.from,e.to])  for e in Edges])
node_max = maximum([maximum([e.from,e.to])  for e in Edges])

# ============================== MODEL ==============================
m = Model(CPLEX.Optimizer)
@variable(m, -e.capacity <= flow[e in Edges] <= e.capacity)
@variable(m, flow_to[e in Edges] <= e.capacity)
@variable(m, flow_loss[e in Edges] == e.loss)
@variable(m, 0 <= flow_abs[e in Edges] <= e.capacity)
@variable(m, 0 <= flow_to_abs[e in Edges] <= e.capacity)
@variable(m, 0 <= generation[v in Verts] <= v.generation)
@variable(m, demand[v in Verts] == v.demand)
@variable(m, dir[e in Edges], Bin,start=0)
@variable(m, conducting[e in Edges], Bin,start=0)

# Load balance
@constraint(m,sum(generation[v] for v in Verts)==sum(demand[v] for v in Verts)+sum(e.loss*conducting[e] for e in Edges))

# Node balance
for n in node_min:node_max
  for v in Verts
    if v.node==n
      @constraint(m,
        sum(generation[v]) +
        sum(flow_to[e] for e in Edges if e.to==n)
        ==
        sum(demand[v]) +
        sum(flow[e] for e in Edges if e.from==n))
    end
  end
end

# Flow balance
for i in node_min:node_max
  for j in node_min:node_max
    for e in Edges
      if e.from == i && e.to == j
        @constraint(m,flow[e] == flow_to[e] + flow_loss[e]*conducting[e])
      end
    end
  end
end

# Direction variable: https://docs.mosek.com/modeling-cookbook/mio.html#implication-of-positivity
for e in Edges
  # Direction variable (for absolute variables)
  @constraint(m, dir[e]*e.capacity>=flow[e])
  @constraint(m, !dir[e] => {flow_abs[e] == -flow_to[e]})
  @constraint(m, !dir[e] => {flow_to_abs[e] == -flow[e]})
  @constraint(m, dir[e] =>  {flow_abs[e]  == flow[e]})
  @constraint(m, dir[e] =>  {flow_to_abs[e]  == flow_to[e]})

  # Conducting variable
  @constraint(m, conducting[e]*e.capacity>=flow_abs[e])
end

@objective(m, Min, sum(generation.*5))

optimize!(m)

value.(flow)
vals = [value.(flow[e]) for e in Edges]

objective_value(m)

# ============================== PLOT ==============================
# Preparing plot with custom labels and colors for nodes and
Random.seed!(node_max)
edge_colors = []
arrows = []

g = SimpleGraph(node_max)  # Directional graph: SimpleDiGraph, Undirectional graph: SimpleGraph

# Coloring Edges regarding flow/capacity-ratio.
for e in Edges
  val = value.(flow)[e]/e.capacity
  println(e.from," ",e.to," ",value.(flow)[e], " ", val)
  if abs(val) - 10e-6 > 0 && abs(val) < 0.7
    push!(edge_colors,RGBA(0,1,0,0.5))
    push!(arrows,0.5)
  elseif abs(val) >= 0.7 && abs(val) < 0.9
    push!(edge_colors,RGBA(1,1,0,0.5))
    push!(arrows,0.5)
  elseif abs(val) >= 0.9
    push!(edge_colors,RGBA(1,0,0,0.5))
    push!(arrows,0.5)
  else
    push!(edge_colors,"lightgrey")
    push!(arrows,0)
  end

  # Creating
  if val >= 0
    add_edge!(g,e.from,e.to)
  else
    add_edge!(g,e.to,e.from)
  end
end

#plot(gplot(g,nodelabel=1:node_max,nodefillc=node_colors, edgelabel=edge_labels,edgelabelc="black",EDGELABELSIZE=6,edgestrokec=edge_colors))
Random.seed!(node_max)
gp = gplot(g,
  nodelabel=[(value.(generation)[v] > 0 || value.(demand)[v] > 0) ? "$(v.node)\n$(round(value.(generation)[v],digits=1))-$(round(value.(demand)[v],digits=1))\n$(round(value.(generation)[v] - value.(demand)[v],digits=1))" : "$(v.node)" for v in Verts],
  nodefillc=[RGBA(1,1,0,0.5) for i in 1:length(Edges)],
  #edgelabel=["$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e]*100 / e.capacity,digits=1)) % \n$(e.cost) \$\n$(e.loss) MW" for e in Edges],
  edgelabel=[value.(flow_abs)[e] > 0 ? "$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e],digits=1)) - $(e.loss) = $(round(value.(flow_abs)[e] - e.loss,digits=1))" : "" for e in Edges],
  edgelabelc="black",
  NODELABELSIZE=5,
  EDGELABELSIZE=5,
  edgestrokec=edge_colors,
  arrowlengthfrac=0.00)
# save file # GraphPlot
cd("C:\\Users\\Benjamin\\Dropbox\\DTU\\05_03_PROPENS-LP-Julia\\project_master")
draw(PNG("transport_model2.png",16cm,16cm),gp)

Random.seed!(node_max)
gp = gplot(g,
  nodelabel=["$(v.node)" for v in Verts],
  nodefillc=[RGBA(1,1,0,0.5) for i in 1:length(Edges)],
  #edgelabel=["$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e]*100 / e.capacity,digits=1)) % \n$(e.cost) \$\n$(e.loss) MW" for e in Edges],
  #edgelabel=[value.(flow_abs)[e] > 0 ? "$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e],digits=1)) - $(e.loss) = $(round(value.(flow_abs)[e] - e.loss,digits=1))" : "" for e in Edges],
  edgelabelc="black",
  #edgelabelsize=6,
  NODELABELSIZE=5,
  EDGELABELSIZE=5,
  edgestrokec="lightgrey")

  draw(PNG("transport_model0.png",16cm,16cm),gp)

  Random.seed!(node_max)
  gp = gplot(g,
    nodelabel=[(value.(generation)[v] > 0 || value.(demand)[v] > 0) ? "$(v.node)\n$(round(value.(generation)[v],digits=1))-$(round(value.(demand)[v],digits=1))\n$(round(value.(generation)[v] - value.(demand)[v],digits=1))" : "$(v.node)" for v in Verts],
    nodefillc=[RGBA(1,1,0,0.5) for i in 1:length(Edges)],
    #edgelabel=["$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e]*100 / e.capacity,digits=1)) % \n$(e.cost) \$\n$(e.loss) MW" for e in Edges],
    #edgelabel=[value.(flow_abs)[e] > 0 ? "$(round(value.(flow_abs)[e],digits=1)) / $(e.capacity)\n$(round(value.(flow_abs)[e],digits=1)) - $(e.loss) = $(round(value.(flow_abs)[e] - e.loss,digits=1))" : "" for e in Edges],
    edgelabelc="black",
    #edgelabelsize=6,
    NODELABELSIZE=5,
    EDGELABELSIZE=5,
    edgestrokec="lightgrey")

    draw(PNG("transport_model1.png",16cm,16cm),gp)
