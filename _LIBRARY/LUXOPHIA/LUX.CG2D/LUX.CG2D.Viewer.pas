unit LUX.CG2D.Viewer;

// シーングラフの汎用ビューア（カメラ越しにシーンを描く）
//
// ・Camera プロパティに TCGCamera を接続すると、カメラの属すシーンを
//   カメラから見た風景として描画する。Camera が nil ならべた塗りのみ。
// ・シーンの変化はカメラの OnScene（TDelegates による多播）で購読し、変化のたびに
//   自動で再描画する。外から Repaint を呼ぶ必要はなく、他の購読者とも共存できる。
// ・カメラの視野（SizeX / SizeY）が UI にぴったり完全に収まる等方スケールで描く。
//   UI と視野のアスペクト比が異なる場合、視野は長い辺の方向へ広がる
//   （視野 -1〜+1 × -1〜+1 を 3:2 の UI に映すと -1.5〜+1.5 × -1〜+1 になる）。
// ・Paint をオーバーライドして Skia キャンバスへ直接レンダリングする。
//   GlobalUseSkia = True が前提。
// ・カメラを先に解放する場合は Camera := nil で購読を外してから解放すること。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Skia,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Skia, FMX.Skia.Canvas,
  LUX.CG2D;

type
  TCGViewer = class(TFrame)
  private
  protected
    _Camera :TCGCamera;
    ///// A C C E S S O R
    procedure SetCamera( const Camera_:TCGCamera );
    ///// M E T H O D
    procedure SceneChange( Sender_:TObject );
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
begin
     if Assigned( _Camera ) then _Camera.OnScene.Del( SceneChange );

     _Camera := Camera_;

     if Assigned( _Camera ) then _Camera.OnScene.Add( SceneChange );

     Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGViewer.SceneChange( Sender_:TObject );
begin
     Repaint;
end;

//------------------------------------------------------------------------------

procedure TCGViewer.Paint;
var
   Canvas_ :ISkCanvas;
   S :Single;
begin
     if not ( Canvas is TSkCanvasCustom ) then Exit;  // 要 GlobalUseSkia = True

     Canvas_ := TSkCanvasCustom( Canvas ).Canvas;

     Canvas_.Save;
     try
          Canvas_.ClipRect( TRectF.Create( 0, 0, Width, Height ) );

          if Assigned( _Camera ) then
          begin
               Canvas_.Translate( Width / 2, Height / 2 );  // 視野の中心 → 画面中央

               S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );  // 視野がぴったり収まる等方スケール

               Canvas_.Scale( S, S );

               _Camera.Render( Canvas_ );  // カメラ座標系への変換とシーンの描画
          end
          else Canvas_.Clear( TAlphaColors.White );  // カメラが無ければべた塗りのみ
     finally
          Canvas_.Restore;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

destructor TCGViewer.Destroy;
begin
     if Assigned( _Camera ) then _Camera.OnScene.Del( SceneChange );  // 購読解除

     inherited;
end;

end. //######################################################################### ■
