unit LUX.Delaunay.D2.Viewer;

// TDelaunay2D のビューア
//
// ・TDelaunay2D を受けて LUX.CG2D のシーングラフを構築し、レンダリングする。
//   自前の描画処理は持たない。
// ・シーンは4枚のレイヤからなる（描画順: 三角形 → 外接円 → ボロノイ → 頂点）。
//     TDelaunayPoins … 頂点（Radius）
//     TDelaunayTrias … 三角形
//     TDelaunayCircs … 外接円
//     TDelaunayVolos … ボロノイ
//   各レイヤは BuildScene( Delaunay_ ) で自分の下に図形を構築する。
// ・色や線の太さは Viewer1.Poins.Style.FillColor のように、レイヤの Style
//   （TCGLayer が強制生成する既定のスタイル）で変更する。既定値は各レイヤの
//   Create で設定される。スタイルの変更はシーンに通知され、自動的に再描画される。
// ・シーンの再構築は「全廃棄・全構築」とし、Paint の直前まで遅延して1フレームに
//   1回だけ行う。再構築は BeginUpdate / EndUpdate で束ね、ノード単位の通知を止める。
// ・強制的に TCGCamera を1つ生成して保持し（Camera プロパティ。カメラ専用レイヤに
//   所属させる）、カメラから見た風景を描く。視野（SizeX / SizeY = 既定 400×400）が
//   UI にぴったり収まる等方スケールで描き、アスペクト比の差は視野の広がりで吸収する。
// ・マウス操作などは載せない。アプリケーション側で OnMouseDown 等を処理し、
//   座標変換 ScrToPos / PosToScr を使って行う。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Skia, FMX.Skia.Canvas,
  LUX, LUX.D2, LUX.D3, LUX.D3x3,
  LUX.CG2D,
  LUX.CG2D.Shapers,
  LUX.Delaunay.D2;

type
  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayPoins

  // 頂点レイヤ
  TDelaunayPoins = class( TCGLayer )
  private
    _Radius :Single;
    ///// A C C E S S O R
    procedure SetRadius( const Radius_:Single );
  protected
  public
    constructor Create; overload; override;
    ///// P R O P E R T Y
    property Radius :Single read _Radius write SetRadius;  // 点の半径
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayTrias

  // 三角形レイヤ
  TDelaunayTrias = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayCircs

  // 外接円レイヤ
  TDelaunayCircs = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVolos

  // ボロノイレイヤ
  TDelaunayVolos = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewer

  TDelaunayViewer = class(TFrame)
  private
  protected
    _Delaunay :TDelaunay2D;    upDelaunay :Boolean;  // シーンの再構築の予約（Paint の直前に1回だけ実行）
    _Layers   :TCGLayers;
    _Camera   :TCGCamera;
    _Poins    :TDelaunayPoins;
    _Trias    :TDelaunayTrias;
    _Circs    :TDelaunayCircs;
    _Volos    :TDelaunayVolos;
    ///// A C C E S S O R
    procedure SetDelaunay( const Delaunay_:TDelaunay2D );
    ///// M E T H O D
    procedure DelaunayChange( Sender_:TObject );
    procedure LayersChange( Sender_:TObject );
    procedure BuildScene;
    procedure Paint; override;
  public
    constructor Create( Owner_:TComponent ); override;
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Delaunay :TDelaunay2D read _Delaunay write SetDelaunay;
    property Layers   :TCGLayers   read _Layers                    ;  // 構築されたシーン
    property Camera   :TCGCamera   read _Camera                    ;  // 視点（強制生成。位置や視野を操作できる）
    ///// P R O P E R T Y （レイヤ）
    property Poins :TDelaunayPoins read _Poins;  // 頂点　　（Viewer1.Poins.Radius など）
    property Trias :TDelaunayTrias read _Trias;  // 三角形
    property Circs :TDelaunayCircs read _Circs;  // 外接円
    property Volos :TDelaunayVolos read _Volos;  // ボロノイ
    ///// M E T H O D
    function ScrToPos( const S_:TPointF ) :TSingle2D;
    function PosToScr( const P_:TSingle2D ) :TPointF;
  end;

implementation //############################################################### ■

{$R *.fmx}

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayPoins

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayPoins.SetRadius( const Radius_:Single );
begin
     _Radius := Radius_;  Changed;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayPoins.Create;
begin
     inherited;

     _Radius := 3;

     Style.FillColor := TAlphaColors.Red;
     Style.LineColor := TAlphaColors.White;
     Style.LineThick := 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayPoins.BuildScene( const Delaunay_:TDelaunay2D );
var
   P :TDelaPoin2D;
   D :TCGCirc;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     for P in Delaunay_.Poins do
     begin
          D := TCGCirc.Create( Self );
          D.Pos    := P.Pos;
          D.Radius := _Radius;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayTrias

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayTrias.Create;
begin
     inherited;

     Style.FillColor := TAlphaColors.Cornflowerblue;
     Style.LineColor := TAlphaColors.White;
     Style.LineThick := 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayTrias.BuildScene( const Delaunay_:TDelaunay2D );
var
   F :TDelaFace2D;
   T :TCGTria;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     for F in Delaunay_.Faces do
     begin
          if F.InfCorn = 0 then
          begin
               T := TCGTria.Create( Self );
               T.Vert1 := F.Poin[ 1 ].Pos;
               T.Vert2 := F.Poin[ 2 ].Pos;
               T.Vert3 := F.Poin[ 3 ].Pos;
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayCircs

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayCircs.Create;
begin
     inherited;

     Style.LineColor := TAlphaColors.Lime;
     Style.LineThick := 0.5;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayCircs.BuildScene( const Delaunay_:TDelaunay2D );
