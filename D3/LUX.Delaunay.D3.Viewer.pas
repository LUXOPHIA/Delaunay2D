unit LUX.Delaunay.D3.Viewer;

// TDelaunay3D のビューア
//
// ・TDelaunay3D を受けて FMX の 3D シーン（TViewport3D）を構築し、レンダリングする。
//   FMX のシーン生成コードはすべてこのフレームの中に閉じており、アプリケーション側
//   （Main）には現れない。
// ・シーンは4枚のレイヤからなる（TControl3D 派生。Render で頂点バッファを直接描画）。
//     TDelaunayPoins … 頂点　　　（球: 緯度4分割 × 経度8分割・Radius）
//     TDelaunayEdges … ドロネー辺（円柱: 円周8分割・Radius。辺の周りの環の代表胞だけが描いて重複を消す）
//     TDelaunayCells … 四面体　　（重心座標で頂点を補間した Shrink 倍の四面体を胞の中に浮かべる）
//     TDelaunayVoros … ボロノイ辺（線分。無限遠胞へは外向きの半直線）
//   各レイヤは BuildScene( Delaunay_ ) で自分のメッシュを構築する。色や寸法は
//   Viewer1.Cells.Color / Shrink のように、レイヤのプロパティで変更する。
//   球と円柱は放射方向の頂点法線（滑らか）、四面体は面法線（フラット）を明示的に張る。
// ・シーンの再構築は「全廃棄・全構築」とし、描画の直前まで遅延して1フレームに
//   1回だけ行う（内部の TViewport3D の Paint の先頭で溜まった変更を反映する）。
// ・強制的に軌道リグ（Yaw → Pitch → TCamera）とヘッドライトを生成して保持する
//   （Camera プロパティ）。マウス操作などは載せない。アプリケーション側で
//   OnMouseDown 等を処理し、Orbit / Dolly / FindPoin を使って行う。

interface //#################################################################### ■

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Math.Vectors, System.RTLConsts,
  FMX.Types, FMX.Types3D, FMX.Controls, FMX.Controls3D, FMX.Forms, FMX.Graphics,
  FMX.Viewport3D, FMX.Objects3D, FMX.MaterialSources,
  LUX, LUX.D3, LUX.D4,
  LUX.Data.Model.TetraFlip.core,
  LUX.Delaunay.D3;

