unit LUX.CG2D.Viewer;

// シーングラフの汎用ビューア（カメラ越しにシーンを描く）
//
// ・Camera プロパティに TCGCamera を接続すると、カメラの属すシーン（TCGLayers）を
//   カメラから見た風景として描画する。Camera が nil ならべた塗りのみ。
//   カメラはシーンに所属させてから接続すること（所属先からシーンを解決する）。
// ・シーンの OnChange（TDelegates による多播）を購読し、変化のたびに自動で
//   再描画する。外から Repaint を呼ぶ必要はなく、他の購読者とも共存できる。
// ・カメラの視野（SizeX / SizeY）が UI にぴったり完全に収まる等方スケールで描く。
//   UI と視野のアスペクト比が異なる場合、視野は長い辺の方向へ広がる
//   （視野 -1〜+1 × -1〜+1 を 3:2 の UI に映すと -1.5〜+1.5 × -1〜+1 になる）。
// ・Paint をオーバーライドして Skia キャンバスへ直接レンダリングする。
//   GlobalUseSkia = True が前提。
// ・シーンを先に解放する場合は Camera := nil で購読を外してから解放すること。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Math.Vectors, System.Skia,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Skia, FMX.Skia.Canvas,
  LUX.D3x3,
  LUX.Data.Tree,
  LUX.CG2D;

type
  TCGViewer = class(TFrame)
  private
  protected
    _Camera :TCGCamera;
    _Layers :TCGLayers;  // カメラから解決したシーン（購読の管理用）
    ///// A C C E S S O R
    procedure SetCamera( const Camera_:TCGCamera );
    ///// M E T H O D
    procedure LayersChange( Sender_:TObject );
    procedure Paint; override;
  public
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Camera :TCGCamera read _Camera write SetCamera;
  end;

implementation //############################################################### ■

{$R *.fmx}

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGViewer.SetCamera( const Camera_:TCGCamera );
var
   R :TTreeNode;
begin
     if Assigned( _Layers ) then _Layers.OnChange.Del( LayersChange );

     _Camera := Camera_;
     _Layers := nil;

     if Assigned( _Camera ) then
     begin
          R := _Camera.Root;  // カメラの所属からシーンを解決する

          if R is TCGLayers then _Layers := TCGLayers( R );
     end;

     if Assigned( _Layers ) then _Layers.OnChange.Add( LayersChange );

     Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGViewer.LayersChange( Sender_:TObject );
begin
     Repaint;
end;

//------------------------------------------------------------------------------

procedure TCGViewer.Paint;
var
   Canvas_ :ISkCanvas;
   S :Single;
   V :TSingleM3;
begin
     if not ( Canvas is TSkCanvasCustom ) then Exit;  // 要 GlobalUseSkia = True

     Canvas_ := TSkCanvasCustom( Canvas ).Canvas;

     Canvas_.Save;
     try
          Canvas_.ClipRect( TRectF.Create( 0, 0, Width, Height ) );

          if Assigned( _Layers ) then
          begin
               Canvas_.Translate( Width / 2, Height / 2 );  // 視野の中心 → 画面中央

               S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );  // 視野がぴったり収まる等方スケール

               Canvas_.Scale( S, S );

               V := _Camera.GlobalPose.Inverse;

               Canvas_.Concat( TMatrix( V ) );  // ワールド座標系 → カメラ座標系

               _Layers.Render( Canvas_ );
          end
          else Canvas_.Clear( TAlphaColors.White );  // カメラ（シーン）が無ければべた塗りのみ
     finally
          Canvas_.Restore;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

destructor TCGViewer.Destroy;
begin
     if Assigned( _Layers ) then _Layers.OnChange.Del( LayersChange );  // 購読解除

     inherited;
end;

end. //######################################################################### ■
