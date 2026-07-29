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
//   行列式は必ず近傍の点を基準に平行移動してから倍精度で評価する（桁落ち対策。
//   外心も同様で、絶対座標のまま評価する式は存在しない）。
// ・点の追加は Bowyer-Watson 法の2相方式。①新しい点を円に含む面群（キャビティ）を
//   Flag で塗り広げて集め（マーク）、②境界辺ごとに新しい面を張って外側と縫い、
//   最後に塗った面をまとめて解放する（カーブ）。マークは冪等なので、共円の退化で
//   同じ面へ複数の経路から到達しても二重処理は起こらない（3D と同型）。
// ・点の削除は「星の除去と埋め戻し」。頂点の星（頂点を含む面の集合）を取り除くと
//   星型の穴が開く。穴の境界（リンク）の頂点だけから成る小さなドロネー図を、同じ
//   集合の中の独立した成分として逐次添加法で作り（入れ子の TDelaunay2D は作らない）、
//   その中から穴を埋める面 ―― 境界辺を同じ向きで含む面から、境界を越えずに届く面 ――
//   を切り出して、穴の縁に縫い付ける。埋め草の切り出しも縫い付けも組合せ的な検査だけで
//   確定し、フリップの探索を含まない。検査に通らない退化配置では、元の分割を一切壊さずに
//   False を返す。
// ・追加も削除も、失敗は戻り値で表す。AddPoin は追加できなければ nil を、DeletePoin は
//   削除できなければ False を返し、分割は常に正しいまま保たれる。遅延挿入のような
//   救済機構は持たない。
// ・無限遠頂点は TDelaPoin2DInf として派生し、リフト（Lift = 0,0,1）と内外判定
//   （InCircled = 向きの行列式）を多態で差し替える。有限点と無限遠点、有限半径の
//   円と直線（無限半径の円）は同じ式で扱われ、述語にフラグの分岐は存在しない。
// ・面の外心は同次座標 Circum = ( X, Y, W ) で取り出す。リフト空間で3頂点を通る
//   平面の係数（小行列式）そのものであり、有限面は ( X/W, Y/W ) が外心、無限遠面は
//   自然に W = 0 へ退化して ( X, Y ) がボロノイ辺の外向きの方向を表す。
//   計算に分岐も除算もなく、中心＋半径という表現の押し付けが要らない。
// ・追加点を空円に含む面の検索はジャンプ＆ウォーク。点集合から n^(1/3) 個を無作為に
//   引き、最も近い点のアンカー面から、追加点が外側にある辺を越えて隣へ渡り続ける
//   （期待 O(n^(1/3))）。辺の向き判定は統一述語の退化形 InCircle( A, B, ∞, P ) で
//   あり、凸包外の点では歩行が自然に無限遠面へ入って止まる。標本は毎回引き直す
//   ため、性能はクエリの履歴や位置に依らず領域全体で一様。
// ・最近傍検索（FindNearPoin）もジャンプ＆ウォークの着地面から始める。Pos_ を空円に
//   含む面の頂点は Pos_ の近くにいるので、その中の最も近い頂点から、ドロネー辺を
//   伝ってより近い隣接頂点へ降下する。移るたびに距離が厳密に縮むため、Pos_ を
//   ボロノイ領域に含む点 ＝ 最近傍点で必ず停止する（期待 O(n^(1/3)) ＋ O(1) 段の降下）。

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
       function Lift( const Pos_:TSingle2D ) :TDouble3D; virtual;  // Pos_ を原点とするリフト座標 ( X, Y, X²+Y² )
       function InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Double; virtual;  // 円 ( P1, P2, P3 ) に対する自分の内外（正 = 内側）
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
       function Lift( const Pos_:TSingle2D ) :TDouble3D; override;  // どこから見ても ( 0, 0, 1 )
       function InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Double; override;  // 円の向き（直線への退化）で決まる
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet2D

     // 点集合。
     TDelaPoinSet2D = class( TTriPoinSet2D<TDelaPoin2D> )
     private
     protected
       ///// M E T H O D
       function LoadPoin( const Pos_:TSingle2D ) :TTriPoin<TSingle2D>; override;  // 読み込む点を TDelaPoin2D として生成する
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
       class function InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Double;  // 統一リフト行列式（正 = 円の内側）
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
       function SeedFace( const P1_,P2_:TDelaPoin2D ) :TDelaFace2D;
       procedure InitFace;
       procedure InsertPoin( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D );
       function JumpPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
       function ScanCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;
     protected
       ///// M E T H O D
       function NewPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
       function NewFace( const Poin1_,Poin2_,Poin3_:TDelaPoin2D ) :TDelaFace2D;
       function PoinCode( const Poin_:TTriPoin<TSingle2D> ) :Integer; override;  // 無限遠頂点 = -2
       function CodePoin( const Code_:Integer ) :TTriPoin<TSingle2D>; override;  // -2 = 無限遠頂点
       function LoadFace :TTriFace<TSingle2D>; override;                         // 読み込む面を TDelaFace2D として生成する
     public
       constructor Create; overload; override;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property PoinInf  :TDelaPoin2D    read _PoinInf ;  // 唯一の無限遠頂点（点集合には属さない）
       property Faces    :TDelaFaceSet2D read GetFaces ;  // 面の集合（＝自分自身）
       property OnChange :TDelegates     read _OnChange;  // 構造が変化したときに発火（Add / Del で多播購読）
       ///// M E T H O D
       function HitCircleFace( const Pos_:TSingle2D ) :TDelaFace2D;  // Pos_ を空円に含む面（ジャンプ＆ウォーク・期待 O(n^(1/3))）
       function FindMaxCircle :TDelaFace2D;  // 無限遠面（＝半径無限大の空円）を除く、最大半径の空円を持つ面（有限面が無ければ nil）
       function FindNearPoin( const Pos_:TSingle2D; out Poin_:TDelaPoin2D ) :Single;  // Pos_ の最近傍点と、そこまでの距離（点が無ければ nil と Infinity）
       function AddPoin( const Pos_:TSingle2D ) :TDelaPoin2D; overload;     // 点の追加（退化配置で追加できなければ nil）
       function AddPoin( const Pos_:TSingle2D; const Face_:TDelaFace2D ) :TDelaPoin2D; overload;
       function DeletePoin( const Poin_:TDelaPoin2D ) :Boolean;             // 点の削除（退化配置で埋め戻せなければ、何も変えずに False）
       procedure LoadFromFile( const FileName_:String ); override;  // *.lxtf から復元（無限遠頂点も接続ごと再現される）
       procedure Clear; reintroduce;  // 点と面を全消去する（PoinInf は残る）
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

