unit Main;

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, ViewerFrame;

type
  TForm1 = class(TForm)
    Viewer1: TViewer;
    Panel1: TPanel;
  private
    { private 宣言 }
  public
    { public 宣言 }
  end;

var
  Form1: TForm1;

implementation //############################################################### ■

{$R *.fmx}

end. //######################################################################### ■
