// Convenient functions for cpp {{{
#define xstr(s) str(s)
#define str(s) #s
// }}}
// Define default values for variables {{{

// Parameters of finite element space
#ifndef SOLVER_POLYNOMIAL_ORDER
#define SOLVER_POLYNOMIAL_ORDER 1
#endif

#define AUX_AUX_SOLVER_ELEMENTS(order) P ## order
#define AUX_SOLVER_ELEMENTS(order) AUX_AUX_SOLVER_ELEMENTS(order)
#define SOLVER_ELEMENTS AUX_SOLVER_ELEMENTS(SOLVER_POLYNOMIAL_ORDER)


// Cahn-Hilliard parameters
#ifndef SOLVER_PE
#define SOLVER_PE 1
#endif

#ifndef SOLVER_CN
#define SOLVER_CN 1e-2
#endif

#ifndef SOLVER_ENERGYB
#define SOLVER_ENERGYB Cn
#endif

#ifndef SOLVER_ENERGYA
#define SOLVER_ENERGYA (1/Cn)
#endif

// Navier-Stokes parameters
#ifndef SOLVER_RE
#define SOLVER_RE 1
#endif

#ifndef SOLVER_WE
#define SOLVER_WE 100
#endif

#ifndef SOLVER_MUGRADPHI
#define SOLVER_MUGRADPHI 1
#endif


// Solver method
#ifndef SOLVER_METHOD
#define SOLVER_METHOD OD2
#endif


// Mesh adaptation
#if DIMENSION == 2
  #ifndef SOLVER_MESH_ADAPTATION_HMIN
  #define SOLVER_MESH_ADAPTATION_HMIN 0.001
  #endif

  #ifndef SOLVER_MESH_ADAPTATION_HMAX
  #define SOLVER_MESH_ADAPTATION_HMAX 0.01
  #endif
#endif

#if DIMENSION == 3
  #ifndef SOLVER_MESH_ADAPTATION_HMIN
  #define SOLVER_MESH_ADAPTATION_HMIN 0.01
  #endif

  #ifndef SOLVER_MESH_ADAPTATION_HMAX
  #define SOLVER_MESH_ADAPTATION_HMAX 0.1
  #endif
#endif

#ifndef SOLVER_ANISO
#define SOLVER_ANISO 0
#endif


// Time parameters
#ifndef SOLVER_DT
#if SOLVER_METHOD == OD1
#define SOLVER_DT 8.0*Pe*(energyB/energyA^2) // Could also be Cn^2/energyA
#endif
#if SOLVER_METHOD == OD2
#define SOLVER_DT 2.0*Pe*(energyB/energyA^2)
#endif
#endif

#ifndef SOLVER_NITER
#define SOLVER_NITER 300
#endif

#ifndef SOLVER_TMAX
#define SOLVER_TMAX 1e1000 // (1e1000 == inf)
#endif


// Time adaptation
#ifdef SOLVER_TIME_ADAPTATION_METHOD
#define SOLVER_TIME_ADAPTATION
#endif // If adaptation method is specified, use adaptation

#ifndef SOLVER_TIME_ADAPTATION_METHOD
#define SOLVER_TIME_ADAPTATION_METHOD AYMARD
#endif

#ifndef SOLVER_TIME_ADAPTATION_FACTOR
#define SOLVER_TIME_ADAPTATION_FACTOR 2
#endif

#ifndef SOLVER_TIME_ADAPTATION_DT_OVER_PE_MIN
#define SOLVER_TIME_ADAPTATION_DT_OVER_PE_MIN 0
#endif

#ifndef SOLVER_TIME_ADAPTATION_DT_OVER_PE_MAX
#define SOLVER_TIME_ADAPTATION_DT_OVER_PE_MAX 2.*(energyB/energyA^2)
#endif

#ifndef SOLVER_TIME_ADAPTATION_TOL_MAX
#define SOLVER_TIME_ADAPTATION_TOL_MAX  0.005
#endif

#ifndef SOLVER_TIME_ADAPTATION_TOL_MIN
#define SOLVER_TIME_ADAPTATION_TOL_MIN  0.001
#endif


// Dimension of the boundary
#if DIMENSION == 2
#define BOUNDARYDIM 1
#endif

#if DIMENSION == 3
#define BOUNDARYDIM 2
#endif

// }}}
// Include auxiliary files and load modules {{{
#include "freefem/write-mesh.pde"
#include "freefem/writers.pde"
#include "freefem/getargs.pde"
#include "freefem/clock.pde"
#include "freefem/match.pde"
//}}}
// Load modules {{{
load "gmsh"
load "isoline"
load "UMFPACK64"

#if DIMENSION == 2
load "metis"
load "iovtk"
#endif

#if DIMENSION == 3
load "medit"
load "mshmet"
load "tetgen"
#endif

#ifdef MUMPS
load "MUMPS"
string ssparams="nprow=1, npcol="+mpisize;
#define SPARAMS , sparams=ssparams
#else
#define SPARAMS
#endif

// Create output directories
system("mkdir -p" + " output/done"
                  + " output/mesh"
                  + " output/phi"
                  + " output/mu"
                  + " output/iso"
                  #ifdef SOLVER_NAVIER_STOKES
                  + " output/velocity"
                  + " output/u"
                  + " output/v"
                  + " output/w"
                  + " output/pressure"
                  #endif
                 );