uses System.Math;

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

function TDelaPoin2D.Lift( const Pos_:TSingle2D ) :TDouble3D;
begin
     with Result do
     begin
          X := Pos.X;  X := X - Pos_.X;  // 差は Single の値を倍精度で取る（正確）
          Y := Pos.Y;  Y := Y - Pos_.Y;

          Z := X * X + Y * Y;
     end;
end;

function TDelaPoin2D.InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Double;
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

function TDelaPoin2DInf.Lift( const Pos_:TSingle2D ) :TDouble3D;
begin
     with Result do
     begin
          X := 0;
          Y := 0;
          Z := 1;
     end;
end;

function TDelaPoin2DInf.InCircled( const P1_,P2_,P3_:TDelaPoin2D ) :Double;
var
   B :TSingle2D;
//･･･････････････････････････････････････････
     function Homo( const P_:TDelaPoin2D ) :TDouble3D;  // 基準点 B へ平行移動した同次座標 ( X - W·Bx, Y - W·By, W )。
     begin                                              // 無限遠点は ( 0, 0, 0 ) となり行列式から自然に消える
          with Result do
          begin
               Z := P_.LiftW;

               X := P_.Pos.X;  X := X - Z * B.X;
               Y := P_.Pos.Y;  Y := Y - Z * B.Y;
          end;
     end;
//･･･････････････････････････････････････････
begin
     if not P1_.Inf then B := P1_.Pos  // 桁落ちを防ぐため、有限の頂点を基準に平行移動して評価する（行列式は不変）
                    else
     if not P2_.Inf then B := P2_.Pos
                    else B := P3_.Pos;

     // 無限遠点が円の内側にあるのは、円が負の向きのときだけ（正の向きの円は必ず無限遠点を外に置く）
     Result := - DotProduct( Homo( P1_ ), CrossProduct( Homo( P2_ ), Homo( P3_ ) ) );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoinSet2D.LoadPoin( const Pos_:TSingle2D ) :TTriPoin<TSingle2D>;
