unit LUX.Delaunay.D3;

// 3D ドロネー図（逐次添加法・無限遠頂点方式）
//
//【モデル】
// ・LUX.Data.Model.TetraFlip.D3 の四面体メッシュを継承し、ドロネー固有の機能だけを
//   加える。プロパティの型付けは TetraFlip の型付け層が行うため、自分の派生クラスを
//   型引数に与えるだけでよい。
//     TDelaPoin3D    … TTetraPoin3D<TDelaCell3D>                    ＋ 無限遠フラグ（Inf）
//     TDelaPoinSet3D … TTetraPoinSet3D<TDelaPoin3D>
//     TDelaCell3D    … TTetraCell3D<TDelaPoin3D,TDelaCell3D>        ＋ 空球判定・同次外心
//     TDelaCellSet3D … TTetraCellSet3D<TDelaCell3D,TDelaPoinSet3D>
//     TDelaunay3D    … TDelaCellSet3D ＋ 点の追加・削除のアルゴリズム
//   頂点・胞の接続（Poin / Cell / Corn / Bond）と巡回表（VertTable / BondTable）、
//   面の縫合（Weld）、隣接検査（CheckCells）、点と胞の所有は TetraFlip 層が担う。
//
//【アルゴリズム】
// ・スーパーテトラを使わず、凸包の外側を「無限遠胞」で覆う。モデルはただ一つの
//   無限遠頂点 PoinInf を持ち、凸包の各面は ( PoinInf, Pi, Pj, Pk ) からなる胞で
//   閉じられる。Poin[] に nil は現れない。最初の3点は無限遠頂点を頂点に持つ鏡像の
//   胞2つで全空間を二重に覆い、4点目からは通常の追加処理がそのまま働く。
// ・空球判定は同次リフトによる単一の行列式で行う。判定点を原点に平行移動し、
//     有限点　 → ( X-Px, Y-Py, Z-Pz, (X-Px)²+(Y-Py)²+(Z-Pz)² )
//     無限遠点 → ( 0, 0, 0, 1 )
//   の4行を並べた 4×4 行列式が正なら「球の内側」。無限遠頂点を含む胞では
//   この式が自動的に半空間判定（orient3d）へ退化する。球と平面（＝半径無限大の
//   球）がリフト空間では同じ「超平面」になることの帰結であり、場合分けは要らない。
//   行列式は必ず近傍の点を基準に平行移動してから倍精度で評価する（桁落ち対策。
//   向きの判定や外心も同様で、絶対座標のまま評価する式は存在しない）。
// ・点の追加は Bowyer-Watson 法の2相方式。①新しい点を球に含む胞群（キャビティ）を
//   Flag で塗り広げて集め（マーク）、②境界面ごとに新しい胞を張って外側と縫い、
//   最後に塗った胞をまとめて解放する（カーブ）。マークは冪等なので、キャビティの
//   双対が木にならない 3D でも（同じ胞に複数の経路で到達しても）二重処理は起こらず、
//   削除済みの胞への再突入も構造的に起こらない（2D と同型・プレースホルダ不要）。
// ・点の削除は「星の除去と埋め戻し」。頂点の星（頂点を含む胞の集合）を取り除くと
//   星型の穴が開く。穴の境界（リンク）の頂点だけから成る小さなドロネー図を、同じ
//   集合の中の独立した成分として逐次添加法で作り（入れ子の TDelaunay3D は作らない）、
//   その中から穴を埋める胞 ―― 境界面を鏡像の向きで貼り合わせられる胞（CanWeld）から、
//   境界を越えずに届く胞 ―― を切り出して、穴の縁に縫い付ける（Weld）。埋め草の
//   切り出しも縫い付けも組合せ的な検査だけで確定し、フリップの探索を含まない。
//   検査に通らない退化配置では、元の分割を一切壊さずに False を返す。
// ・追加も削除も、失敗は戻り値で表す。AddPoin は追加できなければ（重複・最初の3点の
//   共線・既存の稜線の延長上など）nil を、DeletePoin は削除できなければ False を返し、
//   分割は常に正しいまま保たれる。遅延挿入のような救済機構は持たない。最初の2点は
//   無条件に、3点目は共線でなければ受け入れ、3点目以降は常に胞が存在する。
// ・無限遠頂点は TDelaPoin3DInf として派生し、リフト（Lift = 0,0,0,1）と内外判定
//   （InSphered = 向きの行列式）を多態で差し替える。有限点と無限遠点、有限半径の
//   球と平面（無限半径の球）は同じ式で扱われ、述語にフラグの分岐は存在しない。
//   胞の向きの検査も「無限遠点が球の外にあること」として同じ述語で書ける。
// ・胞の外心は同次座標 Circum = ( X, Y, Z, W ) で取り出す。リフト空間で4頂点を通る
//   超平面の係数（小行列式）そのものであり、有限胞は ( X/W, Y/W, Z/W ) が外心、
//   無限遠胞は自然に W = 0 へ退化して ( X, Y, Z ) がボロノイ辺の外向きの方向を表す。
//   計算に分岐も除算もなく、中心＋半径という表現の押し付けが要らない。
// ・追加点を空球に含む胞の検索はジャンプ＆ウォーク。点集合から n^(1/4) 個を無作為に
//   引き、最も近い点のアンカー胞から、追加点が外側にある面を越えて隣へ渡り続ける
//   （期待 O(n^(1/4))）。面の向き判定は統一述語の退化形 InSphere( A, B, C, ∞, P )
//   であり、凸包外の点では歩行が自然に無限遠胞へ入って止まる。標本は毎回引き直す
//   ため、性能はクエリの履歴や位置に依らず領域全体で一様。
// ・最近傍検索（FindNearPoin）もジャンプ＆ウォークの着地胞から始める。Pos_ を空球に
//   含む胞の頂点は Pos_ の近くにいるので、その中の最も近い頂点から、ドロネー辺を
//   伝ってより近い隣接頂点へ降下する。移るたびに距離が厳密に縮むため、Pos_ を
//   ボロノイ領域に含む点 ＝ 最近傍点で必ず停止する（期待 O(n^(1/4)) ＋ O(1) 段の降下）。

