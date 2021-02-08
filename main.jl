"""
Title:              Showcase of Energy Modeling with Julia
                    Project Lab Renewable and Sustainable Energy Systems

Authors:            Benjamin Vilmann
                    Navin Kumar Trivedi
                    Aditya Vyas

Organization:       Technische Universität München (TUM)
                    Chair of Renewable and Sustainable Energy Systems (ENS)
                    (Lehrstuhl für Erneuerbare und Nachhaltige Energiesysteme)

"""
# ================== IMPORT MODELING PACKAGES ==================
include("auxiliary.jl")

# ================== SETTINGS ==================
global Flow_loss           = false
global MIP_runtime         = false
global MIP_unit            = true
global nl                  = false
global silent              = false
global T_range             = 2
global T_range             = ("2019-06-24","2019-06-30")         # Summer
global T_range             = ("2019-06-24","2019-06-27")         # Showcase
global T_range             = ("2019-01-14","2019-01-20")         # Winter

# ================== MODEL ==================
model = energyModel(T_range,Flow_loss, MIP_runtime, MIP_unit, nl,silent)

# ================== PLOT ==================
# ------------------ Initialize ------------------
include("plots.jl")
initModelDoc(model)

# ------------------ Plots ------------------
# p = plotRealData(T_range)
# p = plotCongestion(false,:topright,"numbers",false)
# GroupedBar()
# PlotMap(3,true)
# PieChart()
# AreaPlot()
# p = Dashboard(t)

# savefig("plot.png") # Saves the plot

# ------------------ Animation ------------------
anim = AnimateDashboard()

gif(anim,"gif_winter_4.gif",fps=4) # Saves the animation