type
  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayLayer

  // レイヤの基底。メッシュデータの器と、三角形・線分の構築と描画。
  TDelaunayLayer = class( TControl3D )
  private
  protected
    _Geometry :TMeshData;
    ///// M E T H O D
    procedure MakeMesh( const Ps_,Ns_:array of TSingle3D );  // 3点ずつ三角形にする（法線つき）
    procedure MakeLines( const Ps_:array of TSingle3D );     // 2点ずつ線分にする
    procedure DrawTrias( const Material_:TMaterialSource );
    procedure DrawLines( const Material_:TMaterialSource );
  public
    constructor Create( Owner_:TComponent ); override;
    destructor Destroy; override;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); virtual; abstract;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayFillLayer

  // 面のレイヤ（陰影あり）。
  TDelaunayFillLayer = class( TDelaunayLayer )
  private
  protected
    _Material :TLightMaterialSource;
    ///// A C C E S S O R
    function GetColor :TAlphaColor;
    procedure SetColor( const Color_:TAlphaColor );
    ///// M E T H O D
    procedure Render; override;
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Color :TAlphaColor read GetColor write SetColor;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayLineLayer

  // 線のレイヤ（単色）。
  TDelaunayLineLayer = class( TDelaunayLayer )
  private
  protected
    _Material :TColorMaterialSource;
    ///// A C C E S S O R
    function GetColor :TAlphaColor;
    procedure SetColor( const Color_:TAlphaColor );
    ///// M E T H O D
    procedure Render; override;
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Color :TAlphaColor read GetColor write SetColor;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayPoins

  // 頂点レイヤ（球）
  TDelaunayPoins = class( TDelaunayFillLayer )
  private
    _Radius :Single;
    ///// A C C E S S O R
    procedure SetRadius( const Radius_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Radius :Single read _Radius write SetRadius;  // 点の半径
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); override;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayEdges

  // ドロネー辺レイヤ（円柱）
  TDelaunayEdges = class( TDelaunayFillLayer )
  private
    _Radius :Single;
    ///// A C C E S S O R
    procedure SetRadius( const Radius_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Radius :Single read _Radius write SetRadius;  // 辺の半径
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); override;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayCells

  // 四面体レイヤ（重心座標で補間した縮小四面体）
  TDelaunayCells = class( TDelaunayFillLayer )
  private
    _Shrink :Single;
    ///// A C C E S S O R
    procedure SetShrink( const Shrink_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Shrink :Single read _Shrink write SetShrink;  // 重心への縮小率（1 = 原寸、既定 = 1/2）
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); override;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVoros

  // ボロノイ辺レイヤ
  TDelaunayVoros = class( TDelaunayLineLayer )
  private
    _RayLength :Single;
    ///// A C C E S S O R
    procedure SetRayLength( const RayLength_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property RayLength :Single read _RayLength write SetRayLength;  // 無限遠胞へ伸びる半直線の長さ
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); override;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewport

  // 内部のビューポート。描画の直前に溜まった変更を反映するためだけの差し替え。
  TDelaunayViewport = class( TViewport3D )
  private
    _OnPaint :TNotifyEvent;
  protected
    ///// M E T H O D
    procedure Paint; override;
  public
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewer

  TDelaunayViewer = class(TFrame)
  private
  protected
    _Delaunay :TDelaunay3D;    upDelaunay :Boolean;  // シーンの再構築の予約（描画の直前に1回だけ実行）
    _Viewport :TDelaunayViewport;
    _Yaw      :TDummy;
    _Pitch    :TDummy;
    _Camera   :TCamera;
    _Light    :TLight;
    _Poins    :TDelaunayPoins;
    _Cells    :TDelaunayCells;
    _Edges    :TDelaunayEdges;
    _Voros    :TDelaunayVoros;
    ///// A C C E S S O R
    procedure SetDelaunay( const Delaunay_:TDelaunay3D );
    function GetColor :TAlphaColor;
    procedure SetColor( const Color_:TAlphaColor );
    function GetDistance :Single;
    procedure SetDistance( const Distance_:Single );
    ///// M E T H O D
    procedure DelaunayChange( Sender_:TObject );
    procedure ViewportPaint( Sender_:TObject );
    procedure BuildScene;
  public
    constructor Create( Owner_:TComponent ); override;
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Delaunay :TDelaunay3D read _Delaunay write SetDelaunay;
    property Camera   :TCamera     read _Camera                    ;  // 視点（強制生成。軌道リグの先端）
    property Color    :TAlphaColor read GetColor    write SetColor   ;  // 背景色
    property Distance :Single      read GetDistance write SetDistance;  // 注視点（原点）からの距離
    ///// P R O P E R T Y （レイヤ）
    property Poins :TDelaunayPoins read _Poins;  // 頂点　　（Viewer1.Poins.Radius など）
    property Cells :TDelaunayCells read _Cells;  // 四面体
    property Edges :TDelaunayEdges read _Edges;  // ドロネー辺
    property Voros :TDelaunayVoros read _Voros;  // ボロノイ辺
    ///// M E T H O D
    procedure Orbit( const DYaw_,DPitch_:Single );  // 軌道リグを回す（度）
    procedure Dolly( const DDistance_:Single );     // 距離を変える
    function FindPoin( const Scr_:TPointF; const Radius_:Single ) :TDelaPoin3D;  // スクリーン座標の近傍点（Radius_ px 内に無ければ nil）
  end;

implementation //############################################################### ■

{$R *.fmx}

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% AddSphere / AddTube

// 球（緯度 4 分割 × 経度 8 分割）を張る。法線は放射方向（滑らか）
procedure AddSphere( var Ps_,Ns_:TArray<TSingle3D>; const Center_:TSingle3D; const Radius_:Single );
const
     LatN = 4;
     LonN = 8;
//･･･････････････････････････････････････････
     function Dir( const I_,J_:Integer ) :TSingle3D;  // 緯度 I_ ・経度 J_ の単位方向
     var
        T, P :Single;
     begin
          T := Pi  * ( I_ / LatN - 0.5 );
          P := Pi2 * ( J_ / LonN       );

          Result := TSingle3D.Create( Cos( T ) * Cos( P ), Sin( T ), Cos( T ) * Sin( P ) );
     end;
