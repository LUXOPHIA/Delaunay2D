program Delaunay2D;





uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  Main in 'Main.pas' {Form1},
  LUX in '_LIBRARY\LUXOPHIA\LUX\LUX.pas',
  LUX.D1 in '_LIBRARY\LUXOPHIA\LUX\LUX.D1.pas',
  LUX.D2 in '_LIBRARY\LUXOPHIA\LUX\LUX.D2.pas',
  LUX.Delaunay.D2 in '_LIBRARY\LUXOPHIA\LUX.Delaunay\D2\LUX.Delaunay.D2.pas',
  LUX.Delaunay.D2.Viewer in '_LIBRARY\LUXOPHIA\LUX.Delaunay\D2\LUX.Delaunay.D2.Viewer.pas' {DelaunayViewer: TFrame},
  LUX.CG2D in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.pas',
  LUX.CG2D.Shapers in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.Shapers.pas',
  LUX.CG2D.Viewer in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.Viewer.pas' {CGViewer: TFrame},
  LUX.Data in '_LIBRARY\LUXOPHIA\LUX\Data\LUX.Data.pas',
  LUX.Data.List in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.pas',
  LUX.Data.List.core in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.core.pas',
  LUX.Data.Tree in '_LIBRARY\LUXOPHIA\LUX\Data\Tree\LUX.Data.Tree.pas',
  LUX.D3 in '_LIBRARY\LUXOPHIA\LUX\LUX.D3.pas',
  LUX.D3x3 in '_LIBRARY\LUXOPHIA\LUX\LUX.D3x3.pas',
  LUX.D2x2 in '_LIBRARY\LUXOPHIA\LUX\LUX.D2x2.pas',
  LUX.Data.Model.TriFlip.core in '_LIBRARY\LUXOPHIA\LUX\Data\Model\TriFlip\LUX.Data.Model.TriFlip.core.pas',
  LUX.Data.Model.TriFlip in '_LIBRARY\LUXOPHIA\LUX\Data\Model\TriFlip\LUX.Data.Model.TriFlip.pas',
  LUX.Data.Model.TriFlip.D2 in '_LIBRARY\LUXOPHIA\LUX\Data\Model\TriFlip\LUX.Data.Model.TriFlip.D2.pas',
  LUX.Data.Model.Poins in '_LIBRARY\LUXOPHIA\LUX\Data\Model\LUX.Data.Model.Poins.pas',
  LUX.Data.Model.Faces in '_LIBRARY\LUXOPHIA\LUX\Data\Model\LUX.Data.Model.Faces.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
