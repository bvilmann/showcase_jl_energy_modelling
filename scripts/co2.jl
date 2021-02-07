using Plots, LaTeXStrings       # Plotting
using StatsPlots

vals = [
    740 820 910;
    410 490 650;
    620 740 890;
    130 230 420;
    6 38 79;
    1 24 2200;
    3.7 12 110;
    8.8 27 63;
    26 41 60;
    18 48 180;
    7 11 56;
    8 12 35;
]

cats = [
    "Coal";
    "Gas (CC)";
    "Biomass (cofiring)";
    "Biomass (dedicated)";
    "Geothermal";
    "Hydropower";
    "Nuclear";
    "Concentrated Solar Power";
    "PV (rooftop)";
    "PV (utility)";
    "Wind onshore";
    "Wind offshore";
]
clr = [
  RGB(0.2,0.2,0.2)                   # Coal - Black / dark grey
  RGB(255/255,140/255,25/255)        # Gas - Carrot
  RGB(0/255,102/255,0/255)           # Biomass Green
  RGB(0/255,102/255,0/255)           # Biomass Green
  RGB(0/255,150/255,0/255)           # Geothermal - Green
  RGB(25/255,0/255,255/255)          # Hydro Blue
  RGB(255/255,0/255,0/255)           # Nuclear - Red
  RGB(255/255,247/255,0/255)         # PV - Yellow
  RGB(255/255,247/255,0/255)         # PV - Yellow
  RGB(255/255,247/255,0/255)         # PV - Yellow
  RGB(128/255,212/255,255/255)       # Onshore - Light blue
  RGB(100/255,150/255,255/255)       # Offshore - Light blue
  ]


hght = 450

boxplot(vals',
    ytick=0:250:2250,
    xtick=(1:12,permutedims(cats)),
    label=permutedims(cats),
    ylims=(0,2250),
    legendfontsize=7,
    size=(hght*1.5,hght),
    ylabel="gCO2eq/kWh",
    #legend=:topleft,
    legend=:none,
    color=clr',
    xrotation=45,
    dpi=300
    )
lens!([4.5, 12.5], [0, 200], inset = (1, bbox(0.6, 0.03, 0.4, 0.7)))
savefig("gCO2eqkWh.png")
