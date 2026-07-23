unit LUX.Delaunay.D2.Periodic.Viewer;

// TPeriDelaunay2D のビューア
//
// ・TPeriDelaunay2D を受けて LUX.CG2D のシーングラフを構築し、レンダリングする。
//   自前の描画処理は持たない（LUX.Delaunay.D2.Viewer と同じ流儀）。
// ・基本領域 [0,L)² を原点中心（[-L/2,+L/2)²）に置き、トーラスの面を固定の 3×3
//   タイルで貼り並べる。カメラの視野は 2L×2L の正方形。ウインドウのアスペクト比に
//   よって 3×3 の外が見えることは許容する。
// ・レイヤ（描画は下から上へ。上ほど手前）:
//     TriasFade … ドロネー三角形のコピー8枚（水色50%）
//     Trias     … ドロネー三角形の中央の実体（水色・フチ白）
//     Circs     … 空円（緑）。基本領域の実体の空円だけを描く（周囲8タイルのコピー円は描かない）
//     Grids     … 周期境界の直線（ピンク・太さ1。3×3 のマス = 縦4本・横4本）
//     Volos     … ボロノイ辺（黒）
//     PoinsFade … 頂点のコピー8個（赤50%）
//     Poins     … 頂点の中央の実体（赤・フチ白）
//   淡色は「実体レイヤの現在のスタイルからアルファ50%を作り、専用のコピーレイヤの
//   スタイルへ毎フレーム写す」方式（レイヤ単位のスタイル継承だけで完結する。中間
//   ノードにスタイルを持たせる方式は、このシーングラフでは子へ伝播しないため使わない）。
// ・色や線の太さは Viewer1.Poins.Style.FillColor のように、実体レイヤのスタイルで
//   変更する。コピーレイヤの淡色は次の再構築でそこから導出される。
// ・シーンの再構築は Paint の直前まで遅延して1フレームに1回だけ行う。
// ・マウス操作などは載せない。アプリケーション側で OnMouseDown 等を処理し、
//   座標変換 ScrToPos / PosToScr / ScrToTorus を使って行う。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Skia, FMX.Skia.Canvas,
  LUX, LUX.D2, LUX.D3, LUX.D3x3,
  LUX.CG2D,
  LUX.CG2D.Shapers,
  LUX.Delaunay.D2.Periodic;

