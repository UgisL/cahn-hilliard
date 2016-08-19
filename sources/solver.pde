// Include auxiliary files and load modules {{{
include "freefem/write-mesh.pde"
include "freefem/getargs.pde"
include "freefem/clock.pde"
include "geometry.pde"
//}}}
// Load modules {{{
load "gmsh"

#if DIMENSION == 2
load "metis";
load "iovtk";
load "isoline";
#endif

#if DIMENSION == 3
load "medit"
load "mshmet"
load "tetgen"
#endif

// Create output directories
system("mkdir -p" + " output/phi"
                  + " output/mu"
                  + " output/velocity"
                  + " output/pressure"
                  + " output/iso"
                  + " output/interface "
                  + " output/mesh"
                  #ifdef ELECTRO
                  + " output/potential"
                  #endif
                 );
//}}}
// Process input parameters {{{
int adapt = getARGV("-adapt",0);
int plotSol = getARGV("-plot",0);
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
fespace Vh(Th,P1), V2h(Th,[P1,P1]);
#endif

#if DIMENSION == 3
fespace Vh(Th,P1), V2h(Th,[P1,P1]);
#endif

// Mesh on which to project solution for visualization
fespace VhOut(ThOut,P1);

// Phase field
V2h [phi, mu];
Vh phiOld;
VhOut phiOut, muOut;

// Adaptation
Vh adaptField;

#ifdef NS
Vh u = 0, v = 0, w = 0, p = 0;
Vh uOld, vOld, wOld;
VhOut uOut, vOut, wOut;
#endif

#ifdef ELECTRO
Vh theta;
#endif
//}}}
// Declare default parameters {{{

// Cahn-Hilliard parameters
real M       = 1;
real lambda  = 1;
real eps     = 0.01;

// Navier-Stokes parameters
#ifdef NS
real Re = 0.1;
real Ca = 100;
#endif

#ifdef GRAVITY
real rho1 = -1;
real rho2 = 1;

real gx = 1e8;
real gy = 0;
#endif

// Electric parameters
#ifdef ELECTRO
real epsilonR1 = 1;
real epsilonR2 = 2;
#endif

// Time parameters
real dt = 8.0*eps^4/M;
real nIter = 300;

// Mesh parameters
real meshError = 1.e-2;

#if DIMENSION == 2
real hmax = 0.1;
real hmin = hmax/10;
#endif

#if DIMENSION == 3
real hmax = 0.1;
real hmin = hmax/20;
#endif
//}}}
// Include problem file {{{
#define xstr(s) str(s)
#define str(s) #s
#include xstr(PROBLEM)
//}}}
// Calculate dependent parameters {{{
real eps2 = eps*eps;
real invEps2 = 1./eps2;
real Ch = eps2;

#ifdef GRAVITY
Vh rho = 0.5*(rho1*(1 - phi) + rho2*(1 + phi));
#endif
//}}}
// Define variational formulations {{{

// Macros {{{
#if DIMENSION == 2
macro Grad(u) [dx(u), dy(u)] //EOM
macro Div(u,v) (dx(u) + dy(v)) //EOM
#define UVEC u,v
#define UOLDVEC uOld,vOld
#endif

#if DIMENSION == 3
macro Grad(u) [dx(u), dy(u), dz(u)] //EOM
macro Div(u,v,w) (dx(u) + dy(v) + dz(w)) //EOM
#define UVEC u,v,w
#define UOLDVEC uOld,vOld,wOld
#endif

