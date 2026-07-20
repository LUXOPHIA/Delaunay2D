unit LUX.Delaunay.D2;

// 2D ドロネー図（逐次添加法・無限遠頂点方式）
//
//【モデル】
// ・LUX.Data.Model.TriFlip.D2 の三角形メッシュを継承し、ドロネー固有の機能だけを
//   加える。プロパティの型付けは TriFlip の型付け層が行うため、自分の派生クラスを
//   型引数に与えるだけでよい。
//     TDelaPoin2D    … TTriPoin2D<TDelaFace2D>                     ＋ 無限遠フラグ（Inf）
//     TDelaPoinSet2D … TTriPoinSet2D<TDelaPoin2D>
//     TDelaFace2D    … TTriFace2D<TDelaPoin2D,TDelaFace2D>         ＋ 空円判定・同次外心
//     TDelaFaceSet2D … TTriFaceSet2D<TDelaFace2D,TDelaPoinSet2D>
//     TDelaunay2D    … TDelaFaceSet2D ＋ 点の追加・削除のアルゴリズム
//   頂点・面の接続（Poin / Face / Corn）と巡回表（VertTableInc / VertTableDec）、
//   隣接検査（CheckEdges）、点と面の所有は TriFlip 層が担う。
//
//【アルゴリズム】
// ・スーパートライアングルを使わず、凸包の外側を「無限遠面」で覆う。
//   モデルはただ一つの無限遠頂点 PoinInf を持ち、凸包の各辺は
//   ( PoinInf, Pi, Pj ) からなる面で閉じられる。Poin[] に nil は現れない。
// ・空円判定は同次リフトによる単一の行列式で行う。判定点を原点に平行移動し、
//     有限点　 → ( X-Px, Y-Py, (X-Px)²+(Y-Py)² )
//     無限遠点 → ( 0, 0, 1 )
//   の3行を並べた 3×3 行列式が正なら「円の内側」。無限遠頂点を含む面では
//   この式が自動的に半平面判定（orient2d）へ退化する。円と直線（＝半径無限大の
//   円）がリフト空間では同じ「平面」になることの帰結であり、場合分けは要らない。
// ・点の追加は Bowyer-Watson 法。新しい点を円に含む面群（キャビティ）を
//   FaceTree で再帰的に削除し、境界辺ごとに新しい面を張り直す。
//   キャビティの内部に頂点が存在しないため、その双対グラフは木になり、
//   一度の再帰で削除・生成・縫合が完了する。
// ・点の削除はフリップ法。耳の底辺（頂点と耳先を結ぶ辺）を FlipEdge で外して次数を
//   下げていき、次数3になったら3面を1面に畳み込んで頂点を取り除く。穴を開けない
//   ため途中状態が常に正しい三角形分割であり、リングの配列管理も要らない。
//   耳が有効である条件は「自分が耳の外接円の内側にあり、円が他のリング頂点を
//   含まない」。これは最終形に現れる面そのものなので、選択の優先順位は要らず、
//   最初に見つけた有効な耳を切ればよい。
// ・無限遠頂点は TDelaPoin2DInf として派生し、リフト（Lift = 0,0,1）と内外判定
//   （InCircled = 向きの行列式）を多態で差し替える。有限点と無限遠点、有限半径の
//   円と直線（無限半径の円）は同じ式で扱われ、述語にフラグの分岐は存在しない。
//   リング走査でも、自分自身や無限遠点との判定は行列式が 0 以下となって自然に
//   除外されるため、スキップの条件分岐も無い。
// ・面の外心は同次座標 Circum = ( X, Y, W ) で取り出す。リフト空間で3頂点を通る
//   平面の係数（小行列式）そのものであり、有限面は ( X/W, Y/W ) が外心、無限遠面は
//   自然に W = 0 へ退化して ( X, Y ) がボロノイ辺の外向きの方向を表す。
//   計算に分岐も除算もなく、中心＋半径という表現の押し付けが要らない。
// ・追加点を空円に含む面の検索はジャンプ＆ウォーク。点集合から n^(1/3) 個を無作為に
//   引き、最も近い点のアンカー面から、追加点が外側にある辺を越えて隣へ渡り続ける
//   （期待 O(n^(1/3))）。辺の向き判定は統一述語の退化形 InCircle( A, B, ∞, P ) で
//   あり、凸包外の点では歩行が自然に無限遠面へ入って止まる。標本は毎回引き直す
//   ため、性能はクエリの履歴や位置に依らず領域全体で一様。最近傍検索（FindPoin）
//   も同じ標本から出発し、ドロネー辺を伝う最近傍への貪欲降下で行う。