begin
     Result := TDelaPoin2D.Create( Pos_, Self );
end;

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
     function Minor( const X1_,Y1_,W1_,X2_,Y2_,W2_,X3_,Y3_,W3_:Double ) :Double;
     begin
          Result := DotProduct( TDouble3D.Create( X1_, Y1_, W1_ ),
              CrossProduct( TDouble3D.Create( X2_, Y2_, W2_ ),
                            TDouble3D.Create( X3_, Y3_, W3_ ) ) );
     end;
//･･･････････････････････････････････････････
var
   B :TSingle2D;
   L1, L2, L3 :TDouble3D;
   W1, W2, W3 :Double;
   CX, CY, CW :Double;
begin
     // リフト空間で3頂点を通る平面の係数（小行列式）。無限遠頂点の行は 0 となり、自然に W = 0（直線）へ退化する。
     // 桁落ちを防ぐため有限の頂点を基準に平行移動して評価し、最後に基準ぶんを同次で戻す
     if InfCorn <> 1 then B := Poin[ 1 ].Pos
                     else B := Poin[ 2 ].Pos;

     L1 := Poin[ 1 ].Lift( B );  W1 := Poin[ 1 ].LiftW;
     L2 := Poin[ 2 ].Lift( B );  W2 := Poin[ 2 ].LiftW;
     L3 := Poin[ 3 ].Lift( B );  W3 := Poin[ 3 ].LiftW;

     CX :=   - Minor( L1.Y, L1.Z, W1,  L2.Y, L2.Z, W2,  L3.Y, L3.Z, W3 );
     CY :=   + Minor( L1.X, L1.Z, W1,  L2.X, L2.Z, W2,  L3.X, L3.Z, W3 );
     CW := 2 * Minor( L1.X, L1.Y, W1,  L2.X, L2.Y, W2,  L3.X, L3.Y, W3 );

     with Result do
     begin
          X := CX + CW * B.X;  // 有限面は外心が B ぶん戻り、無限遠面（ W = 0 ）は方向がそのまま残る
          Y := CY + CW * B.Y;
          Z := CW;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

class function TDelaFace2D.InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Double;
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

function TDelaunay2D.SeedFace( const P1_,P2_:TDelaPoin2D ) :TDelaFace2D;
var
   C1, C2 :TDelaFace2D;
begin
     C1 := NewFace( _PoinInf, P1_, P2_ );  // 2点を通る直線の両側を覆う鏡像の無限遠面（任意の2点が種になる）
     C2 := NewFace( _PoinInf, P2_, P1_ );

     C1.Face[ 1 ] := C2;  C1.Corn[ 1 ] := 1;
     C1.Face[ 2 ] := C2;  C1.Corn[ 2 ] := 3;
     C1.Face[ 3 ] := C2;  C1.Corn[ 3 ] := 2;

     C2.Face[ 1 ] := C1;  C2.Corn[ 1 ] := 1;
     C2.Face[ 2 ] := C1;  C2.Corn[ 2 ] := 3;
     C2.Face[ 3 ] := C1;  C2.Corn[ 3 ] := 2;

     Result := C1;
end;

procedure TDelaunay2D.InitFace;
begin
     SeedFace( Poins[ 0 ], Poins[ 1 ] );
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.InsertPoin( const Poin_:TDelaPoin2D; const Face_:TDelaFace2D );
// 2相方式。①マーク: 追加点を円に含む面を Flag で塗り広げて集める。塗りは冪等なので、
// 共円の退化で同じ面へ複数の経路から到達しても二重処理は起こらない。②カーブ: 境界辺
// （塗った面と外側の面の間の辺）ごとに新しい面を張って外側と縫い、新しい面どうしを
// 追加点の周りで縫い、最後に塗った面をまとめて解放する（解放は縫合の後なので、
// 削除済みの面への再突入は構造的に起こらない）
var
   Star :TArray<TDelaFace2D>;  // キャビティ（塗った面）
   News :TArray<TDelaFace2D>;  // 境界辺に張った新しい面 ( A, Poin_, B )
   I, J :Integer;
   K, GK :Byte;
   F, G, C, D :TDelaFace2D;