var
   F :TDelaFace2D;
   V :TSingle3D;
   P :TSingle2D;
   C :TCGCirc;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     for F in Delaunay_.Faces do
     begin
          V := F.Circum;

          if V.Z > 0 then  // 有限面のみ（無限遠面は W = 0）
          begin
               P := TSingle2D.Create( V.X, V.Y ) / V.Z;

               C := TCGCirc.Create( Self );
               C.Pos    := P;
               C.Radius := Distance( P, F.Poin[ 1 ].Pos );
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVolos

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayVolos.Create;
begin
     inherited;

     Style.LineColor := TAlphaColors.Black;
     Style.LineThick := 0.5;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayVolos.BuildScene( const Delaunay_:TDelaunay2D );
//------------------------------------------------
     function CenterPos( const Face_:TDelaFace2D ) :TSingle2D;
     var
        V :TSingle3D;
     begin
          V := Face_.Circum;

          if V.Z > 0 then Result := TSingle2D.Create( V.X, V.Y ) / V.Z              // 有限面 → 外心（ボロノイ頂点）
                     else Result := TSingle2D.Create( V.X, V.Y ).Unitor * 10000;  // 無限遠面 → 外向きの遠方
     end;
//------------------------------------------------
var
   F :TDelaFace2D;
   K :Byte;
   C :TSingle2D;
   L :TCGLine;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     for F in Delaunay_.Faces do
     begin
          if F.InfCorn = 0 then
          begin
               C := CenterPos( F );

               for K := 1 to 3 do
               begin
                    L := TCGLine.Create( Self );
                    L.Pos1 := C;
                    L.Pos2 := ( C + CenterPos( F.Face[ K ] ) ) / 2;
               end;
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayViewer.SetDelaunay( const Delaunay_:TDelaunay2D );
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );

     _Delaunay := Delaunay_;

     if Assigned( _Delaunay ) then _Delaunay.OnChange.Add( DelaunayChange );

     upDelaunay := True;  Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayViewer.DelaunayChange( Sender_:TObject );
begin
     upDelaunay := True;  Repaint;  // 再構築は Paint の直前に1回だけ走る
end;

procedure TDelaunayViewer.LayersChange( Sender_:TObject );
begin
     upDelaunay := True;  Repaint;  // レイヤのスタイル変更もシーンの作り直しで反映する
end;

//------------------------------------------------------------------------------

procedure TDelaunayViewer.BuildScene;
begin
     _Layers.BeginUpdate;  // ノード単位の発火を止め、最後に1回だけ発火させる
     try
          _Poins.BuildScene( _Delaunay );
          _Trias.BuildScene( _Delaunay );
          _Circs.BuildScene( _Delaunay );
          _Volos.BuildScene( _Delaunay );
     finally
          _Layers.EndUpdate;
     end;
end;

//------------------------------------------------------------------------------

procedure TDelaunayViewer.Paint;
var
   Canvas_ :ISkCanvas;
   S :Single;
begin
     if upDelaunay then
     begin
          BuildScene;  // 溜まった変更をここで一括反映する

          upDelaunay := False;  // 再構築の終わりに発火する通知は自分の仕業なので、予約を下ろす
     end;

     if not ( Canvas is TSkCanvasCustom ) then Exit;  // 要 GlobalUseSkia = True

     Canvas_ := TSkCanvasCustom( Canvas ).Canvas;

     Canvas_.Save;
     try
          Canvas_.ClipRect( TRectF.Create( 0, 0, Width, Height ) );

          Canvas_.Translate( Width / 2, Height / 2 );  // 視野の中心 → 画面中央

          S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );  // 視野がぴったり収まる等方スケール

          Canvas_.Scale( S, S );

          _Camera.Render( Canvas_ );  // カメラ座標系への変換とシーンの描画
     finally
          Canvas_.Restore;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayViewer.Create( Owner_:TComponent );
begin
     inherited;

     _Layers := TCGLayers.Create;

     _Trias := TDelaunayTrias.Create( _Layers );  // 生成順＝描画順（下から: 三角形 → 外接円 → ボロノイ → 頂点）
     _Circs := TDelaunayCircs.Create( _Layers );
     _Volos := TDelaunayVolos.Create( _Layers );
     _Poins := TDelaunayPoins.Create( _Layers );

     _Camera := TCGCamera.Create( TCGLayer.Create( _Layers ) );  // カメラ専用レイヤに載せる（BuildScene の Clear で消えないように）

     _Camera.SizeX := 400;
     _Camera.SizeY := 400;

     _Layers.OnChange.Add( LayersChange );  // レイヤの変更はルートがまとめて出力する
end;

destructor TDelaunayViewer.Destroy;
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );  // モデルはビューアより長生きするので購読を外す

     _Layers.Free;  // 破棄中のシーンは通知を発しない

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunayViewer.ScrToPos( const S_:TPointF ) :TSingle2D;
var
   S :Single;
begin
     S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );

     Result := _Camera.GlobalPose.MultPos( ( S_ - TPointF.Create( Width  / 2,
                                                                  Height / 2 ) ) / S );
end;

function TDelaunayViewer.PosToScr( const P_:TSingle2D ) :TPointF;
var
   S :Single;
begin
     S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );

     Result := TPointF( _Camera.GlobalPose.Inverse.MultPos( P_ ) * S ) + TPointF.Create( Width  / 2,
                                                                                         Height / 2 );
end;

end. //######################################################################### ■