//･･･････････････････････････････････････････
var
   I, J :Integer;
   D00, D01, D10, D11 :TSingle3D;
begin
     for I := 0 to LatN-1 do
     begin
          for J := 0 to LonN-1 do
          begin
               D00 := Dir( I  , J   );
               D01 := Dir( I  , J+1 );
               D10 := Dir( I+1, J   );
               D11 := Dir( I+1, J+1 );

               if I > 0 then  // 南極の帯は下辺が1点に潰れる
               begin
                    Ps_ := Ps_ + [ Center_ + Radius_ * D00, Center_ + Radius_ * D11, Center_ + Radius_ * D01 ];
                    Ns_ := Ns_ + [ D00, D11, D01 ];
               end;

               if I < LatN-1 then  // 北極の帯は上辺が1点に潰れる
               begin
                    Ps_ := Ps_ + [ Center_ + Radius_ * D00, Center_ + Radius_ * D10, Center_ + Radius_ * D11 ];
                    Ns_ := Ns_ + [ D00, D10, D11 ];
               end;
          end;
     end;
end;

// 円柱（円周 8 分割）を張る。法線は放射方向（軸の周りに滑らか）
procedure AddTube( var Ps_,Ns_:TArray<TSingle3D>; const A_,B_:TSingle3D; const Radius_:Single );
const
     SegN = 8;
var
   X, U, V, N0, N1 :TSingle3D;
   P00, P01, P10, P11 :TSingle3D;
   T0, T1 :Single;
   J :Integer;
begin
     X := ( B_ - A_ );

     if X.Size2 = 0 then Exit;

     X := X.Unitor;

     if Abs( X.Z ) < 0.9 then U := CrossProduct( X, TSingle3D.IdentityZ ).Unitor   // 軸と平行でない補助軸から基底を作る
                         else U := CrossProduct( X, TSingle3D.IdentityY ).Unitor;

     V := CrossProduct( X, U );

     for J := 0 to SegN-1 do
     begin
          T0 := Pi2 *   J       / SegN;
          T1 := Pi2 * ( J + 1 ) / SegN;

          N0 := Cos( T0 ) * U + Sin( T0 ) * V;
          N1 := Cos( T1 ) * U + Sin( T1 ) * V;

          P00 := A_ + Radius_ * N0;   P10 := B_ + Radius_ * N0;
          P01 := A_ + Radius_ * N1;   P11 := B_ + Radius_ * N1;

          Ps_ := Ps_ + [ P00, P10, P11,  P00, P11, P01 ];
          Ns_ := Ns_ + [ N0 , N0 , N1 ,  N0 , N1 , N1  ];
     end;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayLayer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayLayer.MakeMesh( const Ps_,Ns_:array of TSingle3D );
var
   N, I :Integer;
begin
     N := Length( Ps_ );

     with _Geometry do
     begin
          with VertexBuffer do
          begin
               Length := N;

               for I := 0 to N-1 do
               begin
                    Vertices[ I ] := Ps_[ I ];
                    Normals [ I ] := Ns_[ I ];
               end;
          end;

          with IndexBuffer do
          begin
               Length := N;

               for I := 0 to N-1 do Indices[ I ] := I;
          end;
     end;

     Repaint;
end;

procedure TDelaunayLayer.MakeLines( const Ps_:array of TSingle3D );
var
   N, I :Integer;
begin
     N := Length( Ps_ );

     with _Geometry do
     begin
          with VertexBuffer do
          begin
               Length := N;

               for I := 0 to N-1 do Vertices[ I ] := Ps_[ I ];
          end;

          with IndexBuffer do
          begin
               Length := N;

               for I := 0 to N-1 do Indices[ I ] := I;
          end;
     end;

     Repaint;
end;

//------------------------------------------------------------------------------

procedure TDelaunayLayer.DrawTrias( const Material_:TMaterialSource );
begin
     if _Geometry.IndexBuffer.Length = 0 then Exit;

     Context.SetMatrix( AbsoluteMatrix );

     Context.SetContextState( TContextState.csAllFace );  // 巻き方向に依らず表面が描かれるように（形は閉じているので裏面は隠れる）

     _Geometry.Render( Context, TMaterialSource.ValidMaterial( Material_ ), AbsoluteOpacity );