//}}}
// Import the mesh {{{
#if DIMENSION == 2
#define MESH mesh
#define GMSHLOAD gmshload
#endif

#if DIMENSION == 3
#define MESH mesh3
#define GMSHLOAD gmshload3
#endif

MESH Th; Th = GMSHLOAD("output/mesh.msh");
MESH ThOut; ThOut = GMSHLOAD("output/mesh.msh");
//}}}
// Define functional spaces {{{
#if DIMENSION == 2
#ifdef PERIODICITY
#include xstr(PERIODICITY)
#define ARGPERIODIC ,periodic=periodicity
#else
#define ARGPERIODIC
#endif
fespace Vh(Th,SOLVER_ELEMENTS ARGPERIODIC);
fespace V2h(Th,[SOLVER_ELEMENTS,SOLVER_ELEMENTS] ARGPERIODIC);
#if SOLVER_POLYNOMIAL_ORDER == 2
fespace VhLow(Th,P1 ARGPERIODIC);
#endif
#endif

#if DIMENSION == 3
fespace Vh(Th,SOLVER_ELEMENTS), V2h(Th,[SOLVER_ELEMENTS,SOLVER_ELEMENTS]);
#if SOLVER_POLYNOMIAL_ORDER == 2
fespace VhLow(Th,P1);
#endif
#endif

// Mesh on which to project solution for visualization
fespace VhOut(ThOut,SOLVER_ELEMENTS);

// Phase field
V2h [phi, mu];
Vh phiOld, muOld, test;
#if SOLVER_METHOD == LM1 || SOLVER_METHOD == LM2
Vh qOld;
#endif
#if SOLVER_METHOD == LM2
Vh phiOldOld, muOldOld, phiOldPlusOneHalfTilde;
#endif

#ifdef SOLVER_NAVIER_STOKES
Vh u = 0, v = 0, w = 0, p = 0;
Vh uOld, vOld, wOld;
VhOut uOut, vOut, wOut, pOut;
#endif

#if SOLVER_POLYNOMIAL_ORDER == 2
savemeshgmsh("output/high-order-mesh.msh", Vh, Th);
#endif

//}}}
// Declare default parameters {{{

// Cahn-Hilliard parameters
real Pe = SOLVER_PE;
real Cn = SOLVER_CN;
func energyA = SOLVER_ENERGYA;
func energyB = SOLVER_ENERGYB;

// Navier-Stokes parameters
#ifdef SOLVER_NAVIER_STOKES
real Re = SOLVER_RE;
real We = SOLVER_WE;
real muGradPhi = SOLVER_MUGRADPHI;
#endif

// Time parameters
real dt = SOLVER_DT;
real nIter = SOLVER_NITER;
real tMax = SOLVER_TMAX;
real time = 0;

#ifdef SOLVER_TIME_ADAPTATION
real tolMax = SOLVER_TIME_ADAPTATION_TOL_MAX;
real tolMin = SOLVER_TIME_ADAPTATION_TOL_MIN;
real factor = SOLVER_TIME_ADAPTATION_FACTOR;
real dtOverPeMin = SOLVER_TIME_ADAPTATION_DT_OVER_PE_MIN;
real dtOverPeMax = SOLVER_TIME_ADAPTATION_DT_OVER_PE_MAX;
#endif

// Mesh parameters
#ifdef SOLVER_MESH_ADAPTATION
int aniso = SOLVER_ANISO;
real hmin = SOLVER_MESH_ADAPTATION_HMIN;
real hmax = SOLVER_MESH_ADAPTATION_HMAX;
#endif

//}}}
// Define macros {{{
macro wetting(angle) ((sqrt(2.)/2.)*cos(angle)) // EOM

#if DIMENSION == 2
macro Grad(u) [dx(u), dy(u)] //EOM
macro Div(u,v) (dx(u) + dy(v)) //EOM
macro Normal [N.x, N.y] //EOM
#define UVEC u,v
#define UOLDVEC uOld,vOld
#endif

#if DIMENSION == 3
macro Grad(u) [dx(u), dy(u), dz(u)] //EOM
macro Div(u,v,w) (dx(u) + dy(v) + dz(w)) //EOM
macro Normal [N.x, N.y, N.z] //EOM
#define UVEC u,v,w
#define UOLDVEC uOld,vOld,wOld
#endif

#define AUX_INTEGRAL(dim) int ## dim ## d
#define INTEGRAL(dim) AUX_INTEGRAL(dim)
#define AUX_SAVEGMSHVEC(dim) savegmsh ## dim
#define SAVEGMSHVEC(dim) AUX_SAVEGMSHVEC(dim)
//}}}
// Include problem file {{{
#include xstr(PROBLEM_CONF)
#if SOLVER_BOUNDARY_CONDITION == LINEAR
varf varPhiBoundary([phi1,mu1], [phi2,mu2]) =
  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * mu2)
  +  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * 0 * phi1 * mu2)
;
#endif

#if SOLVER_BOUNDARY_CONDITION == CUBIC
varf varPhiBoundary([phi1,mu1], [phi2,mu2]) =
  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * mu2)
  +  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * phiOld * phi1 * mu2)
;
#endif

#if SOLVER_BOUNDARY_CONDITION == MODIFIED
Vh oneVh = 1; Vh zeroVh = 0;
varf varPhiBoundary([phi1,mu1], [phi2,mu2]) =
  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * (1 + min(1 - phiOld, zeroVh) + min(1 + phiOld, zeroVh)) * mu2)
  +  INTEGRAL(BOUNDARYDIM)(Th) (wetting(contactAngles) * max(-oneVh, min(phiOld, oneVh)) * phi1 * mu2)
