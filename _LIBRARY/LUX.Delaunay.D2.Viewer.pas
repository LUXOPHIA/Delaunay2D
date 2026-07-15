unit LUX.Delaunay.D2.Viewer;

// TDelaunay2D の描画フレーム
//
// ・TSkPaintBox を貼るのではなく、その実装と同じく Paint をオーバーライドして
//   Skia キャンバス（ISkCanvas）へ直接描画する。GlobalUseSkia = True が前提。
// ・Delaunay プロパティにモデルを接続するだけで描画される。
//   モデルの OnChange を購読するので、誰がどこでモデルを変更しても自動で再描画される。
// ・表示専用のクラスであり、マウス操作などは載せない。操作はアプリケーション側で
//   OnMouseDown 等を処理し、公開の座標変換 ScrToPos / PosToScr を使って行う。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Skia, FMX.Skia.Canvas,
  LUX, LUX.D2,
  LUX.Delaunay.D2;

type
  TDelaunayViewer = class(TFrame)
  private
  protected
    _Delaunay :TDelaunay2D;
    ///// A C C E S S O R
    procedure SetDelaunay( const Delaunay_:TDelaunay2D );
    ///// M E T H O D
    procedure DelaunayChange( Sender_:TObject );
    procedure DrawFace( const Canvas_:ISkCanvas );
    procedure DrawCirc( const Canvas_:ISkCanvas );
    procedure DrawVolo( const Canvas_:ISkCanvas );
    procedure DrawPoin( const Canvas_:ISkCanvas );
    procedure Paint; override;
  public
    ///// P R O P E R T Y
    property Delaunay :TDelaunay2D read _Delaunay write SetDelaunay;
    ///// M E T H O D
    function ScrToPos( const S_:TPointF ) :TSingle2D;
    function PosToScr( const P_:TSingle2D ) :TPointF;
  end;

implementation //############################################################### ■

{$R *.fmx}

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayViewer.SetDelaunay( const Delaunay_:TDelaunay2D );
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange := nil;

     _Delaunay := Delaunay_;

     if Assigned( _Delaunay ) then _Delaunay.OnChange := DelaunayChange;

     Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayViewer.DelaunayChange( Sender_:TObject );
begin
     Repaint;
end;

//------------------------------------------------------------------------------

function TDelaunayViewer.ScrToPos( const S_:TPointF ) :TSingle2D;
begin
     Result := S_ - TPointF.Create( Width  / 2,
                                    Height / 2 );
end;

function TDelaunayViewer.PosToScr( const P_:TSingle2D ) :TPointF;
begin
     Result := TPointF( P_ ) + TPointF.Create( Width  / 2,
                                               Height / 2 );
end;

//------------------------------------------------------------------------------

procedure TDelaunayViewer.DrawFace( const Canvas_:ISkCanvas );
var
   Fill, Line :ISkPaint;
   F :TDelaFace2D;
   B :ISkPathBuilder;
   P :ISkPath;
begin
     Fill := TSkPaint.Create( TSkPaintStyle.Fill );
     Fill.AntiAlias := True;
     Fill.Color     := TAlphaColors.Cornflowerblue;

     Line := TSkPaint.Create( TSkPaintStyle.Stroke );
     Line.AntiAlias   := True;
     Line.Color       := TAlphaColors.White;
     Line.StrokeWidth := 1;

     for F in _Delaunay.Faces do
     begin
          if F.InfCorn = 0 then
          begin
               B := TSkPathBuilder.Create;

               B.MoveTo( PosToScr( F.Poin[ 1 ].Pos ) );
               B.LineTo( PosToScr( F.Poin[ 2 ].Pos ) );
               B.LineTo( PosToScr( F.Poin[ 3 ].Pos ) );
               B.Close;

               P := B.Detach;

               Canvas_.DrawPath( P, Fill );
               Canvas_.DrawPath( P, Line );
          end;
     end;
end;

procedure TDelaunayViewer.DrawCirc( const Canvas_:ISkCanvas );
var
   Line :ISkPaint;
   F :TDelaFace2D;