begin
     Face_.Flag := True;  Star := [ Face_ ];  // 呼び出し側の契約: Face_ は追加点を円に含む

     I := 0;
     while I < Length( Star ) do  // ①マーク
     begin
          F := Star[ I ];  Inc( I );

          for K := 1 to 3 do
          begin
               G := F.Face[ K ];

               if not G.Flag and G.IsHitCircle( Poin_.Pos ) then
               begin
                    G.Flag := True;  Star := Star + [ G ];
               end;
          end;
     end;

     News := [];

     for I := 0 to High( Star ) do  // ②カーブ: 境界辺に新しい面を張り、外側と縫う
     begin
          F := Star[ I ];

          for K := 1 to 3 do
          begin
               G := F.Face[ K ];

               if G.Flag then Continue;  // キャビティの内部の辺

               GK := F.Corn[ K ];  // 外側の面から見た境界辺の番号

               with VertTableInc[ GK ] do C := NewFace( G.Poin[ L ], Poin_, G.Poin[ R ] );

               C.Face[ 2 ]  := G;  C.Corn[ 2 ]  := GK;
               G.Face[ GK ] := C;  G.Corn[ GK ] := 2 ;

               News := News + [ C ];
          end;
     end;

     for I := 0 to High( News ) do  // 新しい面どうしを追加点の周りで縫う。
     begin                          // C = ( A, P, B ) の辺 ( P, B ) の相手は、B から始まる面 D = ( B, P, X )
          C := News[ I ];

          for J := 0 to High( News ) do
          begin
               D := News[ J ];

               if D.Poin[ 1 ] = C.Poin[ 3 ] then
               begin
                    C.Face[ 1 ] := D;  C.Corn[ 1 ] := 3;
                    D.Face[ 3 ] := C;  D.Corn[ 3 ] := 1;

                    Break;
               end;
          end;
     end;

     for I := 0 to High( Star ) do Star[ I ].Free;  // マークは面ごと消える
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

function TDelaunay2D.PoinCode( const Poin_:TTriPoin<TSingle2D> ) :Integer;
begin
     if Poin_ = _PoinInf then Result := -2
                         else Result := inherited;
end;

function TDelaunay2D.CodePoin( const Code_:Integer ) :TTriPoin<TSingle2D>;
begin
     if Code_ = -2 then Result := _PoinInf
                   else Result := inherited;
end;

function TDelaunay2D.LoadFace :TTriFace<TSingle2D>;
begin
     Result := TDelaFace2D.Create( Self );
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
     if Poins.ChildrsN = 0 then Exit( nil );  // 点が無ければ面も無い

     F := JumpPoin( Pos_ ).Face;  // ジャンプ：無作為標本の最近点のアンカー面から出発する

     if not Assigned( F ) then Exit( ScanCircleFace( Pos_ ) );  // 面がまだ無い（点が1つだけ）

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

function TDelaunay2D.FindMaxCircle :TDelaFace2D;
var
   F :TDelaFace2D;
   V :TSingle3D;
   R2, Rm :Single;
begin
     Result := nil;  Rm := -1;

     for F in Faces do
     begin
          if F.InfCorn <> 0 then Continue;  // 無限遠面（半径無限大の空円）は除く

          V := F.Circum;  // 同次外心 → 外心 ( X, Y )/W と、頂点までの距離の平方が半径の平方

          R2 := Distance2( TSingle2D.Create( V.X, V.Y ) / V.Z, F.Poin[ 1 ].Pos );

          if R2 > Rm then begin  Rm := R2;  Result := F;  end;
     end;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.AddPoin( const Pos_:TSingle2D ) :TDelaPoin2D;
var
   F :TDelaFace2D;
begin
     case Poins.ChildrsN of
       0: begin
               if Distance2( Pos_, Pos_ ) <> 0 then Exit( nil );  // 座標が数でない（NaN・∞）

               Result := NewPoin( Pos_ );  _OnChange.Run( Self );
          end;
       1: begin
               if not ( Distance2( Pos_, Poins[ 0 ].Pos ) > 0 ) then Exit( nil );  // 重複（NaN も含めて、離れていると言えなければ弾く）

               Result := NewPoin( Pos_ );  InitFace;  _OnChange.Run( Self );
          end;
     else
          F := HitCircleFace( Pos_ );

          if Assigned( F ) then Result := AddPoin( Pos_, F )
                           else Result := nil;  // 退化配置（重複・既存の稜線の延長上）は追加できない
     end;
end;