interface //#################################################################### ■

uses LUX,
     LUX.D2,
     LUX.D3,
     LUX.Data.Model.TriFlip.core,
     LUX.Data.Model.TriFlip.D2;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     TDelaPoin2D    = class;
     TDelaPoin2DInf = class;
     TDelaPoinSet2D = class;
     TDelaFace2D    = class;
     TDelaFaceSet2D = class;
     TDelaunay2D    = class;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFaceJoint

     TFaceJoint = record
     private
     public
       FaceL :TDelaFace2D;
       FaceR :TDelaFace2D;
       VertL :Byte;
       VertR :Byte;
     end;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2D

     // 頂点。TriFlip の点にリフト（同次化）と内外判定を加えたもの。
     TDelaPoin2D = class( TTriPoin2D<TDelaFace2D> )
     private
     protected
       ///// A C C E S S O R
       function GetInf :Boolean; virtual;
       ///// M E T H O D
       function LiftW :Single; virtual;  // 同次成分（有限点 = 1）
     public
       ///// P R O P E R T Y
       property Inf :Boolean read GetInf;  // 無限遠頂点か
       ///// M E T H O D
       function Lift( const Pos_:TSingle2D ) :TSingle3D; virtual;  // Pos_ を原点とするリフト座標 ( X, Y, X²+Y² )
       function InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Single; virtual;  // 円 ( P1, P2, P3 ) に対する自分の内外（正 = 内側）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2DInf

     // 無限遠頂点。リフトと内外判定を多態で差し替える（述語にフラグの分岐は存在しない）。
     TDelaPoin2DInf = class( TDelaPoin2D )
     private
     protected
       ///// A C C E S S O R
       function GetInf :Boolean; override;
       ///// M E T H O D
       function LiftW :Single; override;  // 同次成分（無限遠点 = 0）
     public
       ///// M E T H O D
       function Lift( const Pos_:TSingle2D ) :TSingle3D; override;  // どこから見ても ( 0, 0, 1 )
       function InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Single; override;  // 円の向き（直線への退化）で決まる
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet2D

     // 点集合。
     TDelaPoinSet2D = class( TTriPoinSet2D<TDelaPoin2D> )
     private
     protected
     public
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFace2D

     // 三角形。TriFlip の面に空円判定と同次外心を加えたもの。
     TDelaFace2D = class( TTriFace2D<TDelaPoin2D,TDelaFace2D> )
     private
     protected
       ///// A C C E S S O R
       function GetInfCorn :Byte;
       function GetCircum :TSingle3D;
     public
       ///// P R O P E R T Y
       property InfCorn :Byte      read GetInfCorn;  // 無限遠頂点の番号（0 = 有限面）
       property Circum  :TSingle3D read GetCircum ;  // 同次外心 ( X, Y, W )。有限面は ( X/W, Y/W ) が外心、無限遠面は W = 0 で ( X, Y ) が外向きの方向
       ///// M E T H O D
       class function InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Single;  // 統一リフト行列式（正 = 円の内側）
       function IsHitCircle( const Pos_:TSingle2D ) :Boolean;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFaceSet2D

     // 面集合。
     TDelaFaceSet2D = class( TTriFaceSet2D<TDelaFace2D,TDelaPoinSet2D> )
     private
     protected
       ///// A C C E S S O R
       function GetPoins :TDelaPoinSet2D;
     public
       ///// P R O P E R T Y
       property Poins :TDelaPoinSet2D read GetPoins;  // 有限頂点のみ（PoinSet の別名）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay2D

     TDelaunay2D = class( TDelaFaceSet2D )
     private
       _PoinInf  :TDelaPoin2D;
       _OnChange :TDelegates;
       ///// A C C E S S O R
       function GetFaces :TDelaFaceSet2D;
       ///// M E T H O D
       procedure InitFace;
       function FaceTree( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D; const Vert_:Byte ) :TFaceJoint;
       procedure Connect( const J_,JL_,JR_:TFaceJoint );
       procedure InsertPoin( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D );
       function JumpPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
       function ScanCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;
     protected
       ///// M E T H O D
       function NewPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
       function NewFace( const Poin1_,Poin2_,Poin3_:TDelaPoin2D ) :TDelaFace2D;
     public
       constructor Create; overload; override;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property PoinInf  :TDelaPoin2D    read _PoinInf ;  // 唯一の無限遠頂点（点集合には属さない）
       property Faces    :TDelaFaceSet2D read GetFaces ;  // 面の集合（＝自分自身）
       property OnChange :TDelegates     read _OnChange;  // 構造が変化したときに発火（Add / Del で多播購読）
       ///// M E T H O D
       function HitCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;  // Pos_ を空円に含む面（ジャンプ＆ウォーク・期待 O(n^(1/3))）
       function FindPoin( const Pos_:TSingle2D; const Radius_:Single ) :TDelaPoin2D;  // Pos_ の最近傍点（Radius_ 内に無ければ nil）
       function AddPoin( const Pos_:TSingle2D ) :TDelaPoin2D; overload;
       function AddPoin( const Pos_:TSingle2D; const Face_:TDelaFace2D ) :TDelaPoin2D; overload;
       function DeletePoin( const Poin_:TDelaPoin2D ) :Boolean;
       procedure Clear; reintroduce;  // 点と面を全消去する（PoinInf は残る）
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFaceJoint

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaPoin2D.GetInf :Boolean;
begin
     Result := False;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin2D.LiftW :Single;
