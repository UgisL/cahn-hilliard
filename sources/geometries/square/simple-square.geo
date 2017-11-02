// Dimensions of square

#ifndef LX
#define LX 1
#endif

#ifndef LY
#define LY 1
#endif

#ifndef GEOMETRY_S
#define GEOMETRY_S 0.03
#endif

s = GEOMETRY_S;

// Define domain
Point(1) = {0,  0,  0, s};
Point(2) = {LX, 0,  0, s};
Point(3) = {LX, LY, 0, s};
Point(4) = {0,  LY, 0, s};

Line(1) = {1,2};
Line(2) = {2,3};
Line(3) = {3,4};
Line(4) = {4,1};

Line Loop(1) = {1,2,3,4};
Plane Surface(1) = {1};

Physical Line (1) = {1};
Physical Line (2) = {2};
Physical Line (3) = {3};
Physical Line (4) = {4};

Physical Surface (1) = {1};

// View options
Geometry.LabelType = 2;
Geometry.Lines = 1;
Geometry.LineNumbers = 2;
Geometry.Surfaces = 1;
Geometry.SurfaceNumbers = 2;
