# What is showcase_jl_energy_modelling ?
### Scope of the repository
This repository is build during a 6 ECTS course (Project Lab Renewable and Sustainable Energy Systems) at the Chair of Renewable and Sustainable Energy Systems (ENS) @ Technical University of Munich (TUM).

The repository serves mainly as a reference and for inspiration on how to get started with energy modelling in Julia. The optimization methods includes LP, MIP, NLP and MINLP.

### What does it do?

The program is solving the 'unit commitment problem'. The main purpose of the project was to show the capabilities of energy modelling with Julia. Therefore, realism of the model is second priority. The first is to make a 'simple as possible' demonstration on how energy modelling with Julia would look like.

It models Germany for a period of time in 2019. Further details can be read in the report `PROPENS - LP Model with Julia.pdf`.

Here is a dashboard trying to sum up the outcome of the energy model:

![model](https://github.com/bvilmann/showcase_jl_energy_modelling/blob/main/plots/gif_summer_4.gif)

# Content

The energy model is based on 3 Julia files and gets data from excel file:

### `main.jl`
This is the file from which the energy model is being called. It includes some options for the model:
```
Flow_loss     = false                        # FL: Include flow constant flow losses at lines?
MIP_runtime   = false                        # RT: Enable minimum down and up time constraint. Optimization includes MIP if true
MIP_unit      = true                         # UA: Enable unit activation constraint. Optimization includes MIP if true
nl            = false                        # NL: Enables non-linear modelling
silent        = false                        # Enable output from JuMP model while optimizing?
T_range       = 2                            # Date range (can be integer or tuple of two dates with format "YYYY-mm-dd")
T_range       = ("2019-06-24","2019-06-30")  # Date range (can be integer or tuple of two dates with format "YYYY-mm-dd")
```
Only dates in 2019 is possible to "model". Hereafter, the model is simply called:
```
model = energyModel(T_range,Flow_loss, MIP_runtime, MIP_unit, nl,silent)
```

*NB:* All the variables in `main.jl` are global. This was due to lack of time of creating a proper infrastructure regarding inheritance and readability, which may cause problems when running other "programs" on the side.

### `auxiliary.jl`
Contains the control flow for energy modelling (handling different constraints) based on user input from `main.jl`. Also contains function that models 

### `plots.jl`
Plot functions used for documenting results of the energy model are stored in this file.

### `data.xlsx`
Contains all the data used for the model. Open it and see the different parameters.

# Q & A
### How to get started
Download the repository and run `main.jl`. After pre-compiling packages for the program, an input for the directory where you have located the repository is required. After that, the model optimizes and find a solution. Some plotting features are outcommented for inspiration on how to represent the data from the model. Enjoy!

### I am using other OS than Windows?
The script has not been tested on anything else than Windows, so we cannot guarantee any kind of performance on those platforms.

### This is really slow and could be done faster?!
The program is slow while loading the data. Actually, not much data is actually being used in the end via the structs (`State`, `Plant`, and `Line`) compared to the vast amount being loaded from the excel file `data.xlsx`. Maybe the loading of sheets from `data.xlsx` could be done faster but that could be a task for you to get familiar with Julia if you aren't already?
However, the rigid loading of all the data and then constructing the final parameters for the model serves as documentation on how the energy model is preparing data for the model.

### I want to help?
If you are interested in sharing ideas, open an issue. If you have changes the files, also open an issue or PR. It is not sure whether changes will be implemented because it is not the purpose of this repository to be a julia package from which energy modelling tasks can be called.

# Technical remarks

### Solving time dependent on optimization method chosen:
Solution time regarding the models vary on the chosen optimization method. Here is some benchmarking of the performance based on a average of 10 runs per data point. Abbreviations can be ![mapped here](https://github.com/bvilmann/showcase_jl_energy_modelling#mainjl). 
![solve_time](https://github.com/bvilmann/showcase_jl_energy_modelling/blob/main/plots/sol_time.png)

The benchmarking is performed on:
```
Processor        Intel(R) Core(TM) i7-7500U CPU @2.70GHz 2.90 GHz
Installed RAM    8.00 GB (7.89 GB usable)
```

### Flow chart
Here is a psuedo-technical flow chart:
![flow_chart](https://github.com/bvilmann/showcase_jl_energy_modelling/blob/main/plots/Julia_Flow_Diagram(3).png)