end;

procedure TDelaunayLayer.DrawLines( const Material_:TMaterialSource );
begin
     if _Geometry.IndexBuffer.Length = 0 then Exit;

     Context.SetMatrix( AbsoluteMatrix );

     Context.DrawLines( _Geometry.VertexBuffer, _Geometry.IndexBuffer, TMaterialSource.ValidMaterial( Material_ ), AbsoluteOpacity );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayLayer.Create( Owner_:TComponent );
begin
     inherited;

     HitTest := False;

     _Geometry := TMeshData.Create;
end;

destructor TDelaunayLayer.Destroy;
begin
     _Geometry.Free;

     inherited;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayFillLayer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaunayFillLayer.GetColor :TAlphaColor;
begin
     Result := _Material.Diffuse;
end;

procedure TDelaunayFillLayer.SetColor( const Color_:TAlphaColor );
begin
     _Material.Diffuse := Color_;  Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayFillLayer.Render;
begin
     DrawTrias( _Material );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayFillLayer.Create( Owner_:TComponent );
begin
     inherited;

     _Material := TLightMaterialSource.Create( Self );

     _Material.Ambient   := TAlphaColor( $FF606060 );
     _Material.Specular  := TAlphaColor( $FF303030 );
     _Material.Shininess := 30;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayLineLayer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaunayLineLayer.GetColor :TAlphaColor;
begin
     Result := _Material.Color;
end;

procedure TDelaunayLineLayer.SetColor( const Color_:TAlphaColor );
begin
     _Material.Color := Color_;  Repaint;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayLineLayer.Render;
begin
     DrawLines( _Material );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayLineLayer.Create( Owner_:TComponent );
begin
     inherited;

     _Material := TColorMaterialSource.Create( Self );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayPoins

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayPoins.SetRadius( const Radius_:Single );
begin
     _Radius := Radius_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayPoins.Create( Owner_:TComponent );
begin
     inherited;

     _Radius := 0.08;

     Color := TAlphaColors.Red;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayPoins.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps, Ns :TArray<TSingle3D>;
   P :TDelaPoin3D;
begin
     Ps := [];
     Ns := [];

     if Assigned( Delaunay_ ) then
     begin
          for P in Delaunay_.Poins do AddSphere( Ps, Ns, P.Pos, _Radius );
     end;

     MakeMesh( Ps, Ns );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayEdges

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayEdges.SetRadius( const Radius_:Single );
begin
     _Radius := Radius_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayEdges.Create( Owner_:TComponent );
begin
     inherited;

     _Radius := 0.02;

     Color := TAlphaColor( $FF505050 );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayEdges.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps, Ns :TArray<TSingle3D>;
   C :TDelaCell3D;
   I, K :Byte;
   PA, PB :TDelaPoin3D;
//･･･････････････････････････････････････････
     function Owned( const C_:TDelaCell3D; const PA_,PB_:TDelaPoin3D ) :Boolean;  // 辺の周りの環で自分が代表（最小番地の胞）か
     var
        Cur, Prev, Nxt :TDelaCell3D;
        K :Byte;
        N :Integer;
     begin
          Result := True;

          Prev := nil;
          Cur  := C_;

          for N := 1 to 64 do  // 辺を含む面を渡って環を一周する
          begin
               Nxt := C_;

               for K := 0 to 3 do
               begin
                    if ( Cur.Poin[ K ] = PA_ ) or ( Cur.Poin[ K ] = PB_ ) then Continue;  // 辺を含む面は、辺以外の頂点の対面

                    Nxt := Cur.Cell[ K ];

                    if Nxt <> Prev then Break;
               end;

               if Nxt = C_ then Exit;  // 一周した

               if NativeUInt( Nxt ) < NativeUInt( C_ ) then Exit( False );  // 自分より若い胞が居る

               Prev := Cur;
               Cur  := Nxt;
          end;
     end;