begin
     Result := 1;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin2D.Lift( const Pos_:TSingle2D ) :TSingle3D;
begin
     with Result do
     begin
          X := Pos.X - Pos_.X;
          Y := Pos.Y - Pos_.Y;
          Z := X * X + Y * Y;
     end;
end;

function TDelaPoin2D.InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Single;
begin
     Result := TDelaFace2D.InCircle( P1_, P2_, P3_, Pos );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2DInf

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaPoin2DInf.GetInf :Boolean;
begin
     Result := True;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin2DInf.LiftW :Single;
begin
     Result := 0;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin2DInf.Lift( const Pos_:TSingle2D ) :TSingle3D;
begin
     with Result do
     begin
          X := 0;
          Y := 0;
          Z := 1;
     end;
end;

function TDelaPoin2DInf.InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Single;
//･･･････････････････････････････････････････
     function Homo( const P_:TDelaPoin2D ) :TSingle3D;  // 同次座標 ( X, Y, W )。無限遠点は ( 0, 0, 0 ) となり行列式から自然に消える
     begin
          with Result do
          begin
               X := P_.Pos.X;
               Y := P_.Pos.Y;
               Z := P_.LiftW;
          end;
     end;
//･･･････････････････････････････････････････
begin
     // 無限遠点が円の内側にあるのは、円が負の向きのときだけ（正の向きの円は必ず無限遠点を外に置く）
     Result := - DotProduct( Homo( P1_ ), CrossProduct( Homo( P2_ ), Homo( P3_ ) ) );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFace2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaFace2D.GetInfCorn :Byte;
begin
     if Poin[ 1 ].Inf then Result := 1
                      else
     if Poin[ 2 ].Inf then Result := 2
                      else
     if Poin[ 3 ].Inf then Result := 3
                      else Result := 0;
end;

function TDelaFace2D.GetCircum :TSingle3D;
//･･･････････････････････････････････････････
     function Minor( const X1_,Y1_,W1_,X2_,Y2_,W2_,X3_,Y3_,W3_:Single ) :Single;
     begin
          Result := DotProduct( TSingle3D.Create( X1_, Y1_, W1_ ),
              CrossProduct( TSingle3D.Create( X2_, Y2_, W2_ ),
                            TSingle3D.Create( X3_, Y3_, W3_ ) ) );
     end;
//･･･････････････････････････････････････････
var
   L1, L2, L3 :TSingle3D;
   W1, W2, W3 :Single;
