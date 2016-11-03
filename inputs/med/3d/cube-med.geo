Merge "output/mesh.msh";

// Generate list of files to be included
System "ls -v output/phi/phase-*.msh | sed '$d'  > includes.geo";
System 'sed -i "s/^\(.\+\)$/Merge \"\1\";/" includes.geo';

// Include output files
Include "includes.geo";

// Clean generated list
System 'rm includes.geo';

Hide {
  Surface {
    Physical Surface{1},
    Physical Surface{2},
    Physical Surface{3}
  };
}

General.Trackball = 0;
General.RotationX = 300.7256005599669;
General.RotationY = 1.020846997272915;
General.RotationZ = 318.5479184306434;

Mesh.ColorCarousel   = 2;
Mesh.SurfaceEdges    = 0;
Mesh.VolumeEdges     = 0;

Mesh.ColorCarousel      = 2;
Mesh.SurfaceEdges       = 0;
Mesh.SurfaceFaces       = 1;
Mesh.VolumeEdges        = 0;
Geometry.Lines          = 0;
Geometry.Surfaces       = 0;
Geometry.Points         = 0;
Geometry.SurfaceType    = 0;
Geometry.SurfaceNumbers = 0;

// Number of cutting planes
nplanes = 3;

Plugin(CutPlane).A = 1;
Plugin(CutPlane).B = 0;
Plugin(CutPlane).C = 0;
Plugin(CutPlane).D = 0;
Plugin(CutPlane).View = 0;
Plugin(CutPlane).Run;

Plugin(CutPlane).A = 0;
Plugin(CutPlane).B = 1;
Plugin(CutPlane).C = 0;
Plugin(CutPlane).D = - Ly;
Plugin(CutPlane).View = 0;
Plugin(CutPlane).Run;

Plugin(CutPlane).A = 0;
Plugin(CutPlane).B = 0;
Plugin(CutPlane).C = 1;
Plugin(CutPlane).D = 0;
Plugin(CutPlane).View = 0;
Plugin(CutPlane).Run;

Plugin(Isosurface).Value = 0;
Plugin(Isosurface).View = 0;
Plugin(Isosurface).Run;

For i In {0:PostProcessing.NbViews-1}
  View[i].Visible = 0;
  View[i].ShowScale = 0;
  View[i].RangeType = 2;
  View[i].CustomMin = -2;
  View[i].CustomMax = 2;
EndFor
View[1].ShowScale = 1;

For i In {1:nplanes+1}
  View[i].Visible   = 1;
EndFor

For i In {nplanes+1:PostProcessing.NbViews-2}
  Draw;
  If(Exists(video))
    System "mkdir -p output/iso";
    Print Sprintf("output/iso/isosurface-%04g.jpg", i);
  EndIf
  If(!Exists(video))
    Sleep 0.1;
  EndIf
  For j In {1:nplanes}
    View[j].TimeStep += 1;
  EndFor
  View[i].Visible = 0;
  View[i+1].Visible = 1;
EndFor

Exit;