//･･･････････････････････････････････････････
begin
     Ps := [];
     Ns := [];

     if Assigned( Delaunay_ ) then
     begin
          for C in Delaunay_.Cells do
          begin
               for I := 0 to 2 do
               begin
                    for K := I+1 to 3 do
                    begin
                         PA := C.Poin[ I ];
                         PB := C.Poin[ K ];

                         if PA.Inf or PB.Inf then Continue;

                         if Owned( C, PA, PB ) then AddTube( Ps, Ns, PA.Pos, PB.Pos, _Radius );
                    end;
               end;
          end;
     end;

     MakeMesh( Ps, Ns );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayCells

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayCells.SetShrink( const Shrink_:Single );
begin
     _Shrink := Shrink_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayCells.Create( Owner_:TComponent );
begin
     inherited;

     _Shrink := 0.5;

     Color := TAlphaColors.Cornflowerblue;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayCells.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps, Ns :TArray<TSingle3D>;
   C :TDelaCell3D;
   G :TSingle3D;
   Vs :array [ 0..3 ] of TSingle3D;
   F1, F2, F3, N :TSingle3D;
   I, K :Byte;
begin
     Ps := [];
     Ns := [];

     if Assigned( Delaunay_ ) then
     begin
          for C in Delaunay_.Cells do
          begin
               if C.InfCorn >= 0 then Continue;  // 有限胞のみ

               G := Ave( C.Poin[ 0 ].Pos, C.Poin[ 1 ].Pos, C.Poin[ 2 ].Pos, C.Poin[ 3 ].Pos );

               for I := 0 to 3 do  // 重心座標で補間した Shrink 倍の四面体を胞の中に浮かべる
               begin
                    Vs[ I ] := G + _Shrink * ( C.Poin[ I ].Pos - G );
               end;

               for K := 0 to 3 do  // 面の正準順は外向き。法線はフラット
               begin
                    with VertTable[ K ] do
                    begin
                         F1 := Vs[ _[ 1 ] ];
                         F2 := Vs[ _[ 2 ] ];
                         F3 := Vs[ _[ 3 ] ];
                    end;

                    N := CrossProduct( F2 - F1, F3 - F1 ).Unitor;

                    Ps := Ps + [ F1, F2, F3 ];
                    Ns := Ns + [ N , N , N  ];
               end;
          end;
     end;

     MakeMesh( Ps, Ns );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVoros

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayVoros.SetRayLength( const RayLength_:Single );
begin
     _RayLength := RayLength_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayVoros.Create( Owner_:TComponent );
begin
     inherited;

     _RayLength := 2;

     Color := TAlphaColors.Black;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayVoros.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps :TArray<TSingle3D>;
   C, N :TDelaCell3D;
   K :Byte;
   V :TSingle4D;
   P0, P1 :TSingle3D;
begin
     Ps := [];

     if Assigned( Delaunay_ ) then
     begin
          for C in Delaunay_.Cells do
          begin
               if C.InfCorn < 0 then  // 有限胞のみ（ボロノイ頂点 = 外心）
               begin
                    V := C.Circum;

                    P0 := TSingle3D.Create( V.X, V.Y, V.Z ) / V.W;

                    for K := 0 to 3 do
                    begin
                         N := C.Cell[ K ];

                         V := N.Circum;

                         if N.InfCorn < 0 then P1 := ( P0 + TSingle3D.Create( V.X, V.Y, V.Z ) / V.W ) / 2  // 有限胞 → 中点まで（両側から描いて1本になる）
                                          else P1 := P0 + _RayLength * TSingle3D.Create( V.X, V.Y, V.Z ).Unitor;  // 無限遠胞 → 外向きの半直線

                         Ps := Ps + [ P0, P1 ];
                    end;
               end;
          end;
     end;

     MakeLines( Ps );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewport

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayViewport.Paint;
begin
     if Assigned( _OnPaint ) then _OnPaint( Self );  // 溜まった変更をここで一括反映する

     inherited;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayViewer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayViewer.SetDelaunay( const Delaunay_:TDelaunay3D );
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );

     _Delaunay := Delaunay_;

     if Assigned( _Delaunay ) then _Delaunay.OnChange.Add( DelaunayChange );

     upDelaunay := True;  _Viewport.Repaint;
end;

//------------------------------------------------------------------------------

function TDelaunayViewer.GetColor :TAlphaColor;
begin
     Result := _Viewport.Color;
end;

procedure TDelaunayViewer.SetColor( const Color_:TAlphaColor );
begin
     _Viewport.Color := Color_;
end;

