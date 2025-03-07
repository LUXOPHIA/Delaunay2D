program Delaunay2D;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  LUX.D1 in '_LIBRARY\LUXOPHIA\LUX\LUX.D1.pas',
  LUX.D2 in '_LIBRARY\LUXOPHIA\LUX\LUX.D2.pas',
  LUX in '_LIBRARY\LUXOPHIA\LUX\LUX.pas',
  LUX.Data.List in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.pas',
  LUX.Data.List.core in '_LIBRARY\LUXOPHIA\LUX\Data\List\LUX.Data.List.core.pas',
  LUX.Data.Model.Poins in '_LIBRARY\LUXOPHIA\LUX\Data\Model\LUX.Data.Model.Poins.pas',
  LUX.Data.Model.Faces in '_LIBRARY\LUXOPHIA\LUX\Data\Model\LUX.Data.Model.Faces.pas',
  LUX.Data.Model.TriFlip in '_LIBRARY\LUXOPHIA\LUX\Data\Model\TriFlip\LUX.Data.Model.TriFlip.pas',
  LUX.Data.Model.TriFlip.D2 in '_LIBRARY\LUXOPHIA\LUX\Data\Model\TriFlip\LUX.Data.Model.TriFlip.D2.pas',
  Main in 'Main.pas' {Form1},
  ViewerFrame in 'ViewerFrame.pas' {Viewer: TFrame};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