type
  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayPoins

  // 頂点レイヤ（実体レイヤは中央のみ、コピーレイヤは 8 個を描く）
  TPeriDelaunayPoins = class( TCGLayer )
  private
    _Radius :Single;
    _Copies :Boolean;  // True = 周囲8コピー, False = 中央の実体
    ///// A C C E S S O R
    procedure SetRadius( const Radius_:Single );
  protected
  public
    constructor Create; overload; override;
    ///// P R O P E R T Y
    property Radius :Single read _Radius write SetRadius;  // 点の半径
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TPeriDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayTrias

  // ドロネー三角形レイヤ（実体レイヤは中央のみ、コピーレイヤは 8 枚を描く）
  TPeriDelaunayTrias = class( TCGLayer )
  private
    _Copies :Boolean;
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TPeriDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayCircs

  // 空円レイヤ（基本領域の実体の空円だけを描く。周囲8タイルのコピー円は描かない）
  TPeriDelaunayCircs = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TPeriDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayVolos

  // ボロノイレイヤ
  TPeriDelaunayVolos = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TPeriDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayGrids

  // 周期境界直線レイヤ（3×3 のマスの境界 = 縦4本・横4本）
  TPeriDelaunayGrids = class( TCGLayer )
  private
  protected
  public
    constructor Create; overload; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TPeriDelaunay2D );
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayViewer

  TPeriDelaunayViewer = class(TFrame)
  private
  protected
    _Delaunay  :TPeriDelaunay2D;    upDelaunay :Boolean;  // シーンの再構築の予約（Paint の直前に1回だけ実行）
    _Layers    :TCGLayers;
    _Camera    :TCGCamera;
    _Poins     :TPeriDelaunayPoins;    _PoinsF :TPeriDelaunayPoins;  // 実体 / コピー（Fade）
    _Trias     :TPeriDelaunayTrias;    _TriasF :TPeriDelaunayTrias;
    _Circs     :TPeriDelaunayCircs;                                  // 空円は基本領域の実体のみ（コピーは描かない）
    _Volos     :TPeriDelaunayVolos;
    _Grids     :TPeriDelaunayGrids;
    ///// A C C E S S O R
    procedure SetDelaunay( const Delaunay_:TPeriDelaunay2D );
    ///// M E T H O D
    procedure DelaunayChange( Sender_:TObject );
    procedure LayersChange( Sender_:TObject );
    procedure SyncFade;
    procedure BuildScene;
    procedure Paint; override;
  public
    constructor Create( Owner_:TComponent ); override;
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Delaunay :TPeriDelaunay2D read _Delaunay write SetDelaunay;
    property Layers   :TCGLayers       read _Layers                    ;  // 構築されたシーン
    property Camera   :TCGCamera       read _Camera                    ;  // 視点（強制生成。視野はアプリ側で 2L×2L に設定する）
    ///// P R O P E R T Y （レイヤ。スタイルはここで変更する。コピーの淡色は自動で導出される）
    property Poins :TPeriDelaunayPoins read _Poins;  // 頂点　　　（Viewer1.Poins.Radius など）
    property Trias :TPeriDelaunayTrias read _Trias;  // ドロネー三角形
    property Circs :TPeriDelaunayCircs read _Circs;  // 空円
    property Volos :TPeriDelaunayVolos read _Volos;  // ボロノイ辺
    property Grids :TPeriDelaunayGrids read _Grids;  // 周期境界直線
    ///// M E T H O D
    function ScrToPos( const S_:TPointF ) :TSingle2D;    // 画面座標 → ワールド座標（基本領域の中心が原点）
    function PosToScr( const P_:TSingle2D ) :TPointF;
    function ScrToTorus( const S_:TPointF ) :TSingle2D;  // 画面座標 → トーラスの正準座標（∈ [0,L)²）
  end;

implementation //############################################################### ■

{$R *.fmx}

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

function TileBase( const Delaunay_:TPeriDelaunay2D; const Face_:TPeriFace2D ) :TSingle2D;
begin
     // 面のアンカー（角1）を基本領域へ巻き戻し、原点中心に置く平行移動（格子上なので厳密）
     with Face_.CornPos( 1 ) do Result := Delaunay_.WrapPos( TSingle2D.Create( X, Y ) ) - TSingle2D.Create( X, Y )
                                        - TSingle2D.Create( Delaunay_.Size / 2, Delaunay_.Size / 2 );
end;

function FadeColor( const Color_:TAlphaColor ) :TAlphaColor;
begin
     Result := Color_;

     TAlphaColorRec( Result ).A := TAlphaColorRec( Result ).A div 2;  // アルファ 50%
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayPoins

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TPeriDelaunayPoins.SetRadius( const Radius_:Single );
begin
     _Radius := Radius_;  Changed;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunayPoins.Create;
begin
     inherited;

     _Radius := 3;

     Style.FillColor := TAlphaColors.Red;    // 赤（フチ白）
     Style.LineColor := TAlphaColors.White;
     Style.LineThick := 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayPoins.BuildScene( const Delaunay_:TPeriDelaunay2D );
var
   I, TX, TY :Integer;
   L :Single;
   P :TSingle2D;
   D :TCGCirc;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     L := Delaunay_.Size;

     for I := 0 to Delaunay_.SitesN-1 do
     begin
          P := Delaunay_.Site[ I ] - TSingle2D.Create( L / 2, L / 2 );

          for TY := -1 to +1 do
          for TX := -1 to +1 do
          begin
               if ( ( TX = 0 ) and ( TY = 0 ) ) = _Copies then Continue;  // 実体レイヤは中央だけ、コピーレイヤは周囲8個だけ

               D := TCGCirc.Create( Self );
               D.Pos    := P + TSingle2D.Create( TX * L, TY * L );
               D.Radius := _Radius;
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayTrias

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunayTrias.Create;
begin
     inherited;

     Style.FillColor := TAlphaColors.Cornflowerblue;  // 水色（フチ白）
     Style.LineColor := TAlphaColors.White;
     Style.LineThick := 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayTrias.BuildScene( const Delaunay_:TPeriDelaunay2D );