function TDelaunayViewer.GetDistance :Single;
begin
     Result := - _Camera.Position.Z;
end;

procedure TDelaunayViewer.SetDistance( const Distance_:Single );
begin
     _Camera.Position.Z := - Distance_;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayViewer.DelaunayChange( Sender_:TObject );
begin
     upDelaunay := True;  _Viewport.Repaint;  // 再構築は描画の直前に1回だけ走る
end;

procedure TDelaunayViewer.ViewportPaint( Sender_:TObject );
begin
     if upDelaunay then
     begin
          BuildScene;

          upDelaunay := False;
     end;
end;

//------------------------------------------------------------------------------

procedure TDelaunayViewer.BuildScene;
begin
     _Poins.BuildScene( _Delaunay );
     _Cells.BuildScene( _Delaunay );
     _Edges.BuildScene( _Delaunay );
     _Voros.BuildScene( _Delaunay );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayViewer.Create( Owner_:TComponent );
begin
     inherited;

     _Viewport := TDelaunayViewport.Create( Self );

     with _Viewport do
     begin
          Parent            := Self;
          Align             := TAlignLayout.Client;
          Color             := TAlphaColor( $FFF5F5F5 );
          HitTest           := False;  // マウスはフレーム（自分）が受ける
          UsingDesignCamera := False;

          _OnPaint := ViewportPaint;
     end;

     _Yaw := TDummy.Create( Self );  _Yaw.Parent := _Viewport;  // 軌道リグ（Yaw → Pitch → Camera）

     _Pitch := TDummy.Create( Self );  _Pitch.Parent := _Yaw;

     _Pitch.RotationAngle.X := -20;

     _Camera := TCamera.Create( Self );

     with _Camera do
     begin
          Parent      := _Pitch;
          AngleOfView := 45;

          Position.Z  := -15;
     end;

     _Viewport.Camera := _Camera;

     _Light := TLight.Create( Self );  // ヘッドライト（カメラと一緒に回り、少し上から照らす）

     with _Light do
     begin
          Parent    := _Pitch;
          LightType := TLightType.Directional;

          RotationAngle.X := -30;
          RotationAngle.Y := +20;
     end;

     _Cells := TDelaunayCells.Create( Self );  _Cells.Parent := _Viewport;  // 生成順は任意（3D は深度で解決される）
     _Voros := TDelaunayVoros.Create( Self );  _Voros.Parent := _Viewport;
     _Edges := TDelaunayEdges.Create( Self );  _Edges.Parent := _Viewport;
     _Poins := TDelaunayPoins.Create( Self );  _Poins.Parent := _Viewport;
end;

destructor TDelaunayViewer.Destroy;
begin
     if Assigned( _Delaunay ) then _Delaunay.OnChange.Del( DelaunayChange );  // モデルはビューアより長生きするので購読を外す

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayViewer.Orbit( const DYaw_,DPitch_:Single );
begin
     with _Yaw  .RotationAngle do Y := Y + DYaw_;
     with _Pitch.RotationAngle do X := EnsureRange( X + DPitch_, -88, +88 );
end;

procedure TDelaunayViewer.Dolly( const DDistance_:Single );
begin
     Distance := EnsureRange( Distance + DDistance_, 2, 100 );
end;

//------------------------------------------------------------------------------

function TDelaunayViewer.FindPoin( const Scr_:TPointF; const Radius_:Single ) :TDelaPoin3D;
var
   P :TDelaPoin3D;
   S :TPoint3D;
   C :Single;
   D, Dm :Single;
begin
     Result := nil;

     if not Assigned( _Delaunay ) or not Assigned( _Viewport.Context ) then Exit;

     C := _Viewport.Context.Scale;  // 投影は物理ピクセルで返るので、論理座標（マウス）に合わせる

     Dm := Pow2( Radius_ );

     for P in _Delaunay.Poins do  // スクリーンへ投影して最も近い点を選ぶ
     begin
          S := _Viewport.Context.WorldToScreen( TProjection.Camera, TPoint3D( P.Pos ) );

          if S.Z <= 0 then Continue;  // カメラの背後

          D := Pow2( S.X / C - Scr_.X ) + Pow2( S.Y / C - Scr_.Y );

          if D < Dm then begin  Dm := D;  Result := P;  end;
     end;
end;

end. //######################################################################### ■
