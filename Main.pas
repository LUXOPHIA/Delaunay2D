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
      ButtonC: TButton;
      ButtonA: TButton;
      ButtonD: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure ButtonCClick(Sender: TObject);
    procedure ButtonAClick(Sender: TObject);
    procedure ButtonDClick(Sender: TObject);
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

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          with Camera do
          begin
               SizeX := 600;
               SizeY := 600;
          end;

          with Poins.Style do
          begin
               FillColor := TAlphaColors.Red;
               LineColor := TAlphaColors.White;
               LineThick := 1;
          end;

          with Trias.Style do
          begin
               FillColor := TAlphaColors.Cornflowerblue;
               LineColor := TAlphaColors.White;
               LineThick := 1;
          end;

          with Circs.Style do
          begin
               LineColor := TAlphaColors.Lime;
               LineThick := 0.5;
          end;

          with Volos.Style do
          begin
               LineColor := TAlphaColors.Black;
               LineThick := 0.5;
          end;
     end;

     ButtonAClick( Sender );
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

     V := _Delaunay.FindPoin( P, 6 );

     if Assigned( V ) then _Delaunay.DeletePoin( V )   // 既存点 → 削除
                      else _Delaunay.AddPoin   ( P );  // 空白　 → 追加
end;

//------------------------------------------------------------------------------

procedure TForm1.ButtonCClick(Sender: TObject);
begin
     _Delaunay.Clear;
end;

procedure TForm1.ButtonAClick(Sender: TObject);
var
   N :Integer;
begin
     for N := 1 to 10 do _Delaunay.AddPoin( 100 * TSingle2D.RandG );
end;

procedure TForm1.ButtonDClick(Sender: TObject);
var
   N :Integer;
begin
     for N := 1 to Min( 10, _Delaunay.Poins.Count ) do
     begin
          _Delaunay.DeletePoin( _Delaunay.Poins[ Random( _Delaunay.Poins.Count ) ] );
     end;
end;

end. //######################################################################### ■