begin
     // リフト空間で3頂点を通る平面の係数（小行列式）。無限遠頂点の行は 0 となり、自然に W = 0（直線）へ退化する
     L1 := Poin[ 1 ].Lift( TSingle2D.Create( 0, 0 ) );  W1 := Poin[ 1 ].LiftW;
     L2 := Poin[ 2 ].Lift( TSingle2D.Create( 0, 0 ) );  W2 := Poin[ 2 ].LiftW;
     L3 := Poin[ 3 ].Lift( TSingle2D.Create( 0, 0 ) );  W3 := Poin[ 3 ].LiftW;

     with Result do
     begin
          X :=   - Minor( L1.Y, L1.Z, W1,  L2.Y, L2.Z, W2,  L3.Y, L3.Z, W3 );
          Y :=   + Minor( L1.X, L1.Z, W1,  L2.X, L2.Z, W2,  L3.X, L3.Z, W3 );
          Z := 2 * Minor( L1.X, L1.Y, W1,  L2.X, L2.Y, W2,  L3.X, L3.Y, W3 );
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

class function TDelaFace2D.InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Single;
begin
     Result := DotProduct( P1_.Lift( Pos_ ), CrossProduct( P2_.Lift( Pos_ ), P3_.Lift( Pos_ ) ) );
end;

function TDelaFace2D.IsHitCircle( const Pos_:TSingle2D ) :Boolean;
begin
     Result := InCircle( Poin[ 1 ], Poin[ 2 ], Poin[ 3 ], Pos_ ) > 0;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFaceSet2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaFaceSet2D.GetPoins :TDelaPoinSet2D;
begin
     Result := PoinSet;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaunay2D.GetFaces :TDelaFaceSet2D;
begin
     Result := Self;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunay2D.InitFace;
var
   P1, P2 :TDelaPoin2D;
   C1, C2 :TDelaFace2D;
begin
     P1 := Poins[ 0 ];
     P2 := Poins[ 1 ];

     C1 := NewFace( _PoinInf, P1, P2 );
     C2 := NewFace( _PoinInf, P2, P1 );

     C1.Face[ 1 ] := C2;  C1.Corn[ 1 ] := 1;
     C1.Face[ 2 ] := C2;  C1.Corn[ 2 ] := 3;
     C1.Face[ 3 ] := C2;  C1.Corn[ 3 ] := 2;

     C2.Face[ 1 ] := C1;  C2.Corn[ 1 ] := 1;
     C2.Face[ 2 ] := C1;  C2.Corn[ 2 ] := 3;
     C2.Face[ 3 ] := C1;  C2.Corn[ 3 ] := 2;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.FaceTree( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D; const Vert_:Byte ) :TFaceJoint;
var
   JL, JR :TFaceJoint;
   C :TDelaFace2D;
begin
     if Face_.IsHitCircle( Poin_.Pos ) then
     begin
          with VertTableInc[ Vert_ ] do
          begin
               JL := FaceTree( Poin_, Face_.Face[ R ], Face_.Corn[ R ] );
               JR := FaceTree( Poin_, Face_.Face[ L ], Face_.Corn[ L ] );
          end;

          with JL do
          begin
               with FaceR do
               begin
                    Face[ VertR ] := JR.FaceL;
                    Corn[ VertR ] := JR.VertL;
               end
          end;
          with JR do
          begin
               with FaceL do
               begin
                    Face[ VertL ] := JL.FaceR;
                    Corn[ VertL ] := JL.VertR;
               end
          end;

          Face_.Free;

          with Result do
          begin
               FaceL := JL.FaceL;  VertL := JL.VertL;
               FaceR := JR.FaceR;  VertR := JR.VertR;
          end;
     end
     else
     begin
          with VertTableInc[ Vert_ ] do C := NewFace( Face_.Poin[ L ], Poin_, Face_.Poin[ R ] );

          C.Face[ 2 ] := Face_;
          C.Corn[ 2 ] := Vert_;

          Face_.Face[ Vert_ ] := C;
          Face_.Corn[ Vert_ ] := 2;

          with Result do
          begin
               FaceL := C;  VertL := 3;
               FaceR := C;  VertR := 1;
          end;
     end;
end;

procedure TDelaunay2D.Connect( const J_,JL_,JR_:TFaceJoint );
begin
     with J_ do
     begin
          with FaceL do
          begin
               Face[ VertL ] := JL_.FaceR;
               Corn[ VertL ] := JL_.VertR;
          end;
          with FaceR do
          begin
               Face[ VertR ] := JR_.FaceL;
               Corn[ VertR ] := JR_.VertL;
          end;
     end;
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.InsertPoin( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D );
var
   J1, J2, J3 :TFaceJoint;
