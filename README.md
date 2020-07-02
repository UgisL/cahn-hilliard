# Cahn-Hilliard solver
This repository contains the code to simulate the Cahn-Hilliard equation in 2 and 3 dimensions. This is a fork of repository urbainvaes/cahn-hilliard, now adapted for usage of up-to-date tools and options. The documentation is updated such that anyone with up-to-date Make, Gmsh, FreeFEM and Paraview installation shold be able to run the included examples and post-process results.

## Dependencies
This code depends on the following free and open-source programs:

- **Gmsh**, to generate the mesh and do the post-processing;
- **FreeFem++**, to solve the PDE numerically;
- **Paraview**, to visualize results;
- **Gnuplot**, to produce plots;
- **GNU Make**, to build the project;
- **cpp**, to configure the solver.

## Installation
To code of the project can be obtained by downloading the current git repository or creating a fork of your own (prefferable).

## Quick-start guide or running pre-defined example from the repository

Change to the directiory of repository. Run
```
make uninstall
```
and uninstall any set-up cases through the itneractive menu.

To set up a pre-defined simulation, execute
```
make install
```
and select through the interactive menu one of the examples. To prepare the simulation directory, execute
```
make link
```
which creates appropriate folder structure under tests. Now, change directory to the set-up simulation example and execute
```
make run
```
to launch the simulation. Output of the simulation can be obtained by executing
```
make view
```
or by reading the vtk files (located in output/vtk/) in Paraview for processing.


## Creating a new simulation
Below, we describe step by step how to create a simple simulation for the coalescence of two droplets in 2D, which we name *example-droplets*. TO-DO


OUTDATED below here

## Documentation
This section provides additional documentation about the code.

### Targets of Makefile in top directory
The Makefile in the top directory of the project defines the following targets:
- **install**: lists the simulations defined in inputs, prompts the user to select one and:

    - Ensures that the directory *tests/simulation-name* exists, or creates it if necessary.
    - Creates folders for the output, pictures and logs in the newly created directory, if necessary.
    - Copies (using hard links) all the files from *inputs/simulation-name* and *sources* to the new directory.
    - Creates a file *.problem* containing the name of the simulation in the root directory.

- **uninstall**: removes the file *.problem*.
- **clean-all**: removes the directory *tests*, which contains the outputs of all the simulations run.
- **.DEFAULT**: when calling make with any other target than the three described above,
GNU Make will pass the target to the *Makefile* in the subdirectory *tests/simulation-name*,
where *simulation-name* is read from the file *.problem* created at installation.

### Targets of Makefile in subdirectories
Below, **GEOMETRY**, **PROBLEM** and **VIEW** are the variables defined in the configuration file.
- **mesh** : creates the file *output/mesh.msh* from the file **GEOMETRY**.
- **run** : preprocess and execute *solver.pde* using FreeFem++, using the **PROBLEM**.
- **visualization** : shows the simulation results in Paraview (2D) or Gmsh (3D) using the file **VIEW**.
- **video** : same as **visualization**, but create a video from the frames.
- **view** : view video using vlc.
- **plots** : create plots of the physical quantities based on script in *sources/gnuplot/thermo.plt*.

### Use predefined geometries and views
In the simple example above, we created new files for the geometry, the problem and the post-processing,
and referred to these files for the configuration file *config.mk*.
Often, however, one would like to use the same geometry or post-processing for different simulations.
In addition, this repository defines geometries in *sources/geometries* and views in *sources/views*.
Since these two folders will both be copied to the simulation directory (*tests/simulation-name*),
they can be used for the simulation.
For example, instead of rewriting a *.geo* for a square, one could use the readily available file *sources/geometries/square.geo*,
and refer to it from the configuration file.
The path to the file must be relative to the execution directory, i.e. we have to write
```
GEOMETRY = geometries/square.geo.
```

## Modules of the code
Several modules can be activated to simulate more complicated models.
To activate a module, add a line "MODULE = 1" in *config.mk*.
Each of the modules is described below

### Module *adapt*
The use of this module activates mesh-adaptation.

In 2D, the *FreeFem++* built-in function `adaptmesh` is use,
with parameters `hmax = 0.1` and `hmin = hmax/64`.

In 3D, the metric field used for the adaptation is used using `mshmet`,
with parameters `hmax = 0.1` and `hmin = hmax/20`,
after which the adaptation is accomplished by *Tetgen* through the *FreeFem++* function `tetgreconstruction`.

In both cases,
the default values of `hmin` and `hmax` have been chosen based on a number of examples
and usually provide good results,
but they can be changed if desired in the problem configuration file.

### Module *PLOT*
When activated, the solver will display a plot of the solution at each time step.
Note that this slows down the simulation.

### Module *SOLVER_NAVIER_STOKES*
This modules adds Navier-Stokes equations to the sytem of equations of the simulation.
To use this module, boundary conditions for the pressure and velocity fields have to be specified in the problem file.
```
varf varUBoundary(u, test) = ...;
varf varVBoundary(v, test) = ...;
varf varPBoundary(p, test) = ...;
```
Physical parameters can also be defined, and will take default values if not.
The different parameters, with default values, are defined below:

- `Re` (default: 1) is the Reynolds number of the flow,
  which is assumed to take a constant value across the two phases.
- `Ca` (default: 1) is the capillary number.
- `muGradPhi` (default: 1) is a parameter prescribing the discretization used for the capillary term.
  Its value must be 1, to use the discretization `mu*grad(phi)`, or 0, to use `phi*grad(mu)`.

### Module *ELECTRO* (unstable)
Using this requires the definition of

- epsilonR1: relative permittivity in phase *phi = -1*.
- epsilonR2: relative permittivity in phase *phi = 1*.

When enabled, the system will be coupled to the Poisson equation for the electric potential,
through the addition of an additional term in the free energy.

### Module *GRAVITY* (unstable)
Using this requires the definition of

- `rho1`: specific mass of phase *phi = -1*.
- `rho2`: specific mass of phase *phi = 1*.
- `gx`: x-component of the gravity vector.
- `gy`: y-component of the gravity vector.
- `gz`: In 3D, z-component of the gravity vector.

When enabled, gravity will be added to the simulation.

## Authors
Benjamin Aymard started the project in October 2015, and Urbain Vaes joined in March 2016.