var
   F :TPeriFace2D;
   B, P1, P2, P3, S :TSingle2D;
   L :Single;
   TX, TY :Integer;
   T :TCGTria;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     L := Delaunay_.Size;

     for F in Delaunay_.Faces do
     begin
          B := TileBase( Delaunay_, F );

          P1 := F.CornPos( 1 ) + B;
          P2 := F.CornPos( 2 ) + B;
          P3 := F.CornPos( 3 ) + B;

          for TY := -1 to +1 do
          for TX := -1 to +1 do
          begin
               if ( ( TX = 0 ) and ( TY = 0 ) ) = _Copies then Continue;

               S := TSingle2D.Create( TX * L, TY * L );

               T := TCGTria.Create( Self );
               T.Vert1 := P1 + S;
               T.Vert2 := P2 + S;
               T.Vert3 := P3 + S;
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayCircs

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunayCircs.Create;
begin
     inherited;

     Style.LineColor := TAlphaColors.Lime;  // 空円：緑
     Style.LineThick := 0.5;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayCircs.BuildScene( const Delaunay_:TPeriDelaunay2D );
var
   F :TPeriFace2D;
   C :TCGCirc;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     for F in Delaunay_.Faces do  // 基本領域の実体の空円だけ（周囲8タイルのコピー円は描かない）
     begin
          C := TCGCirc.Create( Self );
          C.Pos    := F.CircumPos + TileBase( Delaunay_, F );
          C.Radius := F.CircumRadius;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayVolos

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunayVolos.Create;
begin
     inherited;

     Style.LineColor := TAlphaColors.Black;  // ボロノイ辺：黒
     Style.LineThick := 0.5;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayVolos.BuildScene( const Delaunay_:TPeriDelaunay2D );
var
   F :TPeriFace2D;
   B, C, M, S :TSingle2D;
   L :Single;
   K :Byte;
   TX, TY :Integer;
   Ln :TCGLine;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     L := Delaunay_.Size;

     for F in Delaunay_.Faces do
     begin
          B := TileBase( Delaunay_, F );

          C := F.CircumPos + B;

          for K := 1 to 3 do
          begin
               M := ( C + F.Face[ K ].CircumPos + F.NeigShift( K ) + B ) / 2;  // 隣の外心を自面のリフトへ移してから中点をとる

               for TY := -1 to +1 do
               for TX := -1 to +1 do
               begin
                    S := TSingle2D.Create( TX * L, TY * L );

                    Ln := TCGLine.Create( Self );
                    Ln.Pos1 := C + S;
                    Ln.Pos2 := M + S;
               end;
          end;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayGrids

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunayGrids.Create;
begin
     inherited;

     Style.LineColor := TAlphaColors.Hotpink;  // 周期境界直線：ピンク
     Style.LineThick := 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayGrids.BuildScene( const Delaunay_:TPeriDelaunay2D );
var
   L, H :Single;
   I :Integer;
   Ln :TCGLine;
begin
     Clear;

     if not Assigned( Delaunay_ ) then Exit;

     L := Delaunay_.Size;
     H := 3 * L / 2;

     for I := 0 to 3 do  // 3×3 のマスの境界（縦4本・横4本。x, y = ±L/2, ±3L/2）
     begin
          Ln := TCGLine.Create( Self );
          Ln.Pos1 := TSingle2D.Create( I * L - H, -H );
          Ln.Pos2 := TSingle2D.Create( I * L - H, +H );

          Ln := TCGLine.Create( Self );
          Ln.Pos1 := TSingle2D.Create( -H, I * L - H );
          Ln.Pos2 := TSingle2D.Create( +H, I * L - H );
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunayViewer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TPeriDelaunayViewer.SetDelaunay( const Delaunay_:TPeriDelaunay2D );
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );

     _Delaunay := Delaunay_;

     if Assigned( _Delaunay ) then _Delaunay.OnChange.Add( DelaunayChange );

     upDelaunay := True;  Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunayViewer.DelaunayChange( Sender_:TObject );