;
#endif

#if SOLVER_METHOD == LM1 || SOLVER_METHOD == LM2
qOld = (phi*phi - 1);
#endif
//}}}
// Define variational formulations {{{
// Cahn-Hilliard {{{

#if SOLVER_METHOD == LM2
problem LagrangeM2Varf1(phiOldPlusOneHalfTilde,test) =
INTEGRAL(DIMENSION)(Th)(phiOldPlusOneHalfTilde*test)
    - INTEGRAL(DIMENSION)(Th) (
            phiOld * test
            + 0.5 * dt * (Grad(muOld)'*Grad(test)));

problem LagrangeM2Varf2(phiOldPlusOneHalfTilde,test) =
INTEGRAL(DIMENSION)(Th)(phiOldPlusOneHalfTilde*test)
    - INTEGRAL(DIMENSION)(Th) (
            0.5*(phiOldOld+phiOld) * test
            + 0.5 * dt * (Grad(muOldOld)'*Grad(test))
            + 0.5 * dt * (Grad(muOld)   '*Grad(test)));
#endif

// LM2 needs can't be started from the beginning because the
// chemical potential at 0 tends to inf close to the boundaries if
// the contact angle boundary condition is not satisfied by the
// initial condition. To resolve this issue, we use a first order
// discretization for the first iteration.
#if SOLVER_METHOD == LM2
int coefSwitch = 1;
#endif
varf varPhi([phi1,mu1], [phi2,mu2]) =
  // Bilinear form
  INTEGRAL(DIMENSION)(Th)(
    phi1*phi2/dt
    + (1/Pe)*(Grad(mu1)'*Grad(phi2))
    - mu1*mu2
    + energyA * mu2 *
    #if SOLVER_METHOD == OD1 || SOLVER_METHOD == OD2 || SOLVER_METHOD == OD2MOD
    (3*0.5*phiOld*phiOld*phi1 - 0.5*phi1)
    #endif
    #if SOLVER_METHOD == E1
    (2*phi1)
    #endif
    #if SOLVER_METHOD == E1MOD
    (phi1)
    #endif
    #if SOLVER_METHOD == LM1
    (2*phiOld*phiOld*phi1)
    #endif
    // q^{n+1} = q^n + 2*φ~^{n+1/2} (φ^{n+1} - φ^n)
    // → q^{n+1/2} = q^n + φ~^{n+1/2} (φ^{n+1} - φ^n)
    // So q^{n+1/2} φ~^{n+1/2} = (φ~^{n+1/2})^2 φ^{n+1} + (q^n φ~^{n+1/2} - φ~^{n+1/2} φ~^{n+1/2} φ^n)
    #if SOLVER_METHOD == LM2
    (coefSwitch*phiOldPlusOneHalfTilde*phiOldPlusOneHalfTilde*phi1)
    #endif
    + energyB *
    #if SOLVER_METHOD == OD1 || SOLVER_METHOD == LM1 || SOLVER_METHOD == E1 || SOLVER_METHOD == E1MOD
    (Grad(phi1)'*Grad(mu2))
    #endif
    #if SOLVER_METHOD == OD2 || SOLVER_METHOD == LM2
    (0.5 * (Grad(phi1)'*Grad(mu2)))
    #endif
    #if SOLVER_METHOD == OD2MOD
    (0.5 + OD2MOD_THETA) * (Grad(phi1)'*Grad(mu2))
    #endif
    )
  // Right-hand side
  + INTEGRAL(DIMENSION)(Th)(
    #ifdef SOLVER_NAVIER_STOKES
    convect([UOLDVEC],-dt,phiOld)/dt*phi2
    #else
    phiOld*phi2/dt
    #endif
    + energyA * mu2 *
    #if SOLVER_METHOD == OD1 || SOLVER_METHOD == OD2 || SOLVER_METHOD == OD2MOD
    (0.5*phiOld*phiOld*phiOld + 0.5*phiOld)
    #endif
    #if SOLVER_METHOD == E1
    (-phiOld*phiOld*phiOld + 3*phiOld)
    #endif
    #if SOLVER_METHOD == E1MOD
    (-phiOld*phiOld*phiOld + 2*phiOld)
    #endif
    #if SOLVER_METHOD == LM1
    (2*phiOld*phiOld*phiOld - qOld*phiOld) // ! No multiplication by energyA of qOld term
    #endif
    #if SOLVER_METHOD == LM2
    (coefSwitch*phiOldPlusOneHalfTilde*phiOldPlusOneHalfTilde*phiOld - qOld*phiOldPlusOneHalfTilde) // ! No multiplication by energyA of qOld term
    #endif
    #if SOLVER_METHOD == OD2 || SOLVER_METHOD == LM2
    + energyB * (- 0.5 * (Grad(phiOld)'*Grad(mu2)))
    #endif
    #if SOLVER_METHOD == OD2MOD
    + energyB * (- (0.5 - OD2MOD_THETA) *  (Grad(phiOld)'*Grad(mu2)))
    #endif
    )
;
//}}}
// Navier-Stokes {{{
#ifdef SOLVER_NAVIER_STOKES
varf varU(u,test) =
    // Bilinear form
    INTEGRAL(DIMENSION)(Th)(u*test/dt + (1/Re)*(Grad(u)'*Grad(test)))
    // Right-hand side
    + INTEGRAL(DIMENSION)(Th)(
        (convect([UOLDVEC],-dt,uOld)/dt)*test
        + muGradPhi     * (1/We)*mu*dx(phi)*test
        - (1-muGradPhi) * (1/We)*phi*dx(mu)*test
        )
;
varf varV(v,test) =
    // Bilinear form
    INTEGRAL(DIMENSION)(Th)(v*test/dt + (1/Re)*(Grad(v)'*Grad(test)))
    // Right-hand side
    + INTEGRAL(DIMENSION)(Th)(
        (convect([UOLDVEC],-dt,vOld)/dt)*test
        + muGradPhi     * (1/We)*mu*dy(phi)*test
        - (1-muGradPhi) * (1/We)*phi*dy(mu)*test
        )
;
#if DIMENSION == 3
varf varW(w,test) =
    // Bilinear form
    INTEGRAL(DIMENSION)(Th)(w*test/dt + (1/Re)*(Grad(w)'*Grad(test)))
    // Right-hand side
    + INTEGRAL(DIMENSION)(Th)(
      (convect([UOLDVEC],-dt,wOld)/dt)*test
      + muGradPhi     * (1/We)*mu*dz(phi)*test
      - (1-muGradPhi) * (1/We)*mu*dz(phi)*test
    )
;
#endif
varf varP(p,test) =
    // Bilinear form
    INTEGRAL(DIMENSION)(Th)( Grad(p)'*Grad(test) )
    // Right-hand side
    + INTEGRAL(DIMENSION)(Th)( -Div(UVEC)*test/dt )
;
#endif
//}}}
//}}}
// Create output file for the mesh {{{
// This is only useful if P2 or higher elements are used.
#if DIMENSION == 3
#endif
//}}}
// Loop in time {{{

// CLear and create output file
{
    ofstream thermodynamics("output/thermodynamics.txt");
    thermodynamics << "iteration time "
      << "time_step "
      << "mass "
      << "wall_free_energy "
      << "interior_free_energy "
      << "total_free_energy "
      << "diffusive_mass_increment "
      << "diffusive_free_energy_increment "
      #ifndef SOLVER_NAVIER_STOKES
      << "numerical_dissipation "
      #endif
      << endl;
    ofstream params("parameters.txt");
};

// Declare macroscopic variables {{{
real massPhi, freeEnergy, kineticEnergy;

real intDiffusiveFluxMass = 0;
#ifdef SOLVER_NAVIER_STOKES
real intConvectiveFluxMass = 0;
#endif

real intDissipationFreeEnergy = 0;
real intDiffusiveFluxFreeEnergy = 0;
#ifndef SOLVER_NAVIER_STOKES
real intNumericalDissipation = 0;
#endif
#ifdef SOLVER_NAVIER_STOKES
real intTransferEnergy = 0;
real intConvectiveFluxFreeEnergy = 0;
#endif

#ifdef SOLVER_NAVIER_STOKES
real intDissipationKineticEnergy = 0;
real intDiffusiveFluxKineticEnergy = 0;
real intConvectiveFluxKineticEnergy = 0;
real intPressureFluxKineticEnergy = 0;
#endif
// }}}

for(int i = 0; i <= nIter && time <= tMax; i++)
{
  tic();
  // Adapt mesh {{{
  #ifdef SOLVER_MESH_ADAPTATION
    int nAdapts = ((i == 0) ? 3 : 1);

    for(int iAdapt = 0; iAdapt < nAdapts; iAdapt++)
    {
      #if DIMENSION == 2
        Th = adaptmesh(anisomax = aniso, Th, phi, hmax = hmax, hmin = hmin, nbvx = 1e6 ARGPERIODIC);
      #endif
      #if DIMENSION == 3
        Vh metricField;
        metricField[] = mshmet(Th, phi, aniso = aniso, hmin = hmin, hmax = hmax, nbregul = 1, verbosity = 0);
        Th=tetgreconstruction(Th,switch="raAQ",sizeofvolume=metricField*metricField*metricField/6.);
      #endif
      if(i == 0) {
        [phi, mu] = [phi0, mu0];
      }
      else {
        [phi, mu] = [phi, mu];
        // qOld = qOld
        #if SOLVER_METHOD == LM2
        // phiOld = phiOld;
        // muOld = muOld;
        #endif
      }
      #ifdef PLOT
        #if DIMENSION == 3
        medit("Phi", Th, phi, wait = false);
        #endif
      #endif
    }

    #ifdef SOLVER_NAVIER_STOKES
      u = u;
      v = v;
      p = p;
      #if DIMENSION == 3
        w = w;
      #endif
    #endif

    cout << "Adapt mesh: " << tic() << endl;
  #endif
  // }}}
  // Update previous solution {{{
  #if SOLVER_METHOD == LM2
  phiOldOld = phiOld;
  muOldOld = muOld;
  #endif
  phiOld = phi;
  muOld = mu;
  #ifdef SOLVER_NAVIER_STOKES
  uOld = u;
  vOld = v;
  #if DIMENSION == 3
  wOld = w;
  #endif
  #endif

  // }}}
  // Calculate macroscopic variables {{{

  // Mass {{{
  real massPhiOld = massPhi;
  massPhi = INTEGRAL(DIMENSION)(Th) (phi);
  real deltaMassPhi = massPhi - massPhiOld;

  // Mass fluxes outside of domain
  real diffusiveFluxMass = - INTEGRAL(BOUNDARYDIM)(Th) ((1/Pe) * Normal'*Grad(mu));
  real totalFluxMass = diffusiveFluxMass;
  #ifdef SOLVER_NAVIER_STOKES
  real convectiveFluxMass = INTEGRAL(BOUNDARYDIM)(Th) (phi * [UVEC]'*Normal);
  totalFluxMass = totalFluxMass + convectiveFluxMass;
  #endif
  //}}}
  // Free energy {{{
  real freeEnergyOld = freeEnergy;
  real bulkFreeEnergy  = INTEGRAL(DIMENSION)(Th) (
      energyA * 0.25 * (phi^2 - 1)^2
      + energyB * 0.5 * (Grad(phi)'*Grad(phi))
      );
  real wallFreeEnergy = INTEGRAL(BOUNDARYDIM)(Th,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20) (wetting(contactAngles) * (phi^3/3 - phi));
  freeEnergy = bulkFreeEnergy + wallFreeEnergy;
  real deltaFreeEnergy = freeEnergy - freeEnergyOld;
  real dissipationFreeEnergy = INTEGRAL(DIMENSION)(Th) ((1/Pe)*(Grad(mu)'*Grad(mu)));
  #ifndef SOLVER_NAVIER_STOKES
  real rateNumericalDissipation = - deltaFreeEnergy/dt - dissipationFreeEnergy;
  #endif
  real diffusiveFluxFreeEnergy = - INTEGRAL(BOUNDARYDIM)(Th) ((1/Pe) * mu * Normal'*Grad(mu));
  real totalContributionsFreeEnergy = diffusiveFluxFreeEnergy + dissipationFreeEnergy;
  #ifdef SOLVER_NAVIER_STOKES
  real transferEnergy = INTEGRAL(DIMENSION)(Th) (phi*[UVEC]'*Grad(mu));
  real convectiveFluxFreeEnergy = INTEGRAL(BOUNDARYDIM)(Th) (mu * phi* [UVEC]'*Normal);
  totalContributionsFreeEnergy += convectiveFluxFreeEnergy + transferEnergy;
  #endif
  // }}}
  // Kinetic energy {{{
  #ifdef SOLVER_NAVIER_STOKES
  real kineticEnergyOld = kineticEnergy;
  kineticEnergy = INTEGRAL(DIMENSION)(Th) (u*u/2);
  real deltaKineticEnergy = kineticEnergy - kineticEnergyOld;
  real dissipationKineticEnergy = INTEGRAL(DIMENSION)(Th) ((1/Re) * (Grad(u)'*Grad(u) + Grad(v)'*Grad(v)
      #if DIMENSION == 3
      + Grad(w)'*Grad(w)
      #endif
      ));
  real diffusiveFluxKineticEnergy = - INTEGRAL(BOUNDARYDIM)(Th) ((1/Re) * (
      u*(Normal'*Grad(u)) + v*(Normal'*Grad(v))
      #if DIMENSION == 3
      + w*(Normal'*Grad(w))
      #endif
      )); // check!
  real convectiveFluxKineticEnergy = INTEGRAL(BOUNDARYDIM)(Th) (([UVEC]'* // splitting required for correct macro expansion
      [UVEC]/2) * [UVEC]'*Normal);
  real pressureFluxKineticEnergy = INTEGRAL(BOUNDARYDIM)(Th) (p * [UVEC]'*Normal);
  real totalContributionsKineticEnergy = diffusiveFluxKineticEnergy + convectiveFluxKineticEnergy + pressureFluxKineticEnergy - transferEnergy;
  #endif
  // }}}
  // Update integrated quantities {{{
  intDiffusiveFluxMass += dt*diffusiveFluxMass;
  #ifdef SOLVER_NAVIER_STOKES
  intConvectiveFluxMass += dt*convectiveFluxMass;
  #endif

  intDissipationFreeEnergy += dt*dissipationFreeEnergy;
  intDiffusiveFluxFreeEnergy += dt*diffusiveFluxFreeEnergy;
  #ifndef SOLVER_NAVIER_STOKES
  intNumericalDissipation += dt*rateNumericalDissipation;
  #endif
  #ifdef SOLVER_NAVIER_STOKES
  intTransferEnergy += dt*transferEnergy;
  intConvectiveFluxFreeEnergy += dt*convectiveFluxFreeEnergy;
  #endif

  #ifdef SOLVER_NAVIER_STOKES
  intDissipationKineticEnergy += dt*dissipationKineticEnergy;
  intDiffusiveFluxKineticEnergy += dt*diffusiveFluxKineticEnergy;
  intConvectiveFluxKineticEnergy += dt*convectiveFluxKineticEnergy;
  intPressureFluxKineticEnergy += dt*pressureFluxKineticEnergy;
  #endif
  // }}}
  // Print to stdout {{{
  cout << endl
       << "** ITERATION **" << endl
       << "Iteration: "     << i    << endl
       << "Time:      "     << time << endl
       << "Time step: "     << dt   << endl
       << endl
       << "** Mass **"                        << endl
       << "Mass:                       "      << massPhi              << endl
       << "Diffusive mass flux:        "      << dt*diffusiveFluxMass << endl
       << "Integrated diffusive mass flux:  " << intDiffusiveFluxMass << endl
       #ifdef SOLVER_NAVIER_STOKES
       << "Convective mass flux:       "            << dt*convectiveFluxMass << endl
       << "Integrated convective mass flux:       " << intConvectiveFluxMass << endl
       << "Total outgoing mass flux:   "            << dt*totalFluxMass      << endl
       #endif
       << "Increase in mass:           "                   << deltaMassPhi                    << endl
       << "Mass balance (must be = 0): "                   << deltaMassPhi + dt*totalFluxMass << endl
       << endl
       << "** Free energy **"                              << endl
       << "Bulk free energy:                  "            << bulkFreeEnergy                  << endl
       << "Wall free energy:                  "            << wallFreeEnergy                  << endl
       << "Free energy dissipations:          "            << dt*dissipationFreeEnergy        << endl
       << "Integrated free energy dissipations:          " << intDissipationFreeEnergy        << endl
       << "Diffusive free energy flux:        "            << dt*diffusiveFluxFreeEnergy      << endl
       << "Integrated diffusive free energy flux:        " << intDiffusiveFluxFreeEnergy      << endl
       #ifdef SOLVER_NAVIER_STOKES
       << "Convective free energy flux:       "            << dt*convectiveFluxFreeEnergy     << endl
       << "Integrated convective free energy flux:       " << intConvectiveFluxFreeEnergy     << endl
       << "Transfer to kinetic energy:        "            << dt*transferEnergy               << endl
       << "Integrated transfer to kinetic energy:        " << intTransferEnergy               << endl
       << "Sum of all contributions:          "            << dt*totalContributionsFreeEnergy << endl
       #endif
       << "Increase in free energy:           " << deltaFreeEnergy                                   << endl
       << "Free energy balance (must be = 0): " << deltaFreeEnergy + dt*totalContributionsFreeEnergy << endl
       #ifdef SOLVER_NAVIER_STOKES
       << endl
       << "** Kinetic energy **"                              << endl
       << "Kinetic energy:                       "            << kineticEnergy                                           << endl
       << "Kinetic energy dissipations:          "            << dt* dissipationKineticEnergy                            << endl
       << "Integrated kinetic energy dissipations:          " << intDissipationKineticEnergy                             << endl
       << "Diffusive kinetic energy flux:        "            << dt* diffusiveFluxKineticEnergy                          << endl
       << "Integrated diffusive kinetic energy flux:        " << intDiffusiveFluxKineticEnergy                           << endl
       << "Convective kinetic energy flux:       "            << dt* convectiveFluxKineticEnergy                         << endl
       << "Integrated convective kinetic energy flux:       " << intConvectiveFluxKineticEnergy                          << endl
       << "Pressure-induced kinetic energy flux: "            << dt* pressureFluxKineticEnergy                           << endl
       << "Integrated pressure-induced kinetic energy flux: " << intPressureFluxKineticEnergy                            << endl
       << "Sum of all contributions:             "            << dt* totalContributionsKineticEnergy                     << endl
       << "Increase in kinetic energy:           "            << deltaKineticEnergy                                      << endl
       << "Kinetic energy balance (must be = 0): "            << deltaKineticEnergy + dt*totalContributionsKineticEnergy << endl
       #endif
       << endl
       << "** Parameters **" << endl
       << "dt = "            << dt   << endl
       << "Pe = "            << Pe   << endl
       << "Cn = "            << Cn   << endl
       #ifdef SOLVER_MESH_ADAPTATION
       << "hmin = "          << hmin << endl
       << "hmax = "          << hmax << endl
       #endif
       #ifdef SOLVER_NAVIER_STOKES
       << "Re = "            << Re   << endl
       << "We = "            << We   << endl
       #endif
       << endl;
  {
      ofstream thermodynamics("output/thermodynamics.txt", append);
      thermodynamics << i << " "
                     << time << " "
                     << dt << " "
                     << massPhi << " "
                     << wallFreeEnergy << " "
                     << bulkFreeEnergy << " "
                     << freeEnergy << " "
                     << diffusiveFluxMass * dt << " "
                     << diffusiveFluxFreeEnergy * dt << " "
                     #ifndef SOLVER_NAVIER_STOKES
                     << intNumericalDissipation << " "
                     #endif
                     << endl;
  }
  // }}}
  cout << "Calculate macroscopic variables: " << tic() << endl;
  // }}}
  // Save data to files and stdout {{{
  #if DIMENSION == 2
      real[int,int] xy(3,1);
      isoline(Th, phi, xy, close=false, iso=0.0, smoothing=0.1, file="output/iso/contactLine"+i+".dat");
  #endif

  savegmsh("output/phi/phi-" + i + ".msh", "Cahn-Hilliard", i*dt, i, phiOld);
  savegmsh("output/mu/mu-" + i + ".msh", "Chemical potential", i*dt, i, muOld);
  savefreefem("output/phi/phi-" + i + ".txt", phiOld);
  savefreefem("output/mu/mu-" + i + ".txt", muOld);

  #ifdef SOLVER_NAVIER_STOKES
  savegmsh("output/pressure/pressure-" + i + ".msh", "Pressure", i*dt, i, p);
  SAVEGMSHVEC(DIMENSION)("output/velocity/velocity-" + i + ".msh", "Velocity field", i*dt, i, UVEC);
  savefreefem("output/pressure/pressure-" + i + ".txt", p);
  savefreefem("output/u/u-" + i + ".txt", u);
  savefreefem("output/v/v-" + i + ".txt", v);
  #if DIMENSION == 3
  savefreefem("output/w/w-" + i + ".txt", w);
  #endif
  #endif

  #ifdef SOLVER_MESH_ADAPTATION
  savemeshgmsh("output/mesh/mesh-" + i + ".msh", Vh, Th);
  #if SOLVER_POLYNOMIAL_ORDER == 2
    savemeshgmsh("output/mesh/low-order-mesh-" + i + ".msh", VhLow, Th);
  #endif
  system(xstr(GITROOT) + "/sources/bin/msh2pos output/mesh/mesh-" + i + ".msh"
              + " output/phi/phi-" + i + ".msh"
              + " output/mu/mu-" + i + ".msh"
              #ifdef SOLVER_NAVIER_STOKES
              + " output/pressure/pressure-" + i + ".msh"
              + " output/velocity/velocity-" + i + ".msh"
              #endif
        );
  #endif
  // ! phi[]

  cout << "Save data to files and stdout: " << tic() << endl;
  //}}}
  // Visualize solution at current time step {{{
  #ifdef PLOT
      #if DIMENSION == 2
      plot(phi, fill=true, WindowIndex = 0);
      #ifdef SOLVER_NAVIER_STOKES
      plot(u, fill=true, WindowIndex = 1);
      plot(p, fill=true, WindowIndex = 2);
      #endif
      #endif

      #if DIMENSION == 3
      medit("Phi",Th,phi,wait = false);
      #endif
  #endif
  //}}}
  // After iteration {{{
  #ifdef SOLVER_AFTER
  #include xstr(SOLVER_AFTER)
  #endif
  {
      ofstream fdone("output/done/done-"+i+".txt");
      fdone << "done" << endl;
  }
  /// }}}
  // Exit if required {{{
  if (i == nIter) break;
  //}}}
  // Before iteration {{{
  #ifdef SOLVER_SOLVER_BEFORE
  #include xstr(SOLVER_SOLVER_BEFORE)
  #endif

  if(i == 0) {
      ofstream file("parameters.txt",append);
      #ifndef SOLVER_TIME_ADAPTATION
      file << "dt = " << dt << endl;
      #endif
      file << "Pe = " << Pe << endl;
      file << "Cn = " << Cn << endl;
      #ifdef SOLVER_MESH_ADAPTATION
      file << "hmin = " << hmin << endl;
      file << "hmax = " << hmax << endl;
      #endif
      #ifdef SOLVER_NAVIER_STOKES
      file << "Re = " << Re << endl;
      file << "We = " << We << endl;
      #endif
  }
  else {
      #ifndef SOLVER_TIME_ADAPTATION
      if (doesMatch("parameters.txt","dt")) dt = getMatch("parameters.txt","dt =");
      #endif
      if (doesMatch("parameters.txt","Pe")) Pe = getMatch("parameters.txt","Pe =");
      if (doesMatch("parameters.txt","Cn")) Cn = getMatch("parameters.txt","Cn =");
      #ifdef SOLVER_MESH_ADAPTATION
      if (doesMatch("parameters.txt","hmin")) hmin = getMatch("parameters.txt","hmin =");
      if (doesMatch("parameters.txt","hmax")) hmax = getMatch("parameters.txt","hmax =");
      #endif
      #ifdef SOLVER_NAVIER_STOKES
      if (doesMatch("parameters.txt","Re")) Re = getMatch("parameters.txt","Re =");
      if (doesMatch("parameters.txt","We")) We = getMatch("parameters.txt","We =");
      #endif
  }
  // }}}
  // Cahn-Hilliard equation {{{
  #ifdef SOLVER_TIME_ADAPTATION
  bool recalculate = true;
  while(recalculate) {
  #endif

  #if SOLVER_METHOD == LM2
  if(i == 0) {
      coefSwitch = 2;
      phiOldPlusOneHalfTilde = phiOld;
  }
  else {
      coefSwitch = 1;
      LagrangeM2Varf2;
  }
  #endif

  matrix matPhiBulk = varPhi(V2h, V2h);
  matrix matPhiBoundary = varPhiBoundary(V2h, V2h);
  matrix matPhi = matPhiBulk + matPhiBoundary;
  real[int] rhsPhiBulk = varPhi(0, V2h);
  real[int] rhsPhiBoundary = varPhiBoundary(0, V2h);
  real[int] rhsPhi = rhsPhiBulk + rhsPhiBoundary;
  set(matPhi,solver=sparsesolver SPARAMS);
  phi[] = matPhi^-1*rhsPhi;

  #ifdef SOLVER_TIME_ADAPTATION
  real dissipationFreeEnergy = dt*INTEGRAL(DIMENSION)(Th) ((1/Pe)*(Grad(mu)'*Grad(mu)));
  real newFreeEnergy  = INTEGRAL(DIMENSION)(Th) ( energyA * 0.25 * (phi^2 - 1)^2 + energyB * 0.5 * (Grad(phi)'*Grad(phi)))
      + INTEGRAL(BOUNDARYDIM)(Th,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20) (wetting(contactAngles) * (phi^3/3 - phi));
  real increaseFreeEnergy = newFreeEnergy - freeEnergy;
  real numericalDissipation = - increaseFreeEnergy - dissipationFreeEnergy;


  #if SOLVER_TIME_ADAPTATION_METHOD == AYMARD
  real parameterAdaptation = dissipationFreeEnergy;
  bool additionalCondition = (increaseFreeEnergy > 0);
  #endif

  #if SOLVER_TIME_ADAPTATION_METHOD == GUILLEN
  real parameterAdaptation = abs(numericalDissipation)/(dt/Pe); // Use normalized time!
  bool additionalCondition = false; // No additional condition
  #endif

  bool dtTooLarge = (parameterAdaptation > tolMax && dt/Pe > dtOverPeMin) || (dt/Pe > dtOverPeMax);
  bool dtTooLow   = (parameterAdaptation < tolMin && dt/Pe < dtOverPeMax) || (dt/Pe < dtOverPeMin);

  recalculate = (dtTooLarge || additionalCondition);

  real dtOld = dt;
  if(recalculate) {
    dt = dt/factor;
  }
  else if (dtTooLow) {
    dt = dt*factor;
  }

  // Output {{{
  cout << endl << "** Time adaptation **" << endl;
  cout << "Normalized time step:  " << (dtOld/Pe)  << "." << endl;
  cout << "--> Admissible range for normalized time step: [" << dtOverPeMin << ", " << dtOverPeMax << "]" << endl;
  cout << "Normalized time step:  " << (dt/Pe)  << "." << endl;
  cout << "Free energy increase:  " << increaseFreeEnergy  << "." << endl;
  cout << "Physical dissipation:  " << dissipationFreeEnergy << "." << endl;
  cout << "Numerical dissipation: " << numericalDissipation  << "." << endl;
  cout << "Normalized rate of Numerical dissipation: " << numericalDissipation/(dt/Pe) << "." << endl;
  cout << "--> Adaptation parameter: " << parameterAdaptation << endl
    << "--> Admissible range for parameter: [" << tolMin << ", " << tolMax << "]" << endl;
  if (recalculate) {
    if(dtTooLarge) {
      cout << "Adaptation parameter out of adimssible range:" << endl;
    }
    else {
      cout << "Additional condition is met!" << endl;
    }
    cout << "Recalculating solution with dt = " << dt << endl;
  }
  else if (dtTooLow) {
    cout << "Time step is too small, increasing to dt = " << dt << "." << endl;
  }
  else {
    cout << "Continuing with the same time step ..." << endl;
  }
  // }}}
  }
  #endif
  cout << "Solve Cahn-Hilliard system: " << tic() << endl;
  //}}}
  // Navier stokes {{{
  #ifdef SOLVER_NAVIER_STOKES
  Vh uOld = u, vOld = v, pold=p;
  #if DIMENSION == 3
  Vh wOld = w;
  #endif
  matrix matUBulk = varU(Vh, Vh);
  matrix matUBoundary = varUBoundary(Vh, Vh);
  matrix matU = matUBulk + matUBoundary;
  real[int] rhsUBulk = varU(0, Vh);
  real[int] rhsUBoundary = varUBoundary(0, Vh);
  real[int] rhsU = rhsUBulk + rhsUBoundary;
  set(matU,solver=sparsesolver SPARAMS);
  u[] = matU^-1*rhsU;

  matrix matVBulk = varV(Vh, Vh);
  matrix matVBoundary = varVBoundary(Vh, Vh);
  matrix matV = matVBulk + matVBoundary;
  real[int] rhsVBulk = varV(0, Vh);
  real[int] rhsVBoundary = varVBoundary(0, Vh);
  real[int] rhsV = rhsVBulk + rhsVBoundary;
  set(matV,solver=sparsesolver SPARAMS);
  v[] = matV^-1*rhsV;

  #if DIMENSION == 3
  matrix matWBulk = varW(Vh, Vh);
  matrix matWBoundary = varWBoundary(Vh, Vh);
  matrix matW = matWBulk + matWBoundary;
  real[int] rhsWBulk = varW(0, Vh);
  real[int] rhsWBoundary = varWBoundary(0, Vh);
  real[int] rhsW = rhsWBulk + rhsWBoundary;
  set(matW,solver=sparsesolver SPARAMS);
  w[] = matW^-1*rhsW;
  #endif

  matrix matPBulk = varP(Vh, Vh);
  matrix matPBoundary = varPBoundary(Vh, Vh);
  matrix matP = matPBulk + matPBoundary;
  real[int] rhsPBulk = varP(0, Vh);
  real[int] rhsPBoundary = varPBoundary(0, Vh);
  real[int] rhsP = rhsPBulk + rhsPBoundary;
  set(matP,solver=sparsesolver SPARAMS);
  p[] = matP^-1*rhsP;

  u = u - dx(p)*dt;
  v = v - dy(p)*dt;
  #if DIMENSION == 3
  w = w - dz(p)*dt;
  #endif
  cout << "Solve Navier-Stokes system: " << tic() << endl;
  #endif
  // }}}
  // Do thing for all time steps but the 0-th {{{
  time += dt;
  #if SOLVER_METHOD == LM1
  qOld = qOld + 2 * (phiOld*phi - phiOld*phiOld);
  #endif
  #if SOLVER_METHOD == LM2
  qOld = qOld + 2 * (phiOldPlusOneHalfTilde*phi - phiOldPlusOneHalfTilde*phiOld);
  #endif
  // }}}
}
//}}}

// vim: ft=freefem ts=2 sw=2 sts=2