begin
     J1 := FaceTree( Poin_, Face_.Face[ 1 ], Face_.Corn[ 1 ] );
     J2 := FaceTree( Poin_, Face_.Face[ 2 ], Face_.Corn[ 2 ] );
     J3 := FaceTree( Poin_, Face_.Face[ 3 ], Face_.Corn[ 3 ] );

     Face_.Free;

     Connect( J1, J2, J3 );
     Connect( J2, J3, J1 );
     Connect( J3, J1, J2 );
end;

//------------------------------------------------------------------------------

function TDelaunay2D.JumpPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
var
   N, K, I :Integer;
   P :TDelaPoin2D;
   D, Dm :Single;
begin
     N := Poins.ChildrsN;

     Result := Poins[ Random( N ) ];  Dm := Distance2( Pos_, Result.Pos );

     K := 1;  while K * K * K < N do Inc( K );  // 標本数 = ⌈n^(1/3)⌉（歩行距離との釣り合いで合計が期待 O(n^(1/3)) になる）

     for I := 2 to K do
     begin
          P := Poins[ Random( N ) ];  D := Distance2( Pos_, P.Pos );

          if D < Dm then begin  Dm := D;  Result := P;  end;
     end;
end;

function TDelaunay2D.ScanCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;
var
   F :TDelaFace2D;
begin
     for F in Faces do  // 全面走査（歩行の保険。退化配置でのみ使われる）
     begin
          if F.IsHitCircle( Pos_ ) then Exit( F );
     end;

     Result := nil;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay2D.NewPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
begin
     Result := TDelaPoin2D.Create( Pos_, PoinSet );
end;

function TDelaunay2D.NewFace( const Poin1_,Poin2_,Poin3_:TDelaPoin2D ) :TDelaFace2D;
begin
     Result := TDelaFace2D.Create( Self );

     Result.Poin[ 1 ] := Poin1_;
     Result.Poin[ 2 ] := Poin2_;
     Result.Poin[ 3 ] := Poin3_;

     Result.BindPoins;  // 頂点のアンカーを張り直す（削除時の面探索が O(1) になる）
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunay2D.Create;
begin
     inherited;

     _PoinInf := TDelaPoin2DInf.Create( TSingle2D.Create( 0, 0 ) );
end;

destructor TDelaunay2D.Destroy;
begin
     inherited;        // 点と面は集合ごと解放される

     _PoinInf.Free;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay2D.HitCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;
var
   F :TDelaFace2D;
   N, O, I :Integer;
   E, K :Byte;
begin
     F := JumpPoin( Pos_ ).Face;  // ジャンプ：無作為標本の最近点のアンカー面から出発する

     if not Assigned( F ) then Exit( ScanCircleFace( Pos_ ) );

     for N := 1 to 4 * ChildrsN + 8 do  // ウォーク：Pos_ が外側にある辺を越えて隣へ渡り続ける（面数程度で必ず着く）
     begin
          if F.InfCorn > 0 then  // 無限遠面（凸包外の楔）
          begin
               if F.IsHitCircle( Pos_ ) then Exit( F );  // Pos_ は凸包辺の外側 → この半平面が空円

               F := F.Face[ F.InfCorn ];  // 凸包の内側へ渡る
          end
          else
          begin
               K := 0;

               O := Random( 3 );  // 調べる辺の順を無作為化した確率的歩行（共円退化での振動を防ぐ）

               for I := 0 to 2 do
               begin
                    E := 1 + ( O + I ) mod 3;

                    with VertTableInc[ E ] do  // 辺の向き判定は統一述語の退化形（第3点に無限遠頂点を与えると orient2d になる）
                    begin
                         if TDelaFace2D.InCircle( F.Poin[ L ], F.Poin[ R ], _PoinInf, Pos_ ) < 0 then K := E;
                    end;

                    if K > 0 then Break;
               end;

               if K > 0 then F := F.Face[ K ]
               else
               if F.IsHitCircle( Pos_ ) then Exit( F )                        // 内包面に到達（三角形 ⊆ 外接円）
                                        else Exit( ScanCircleFace( Pos_ ) );  // 共円・重複の退化 → 全面走査で確定する
          end;
     end;

     Result := ScanCircleFace( Pos_ );  // 歩行が収束しない退化配置 → 全面走査へ退避する
end;

//------------------------------------------------------------------------------

function TDelaunay2D.AddPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
var
   F :TDelaFace2D;