begin
     upDelaunay := True;  Repaint;  // 再構築は Paint の直前に1回だけ走る
end;

procedure TPeriDelaunayViewer.LayersChange( Sender_:TObject );
begin
     upDelaunay := True;  Repaint;  // レイヤのスタイル変更もシーンの作り直しで反映する
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunayViewer.SyncFade;  // コピーレイヤの淡色を、実体レイヤの現在のスタイルから導出する
begin
     _PoinsF.Radius          := _Poins.Radius;
     _PoinsF.Style.FillColor := FadeColor( _Poins.Style.FillColor );
     _PoinsF.Style.LineColor := FadeColor( _Poins.Style.LineColor );
     _PoinsF.Style.LineThick :=            _Poins.Style.LineThick;

     _TriasF.Style.FillColor := FadeColor( _Trias.Style.FillColor );
     _TriasF.Style.LineColor := FadeColor( _Trias.Style.LineColor );
     _TriasF.Style.LineThick :=            _Trias.Style.LineThick;
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunayViewer.BuildScene;
begin
     _Layers.BeginUpdate;  // ノード単位の発火を止め、最後に1回だけ発火させる
     try
          SyncFade;

          _TriasF.BuildScene( _Delaunay );
          _Trias .BuildScene( _Delaunay );
          _Circs .BuildScene( _Delaunay );
          _Grids .BuildScene( _Delaunay );
          _Volos .BuildScene( _Delaunay );
          _PoinsF.BuildScene( _Delaunay );
          _Poins .BuildScene( _Delaunay );
     finally
          _Layers.EndUpdate;
     end;
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunayViewer.Paint;
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

constructor TPeriDelaunayViewer.Create( Owner_:TComponent );
begin
     inherited;

     _Layers := TCGLayers.Create;

     _TriasF := TPeriDelaunayTrias.Create( _Layers );  _TriasF._Copies := True;   // 生成順＝描画順（下から上へ）
     _Trias  := TPeriDelaunayTrias.Create( _Layers );  _Trias ._Copies := False;
     _Circs  := TPeriDelaunayCircs.Create( _Layers );                             // 空円は基本領域の実体のみ
     _Grids  := TPeriDelaunayGrids.Create( _Layers );
     _Volos  := TPeriDelaunayVolos.Create( _Layers );
     _PoinsF := TPeriDelaunayPoins.Create( _Layers );  _PoinsF._Copies := True;
     _Poins  := TPeriDelaunayPoins.Create( _Layers );  _Poins ._Copies := False;

     _Camera := TCGCamera.Create( TCGLayer.Create( _Layers ) );  // カメラ専用レイヤに載せる（BuildScene の Clear で消えないように）

     _Camera.SizeX := 400;
     _Camera.SizeY := 400;

     _Layers.OnChange.Add( LayersChange );  // レイヤの変更はルートがまとめて出力する
end;

destructor TPeriDelaunayViewer.Destroy;
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );  // モデルはビューアより長生きするので購読を外す

     _Layers.Free;  // 破棄中のシーンは通知を発しない

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TPeriDelaunayViewer.ScrToPos( const S_:TPointF ) :TSingle2D;
var
   S :Single;
begin
     S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );

     Result := _Camera.GlobalPose.MultPos( ( S_ - TPointF.Create( Width  / 2,
                                                                  Height / 2 ) ) / S );
end;

function TPeriDelaunayViewer.PosToScr( const P_:TSingle2D ) :TPointF;
var
   S :Single;
begin
     S := Min( Width / _Camera.SizeX, Height / _Camera.SizeY );

     Result := TPointF( _Camera.GlobalPose.Inverse.MultPos( P_ ) * S ) + TPointF.Create( Width  / 2,
                                                                                         Height / 2 );
end;

function TPeriDelaunayViewer.ScrToTorus( const S_:TPointF ) :TSingle2D;
var
   P :TSingle2D;
begin
     P := ScrToPos( S_ );

     if Assigned( _Delaunay )
     then Result := _Delaunay.WrapPos( P + TSingle2D.Create( _Delaunay.Size / 2, _Delaunay.Size / 2 ) )
     else Result := P;
end;

end. //######################################################################### ■
