x = 0;
y = 0;
r = 0.5;
s = 0.1;

// Define surface circle
points[1] = newp; Point(points[1]) = {x    , y    , 0, s}; // Center
points[2] = newp; Point(points[2]) = {x - r, y, 0, s};
points[3] = newp; Point(points[3]) = {x, y - r, 0, s};
points[4] = newp; Point(points[4]) = {x + r, y, 0, s};
points[5] = newp; Point(points[5]) = {x, y + r, 0, s};

lines[1] = newl; Circle(lines[1]) = {points[2],points[1],points[3]};
lines[2] = newl; Circle(lines[2]) = {points[3],points[1],points[4]};
lines[3] = newl; Circle(lines[3]) = {points[4],points[1],points[5]};
lines[4] = newl; Circle(lines[4]) = {points[5],points[1],points[2]};

lloop = newreg; Line Loop(lloop) = {lines[1],lines[2],lines[3],lines[4]};
Plane Surface(1) = {lloop};
Physical Surface(1) = {1};
Physical Line(1) = {lines[]};

// Setting the appropriate mesh format
Mesh.Format=1;
Mesh.MshFileVersion = 2.2;