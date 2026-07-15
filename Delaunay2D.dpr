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
  LUX.Delaunay.D2.Viewer in '_LIBRARY\LUX.Delaunay.D2.Viewer.pas' {DelaunayViewer: TFrame};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