function TDelaunay2D.AddPoin( const Pos_:TSingle2D; const Face_:TDelaFace2D ) :TDelaPoin2D;
begin
     Result := NewPoin( Pos_ );  InsertPoin( Result, Face_ );  _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TDelaunay2D.FindNearPoin( const Pos_:TSingle2D; out Poin_:TDelaPoin2D ) :Single;
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

          if not Assigned( F0 ) then Exit;  // 面がまだ無い（点が1つだけ）

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
   F :TDelaFace2D;
   I :Byte;
   W :TDelaPoin2D;
   D :Single;
begin
     Poin_ := nil;  Result := Infinity;

     if Poins.ChildrsN = 0 then Exit;

     F := HitCircleFace( Pos_ );  // ジャンプ＆ウォークで Pos_ を空円に含む面へ直行し、その面の最も近い頂点から出発する

     P := nil;

     if Assigned( F ) then
     begin
          for I := 1 to 3 do
          begin
               W := F.Poin[ I ];

               if W.Inf then Continue;

               D := Distance2( Pos_, W.Pos );

               if ( P = nil ) or ( D < Dm ) then begin  P := W;  Dm := D;  end;
          end;
     end;

     if P = nil then P := JumpPoin( Pos_ );  // 面が定まらない退化（既存頂点との一致・面が無い少数点）は無作為標本から

     Dm := Distance2( Pos_, P.Pos );  // ドロネー辺を伝ってより近い隣接頂点へ降下する。移るたびに
                                      // 距離が厳密に縮むので、Pos_ をボロノイ領域に含む点 ＝
     while GoNear do ;                // 最近傍点で必ず停止する

     Poin_ := P;  Result := Roo2( Dm );
end;

//------------------------------------------------------------------------------

function TDelaunay2D.DeletePoin( const Poin_:TDelaPoin2D ) :Boolean;
type
    TBond = record            // 穴の境界辺（PA → PB・穴は左側）と、その外側の面（フック）・内側の埋め草
      PA, PB :TDelaPoin2D;
      HF :TDelaFace2D;  HC :Byte;
      FF :TDelaFace2D;  FC :Byte;
    end;
var
   Star  :TArray<TDelaFace2D>;   // Poin_ の星（Poin_ を含む面。取り除くと星型の穴が開く）
   Bonds :TArray<TBond>;         // 穴の境界（星の面ごとに、Poin_ の対辺が1本）
   Links :TArray<TDelaPoin2D>;   // 有限のリンク頂点（重複なし）
   Minis :TArray<TDelaFace2D>;   // リンク頂点だけの小さなドロネー図（同じ集合の中の独立した成分）
   Fills :TArray<TDelaFace2D>;   // Minis のうち、穴を埋める面
   Hull  :Boolean;               // 穴が凸包に接しているか（リンクに無限遠頂点が現れるか）
   AF :TDelaFace2D;    AC :Byte; // 無限遠頂点のアンカーの控え
   F :TDelaFace2D;
   I :Integer;
//･･･････････････････････････････････････････
     function Has( const Fs_:TArray<TDelaFace2D>; const F_:TDelaFace2D ) :Boolean;
     var
        I :Integer;
     begin
          for I := 0 to High( Fs_ ) do if Fs_[ I ] = F_ then Exit( True );

          Result := False;
     end;
//･･･････････････････････････････････････････
     function IsSeam( const F_:TDelaFace2D; const C_:Byte ) :Boolean;  // 面のこの辺は縫い目（境界辺の内側）か
     var
        I :Integer;
     begin
          for I := 0 to High( Bonds ) do with Bonds[ I ] do if ( FF = F_ ) and ( FC = C_ ) then Exit( True );

          Result := False;
     end;
//･･･････････････････････････････････････････
     procedure CollectStar;  // 星・穴の境界・リンクを集める（構造を読むだけで、何も壊さない）
     var
        F :TDelaFace2D;
        C, R :Byte;
        B :TBond;
        P :TDelaPoin2D;
        I :Integer;
        Known :Boolean;
     begin
          F := Poin_.Face;  C := Poin_.Corn;  // 頂点のアンカーから所属面へ直行する

          repeat
                Star := Star + [ F ];

                B.PA := F.Poin[ VertTableInc[ C ].L ];  // Poin_ の対辺。面の向きのまま PA → PB と辿ると穴は左側
                B.PB := F.Poin[ VertTableInc[ C ].R ];
                B.HF := F.Face[ C ];
                B.HC := F.Corn[ C ];
                B.FF := nil;
                B.FC := 0;

                Bonds := Bonds + [ B ];

                Hull := Hull or B.PA.Inf or B.PB.Inf;

                P := B.PA;  // リンク頂点は境界辺の始点として現れる（無限遠頂点と重複は除く）

                if not P.Inf then
                begin
                     Known := False;

                     for I := 0 to High( Links ) do if Links[ I ] = P then begin  Known := True;  Break;  end;

                     if not Known then Links := Links + [ P ];
                end;

                R := VertTableInc[ C ].R;  // 次の面へ

                C := VertTableInc[ F.Corn[ R ] ].R;
                F :=               F.Face[ R ]    ;
          until F = Star[ 0 ];
     end;
