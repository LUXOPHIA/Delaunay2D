unit Main;

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,
  LUX, LUX.D2,
  LUX.Delaunay.D2,
  LUX.Delaunay.D2.Viewer;

type
  TForm1 = class(TForm)
    Viewer1: TDelaunayViewer;
    Panel1: TPanel;
      Button1: TButton;
      Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { private 宣言 }
  public
    { public 宣言 }
    _Delaunay :TDelaunay2D;
  end;

var
  Form1: TForm1;

implementation //############################################################### ■

uses System.Math;

{$R *.fmx}

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TDelaunay2D.Create;

     Viewer1.Delaunay := _Delaunay;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // 購読を解除してから解放する

     _Delaunay.Free;
end;

////////////////////////////////////////////////////////////////////////////////

procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TDelaPoin2D;
begin
     P := Viewer1.ScrToPos( TPointF.Create( X, Y ) );

     V := _Delaunay.FindPoin( P, 6{点の描画半径+縁} );

     if Assigned( V ) then _Delaunay.DeletePoin( V )   // 既存点 → 削除
                      else _Delaunay.AddPoin   ( P );  // 空白　 → 追加
end;

//------------------------------------------------------------------------------

procedure TForm1.Button1Click(Sender: TObject);
var
   N :Integer;
begin
     for N := 1 to 100 do _Delaunay.AddPoin( TSingle2D.RandG * ( Min( Viewer1.Width, Viewer1.Height ) / 4 ) );
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
     _Delaunay.Clear;
end;

end. //######################################################################### ■