begin
     Line := TSkPaint.Create( TSkPaintStyle.Stroke );
     Line.AntiAlias   := True;
     Line.Color       := TAlphaColors.Lime;
     Line.StrokeWidth := 0.5;

     for F in _Delaunay.Faces do
     begin
          if F.InfCorn = 0 then
          begin
               with F.Circle do Canvas_.DrawCircle( PosToScr( Center ), Radius, Line );
          end;
     end;
end;

procedure TDelaunayViewer.DrawVolo( const Canvas_:ISkCanvas );
//------------------------------------------------
     function CenterPos( const Face_:TDelaFace2D ) :TSingle2D;
     //------------------------------------------------
          function EdgeCenter( const P1_,P2_:TDelaPoin2D ) :TSingle2D;
          begin
               Result := ( P1_.Pos + P2_.Pos ) / 2 - 10000 * Face_.Circle.Center;
          end;
     //------------------------------------------------
     begin
          with Face_ do
          begin
               case InfCorn of
                 0: Result := Circle.Center;
                 1: Result := EdgeCenter( Poin[ 2 ], Poin[ 3 ] );
                 2: Result := EdgeCenter( Poin[ 3 ], Poin[ 1 ] );
                 3: Result := EdgeCenter( Poin[ 1 ], Poin[ 2 ] );
               end;
          end;
     end;
//------------------------------------------------
var
   Line :ISkPaint;
   F :TDelaFace2D;
   C, P1, P2, P3 :TPointF;
begin
     Line := TSkPaint.Create( TSkPaintStyle.Stroke );
     Line.AntiAlias   := True;
     Line.Color       := TAlphaColors.Black;
     Line.StrokeWidth := 0.5;

     for F in _Delaunay.Faces do
     begin
          if F.InfCorn = 0 then
          begin
               C := PosToScr( F.Circle.Center );

               P1 := PosToScr( CenterPos( F.Face[ 1 ] ) );
               P2 := PosToScr( CenterPos( F.Face[ 2 ] ) );
               P3 := PosToScr( CenterPos( F.Face[ 3 ] ) );

               Canvas_.DrawLine( C, ( C + P1 ) / 2, Line );
               Canvas_.DrawLine( C, ( C + P2 ) / 2, Line );
               Canvas_.DrawLine( C, ( C + P3 ) / 2, Line );
          end;
     end;
end;

procedure TDelaunayViewer.DrawPoin( const Canvas_:ISkCanvas );
var
   Fill, Line :ISkPaint;
   P :TDelaPoin2D;
   S :TPointF;
begin
     Fill := TSkPaint.Create( TSkPaintStyle.Fill );
     Fill.AntiAlias := True;
     Fill.Color     := TAlphaColors.Red;

     Line := TSkPaint.Create( TSkPaintStyle.Stroke );
     Line.AntiAlias   := True;
     Line.Color       := TAlphaColors.White;
     Line.StrokeWidth := 1;

     for P in _Delaunay.Poins do
     begin
          S := PosToScr( P.Pos );

          Canvas_.DrawCircle( S, 5, Fill );
          Canvas_.DrawCircle( S, 5, Line );
     end;
end;

//------------------------------------------------------------------------------

procedure TDelaunayViewer.Paint;
var
   Canvas_ :ISkCanvas;
begin
     if not ( Canvas is TSkCanvasCustom ) then Exit;  // 要 GlobalUseSkia = True

     Canvas_ := TSkCanvasCustom( Canvas ).Canvas;

     Canvas_.Save;
     try
          Canvas_.ClipRect( TRectF.Create( 0, 0, Width, Height ) );

          Canvas_.Clear( TAlphaColors.White );

          if Assigned( _Delaunay ) then
          begin
               DrawFace( Canvas_ );
               DrawCirc( Canvas_ );
               DrawVolo( Canvas_ );
               DrawPoin( Canvas_ );
          end;
     finally
          Canvas_.Restore;
     end;
end;

end. //######################################################################### ■