begin
     case Poins.ChildrsN of
       0: begin
               Result := NewPoin( Pos_ );  _OnChange.Run( Self );
          end;
       1: begin
               Result := NewPoin( Pos_ );  InitFace;  _OnChange.Run( Self );
          end;
     else
          F := HitCircleFace( Pos_ );

          if Assigned( F ) then Result := AddPoin( Pos_, F )
                           else Result := nil;  // 退化配置（既存の辺と一直線上）は無視する
     end;
end;

function TDelaunay2D.AddPoin( const Pos_:TSingle2D; const Face_:TDelaFace2D ) :TDelaPoin2D;
begin
     Result := NewPoin( Pos_ );  InsertPoin( Result, Face_ );  _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TDelaunay2D.FindPoin( const Pos_:TSingle2D; const Radius_:Single ) :TDelaPoin2D;
var
   P :TDelaPoin2D;
   Dm :Single;
//･･･････････････････････････････････････････
     function GoNear :Boolean;  // P の隣接頂点に今より近い点があれば移る
     var
        F0, F :TDelaFace2D;
        C, R :Byte;
        W :TDelaPoin2D;
        D :Single;
     begin
          Result := False;

          F0 := P.Face;

          if not Assigned( F0 ) then Exit;

          F := F0;
          C := P.Corn;
          repeat
                R := VertTableInc[ C ].R;

                W := F.Poin[ R ];

                if not W.Inf then
                begin
                     D := Distance2( Pos_, W.Pos );

                     if D < Dm then begin  P := W;  Dm := D;  Exit( True );  end;
                end;

                C := VertTableInc[ F.Corn[ R ] ].R;
                F :=               F.Face[ R ]    ;
          until F = F0;
     end;
//･･･････････････････････････････････････････
var
   N :Integer;
begin
     Result := nil;

     if Poins.ChildrsN = 0 then Exit;

     P := JumpPoin( Pos_ );  Dm := Distance2( Pos_, P.Pos );  // 無作為標本の最近点から出発し、

     for N := 1 to Poins.ChildrsN do  // ドロネー辺を伝って近い方へ降下する。移るたびに距離が縮むので移動は
     begin                            // 高々 n-1 回であり、Pos_ をボロノイ領域に含む点 ＝ 最近傍点で必ず停止する
          if not GoNear then Break;
     end;

     if Dm < Pow2( Radius_ ) then Result := P;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.DeletePoin( const Poin_:TDelaPoin2D ) :Boolean;
var
   F0 :TDelaFace2D;    C0 :Byte;  // Poin_ の現在位置（面と、その中の角番号）
//･･･････････････････････････････････････････
     procedure GoNext;  // Poin_ の周りを1面ぶん回る
     var
        R :Byte;
     begin
          R := VertTableInc[ C0 ].R;

          C0 := VertTableInc[ F0.Corn[ R ] ].R;
          F0 :=               F0.Face[ R ]    ;
     end;
//･･･････････････････････････････････････････
     function Degree :Integer;  // Poin_ の周囲の面数
     var
        F :TDelaFace2D;
     begin
          Result := 0;

          F := F0;
          repeat
                Inc( Result );  GoNext;
          until F0 = F;
     end;
//･･･････････････････････････････････････････
     function EarOK :Boolean;  // 現在位置の耳 ( A, B, C ) が切り出せるか（＝最終形に現れる面か）
     var
        A, B, C :TDelaPoin2D;
        E, K, R :Byte;
        F :TDelaFace2D;
     begin
          Result := False;

          E := VertTableInc[ C0 ].L;

          A := F0.Poin[ E                    ];
          B := F0.Poin[ VertTableInc[ C0 ].R ];
          C := F0.Face[ E ].Poin[ F0.Corn[ E ] ];

          // 自分が耳の円の内側にあること（耳が正の向きであることも兼ねる。裏向きの耳は符号が反転して自然に落ちる）
          if Poin_.InCircled( A, B, C ) <= 0 then Exit;

          // 耳を外したあとに残る面が有限なら、正の向きであること（無限遠点を含む面は幾何を持たないため無条件に良い）
          if not ( A.Inf or C.Inf ) then
          begin
               if CrossProduct( Poin_.Pos - C.Pos, A.Pos - C.Pos ) <= 0 then Exit;
          end;

          // 耳の円が他のリング頂点を含まないこと（自分自身や無限遠点との判定は行列式が 0 以下となり、スキップは要らない）
          F := F0;
          K := C0;
          repeat
                if F.Poin[ VertTableInc[ K ].R ].InCircled( A, B, C ) > 0 then Exit;

                R := VertTableInc[ K ].R;

                K := VertTableInc[ F.Corn[ R ] ].R;
                F :=               F.Face[ R ]    ;
          until F = F0;

          Result := True;
     end;