//･･･････････････････････････････････････････
     function MiniFaces :TArray<TDelaFace2D>;  // 小さなドロネー図の全面（成分の接続を辿って集める）
     var
        I :Integer;
        K :Byte;
        N :TDelaFace2D;
     begin
          Result := [ Links[ 0 ].Face ];  // 種の頂点のアンカーは、面が張り直されるたびに更新されて常に成分内を指す

          I := 0;
          while I < Length( Result ) do
          begin
               for K := 1 to 3 do
               begin
                    N := Result[ I ].Face[ K ];

                    if not Has( Result, N ) then Result := Result + [ N ];
               end;

               Inc( I );
          end;
     end;
//･･･････････････････････････････････････････
     function BuildMini :Boolean;  // リンク頂点だけの小さなドロネー図を、同じ集合の中に逐次添加法で作る
     var                           // （入れ子の TDelaunay2D は作らない。面は同じ集合が所有する別成分になる）
        I, Rest :Integer;
        P :TDelaPoin2D;
        F, H :TDelaFace2D;
        Done :TArray<Boolean>;
        Progress :Boolean;
     begin
          Result := False;

          SeedFace( Links[ 0 ], Links[ 1 ] );

          SetLength( Done, Length( Links ) );

          Done[ 0 ] := True;  Done[ 1 ] := True;

          Rest := Length( Links ) - 2;

          repeat  // 挿入が新たな面を張ると、種の直線上などで見送られた頂点が入れるようになるので、
                  // 挿入が起きなくなるまで繰り返す（有界なローカル構築の順序調整）
                Progress := False;

                for I := 2 to High( Links ) do
                begin
                     if Done[ I ] then Continue;

                     P := Links[ I ];

                     H := nil;  // 位置検索は総当たりでよい（成分はリンクの大きさしかない）

                     for F in MiniFaces do
                     begin
                          if F.IsHitCircle( P.Pos ) then begin  H := F;  Break;  end;
                     end;

                     if H = nil then Continue;

                     InsertPoin( P, H );

                     Done[ I ] := True;  Dec( Rest );  Progress := True;
                end;
          until not Progress;

          if Rest > 0 then Exit;  // 退化（どの外接円にも入らない頂点が残った）→ 埋め戻し不能

          Minis := MiniFaces;

          Result := True;
     end;
