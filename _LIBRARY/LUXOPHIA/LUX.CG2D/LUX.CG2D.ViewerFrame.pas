unit LUX.CG2D.ViewerFrame;

// TCGLayers（シーングラフ）の汎用ビューア
//
// ・Layers プロパティにシーンを接続するだけで描画される。
// ・シーンの OnChange（TDelegates による多播）を購読し、変化のたびに自動で
//   再描画する。外から Repaint を呼ぶ必要はなく、他の購読者とも共存できる。
// ・Paint をオーバーライドして Skia キャンバスへ直接レンダリングする。
//   GlobalUseSkia = True が前提。
// ・シーンを先に解放する場合は Layers := nil で購読を外してから解放すること。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Skia,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Skia, FMX.Skia.Canvas,
  LUX.CG2D;

type
  TViewer = class(TFrame)
  private
  protected
    _Layers :TCGLayers;
    ///// A C C E S S O R
    procedure SetLayers( const Layers_:TCGLayers );
    ///// M E T H O D
    procedure LayersChange( Sender_:TObject );
    procedure Paint; override;
  public
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Layers :TCGLayers read _Layers write SetLayers;
  end;

implementation //############################################################### ■

{$R *.fmx}

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TViewer.SetLayers( const Layers_:TCGLayers );
begin
     if Assigned( _Layers ) then _Layers.OnChange.Del( LayersChange );

     _Layers := Layers_;

     if Assigned( _Layers ) then _Layers.OnChange.Add( LayersChange );

     Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TViewer.LayersChange( Sender_:TObject );
begin
     Repaint;
end;

//------------------------------------------------------------------------------

procedure TViewer.Paint;
var
   Canvas_ :ISkCanvas;
begin
     if not ( Canvas is TSkCanvasCustom ) then Exit;  // 要 GlobalUseSkia = True

     Canvas_ := TSkCanvasCustom( Canvas ).Canvas;

     Canvas_.Save;
     try
          Canvas_.ClipRect( TRectF.Create( 0, 0, Width, Height ) );

          if Assigned( _Layers ) then _Layers.Render( Canvas_ )
                                 else Canvas_.Clear( TAlphaColors.White );
     finally
          Canvas_.Restore;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

destructor TViewer.Destroy;
begin
     if Assigned( _Layers ) then _Layers.OnChange.Del( LayersChange );  // 購読解除

     inherited;
end;

end. //######################################################################### ■