//･･･････････････････････････････････････････
     procedure ClipEar;  // 耳の底辺（Poin_ と B を結ぶ辺）をフリップして、次数を1つ下げる
     var
        E, G :Byte;
        F :TDelaFace2D;
     begin
          E := VertTableInc[ C0 ].L;

          F := F0.Face[ E ];
          G := F0.Corn[ E ];

          F0.FlipEdge( E );  // 耳 ( A, B, C ) がそのまま完成品の面になる

          F0 := F;                      // フリップ後、Poin_ は隣の面へ移る
          C0 := VertTableInc[ G ].L;
     end;
//･･･････････････････････････････････････････
     procedure Unhook;  // 次数3になった Poin_ を、3面 → 1面の畳み込みで取り除く
     var
        I :Integer;
        R :Byte;
        F :TDelaFace2D;
        Ws :array [ 0..2 ] of TDelaPoin2D;
        Fs :array [ 0..2 ] of TDelaFace2D;
        Cs :array [ 0..2 ] of Byte;
     begin
          for I := 0 to 2 do  // リング頂点と外側リンクを収集する（収集順は時計回り）
          begin
               R := VertTableInc[ C0 ].R;

               Ws[ I ] := F0.Poin[ R  ];
               Fs[ I ] := F0.Face[ C0 ];
               Cs[ I ] := F0.Corn[ C0 ];

               F := F0;  GoNext;  F.Free;
          end;

          F := NewFace( Ws[ 2 ], Ws[ 1 ], Ws[ 0 ] );  // 反転して正の向きにする

          F.Face[ 3 ] := Fs[ 1 ];  F.Corn[ 3 ] := Cs[ 1 ];   Fs[ 1 ].Face[ Cs[ 1 ] ] := F;  Fs[ 1 ].Corn[ Cs[ 1 ] ] := 3;
          F.Face[ 1 ] := Fs[ 0 ];  F.Corn[ 1 ] := Cs[ 0 ];   Fs[ 0 ].Face[ Cs[ 0 ] ] := F;  Fs[ 0 ].Corn[ Cs[ 0 ] ] := 1;
          F.Face[ 2 ] := Fs[ 2 ];  F.Corn[ 2 ] := Cs[ 2 ];   Fs[ 2 ].Face[ Cs[ 2 ] ] := F;  Fs[ 2 ].Corn[ Cs[ 2 ] ] := 2;
     end;
//･･･････････････････････････････････････････
var
   N, K :Integer;
begin
     Result := False;

     if ( Poin_ = nil ) or Poin_.Inf or ( Poin_.Parent <> PoinSet ) then Exit;

     case Poins.ChildrsN of
       1: begin
               Poin_.Free;
          end;
       2: begin
               inherited Clear;  // 面を全解放する

               Poin_.Free;
          end;
     else
          F0 := Poin_.Face;  C0 := Poin_.Corn;  // 頂点のアンカーから所属面へ直行する

          if not Assigned( F0 ) then Exit;

          // 有効な耳の底辺をフリップして外していき、次数を3まで下げる
          K := Degree;

          for N := 1 to 2 * K * K + 8 do  // 有効な耳は必ず存在するので、この回数までに必ず次数3に達する
          begin
               if K = 3 then Break;

               if EarOK then begin ClipEar;  Dec( K ); end
                        else GoNext;
          end;

          Assert( K = 3, 'DeletePoin: ear deadlock' );

          if K > 3 then begin  _OnChange.Run( Self );  Exit;  end;  // 異常時は削除を断念する（分割は正しいまま残る）

          Unhook;

          Poin_.Free;
     end;

     _OnChange.Run( Self );

     Result := True;
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.Clear;
begin
     inherited Clear;  // 面を全解放する

     Poins.Clear;      // 点を全解放する（PoinInf は集合外なので残る）

     _PoinInf.Face := nil;

     _OnChange.Run( Self );
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

end. //######################################################################### ■