//･･･････････････････････････････････････････
     function MatchSeams :Boolean;  // 境界辺 PA → PB を同じ向きで含む面（＝辺の左の面 ＝ 穴の側の面）を探す
     var
        I, J :Integer;
        F :TDelaFace2D;
        C :Byte;
     begin
          Result := False;

          for I := 0 to High( Bonds ) do
          begin
               with Bonds[ I ] do
               begin
                    for J := 0 to High( Minis ) do
                    begin
                         F := Minis[ J ];

                         for C := 1 to 3 do
                         begin
                              if ( F.Poin[ C ] = PA ) and ( F.Poin[ VertTableInc[ C ].L ] = PB ) then
                              begin
                                   FF := F;
                                   FC := VertTableInc[ C ].R;  // 辺 PA → PB の対頂点
                              end;
                         end;
                    end;

                    if FF = nil then Exit;  // 境界辺が現れない（共円の同数で別の対角が選ばれた等）→ 埋め戻し不能
               end;
          end;

          for I := 1 to High( Bonds ) do  // 同じ縫い目が2本の境界辺に割り当たる退化（潰れた穴）も埋め戻し不能
          begin
               for J := 0 to I-1 do
               begin
                    if ( Bonds[ I ].FF = Bonds[ J ].FF ) and ( Bonds[ I ].FC = Bonds[ J ].FC ) then Exit;
               end;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
     function FloodFills :Boolean;  // 埋め草から縫い目を越えずに広がり、閉包の境界が穴の境界と一致することを確かめる
     var
        I :Integer;
        K, C :Byte;
        F, N :TDelaFace2D;
     begin
          Result := False;

          Fills := [];

          for I := 0 to High( Bonds ) do
          begin
               if not Has( Fills, Bonds[ I ].FF ) then Fills := Fills + [ Bonds[ I ].FF ];
          end;

          I := 0;
          while I < Length( Fills ) do
          begin
               F := Fills[ I ];

               for K := 1 to 3 do
               begin
                    if IsSeam( F, K ) then Continue;  // 縫い目は越えない

                    N := F.Face[ K ];

                    if not Has( Fills, N ) then Fills := Fills + [ N ];
               end;

               Inc( I );
          end;

          for I := 0 to High( Fills ) do  // 無限遠面が埋め草になるのは、穴が凸包に接しているときだけ
          begin
               if ( Fills[ I ].InfCorn > 0 ) and not Hull then Exit;
          end;

          for I := 0 to High( Bonds ) do  // 縫い目の外側は、捨てられる面か、それ自身も縫い目（穴が自分と接する退化）で
          begin                           // なければならない ―― これで閉包の境界が穴の境界とちょうど一致する
               with Bonds[ I ] do
               begin
                    N := FF.Face[ FC ];
                    C := FF.Corn[ FC ];
               end;

               if Has( Fills, N ) and not IsSeam( N, C ) then Exit;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
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
          Hull := False;

          CollectStar;

          if Length( Bonds ) = 2 then  // 次数2（共線被覆の端点など）：境界辺2本は同じ辺の裏表 → 外側どうしを直接貼り合わせる
          begin
               if ( Bonds[ 0 ].PA <> Bonds[ 1 ].PB ) or ( Bonds[ 0 ].PB <> Bonds[ 1 ].PA ) then Exit;

               Bonds[ 0 ].HF.Face[ Bonds[ 0 ].HC ] := Bonds[ 1 ].HF;  Bonds[ 0 ].HF.Corn[ Bonds[ 0 ].HC ] := Bonds[ 1 ].HC;
               Bonds[ 1 ].HF.Face[ Bonds[ 1 ].HC ] := Bonds[ 0 ].HF;  Bonds[ 1 ].HF.Corn[ Bonds[ 1 ].HC ] := Bonds[ 0 ].HC;

               for F in Star do F.Free;

               Poin_.Free;

               Bonds[ 0 ].HF.BindPoins;  // 星と共に消えたアンカーを張り直す
               Bonds[ 1 ].HF.BindPoins;
          end
          else
          begin
               if Length( Links ) < 2 then Exit;  // 埋め戻しの種が張れない

               AF := _PoinInf.Face;  AC := _PoinInf.Corn;  // 小さなドロネー図がアンカーを奪うので控えておく

               if BuildMini and MatchSeams and FloodFills then
               begin
                    for I := 0 to High( Bonds ) do  // 縫い付け（埋め草の面と外側の面を貼り合わせる）
                    begin
                         with Bonds[ I ] do
                         begin
                              HF.Face[ HC ] := FF;  HF.Corn[ HC ] := FC;
                              FF.Face[ FC ] := HF;  FF.Corn[ FC ] := HC;
                         end;
                    end;

                    _PoinInf.Face := AF;  _PoinInf.Corn := AC;  // 先に戻す（星と共に消えるなら、後の張り直しが引き受ける）

                    for F in Star  do F.Free;                              // 星を取り除き、
                    for F in Minis do if not Has( Fills, F ) then F.Free;  // 使わなかった埋め草を捨てる

                    Poin_.Free;

                    for F in Fills do F.BindPoins;  // 埋め草に現れる頂点（全リンク頂点）のアンカーを張り直す
               end
               else
               begin
                    _PoinInf.Face := AF;  _PoinInf.Corn := AC;  // 何も壊していない ―― 小さなドロネー図だけ消して戻る

                    for F in MiniFaces do F.Free;

                    for F in Star do F.BindPoins;

                    Exit;
               end;
          end;
     end;

     _OnChange.Run( Self );

     Result := True;
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.LoadFromFile( const FileName_:String );
begin
     inherited;

     _OnChange.Run( Self );
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
