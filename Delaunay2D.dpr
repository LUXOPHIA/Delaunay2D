program Delaunay2D;





uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  Main in 'Main.pas' {Form1},
  LUX in '_LIBRARY\LUXOPHIA\LUX\LUX.pas',
  LUX.D1 in '_LIBRARY\LUXOPHIA\LUX\LUX.D1.pas',
  LUX.D2 in '_LIBRARY\LUXOPHIA\LUX\LUX.D2.pas',
  LUX.Delaunay.D2 in '_LIBRARY\LUX.Delaunay.D2.pas',
  LUX.Delaunay.D2.Viewer in '_LIBRARY\LUX.Delaunay.D2.Viewer.pas' {DelaunayViewer: TFrame},
  LUX.CG2D in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.pas',
  LUX.CG2D.Shapers in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.Shapers.pas',
  LUX.CG2D.ViewerFrame in '_LIBRARY\LUXOPHIA\LUX.CG2D\LUX.CG2D.ViewerFrame.pas' {CGViewer: TFrame},
  LUX.Data.List in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.pas',
  LUX.Data.List.core in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.core.pas',
  LUX.Data.Tree in '_LIBRARY\LUXOPHIA\LUX\Data\Tree\LUX.Data.Tree.pas',
  LUX.D3 in '_LIBRARY\LUXOPHIA\LUX\LUX.D3.pas',
  LUX.D3x3 in '_LIBRARY\LUXOPHIA\LUX\LUX.D3x3.pas',
  LUX.D2x2 in '_LIBRARY\LUXOPHIA\LUX\LUX.D2x2.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