#define AUX_INTEGRAL(dim) int ## dim ## d
#define INTEGRAL(dim) AUX_INTEGRAL(dim)
//}}}
// Cahn-Hilliard {{{
varf varCH([phi1,mu1], [phi2,mu2]) =
  INTEGRAL(DIMENSION)(Th)(
    phi1*phi2/dt
    + M*(Grad(mu1)'*Grad(phi2))
    - mu1*mu2
    + Ch*(Grad(phi1)'*Grad(mu2))
    + 0.5*3*phiOld*phiOld*phi1*mu2
    - 0.5*phi1*mu2
    )
;

varf varCHrhs([phi1,mu1], [phi2,mu2]) =
  INTEGRAL(DIMENSION)(Th)(
    #ifdef NS
    convect([UOLDVEC],-dt,phiOld)/dt*phi2
    #else
    phiOld*phi2/dt
    #endif
    + 0.5*phiOld*phiOld*phiOld*mu2
    + 0.5*phiOld*mu2
    #ifdef ELECTRO
    + 0.25 * (epsilonR2 - epsilonR1) * (Grad(theta)'*Grad(theta)) * mu2
    #endif
    )
;
//}}}
// Navier-Stokes {{{
#ifdef NS
varf varU(u,test) =
  INTEGRAL(DIMENSION)(Th)(
    u*test/dt + (1/Re)*(Grad(u)'*Grad(test))
    );
varf varUrhs(u,test) =
  INTEGRAL(DIMENSION)(Th)(
    (convect([UOLDVEC],-dt,uOld)/dt)*test
    + (1/Ca)*mu*dx(phi)*test
    #ifdef GRAVITY
    + gx*phi*test
    #endif
    );
varf varV(v,test) =
  INTEGRAL(DIMENSION)(Th)(
    v*test/dt + (1/Re)*(Grad(v)'*Grad(test))
    );
varf varVrhs(v,test) =
  INTEGRAL(DIMENSION)(Th)(
    (convect([UOLDVEC],-dt,vOld)/dt)*test
    + (1/Ca)*mu*dy(phi)*test
    #ifdef GRAVITY
    + gy*phi*test
    #endif
    );
#if DIMENSION == 3
varf varW(w,test) = INTEGRAL(DIMENSION)(Th)(
    w*test/dt +(1/Re)*(Grad(w)'*Grad(test))
    );
varf varWrhs(w,test) =
  INTEGRAL(DIMENSION)(Th)(
    (convect([UOLDVEC],-dt,wOld)/dt)*test
    + (1/Ca)*mu*dz(phi)*test
    #ifdef GRAVITY
    + gz*phi*test
    #endif
    );
#endif
varf varP(p,test) = INTEGRAL(DIMENSION)(Th)( Grad(p)'*Grad(test) );
varf varPrhs(p,test) = INTEGRAL(DIMENSION)(Th)( -Div(UVEC)*test/dt );
/* 	 - Div(UVEC)*test/dt */
/* varf varPrhs(p,test) = */
/*   INTEGRAL(DIMENSION)(Th)( */
/* 	 - Div(UVEC)*test/dt */
/*     ); */
#endif
//}}}
// Poisson for electric potential {{{
#ifdef ELECTRO
varf varPotential(theta,test) =
  INTEGRAL(DIMENSION)(Th)(
    0.5*(epsilonR1*(1 - phi) + epsilonR2*(1 + phi))
    * Grad(theta)'*Grad(test)
    )
  ;
#endif
//}}}
//}}}
// Create output file for the mesh {{{
// This is only useful if P2 or higher elements are used.
#if DIMENSION == 3
#endif
//}}}
// Adapt mesh before starting computation {{{
if (adapt)
{
  #if DIMENSION == 2
  Th = adaptmesh(Th, phi, hmax = hmax, hmin = hmin, nbvx = 1e6);
  [phi, mu] = [phi0, mu0];
    #ifdef NS
    u = u;
    v = v;
    p = p;
    #if DIMENSION == 3
    w = w;
    #endif
    #endif
  #endif
  #if DIMENSION == 3
  system("cp output/mesh.msh output/mesh/mesh-init-0.msh");
  for(int i = 0; i < 3; i++)
  {
      Vh metricField;
      metricField[] = mshmet(Th, phi, aniso = 0, hmin = hmin, hmax = hmax, nbregul = 1);
      Th=tetgreconstruction(Th,switch="raAQ",sizeofvolume=metricField*metricField*metricField/6.);
      [phi, mu] = [phi0, mu0];

      if(plotSol)
      {
          medit("Phi", Th, phi, wait = false);
      }
  }
  #endif
}
//}}}
// Loop in time {{{

// Open output file
ofstream file("output/thermodynamics.txt");

// Declare extensive physical variables {{{
real freeEnergy,
     massPhi,
     dissipation;

real timeStart,
     timeMacro,
     timeMatrixBulk,
     timeMatrixBc,
     timeMatrix,
     timeRhsBulk,
     timeRhsBc,
     timeRhs,
     timeFactorization,
     timeSolution;
//}}}
for(int i = 0; i <= nIter; i++)
{
  // Update previous solution {{{
  timeStart = clock(); tic();
  phiOld = phi;
#ifdef NS
  uOld = u;
  vOld = v;
#if DIMENSION == 3
  wOld = w;
#endif
#endif
  //}}}

  ofstream interface("output/interface/interface."+ i +".xyz");
  for (int j = 0; j<Th.nv ;j++)
  {
      if (abs(phiOld[][j]) < 0.2)
      {
          #if DIMENSION == 2
          interface << "1 " << Th(j).x << " " << Th(j).y << endl;
          #endif

          #if DIMENSION == 3
          interface << "1 " << Th(j).x << " " << Th(j).y << " " << Th(j).z << endl;
          #endif
      }
  }

  // Calculate macroscopic variables {{{

  freeEnergy  = INTEGRAL(DIMENSION)(Th) (
      0.5*lambda*(Grad(phi)'*Grad(phi))
      + 0.25*lambda*invEps2*(phi^2 - 1)^2
#ifdef ELECTRO
      - 0.25 * (epsilonR1*(1 - phi) + epsilonR2*(1 + phi)) * Grad(theta)'*Grad(theta)
#endif
      );
  massPhi     = INTEGRAL(DIMENSION)(Th) (phi);
  dissipation = INTEGRAL(DIMENSION)(Th) (M*(Grad(mu)'*Grad(mu)));

  timeMacro = tic();
  //}}}
  // Save data to files and stdout {{{
  #if DIMENSION == 2
  savevtk("output/phi/phi."+i+".vtk", Th, phi, dataname="Phase");
  savevtk("output/mu/mu."+i+".vtk",  Th, mu,  dataname="ChemicalPotential");

  real[int,int] xy(3,1);
  isoline(Th, phi, xy, close=false, iso=0.0, smoothing=0.1, file="output/iso/contactLine"+i+".dat");

  // Export to gnuplot
  {
      ofstream fgnuplot("output/phi/phi."+i+".gnuplot");
      for (int ielem=0; ielem<Th.nt; ielem++)
      {
          for (int j=0; j <3; j++)
          {
              fgnuplot << Th[ielem][j].x << " " << Th[ielem][j].y << " " << phiOld[][Vh(ielem,j)] << endl;
          }
          fgnuplot << Th[ielem][0].x << " " << Th[ielem][0].y << " " << phiOld[][Vh(ielem,0)] << "\n\n\n";
      }
  }

#ifdef NS
  savevtk("output/velocity/velocity."+i+".vtk", Th, [u,v,0], dataname="Velocity");
  savevtk("output/velocity/pressure."+i+".vtk", Th, p, dataname="Pressure");
#endif

#ifdef ELECTRO
  savevtk("output/potential/potential."+i+".vtk",Th,theta, dataname="Potential");
#endif

#endif

#if DIMENSION == 3
  {
      ofstream currentMesh("output/mesh/mesh-" + i + ".msh");
      ofstream data("output/phi/phase-" + i + ".msh");

      if(adapt)
      {
          phiOut = phi;
          muOut  = mu;
#ifdef NS
          uOut = u;
          vOut = v;
          wOut = w;
#endif
          writeHeader(currentMesh);
          writeNodes(currentMesh, Vh);
          writeElements(currentMesh, Vh, Th);

          writeHeader(data);
          write1dData(data, "Cahn-Hilliard", i*dt, i, phiOld);

      }
      else
      {
          writeHeader(data); write1dData(data, "Cahn-Hilliard", i*dt, i, phiOld);
      }
  }
  system("./bin/msh2pos output/mesh/mesh-" + i + ".msh output/phi/phase-" + i + ".msh");
  // ! phi[]
#endif

  file << i*dt           << "    "
      << freeEnergy     << "    "
      << massPhi        << "    "
      << dt*dissipation << "    " << endl;

  // Print variables at current iteration
  cout << endl
      << "** ITERATION **"      << endl
      << "Time = "              << i*dt          << endl
      << "Iteration = "         << i             << endl
      << "Mass = "              << massPhi       << endl
      << "Free energy bulk = "  << freeEnergy    << endl;
  //}}}
  // Visualize solution at current time step {{{
  if (plotSol)
  {
#if DIMENSION == 2
      plot(phi, fill=true, WindowIndex = 0);
      plot(u, fill=true, WindowIndex = 1);
      plot(p, fill=true, WindowIndex = 2);
#endif

#if DIMENSION == 3
      medit("Phi",Th,phi,wait = false);
#endif
  }
  //}}}
  // Exit if required {{{
  if (i == nIter) break;

  tic();
  //}}}
  // Poisson for electric potential {{{
#ifdef ELECTRO
  matrix matPotentialBulk = varPotential(Vh, Vh);
  matrix matPotentialBoundary = varBoundaryPotential(Vh, Vh);
  matrix matPotential = matPotentialBulk + matPotentialBoundary;
  real[int] rhsPotential = varBoundaryPotential(0, Vh);
  set(matPotential,solver=sparsesolver);
  theta[] = matPotential^-1*rhsPotential;
#endif
  //}}}
  // Calculate the matrix {{{
  matrix matBulk = varCH(V2h, V2h);
  timeMatrixBulk = tic();

  matrix matBoundary = varBoundary(V2h, V2h);
  timeMatrixBc = tic();

  matrix matCH = matBulk + matBoundary;
  timeMatrix = timeMatrixBulk + timeMatrixBc + tic();

  set(matCH,solver=sparsesolver);
  timeFactorization = tic();
  //}}}
  // Calculate the right-hand side {{{

  real[int] rhsBulk = varCHrhs(0, V2h);
  timeRhsBulk = tic();

  real[int] rhsBoundary = varBoundary(0, V2h);
  timeRhsBc  = tic();

  real[int] rhsCH = rhsBulk + rhsBoundary;
  timeRhs = timeRhsBulk + timeRhsBc + tic();
  //}}}
  // Solve the linear system {{{
  phi[] = matCH^-1*rhsCH;
  timeSolution = tic();
  //}}}
  // Navier stokes {{{
  #ifdef NS
  Vh uOld = u, vOld = v, pold=p;
  #if DIMENSION == 3
  Vh wOld = w;
  #endif
  real vol = INTEGRAL(DIMENSION)(Th)(1.);

  matrix matUBulk = varU(Vh, Vh);
  matrix matUBoundary = varUBoundary(Vh, Vh);
  matrix matU = matUBulk + matUBoundary;
  real[int] rhsUBulk = varUrhs(0, Vh);
  real[int] rhsUBoundary = varUBoundary(0, Vh);
  real[int] rhsU = rhsUBulk + rhsUBoundary;
  set(matU,solver=sparsesolver);
  u[] = matU^-1*rhsU;

  matrix matVBulk = varV(Vh, Vh);
  matrix matVBoundary = varVBoundary(Vh, Vh);
  matrix matV = matVBulk + matVBoundary;
  real[int] rhsVBulk = varVrhs(0, Vh);
  real[int] rhsVBoundary = varVBoundary(0, Vh);
  real[int] rhsV = rhsVBulk + rhsVBoundary;
  set(matV,solver=sparsesolver);
  v[] = matV^-1*rhsV;

  #if DIMENSION == 3
  matrix matWBulk = varW(Vh, Vh);
  matrix matWBoundary = varWBoundary(Vh, Vh);
  matrix matW = matWBulk + matWBoundary;
  real[int] rhsWBulk = varWrhs(0, Vh);
  real[int] rhsWBoundary = varWBoundary(0, Vh);
  real[int] rhsW = rhsWBulk + rhsWBoundary;
  set(matW,solver=sparsesolver);
  w[] = matW^-1*rhsW;
  #endif

  matrix matPBulk = varP(Vh, Vh);
  matrix matPBoundary = varPBoundary(Vh, Vh);
  matrix matP = matPBulk + matPBoundary;
  real[int] rhsPBulk = varPrhs(0, Vh);
  real[int] rhsPBoundary = varPBoundary(0, Vh);
  real[int] rhsP = rhsPBulk + rhsPBoundary;
  set(matP,solver=sparsesolver);
  p[] = matP^-1*rhsP;

  u = u - dx(p)*dt;
  v = v - dy(p)*dt;
  #if DIMENSION == 3
  w = w - dz(p)*dt;
  #endif
  #endif
  //}}}
  // Adapt mesh {{{
  if (adapt)
  {
    #if DIMENSION == 2
    Th = adaptmesh(Th, phi, hmax = hmax, hmin = hmin, nbvx = 1e6);
    #endif

    #if DIMENSION == 3
    Vh metricField;
    metricField[] = mshmet(Th, phi, aniso = 0, hmin = hmin, hmax = hmax, nbregul = 1);
    Th=tetgreconstruction(Th,switch="raAQ",sizeofvolume=metricField*metricField*metricField/6.);
    #endif
    [phi, mu] = [phi, mu];

    #ifdef NS
    u = u;
    v = v;
    p = p;
    #if DIMENSION == 3
    w = w;
    #endif
    #endif

    #ifdef ELECTRO
    theta = theta;
    #endif
  }
  //}}}
  // Print the times to stdout {{{
  cout << endl
      << "** TIME OF COMPUTATIONS **    " << endl
      << "Matrix: assembly (master)     " << timeMatrix          << endl
      << "Matrix: volume terms          " << timeMatrixBulk      << endl
      << "Matrix: boundary conditions   " << timeMatrixBc        << endl
      << "Matrix: factorization         " << timeFactorization   << endl;

  cout << endl
      << "Rhs: assembly (master)       " << timeRhs             << endl
      << "Rhs: volume terms            " << timeRhsBulk         << endl
      << "Rhs: boundary conditions     " << timeRhsBc           << endl;
  cout << endl
      << "Solution  of the linear system       " << timeSolution        << endl
      << "Total time spent in process 0        " << clock() - timeStart << endl;
  //}}}
}
//}}}