interface //#################################################################### ■

uses LUX,
     LUX.D3,
     LUX.D4,
     LUX.Data.Model.TetraFlip.core,
     LUX.Data.Model.TetraFlip.D3;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     TDelaPoin3D    = class;
     TDelaPoin3DInf = class;
     TDelaPoinSet3D = class;
     TDelaCell3D    = class;
     TDelaCellSet3D = class;
     TDelaunay3D    = class;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin3D

     // 頂点。TetraFlip の点にリフト（同次化）と内外判定を加えたもの。
     TDelaPoin3D = class( TTetraPoin3D<TDelaCell3D> )
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
       function Lift( const Pos_:TSingle3D ) :TDouble4D; virtual;  // Pos_ を原点とするリフト座標 ( X, Y, Z, X²+Y²+Z² )
       function InSphered( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Double; virtual;  // 球 ( P0, P1, P2, P3 ) に対する自分の内外（正 = 内側）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin3DInf

     // 無限遠頂点。リフトと内外判定を多態で差し替える（述語にフラグの分岐は存在しない）。
     TDelaPoin3DInf = class( TDelaPoin3D )
     private
     protected
       ///// A C C E S S O R
       function GetInf :Boolean; override;
       ///// M E T H O D
       function LiftW :Single; override;  // 同次成分（無限遠点 = 0）
     public
       ///// M E T H O D
       function Lift( const Pos_:TSingle3D ) :TDouble4D; override;  // どこから見ても ( 0, 0, 0, 1 )
       function InSphered( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Double; override;  // 球の向き（平面への退化）で決まる
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet3D

     // 点集合。
     TDelaPoinSet3D = class( TTetraPoinSet3D<TDelaPoin3D> )
     private
     protected
       ///// M E T H O D
       function LoadPoin( const Pos_:TSingle3D ) :TTetraPoin<TSingle3D>; override;  // 読み込む点を TDelaPoin3D として生成する
     public
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaCell3D

     // 四面体。TetraFlip の胞に空球判定と同次外心を加えたもの。
     TDelaCell3D = class( TTetraCell3D<TDelaPoin3D,TDelaCell3D> )
     private
     protected
       ///// A C C E S S O R
       function GetInfCorn :Shortint;
       function GetCircum :TSingle4D;
     public
       ///// P R O P E R T Y
       property InfCorn :Shortint  read GetInfCorn;  // 無限遠頂点の番号（-1 = 有限胞）
       property Circum  :TSingle4D read GetCircum ;  // 同次外心 ( X, Y, Z, W )。有限胞は ( X/W, Y/W, Z/W ) が外心、無限遠胞は W = 0 で ( X, Y, Z ) が外向きの方向
       ///// M E T H O D
       class function InSphere( const P0_,P1_,P2_,P3_:TDelaPoin3D; const Pos_:TSingle3D ) :Double;  // 統一リフト行列式（正 = 球の内側）
       function IsHitSphere( const Pos_:TSingle3D ) :Boolean;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaCellSet3D

     // 胞集合。
     TDelaCellSet3D = class( TTetraCellSet3D<TDelaCell3D,TDelaPoinSet3D> )
     private
     protected
       ///// A C C E S S O R
       function GetPoins :TDelaPoinSet3D;
     public
       ///// P R O P E R T Y
       property Poins :TDelaPoinSet3D read GetPoins;  // 有限頂点のみ（PoinSet の別名）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay3D

     TDelaunay3D = class( TDelaCellSet3D )
     private
       _PoinInf  :TDelaPoin3D;
       _OnChange :TDelegates;
       ///// A C C E S S O R
       function GetCells :TDelaCellSet3D;
       ///// M E T H O D
       procedure SeedCells( const P0_,P1_,P2_:TDelaPoin3D );
       procedure InitCell;
       procedure InsertPoin( const Poin_:TDelaPoin3D; const Cell_:TDelaCell3D );
       function JumpPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
       function ScanSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;
       procedure CollectStar( const Poin_:TDelaPoin3D; var Cells_:TArray<TDelaCell3D> );
     protected
       ///// M E T H O D
       function NewPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
       function NewCell( const Poin0_,Poin1_,Poin2_,Poin3_:TDelaPoin3D ) :TDelaCell3D;
       function PoinCode( const Poin_:TTetraPoin<TSingle3D> ) :Integer; override;  // 無限遠頂点 = -2
       function CodePoin( const Code_:Integer ) :TTetraPoin<TSingle3D>; override;  // -2 = 無限遠頂点
       function LoadCell :TTetraCell<TSingle3D>; override;                         // 読み込む胞を TDelaCell3D として生成する
     public
       constructor Create; overload; override;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property PoinInf  :TDelaPoin3D    read _PoinInf ;  // 唯一の無限遠頂点（点集合には属さない）
       property Cells    :TDelaCellSet3D read GetCells ;  // 胞の集合（＝自分自身）
       property OnChange :TDelegates     read _OnChange;  // 構造が変化したときに発火（Add / Del で多播購読）
       ///// M E T H O D
       function HitSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;  // Pos_ を空球に含む胞（ジャンプ＆ウォーク・期待 O(n^(1/4))）
       function FindMaxCircle :TDelaCell3D;  // 無限遠胞（＝半径無限大の空球）を除く、最大半径の空球を持つ胞（有限胞が無ければ nil）
       function FindNearPoin( const Pos_:TSingle3D; out Poin_:TDelaPoin3D ) :Single;  // Pos_ の最近傍点と、そこまでの距離（点が無ければ nil と Infinity）
       function AddPoin( const Pos_:TSingle3D ) :TDelaPoin3D; overload;     // 点の追加（退化配置で追加できなければ nil）
       function AddPoin( const Pos_:TSingle3D; const Cell_:TDelaCell3D ) :TDelaPoin3D; overload;
       function DeletePoin( const Poin_:TDelaPoin3D ) :Boolean;             // 点の削除（退化配置で埋め戻せなければ、何も変えずに False）
       procedure LoadFromFile( const FileName_:String ); override;  // *.lxtc から復元（無限遠頂点も接続ごと再現される）
       procedure Clear; reintroduce;  // 点と胞を全消去する（PoinInf は残る）
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

uses System.Math;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Det3 / LiftDet

// 空間成分（X,Y,Z）のスカラー三重積
function Det3( const A_,B_,C_:TDouble4D ) :Double;
begin
     Result := DotProduct( TDouble3D.Create( A_.X, A_.Y, A_.Z ),
             CrossProduct( TDouble3D.Create( B_.X, B_.Y, B_.Z ),
                           TDouble3D.Create( C_.X, C_.Y, C_.Z ) ) );
end;

// 4行のリフト行列式（列順 W,X,Y,Z の 4×4 行列式）。正の向きの胞で「内側 = 正」となる符号
function LiftDet( const L0_,L1_,L2_,L3_:TDouble4D ) :Double;
begin
     Result := + L0_.W * Det3( L1_, L2_, L3_ )
               - L1_.W * Det3( L0_, L2_, L3_ )
               + L2_.W * Det3( L0_, L1_, L3_ )
               - L3_.W * Det3( L0_, L1_, L2_ );
end;

// Single の点を倍精度へ持ち上げる（座標の差や外積を桁落ち・桁あふれなく評価するため）
function ToD3( const P_:TSingle3D ) :TDouble3D;
begin
     Result := TDouble3D.Create( P_.X, P_.Y, P_.Z );
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaPoin3D.GetInf :Boolean;
begin
     Result := False;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin3D.LiftW :Single;
begin
     Result := 1;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin3D.Lift( const Pos_:TSingle3D ) :TDouble4D;
begin
     with Result do
     begin
          X := Pos.X;  X := X - Pos_.X;  // 差分から先は倍精度で評価する
          Y := Pos.Y;  Y := Y - Pos_.Y;
          Z := Pos.Z;  Z := Z - Pos_.Z;
          W := X * X + Y * Y + Z * Z;
     end;
end;

function TDelaPoin3D.InSphered( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Double;
begin
     Result := TDelaCell3D.InSphere( P0_, P1_, P2_, P3_, Pos );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin3DInf

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaPoin3DInf.GetInf :Boolean;
begin
     Result := True;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin3DInf.LiftW :Single;
begin
     Result := 0;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoin3DInf.Lift( const Pos_:TSingle3D ) :TDouble4D;
begin
     with Result do
     begin
          X := 0;
          Y := 0;
          Z := 0;
          W := 1;
     end;
end;

function TDelaPoin3DInf.InSphered( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Double;
var
   B :TSingle3D;
//･･･････････････････････････････････････････
     function Homo( const P_:TDelaPoin3D ) :TDouble4D;  // 基準点 B へ平行移動した同次座標 ( X - W·Bx, Y - W·By, Z - W·Bz, W )。
     begin                                              // 無限遠点は ( 0, 0, 0, 0 ) となり行列式から自然に消える
          with Result do
          begin
               W := P_.LiftW;

               X := P_.Pos.X;  X := X - W * B.X;
               Y := P_.Pos.Y;  Y := Y - W * B.Y;
               Z := P_.Pos.Z;  Z := Z - W * B.Z;
          end;
     end;
//･･･････････････････････････････････････････
begin
     if not P0_.Inf then B := P0_.Pos  // 桁落ちを防ぐため、有限の頂点を基準に平行移動して評価する（行列式は不変）
                    else
     if not P1_.Inf then B := P1_.Pos
                    else B := P2_.Pos;

     // 無限遠点が球の内側にあるのは、球が負の向きのときだけ（正の向きの球は必ず無限遠点を外に置く）
     Result := - LiftDet( Homo( P0_ ), Homo( P1_ ), Homo( P2_ ), Homo( P3_ ) );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoinSet3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaPoinSet3D.LoadPoin( const Pos_:TSingle3D ) :TTetraPoin<TSingle3D>;
begin
     Result := TDelaPoin3D.Create( Pos_, Self );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaCell3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaCell3D.GetInfCorn :Shortint;
begin
     if Poin[ 0 ].Inf then Result := 0
                      else
     if Poin[ 1 ].Inf then Result := 1
                      else
     if Poin[ 2 ].Inf then Result := 2
                      else
     if Poin[ 3 ].Inf then Result := 3
                      else Result := -1;
end;

function TDelaCell3D.GetCircum :TSingle4D;
var
   B :TSingle3D;
   L0, L1, L2, L3 :TDouble4D;
   W0, W1, W2, W3 :Double;
   CX, CY, CZ, CW :Double;
begin
     // リフト空間で4頂点を通る超平面の係数（小行列式）。無限遠頂点の行は 0 となり、自然に W = 0（平面）へ退化する。
     // 桁落ちを防ぐため有限の頂点を基準に平行移動して評価し、最後に基準ぶんを同次で戻す
     if InfCorn <> 0 then B := Poin[ 0 ].Pos
                     else B := Poin[ 1 ].Pos;

     L0 := Poin[ 0 ].Lift( B );  W0 := Poin[ 0 ].LiftW;
     L1 := Poin[ 1 ].Lift( B );  W1 := Poin[ 1 ].LiftW;
     L2 := Poin[ 2 ].Lift( B );  W2 := Poin[ 2 ].LiftW;
     L3 := Poin[ 3 ].Lift( B );  W3 := Poin[ 3 ].LiftW;

     CX :=   + LiftDet( TDouble4D.Create( L0.Y, L0.Z, L0.W, W0 ),
                        TDouble4D.Create( L1.Y, L1.Z, L1.W, W1 ),
                        TDouble4D.Create( L2.Y, L2.Z, L2.W, W2 ),
                        TDouble4D.Create( L3.Y, L3.Z, L3.W, W3 ) );

     CY :=   - LiftDet( TDouble4D.Create( L0.X, L0.Z, L0.W, W0 ),
                        TDouble4D.Create( L1.X, L1.Z, L1.W, W1 ),
                        TDouble4D.Create( L2.X, L2.Z, L2.W, W2 ),
                        TDouble4D.Create( L3.X, L3.Z, L3.W, W3 ) );

     CZ :=   + LiftDet( TDouble4D.Create( L0.X, L0.Y, L0.W, W0 ),
                        TDouble4D.Create( L1.X, L1.Y, L1.W, W1 ),
                        TDouble4D.Create( L2.X, L2.Y, L2.W, W2 ),
                        TDouble4D.Create( L3.X, L3.Y, L3.W, W3 ) );

     CW := 2 * LiftDet( TDouble4D.Create( L0.X, L0.Y, L0.Z, W0 ),
                        TDouble4D.Create( L1.X, L1.Y, L1.Z, W1 ),
                        TDouble4D.Create( L2.X, L2.Y, L2.Z, W2 ),
                        TDouble4D.Create( L3.X, L3.Y, L3.Z, W3 ) );

     with Result do
     begin
          X := CX + CW * B.X;  // 有限胞は外心が B ぶん戻り、無限遠胞（ W = 0 ）は方向がそのまま残る
          Y := CY + CW * B.Y;
          Z := CZ + CW * B.Z;
          W := CW;
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

class function TDelaCell3D.InSphere( const P0_,P1_,P2_,P3_:TDelaPoin3D; const Pos_:TSingle3D ) :Double;
begin
     Result := LiftDet( P0_.Lift( Pos_ ), P1_.Lift( Pos_ ), P2_.Lift( Pos_ ), P3_.Lift( Pos_ ) );
end;

function TDelaCell3D.IsHitSphere( const Pos_:TSingle3D ) :Boolean;
begin
     Result := InSphere( Poin[ 0 ], Poin[ 1 ], Poin[ 2 ], Poin[ 3 ], Pos_ ) > 0;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaCellSet3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaCellSet3D.GetPoins :TDelaPoinSet3D;
begin
     Result := PoinSet;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaunay3D.GetCells :TDelaCellSet3D;
begin
     Result := Self;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunay3D.SeedCells( const P0_,P1_,P2_:TDelaPoin3D );
var
   C0, C1 :TDelaCell3D;
begin
     C0 := NewCell( _PoinInf, P0_, P1_, P2_ );  // 3点を通る平面の両側を覆う鏡像の無限遠胞（共線でない3点が種になる）
     C1 := NewCell( _PoinInf, P0_, P2_, P1_ );

     C0.Weld( 0, C1, 0 );
     C0.Weld( 1, C1, 1 );
     C0.Weld( 2, C1, 3 );
     C0.Weld( 3, C1, 2 );
end;

procedure TDelaunay3D.InitCell;
begin
     SeedCells( Poins[ 0 ], Poins[ 1 ], Poins[ 2 ] );  // 最初の3点（共線でないことは AddPoin が保証している）
end;

//------------------------------------------------------------------------------

procedure TDelaunay3D.InsertPoin( const Poin_:TDelaPoin3D; const Cell_:TDelaCell3D );
// 2相方式。①マーク: 追加点を球に含む胞を Flag で塗り広げて集める。塗りは冪等なので、
// キャビティの双対が木にならない 3D でも（同じ胞に複数の経路で到達しても）二重処理は
// 起こらない。②カーブ: 境界面（塗った胞と外側の胞の間の面）ごとに新しい胞を張って
// 外側と縫い、新しい胞どうしを追加点の周りで縫い、最後に塗った胞をまとめて解放する
// （解放は縫合の後なので、削除済みの胞への再突入は構造的に起こらない）
var
   Star :TArray<TDelaCell3D>;  // キャビティ（塗った胞）
   News :TArray<TDelaCell3D>;  // 境界面に張った新しい胞 ( Poin_, F1, F3, F2 )
   I, J :Integer;
   K, GK :Byte;
   CA, CB :Shortint;
   T, G, C, D :TDelaCell3D;
   A, B :TDelaPoin3D;
begin
     Cell_.Flag := 1;  Star := [ Cell_ ];  // 呼び出し側の契約: Cell_ は追加点を球に含む

     I := 0;
     while I < Length( Star ) do  // ①マーク
     begin
          T := Star[ I ];  Inc( I );

          for K := 0 to 3 do
          begin
               G := T.Cell[ K ];

               if ( G.Flag = 0 ) and G.IsHitSphere( Poin_.Pos ) then
               begin
                    G.Flag := 1;  Star := Star + [ G ];
               end;
          end;
     end;

     News := [];

     for I := 0 to High( Star ) do  // ②カーブ: 境界面に新しい胞を張り、外側と縫う
     begin
          T := Star[ I ];

          for K := 0 to 3 do
          begin
               G := T.Cell[ K ];

               if G.Flag <> 0 then Continue;  // キャビティの内部の面

               GK := T.Corn[ K ];  // 外側の胞から見た境界面の番号

               // 境界面の頂点は外側の胞の正準順 VertTable[ GK ] で取り出す。頂点 GK（外側の
               // 頂点）を追加点で置き換えると向きが反転するため、奇置換で正の向きに戻す
               with VertTable[ GK ] do C := NewCell( Poin_, G.Poin[ _[ 1 ] ], G.Poin[ _[ 3 ] ], G.Poin[ _[ 2 ] ] );

               C.Weld( 0, G, GK );  // 追加点の対面（面0）を外側と縫う。回転コードは頂点の同一性から導出される

               News := News + [ C ];
          end;
     end;

     for I := 0 to High( News ) do  // 新しい胞どうしを追加点の周りで縫う。
     begin                          // 側面 K（追加点を含む面）の相手は、残る2頂点 A, B を共有する胞
          C := News[ I ];

          for K := 1 to 3 do
          begin
               if C.Cell[ K ] <> C then Continue;  // 縫合済み（Weld は両側を張る）

               A := C.Poin[ K mod 3 + 1 ];          // 側面 K の頂点 = { Poin_, A, B }（1..3 のうち K 以外の2つ）
               B := C.Poin[ ( K + 1 ) mod 3 + 1 ];

               for J := 0 to High( News ) do
               begin
                    D := News[ J ];

                    if D = C then Continue;

                    CA := D.CornOf( A );
                    CB := D.CornOf( B );

                    if ( CA > 0 ) and ( CB > 0 ) then  // A も B も持つ胞は境界面の隣だけ
                    begin
                         C.Weld( K, D, 6 - CA - CB );  // D の残る側面が合わせ面

                         Break;
                    end;
               end;
          end;
     end;

     for I := 0 to High( Star ) do Star[ I ].Free;  // マークは胞ごと消える
end;

//------------------------------------------------------------------------------

function TDelaunay3D.JumpPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
var
   N, K, I :Integer;
   P :TDelaPoin3D;
   D, Dm :Single;
begin
     N := Poins.ChildrsN;

     Result := Poins[ Random( N ) ];  Dm := Distance2( Pos_, Result.Pos );

     K := 1;  while K * K * K * K < N do Inc( K );  // 標本数 = ⌈n^(1/4)⌉（歩行距離との釣り合いで合計が期待 O(n^(1/4)) になる）

     for I := 2 to K do
     begin
          P := Poins[ Random( N ) ];  D := Distance2( Pos_, P.Pos );

          if D < Dm then begin  Dm := D;  Result := P;  end;
     end;
end;

function TDelaunay3D.ScanSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;
var
   C :TDelaCell3D;
begin
     for C in Cells do  // 全胞走査（歩行の保険。退化配置でのみ使われる）
     begin
          if C.IsHitSphere( Pos_ ) then Exit( C );
     end;

     Result := nil;
end;

//------------------------------------------------------------------------------

procedure TDelaunay3D.CollectStar( const Poin_:TDelaPoin3D; var Cells_:TArray<TDelaCell3D> );
var
   I :Integer;
   K :Byte;
   C, N :TDelaCell3D;
begin
     Cells_ := [];

     C := Poin_.Cell;

     if not Assigned( C ) then Exit;

     C.Flag := 1;  Cells_ := [ C ];

     I := 0;
     while I < Length( Cells_ ) do  // 頂点を含む面を渡って広がる（星のリンクは閉じた球面なので必ず尽きる）
     begin
          C := Cells_[ I ];

          for K := 0 to 3 do
          begin
               if C.Poin[ K ] = Poin_ then Continue;  // 頂点の対面だけは星の外へ出る

               N := C.Cell[ K ];

               if N.Flag = 0 then begin  N.Flag := 1;  Cells_ := Cells_ + [ N ];  end;
          end;

          Inc( I );
     end;

     for C in Cells_ do C.Flag := 0;  // フラグは常に 0 へ戻す（追加処理との共用）
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay3D.NewPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
begin
     Result := TDelaPoin3D.Create( Pos_, PoinSet );
end;

function TDelaunay3D.NewCell( const Poin0_,Poin1_,Poin2_,Poin3_:TDelaPoin3D ) :TDelaCell3D;
begin
     Result := TDelaCell3D.Create( Self );

     Result.Poin[ 0 ] := Poin0_;
     Result.Poin[ 1 ] := Poin1_;
     Result.Poin[ 2 ] := Poin2_;
     Result.Poin[ 3 ] := Poin3_;

     Result.BindPoins;  // 頂点のアンカーを張り直す（削除時の星探索が O(1) で始まる）
end;

function TDelaunay3D.PoinCode( const Poin_:TTetraPoin<TSingle3D> ) :Integer;
begin
     if Poin_ = _PoinInf then Result := -2
                         else Result := inherited;
end;

function TDelaunay3D.CodePoin( const Code_:Integer ) :TTetraPoin<TSingle3D>;
begin
     if Code_ = -2 then Result := _PoinInf
                   else Result := inherited;
end;

function TDelaunay3D.LoadCell :TTetraCell<TSingle3D>;
begin
     Result := TDelaCell3D.Create( Self );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunay3D.Create;
begin
     inherited;

     _PoinInf := TDelaPoin3DInf.Create( TSingle3D.Create( 0, 0, 0 ) );
end;

destructor TDelaunay3D.Destroy;
begin
     inherited;        // 点と胞は集合ごと解放される

     _PoinInf.Free;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay3D.HitSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;
var
   C :TDelaCell3D;
   N, O, I :Integer;
   E :Byte;
   K :Shortint;
begin
     if Poins.ChildrsN = 0 then Exit( nil );  // 点が無ければ胞も無い

     C := JumpPoin( Pos_ ).Cell;  // ジャンプ：無作為標本の最近点のアンカー胞から出発する

     if not Assigned( C ) then Exit( ScanSphereCell( Pos_ ) );  // 胞がまだ無い少数点（1〜2点）

     for N := 1 to 4 * ChildrsN + 8 do  // ウォーク：Pos_ が外側にある面を越えて隣へ渡り続ける（胞数程度で必ず着く）
     begin
          if C.InfCorn >= 0 then  // 無限遠胞（凸包外の楔）
          begin
               if C.IsHitSphere( Pos_ ) then Exit( C );  // Pos_ は凸包面の外側 → この半空間が空球

               C := C.Cell[ Byte( C.InfCorn ) ];  // 凸包の内側へ渡る
          end
          else
          begin
               K := -1;

               O := Random( 4 );  // 調べる面の順を無作為化した確率的歩行（共球退化での振動を防ぐ）

               for I := 0 to 3 do
               begin
                    E := ( O + I ) mod 4;

                    with VertTable[ E ] do  // 面の向き判定は統一述語の退化形（第4点に無限遠頂点を与えると orient3d になる）
                    begin
                         if TDelaCell3D.InSphere( C.Poin[ _[ 1 ] ], C.Poin[ _[ 2 ] ], C.Poin[ _[ 3 ] ], _PoinInf, Pos_ ) > 0 then K := E;
                    end;

                    if K >= 0 then Break;
               end;

               if K >= 0 then C := C.Cell[ Byte( K ) ]
               else
               if C.IsHitSphere( Pos_ ) then Exit( C )                         // 内包胞に到達（四面体 ⊆ 外接球）
                                        else Exit( ScanSphereCell( Pos_ ) );   // 共球・重複の退化 → 全胞走査で確定する
          end;
     end;

     Result := ScanSphereCell( Pos_ );  // 歩行が収束しない退化配置 → 全胞走査へ退避する
end;

//------------------------------------------------------------------------------

function TDelaunay3D.FindMaxCircle :TDelaCell3D;
var
   C :TDelaCell3D;
   V :TSingle4D;
   R2, Rm :Single;
begin
     Result := nil;  Rm := -1;

     for C in Cells do
     begin
          if C.InfCorn >= 0 then Continue;  // 無限遠胞（半径無限大の空球）は除く

          V := C.Circum;  // 同次外心 → 外心 ( X, Y, Z )/W と、頂点までの距離の平方が半径の平方

          R2 := Distance2( TSingle3D.Create( V.X, V.Y, V.Z ) / V.W, C.Poin[ 0 ].Pos );

          if R2 > Rm then begin  Rm := R2;  Result := C;  end;
     end;
end;

//------------------------------------------------------------------------------

function TDelaunay3D.AddPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
var
   C :TDelaCell3D;
begin
     case Poins.ChildrsN of
       0: begin
               if Distance2( Pos_, Pos_ ) <> 0 then Exit( nil );  // 座標が数でない（NaN・∞）

               Result := NewPoin( Pos_ );  _OnChange.Run( Self );
          end;
       1: begin
               if not ( Distance2( Pos_, Poins[ 0 ].Pos ) > 0 ) then Exit( nil );  // 重複（NaN も含めて、離れていると言えなければ弾く）

               Result := NewPoin( Pos_ );  _OnChange.Run( Self );
          end;
       2: begin
               // 共線なら胞を張れない（外積は倍精度で評価し、共線でないと言えなければ弾く）
               if not ( CrossProduct( ToD3( Pos_ ) - ToD3( Poins[ 0 ].Pos ), ToD3( Poins[ 1 ].Pos ) - ToD3( Poins[ 0 ].Pos ) ).Size2 > 0 ) then Exit( nil );

               Result := NewPoin( Pos_ );  InitCell;  _OnChange.Run( Self );
          end;
     else
          C := HitSphereCell( Pos_ );

          if Assigned( C ) then Result := AddPoin( Pos_, C )
                           else Result := nil;  // 退化配置（重複・既存の稜線の延長上など）は追加できない
     end;
end;

function TDelaunay3D.AddPoin( const Pos_:TSingle3D; const Cell_:TDelaCell3D ) :TDelaPoin3D;
begin
     Result := NewPoin( Pos_ );  InsertPoin( Result, Cell_ );  _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TDelaunay3D.FindNearPoin( const Pos_:TSingle3D; out Poin_:TDelaPoin3D ) :Single;
var
   P :TDelaPoin3D;
   Dm :Single;
//･･･････････････････････････････････････････
     function GoNear :Boolean;  // P の隣接頂点に今より近い点があれば移る
     var
        Cs :TArray<TDelaCell3D>;
        C :TDelaCell3D;
        I :Byte;
        W :TDelaPoin3D;
        D :Single;
     begin
          Result := False;

          CollectStar( P, Cs );

          for C in Cs do
          begin
               for I := 0 to 3 do
               begin
                    W := C.Poin[ I ];

                    if ( W = P ) or W.Inf then Continue;

                    D := Distance2( Pos_, W.Pos );

                    if D < Dm then begin  P := W;  Dm := D;  Exit( True );  end;
               end;
          end;
     end;
//･･･････････････････････････････････････････
var
   C :TDelaCell3D;
   I :Byte;
   W :TDelaPoin3D;
   D :Single;
   J :Integer;
begin
     Poin_ := nil;  Result := Infinity;

     if Poins.ChildrsN = 0 then Exit;

     if ChildrsN = 0 then  // 胞がまだ無い少数点（1〜2点）は総当たり
     begin
          for J := 0 to Poins.ChildrsN-1 do
          begin
               W := Poins[ J ];

               D := Distance2( Pos_, W.Pos );

               if ( Poin_ = nil ) or ( D < Dm ) then begin  Poin_ := W;  Dm := D;  end;
          end;

          Exit( Roo2( Dm ) );
     end;

     C := HitSphereCell( Pos_ );  // ジャンプ＆ウォークで Pos_ を空球に含む胞へ直行し、その胞の最も近い頂点から出発する

     P := nil;

     if Assigned( C ) then
     begin
          for I := 0 to 3 do
          begin
               W := C.Poin[ I ];

               if W.Inf then Continue;

               D := Distance2( Pos_, W.Pos );

               if ( P = nil ) or ( D < Dm ) then begin  P := W;  Dm := D;  end;
          end;
     end;

     if P = nil then P := JumpPoin( Pos_ );  // 胞が定まらない退化（既存頂点との一致など）は無作為標本から

     Dm := Distance2( Pos_, P.Pos );  // ドロネー辺を伝ってより近い隣接頂点へ降下する。移るたびに
                                      // 距離が厳密に縮むので、Pos_ をボロノイ領域に含む点 ＝
     while GoNear do ;                // 最近傍点で必ず停止する

     Poin_ := P;  Result := Roo2( Dm );
end;

//------------------------------------------------------------------------------

function TDelaunay3D.DeletePoin( const Poin_:TDelaPoin3D ) :Boolean;
type
    TBond = record            // 穴の境界面（PA, PB, PC）と、その外側の胞（フック）・内側の埋め草
      PA, PB, PC :TDelaPoin3D;
      HC :TDelaCell3D;  HK :Byte;
      FC :TDelaCell3D;  FK :Byte;
    end;
var
   Star  :TArray<TDelaCell3D>;   // Poin_ の星（Poin_ を含む胞。取り除くと星型の穴が開く）
   Bonds :TArray<TBond>;         // 穴の境界（星の胞ごとに、Poin_ の対面が1枚）
   Links :TArray<TDelaPoin3D>;   // 有限のリンク頂点（重複なし）
   Minis :TArray<TDelaCell3D>;   // リンク頂点だけの小さなドロネー図（同じ集合の中の独立した成分）
   Fills :TArray<TDelaCell3D>;   // Minis のうち、穴を埋める胞
   Hull  :Boolean;               // 穴が凸包に接しているか（リンクに無限遠頂点が現れるか）
   AC :TDelaCell3D;    AK :Byte; // 無限遠頂点のアンカーの控え
   C :TDelaCell3D;
   I, S :Integer;
//･･･････････････････････････････････････････
     function Has( const Cs_:TArray<TDelaCell3D>; const C_:TDelaCell3D ) :Boolean;
     var
        I :Integer;
     begin
          for I := 0 to High( Cs_ ) do if Cs_[ I ] = C_ then Exit( True );

          Result := False;
     end;
//･･･････････････････････････････････････････
     function IsSeam( const C_:TDelaCell3D; const K_:Byte ) :Boolean;  // 胞のこの面は縫い目（境界面の内側）か
     var
        I :Integer;
     begin
          for I := 0 to High( Bonds ) do with Bonds[ I ] do if ( FC = C_ ) and ( FK = K_ ) then Exit( True );

          Result := False;
     end;
//･･･････････････････････････････････････････
     procedure CollectHole;  // 星・穴の境界・リンクを集める（アンカーから面渡りで広がる。構造を読むだけで、何も壊さない）
     var
        C :TDelaCell3D;
        K, I :Byte;
        B :TBond;
        W :TDelaPoin3D;
        J :Integer;
        Known :Boolean;
     begin
          CollectStar( Poin_, Star );

          for C in Star do
          begin
               K := Byte( C.CornOf( Poin_ ) );

               B.PA := C.Poin[ VertTable[ K ]._[ 1 ] ];  // Poin_ の対面（正準順）
               B.PB := C.Poin[ VertTable[ K ]._[ 2 ] ];
               B.PC := C.Poin[ VertTable[ K ]._[ 3 ] ];
               B.HC := C.Cell[ K ];
               B.HK := C.Corn[ K ];
               B.FC := nil;
               B.FK := 0;

               Bonds := Bonds + [ B ];

               Hull := Hull or B.PA.Inf or B.PB.Inf or B.PC.Inf;

               for I := 1 to 3 do  // リンク頂点を集める（無限遠頂点と重複は除く）
               begin
                    W := C.Poin[ VertTable[ K ]._[ I ] ];

                    if W.Inf then Continue;

                    Known := False;

                    for J := 0 to High( Links ) do if Links[ J ] = W then begin  Known := True;  Break;  end;

                    if not Known then Links := Links + [ W ];
               end;
          end;
     end;
//･･･････････････････････････････････････････
     function MiniCells :TArray<TDelaCell3D>;  // 小さなドロネー図の全胞（成分の接続を辿って集める）
     var
        I :Integer;
        K :Byte;
        N :TDelaCell3D;
     begin
          Result := [ Links[ 0 ].Cell ];  // 種の頂点のアンカーは、胞が張り直されるたびに更新されて常に成分内を指す

          I := 0;
          while I < Length( Result ) do
          begin
               for K := 0 to 3 do
               begin
                    N := Result[ I ].Cell[ K ];

                    if not Has( Result, N ) then Result := Result + [ N ];
               end;

               Inc( I );
          end;
     end;
//･･･････････････････････････････････････････
     function BuildMini( const S_:Integer ) :Boolean;  // リンク頂点だけの小さなドロネー図を、同じ集合の中に逐次添加法で作る
     var                                               // （入れ子の TDelaunay3D は作らない。胞は同じ集合が所有する別成分になる）
        I, Rest :Integer;
        P :TDelaPoin3D;
        C, H :TDelaCell3D;
        Done :TArray<Boolean>;
        Progress :Boolean;
     begin
          Result := False;

          SeedCells( Links[ 0 ], Links[ 1 ], Links[ S_ ] );

          SetLength( Done, Length( Links ) );

          Done[ 0 ] := True;  Done[ 1 ] := True;  Done[ S_ ] := True;

          Rest := Length( Links ) - 3;

          repeat  // 挿入が新たな胞を張ると、種の平面上などで見送られた頂点が入れるようになるので、
                  // 挿入が起きなくなるまで繰り返す（有界なローカル構築の順序調整）
                Progress := False;

                for I := 2 to High( Links ) do
                begin
                     if Done[ I ] then Continue;

                     P := Links[ I ];

                     H := nil;  // 位置検索は総当たりでよい（成分はリンクの大きさしかない）

                     for C in MiniCells do
                     begin
                          if C.IsHitSphere( P.Pos ) then begin  H := C;  Break;  end;
                     end;

                     if H = nil then Continue;

                     InsertPoin( P, H );

                     Done[ I ] := True;  Dec( Rest );  Progress := True;
                end;
          until not Progress;

          if Rest > 0 then Exit;  // 退化（どの外接球にも入らない頂点が残った）→ 埋め戻し不能

          Minis := MiniCells;

          Result := True;
     end;
//･･･････････････････････････････････････････
     function MatchSeams :Boolean;  // 境界面と同じ頂点集合を持ち、外側の胞に鏡像の向きで貼り合わせられる胞（＝穴の側）を探す
     var
        I, J :Integer;
        C :TDelaCell3D;
        A, B, D :Shortint;
        K :Byte;
     begin
          Result := False;

          for I := 0 to High( Bonds ) do
          begin
               with Bonds[ I ] do
               begin
                    for J := 0 to High( Minis ) do
                    begin
                         C := Minis[ J ];

                         A := C.CornOf( PA );
                         B := C.CornOf( PB );
                         D := C.CornOf( PC );

                         if ( A < 0 ) or ( B < 0 ) or ( D < 0 ) then Continue;

                         K := Byte( 6 - A - B - D );  // 3頂点を除いた残りの1隅 ＝ 境界面の対頂点

                         if C.CanWeld( K, HC, HK ) then begin  FC := C;  FK := K;  end;  // 面を共有する2胞のうち、
                    end;                                                                 // 鏡像で貼り合う側だけが通る

                    if FC = nil then Exit;  // 境界面が現れない（共球の同数で別の対角が選ばれた等）→ 埋め戻し不能
               end;
          end;

          for I := 1 to High( Bonds ) do  // 同じ縫い目が2枚の境界面に割り当たる退化（潰れた穴）も埋め戻し不能
          begin
               for J := 0 to I-1 do
               begin
                    if ( Bonds[ I ].FC = Bonds[ J ].FC ) and ( Bonds[ I ].FK = Bonds[ J ].FK ) then Exit;
               end;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
     function FloodFills :Boolean;  // 埋め草から縫い目を越えずに広がり、閉包の境界が穴の境界と一致することを確かめる
     var
        I :Integer;
        K, K2 :Byte;
        C, N :TDelaCell3D;
     begin
          Result := False;

          Fills := [];

          for I := 0 to High( Bonds ) do
          begin
               if not Has( Fills, Bonds[ I ].FC ) then Fills := Fills + [ Bonds[ I ].FC ];
          end;

          I := 0;
          while I < Length( Fills ) do
          begin
               C := Fills[ I ];

               for K := 0 to 3 do
               begin
                    if IsSeam( C, K ) then Continue;  // 縫い目は越えない

                    N := C.Cell[ K ];

                    if not Has( Fills, N ) then Fills := Fills + [ N ];
               end;

               Inc( I );
          end;

          for I := 0 to High( Fills ) do  // 無限遠胞が埋め草になるのは、穴が凸包に接しているときだけ
          begin
               if ( Fills[ I ].InfCorn >= 0 ) and not Hull then Exit;
          end;

          for I := 0 to High( Bonds ) do  // 縫い目の外側は、捨てられる胞か、それ自身も縫い目（穴が自分と接する退化）で
          begin                           // なければならない ―― これで閉包の境界が穴の境界とちょうど一致する
               with Bonds[ I ] do
               begin
                    N  := FC.Cell[ FK ];
                    K2 := FC.Corn[ FK ];
               end;

               if Has( Fills, N ) and not IsSeam( N, K2 ) then Exit;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
begin
     Result := False;

     if ( Poin_ = nil ) or Poin_.Inf or ( Poin_.Parent <> PoinSet ) then Exit;

     case Poins.ChildrsN of
       1,
       2: begin
               Poin_.Free;       // 胞はまだ無い
          end;
       3: begin
               inherited Clear;  // 胞を全解放する（残り2点では胞は張れない）

               Poin_.Free;
          end;
     else
          Hull := False;

          CollectHole;

          if Length( Bonds ) = 2 then  // 星が2胞（鏡像対）：境界面2枚は同じ面の裏表 → 外側どうしを直接貼り合わせる
          begin
               if not Bonds[ 0 ].HC.CanWeld( Bonds[ 0 ].HK, Bonds[ 1 ].HC, Bonds[ 1 ].HK ) then Exit;

               Bonds[ 0 ].HC.Weld( Bonds[ 0 ].HK, Bonds[ 1 ].HC, Bonds[ 1 ].HK );

               for C in Star do C.Free;

               Poin_.Free;

               Bonds[ 0 ].HC.BindPoins;  // 星と共に消えたアンカーを張り直す
               Bonds[ 1 ].HC.BindPoins;
          end
          else
          begin
               if Length( Links ) < 3 then Exit;  // 埋め戻しの種が張れない

               S := -1;  // 種の3点目 = 先頭の2点と共線でない最初のリンク頂点（外積は倍精度で評価する）
               for I := 2 to High( Links ) do
               begin
                    if CrossProduct( ToD3( Links[ I ].Pos ) - ToD3( Links[ 0 ].Pos ), ToD3( Links[ 1 ].Pos ) - ToD3( Links[ 0 ].Pos ) ).Size2 > 0 then begin  S := I;  Break;  end;
               end;

               if S < 0 then Exit;  // リンクが共線（埋め戻し不能）

               AC := _PoinInf.Cell;  AK := _PoinInf.Corn;  // 小さなドロネー図がアンカーを奪うので控えておく

               if BuildMini( S ) and MatchSeams and FloodFills then
               begin
                    for I := 0 to High( Bonds ) do  // 縫い付け（回転コードは頂点の同一性から導かれる）
                    begin
                         with Bonds[ I ] do FC.Weld( FK, HC, HK );
                    end;

                    _PoinInf.Cell := AC;  _PoinInf.Corn := AK;  // 先に戻す（星と共に消えるなら、後の張り直しが引き受ける）

                    for C in Star  do C.Free;                              // 星を取り除き、
                    for C in Minis do if not Has( Fills, C ) then C.Free;  // 使わなかった埋め草を捨てる

                    Poin_.Free;

                    for C in Fills do C.BindPoins;  // 埋め草に現れる頂点（全リンク頂点）のアンカーを張り直す
               end
               else
               begin
                    _PoinInf.Cell := AC;  _PoinInf.Corn := AK;  // 何も壊していない ―― 小さなドロネー図だけ消して戻る

                    for C in MiniCells do C.Free;

                    for C in Star do C.BindPoins;

                    Exit;
               end;
          end;
     end;

     _OnChange.Run( Self );

     Result := True;
end;

//------------------------------------------------------------------------------

procedure TDelaunay3D.LoadFromFile( const FileName_:String );
begin
     inherited;

     _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

procedure TDelaunay3D.Clear;
begin
     inherited Clear;  // 胞を全解放する

     Poins.Clear;      // 点を全解放する（PoinInf は集合外なので残る）

     _PoinInf.Cell := nil;

     _OnChange.Run( Self );
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

end. //######################################################################### ■
