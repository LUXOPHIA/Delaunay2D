unit LUX.Delaunay.D3.Viewer;

// TDelaunay3D のビューア
//
// ・TDelaunay3D を受けて FMX の 3D シーン（TViewport3D）を構築し、レンダリングする。
//   FMX のシーン生成コードはすべてこのフレームの中に閉じており、アプリケーション側
//   （Main）には現れない。
// ・シーンは2枚のレイヤからなる（TControl3D 派生。Render で頂点バッファを直接描画）。
//     TDelaunayEdges … ドロネー辺
//     TDelaunayVoros … ボロノイ辺
//   どちらも円柱のような「辺の芯」を張らない。四面体の面やボロノイ面の一部を、
//   辺から MarginCorner の幅だけ切り出した平面の帯・柱・錐だけで構成する
//   （旧 ・Delaunay3D2 のポリゴン化の洗練。曲面が無いのでフラットな面法線が
//   辺の稜線をそのまま見せ、図の構造だけが浮かび上がる）。
// ・ドロネー辺: 各有限胞の各頂点 K について、頂点を囲む3面のコーナー点
//   （MarginCorner = 角の二等分線上、両辺から距離 Margin の点）を結ぶ4枚の
//   三角形（中央の1枚＋辺沿いの3枚）を張る。辺のまわりでは環をなす胞の帯が
//   繋がって、辺を包む多角形の管が閉じる。凸包の面（無限遠胞に接する面）は
//   さらに外側の帯を張って管を閉じる。
// ・ボロノイ辺: 各有限胞の外心（＝ボロノイ頂点）のまわりに、そこから出る4本の
//   ボロノイ辺の方向の対ごとのコーナー三角形（4枚で外心を囲む殻）を張り、
//   有限の隣の外心へは三角柱の半分（3枚）を渡して両側から1本の柱を完成させる。
//   無限遠胞へは長さ RayLength の錐で閉じる。辺の方向は隣接胞の同次外心から
//   得られる（有限胞 → 外心まで、無限遠胞 → W = 0 に退化して外向きの方向）。
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

  // レイヤの基底。メッシュデータの器と材質、三角形の構築と描画。
  TDelaunayLayer = class( TControl3D )
  private
  protected
    _Geometry :TMeshData;
    _Material :TLightMaterialSource;
    ///// A C C E S S O R
    function GetColor :TAlphaColor;
    procedure SetColor( const Color_:TAlphaColor );
    ///// M E T H O D
    procedure MakeMesh( const Ps_,Ns_:array of TSingle3D );  // 3点ずつ三角形にする（法線つき）
    procedure Render; override;
  public
    constructor Create( Owner_:TComponent ); override;
    destructor Destroy; override;
    ///// P R O P E R T Y
    property Color :TAlphaColor read GetColor write SetColor;
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); virtual; abstract;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayEdges

  // ドロネー辺レイヤ（面の枠の張り合わせによる多角形の管）
  TDelaunayEdges = class( TDelaunayLayer )
  private
    _Margin :Single;
    ///// A C C E S S O R
    procedure SetMargin( const Margin_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Margin :Single read _Margin write SetMargin;  // 辺から枠までの幅
    ///// M E T H O D
    procedure BuildScene( const Delaunay_:TDelaunay3D ); override;
  end;

  //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVoros

  // ボロノイ辺レイヤ（コーナー殻と三角柱・錐）
  TDelaunayVoros = class( TDelaunayLayer )
  private
    _Margin    :Single;
    _RayLength :Single;
    ///// A C C E S S O R
    procedure SetMargin( const Margin_:Single );
    procedure SetRayLength( const RayLength_:Single );
  protected
  public
    constructor Create( Owner_:TComponent ); override;
    ///// P R O P E R T Y
    property Margin    :Single read _Margin    write SetMargin   ;  // 辺から柱の面までの幅
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
    property Edges :TDelaunayEdges read _Edges;  // ドロネー辺（Viewer1.Edges.Margin など）
    property Voros :TDelaunayVoros read _Voros;  // ボロノイ辺
    ///// M E T H O D
    procedure Orbit( const DYaw_,DPitch_:Single );  // 軌道リグを回す（度）
    procedure Dolly( const DDistance_:Single );     // 距離を変える
    function FindPoin( const Scr_:TPointF; const Radius_:Single ) :TDelaPoin3D;  // スクリーン座標の近傍点（Radius_ px 内に無ければ nil）
  end;

implementation //############################################################### ■

{$R *.fmx}

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% AddTria / MarginCorner

// 三角形を1枚足す（面法線フラット。潰れた三角形は捨てる）
procedure AddTria( var Ps_,Ns_:TArray<TSingle3D>; const P1_,P2_,P3_:TSingle3D );
var
   N :TSingle3D;
begin
     N := CrossProduct( P3_ - P1_, P2_ - P1_ );  // FMX は左手系なので、表（カリングで残る側）の法線は逆順の外積

     if N.Size2 = 0 then Exit;

     N := N.Unitor;

     Ps_ := Ps_ + [ P1_, P2_, P3_ ];
     Ns_ := Ns_ + [ N  , N  , N   ];
end;

// 原点から V1_・V2_ へ伸びる2辺の間に取るコーナー点。角の二等分線上にあり、
// どちらの辺からも距離 Margin_ に置かれる。三角形 ( 0, V1_, V2_ ) の内接円半径で
// クランプするので、鋭角や短い辺でも隣のコーナーと交差しない。
// 退化（零辺・平行）では角の点そのもの（零ベクトル）に落ちる。
function MarginCorner( const V1_,V2_:TSingle3D; Margin_:Single ) :TSingle3D; overload;
var
   L1, L2, S2, R :Single;
   E1, E2 :TSingle3D;
begin
     L1 := V1_.Size;
     L2 := V2_.Size;

     if ( L1 = 0 ) or ( L2 = 0 ) then Exit( TSingle3D.Create( 0, 0, 0 ) );

     E1 := V1_ / L1;
     E2 := V2_ / L2;

     S2 := 1 - Pow2( DotProduct( E1, E2 ) );

     if S2 <= 0 then Exit( TSingle3D.Create( 0, 0, 0 ) );

     R := CrossProduct( V1_, V2_ ).Size / ( L1 + L2 + Distance( V1_, V2_ ) );  // 内接円半径 = 2×面積 ÷ 周長

     if R < Margin_ then Margin_ := R;

     Result := ( Margin_ / Roo2( S2 ) ) * ( E1 + E2 );
end;

// 三角形 ( P0_, P1_, P2_ ) の頂点 P0_ のコーナー点。
function MarginCorner( const P0_,P1_,P2_:TSingle3D; const Margin_:Single ) :TSingle3D; overload;
begin
     Result := P0_ + MarginCorner( P1_ - P0_, P2_ - P0_, Margin_ );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CircumOf / VoroVector

// 胞の外心（同次外心の非同次化）。
function CircumOf( const Cell_:TDelaCell3D ) :TSingle3D;
var
   V :TSingle4D;
begin
     V := Cell_.Circum;

     Result := TSingle3D.Create( V.X, V.Y, V.Z ) / V.W;
end;

// 外心 Center_ から面 K_ を貫いて伸びるボロノイ辺のベクトル
// （有限の隣 → 隣の外心まで。無限遠胞 → 外向きに長さ Ray_ の半直線）。
function VoroVector( const Cell_:TDelaCell3D; const Center_:TSingle3D; const K_:Byte; const Ray_:Single ) :TSingle3D;
var
   N :TDelaCell3D;
   V :TSingle4D;
begin
     N := Cell_.Cell[ K_ ];

     V := N.Circum;

     if N.InfCorn < 0 then Result :=        TSingle3D.Create( V.X, V.Y, V.Z ) / V.W - Center_
                      else Result := Ray_ * TSingle3D.Create( V.X, V.Y, V.Z ).Unitor;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayLayer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaunayLayer.GetColor :TAlphaColor;
begin
     Result := _Material.Diffuse;
end;

procedure TDelaunayLayer.SetColor( const Color_:TAlphaColor );
begin
     _Material.Diffuse := Color_;  Repaint;
end;

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

procedure TDelaunayLayer.Render;
begin
     if _Geometry.IndexBuffer.Length = 0 then Exit;

     Context.SetMatrix( AbsoluteMatrix );

     Context.SetContextState( TContextState.csFrontFace );  // 裏面（光の当たらない面）はカリングで消す。巻き方向は正準順で外向きに揃えてある

     _Geometry.Render( Context, TMaterialSource.ValidMaterial( _Material ), AbsoluteOpacity );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayLayer.Create( Owner_:TComponent );
begin
     inherited;

     HitTest := False;

     _Geometry := TMeshData.Create;

     _Material := TLightMaterialSource.Create( Self );

     _Material.Ambient   := TAlphaColor( $FF202020 );
     _Material.Specular  := TAlphaColor( $FF303030 );
     _Material.Shininess := 30;
end;

destructor TDelaunayLayer.Destroy;
begin
     _Geometry.Free;

     inherited;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayEdges

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayEdges.SetMargin( const Margin_:Single );
begin
     _Margin := Margin_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayEdges.Create( Owner_:TComponent );
begin
     inherited;

     _Margin := 0.05;

     Color := TAlphaColor( $FFF35594 );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayEdges.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps, Ns :TArray<TSingle3D>;
   C :TDelaCell3D;
   K :Byte;
   P0, P1, P2, P3,
   C102, C203, C301,
   C021, C032, C013,
   C312, C123, C231 :TSingle3D;
begin
     Ps := [];
     Ns := [];

     if Assigned( Delaunay_ ) then
     begin
          for C in Delaunay_.Cells do
          begin
               if C.InfCorn >= 0 then Continue;  // 有限胞のみ

               for K := 0 to 3 do
               begin
                    with VertTable[ K ] do
                    begin
                         P0 := C.Poin[ _[ 0 ] ].Pos;  // 頂点 K
                         P1 := C.Poin[ _[ 1 ] ].Pos;  // 対面（外向きの正準順）
                         P2 := C.Poin[ _[ 2 ] ].Pos;
                         P3 := C.Poin[ _[ 3 ] ].Pos;
                    end;

                    // 頂点 K を囲む3面のコーナー点（Ciaj = 頂点 a の、辺 ai・aj の間のコーナー）
                    C102 := MarginCorner( P0, P1, P2, _Margin );
                    C203 := MarginCorner( P0, P2, P3, _Margin );
                    C301 := MarginCorner( P0, P3, P1, _Margin );

                    C021 := MarginCorner( P2, P0, P1, _Margin );
                    C032 := MarginCorner( P3, P0, P2, _Margin );
                    C013 := MarginCorner( P1, P0, P3, _Margin );

                    // 中央の1枚 ＋ 辺 02・03・01 沿いの3枚。対頂点側の反復と合わさって
                    // 辺を包む管、頂点を囲む殻が閉じる
                    AddTria( Ps, Ns, C102, C301, C203 );

                    AddTria( Ps, Ns, C021, C102, C203 );
                    AddTria( Ps, Ns, C032, C203, C301 );
                    AddTria( Ps, Ns, C013, C301, C102 );

                    if C.Cell[ K ].InfCorn >= 0 then  // 凸包の面は外側の帯で管を閉じる
                    begin
                         C312 := MarginCorner( P1, P3, P2, _Margin );
                         C123 := MarginCorner( P2, P1, P3, _Margin );
                         C231 := MarginCorner( P3, P2, P1, _Margin );

                         AddTria( Ps, Ns, P2, P1, C312 );  AddTria( Ps, Ns, C312, C123, P2 );
                         AddTria( Ps, Ns, P3, P2, C123 );  AddTria( Ps, Ns, C123, C231, P3 );
                         AddTria( Ps, Ns, P1, P3, C231 );  AddTria( Ps, Ns, C231, C312, P1 );
                    end;
               end;
          end;
     end;

     MakeMesh( Ps, Ns );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunayVoros

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TDelaunayVoros.SetMargin( const Margin_:Single );
begin
     _Margin := Margin_;  Repaint;
end;

procedure TDelaunayVoros.SetRayLength( const RayLength_:Single );
begin
     _RayLength := RayLength_;  Repaint;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunayVoros.Create( Owner_:TComponent );
begin
     inherited;

     _Margin    := 0.05;
     _RayLength := 10;

     Color := TAlphaColor( $FF1F95FF );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunayVoros.BuildScene( const Delaunay_:TDelaunay3D );
var
   Ps, Ns :TArray<TSingle3D>;
   C, N :TDelaCell3D;
   K :Byte;
   S0, S1,
   V0, V1, V2, V3,
   W0, W1, W2, W3,
   C23, C31, C13,
   C01, C02, C03,
   D01, D02, D03 :TSingle3D;
begin
     Ps := [];
     Ns := [];

     if Assigned( Delaunay_ ) then
     begin
          for C in Delaunay_.Cells do
          begin
               if C.InfCorn >= 0 then Continue;  // ボロノイ頂点 = 有限胞の外心

               S0 := CircumOf( C );

               for K := 0 to 3 do
               begin
                    with VertTable[ K ] do
                    begin
                         V0 := VoroVector( C, S0, _[ 0 ], _RayLength );  // 面 K を貫く辺
                         V1 := VoroVector( C, S0, _[ 1 ], _RayLength );  // 残る3本
                         V2 := VoroVector( C, S0, _[ 2 ], _RayLength );
                         V3 := VoroVector( C, S0, _[ 3 ], _RayLength );
                    end;

                    // 辺 V0 を除く3方向の対のコーナー三角形（4枚の反復で外心を囲む殻が閉じる）
                    C23 := S0 + MarginCorner( V2, V3, _Margin );
                    C31 := S0 + MarginCorner( V3, V1, _Margin );
                    C13 := S0 + MarginCorner( V1, V2, _Margin );

                    AddTria( Ps, Ns, C23, C31, C13 );

                    // 辺 V0 とその他の方向の間のコーナー点（三角柱の口）
                    C01 := S0 + MarginCorner( V0, V1, _Margin );
                    C02 := S0 + MarginCorner( V0, V2, _Margin );
                    C03 := S0 + MarginCorner( V0, V3, _Margin );

                    N := C.Cell[ K ];

                    if N.InfCorn < 0 then  // 有限の隣 → 三角柱の半分（3枚）を渡す。両側から張って柱が閉じる
                    begin
                         S1 := CircumOf( N );

                         W0 := VoroVector( N, S1, C.Join[ K, 0 ], _RayLength );  // 隣から見た同じ辺の束
                         W1 := VoroVector( N, S1, C.Join[ K, 1 ], _RayLength );
                         W2 := VoroVector( N, S1, C.Join[ K, 2 ], _RayLength );
                         W3 := VoroVector( N, S1, C.Join[ K, 3 ], _RayLength );

                         D01 := S1 + MarginCorner( W0, W1, _Margin );
                         D02 := S1 + MarginCorner( W0, W2, _Margin );
                         D03 := S1 + MarginCorner( W0, W3, _Margin );

                         AddTria( Ps, Ns, D01, C01, C03 );
                         AddTria( Ps, Ns, D02, C02, C01 );
                         AddTria( Ps, Ns, D03, C03, C02 );
                    end
                    else  // 無限遠胞 → 半直線の先の1点へ錐で閉じる
                    begin
                         S1 := S0 + V0;

                         AddTria( Ps, Ns, S1, C01, C03 );
                         AddTria( Ps, Ns, S1, C02, C01 );
                         AddTria( Ps, Ns, S1, C03, C02 );
                    end;
               end;
          end;
     end;

     MakeMesh( Ps, Ns );
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
          Color             := TAlphaColors.Black;
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

     _Edges := TDelaunayEdges.Create( Self );  _Edges.Parent := _Viewport;  // 生成順は任意（3D は深度で解決される）
     _Voros := TDelaunayVoros.Create( Self );  _Voros.Parent := _Viewport;
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
