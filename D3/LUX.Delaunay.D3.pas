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
// ・点の追加は Bowyer-Watson 法。新しい点を球に含む胞群（キャビティ）を CellTree で
//   再帰的に削除し、境界面ごとに新しい胞を張り直す。3D ではキャビティの双対が木に
//   ならない（同じ胞に複数の経路で到達しうる）ため、削除済みの胞に再突入したときは
//   一時的なプレースホルダ胞を「縫合待ちの受け箱」として置き、貼り合わせの情報を
//   受け渡す。再帰が終わればプレースホルダは全て破棄される。
// ・点の削除はフリップ法。頂点の星（頂点を含む胞の集合）の耳（隣接する2胞が張る
//   四面体）のうち、「自分が耳の外接球の内側にあり、球が他のリンク頂点を含まない」
//   もの（＝最終形に現れる胞そのもの）を 2-3 フリップまたは 3-2 フリップで確定して
//   いく。リンクは最初の星から集めて凍結し、常に元のリンク全体に対して検定する。
//   フリップ1回につき最終形の胞が1つ完成し、以後の操作はそれに触れないため、
//   有限回で星は4胞まで縮む。最後の1胞も同じ検査（全ての点に対する空球）に通して
//   から4胞を畳み込んで頂点を取り除く。穴を開けないため途中状態が常に正しい四面体
//   分割であり、凸包上の頂点もリンクに無限遠頂点が現れるだけで同じ手順で削除できる。
// ・3D では2-3 と 3-2 の選択が要る。反射辺の環がちょうど3胞で閉じているなら 3-2 で
//   既存の胞を消費し、両方の環が開いているときだけ 2-3 で新しい辺を張る。無限遠胞は
//   幾何（凸性）の検査が退化するため、この組合せ的な優先順位が既存の胞と同じ頂点集合
//   の複製を防ぐ。それでも凸包の周りでは体積ゼロの鏡像対（ポケット）が生じ得るので、
//   見つけ次第 2-0 フリップで取り除く。全てのフリップは貼り合わせの可否（CanWeld）を
//   確かめてから壊す。フリップでは畳み切れない退化配置（数%）は、点のインスタンスを
//   保ったまま胞だけを作り直して確実に取り除く（実証済みの追加処理の再利用）。
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
//   ため、性能はクエリの履歴や位置に依らず領域全体で一様。最近傍検索（FindPoin）
//   も同じ標本から出発し、ドロネー辺を伝う最近傍への貪欲降下で行う。

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

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellJoint

     // キャビティ縫合の合わせ面（入口の面の3辺に対応する、縫合待ちの3面）。
     TCellJoint = record
     private
     public
       Cell1 :TDelaCell3D;  Corn1 :Byte;  Edge1 :Byte;
       Cell2 :TDelaCell3D;  Corn2 :Byte;  Edge2 :Byte;
       Cell3 :TDelaCell3D;  Corn3 :Byte;  Edge3 :Byte;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellHook

     // フリップで消える胞の外側リンクの控え。
     TCellHook = record
     private
     public
       Cell :TDelaCell3D;
       Corn :Byte;
     end;

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
       _TempSet  :TDelaCellSet3D;  // キャビティ縫合のプレースホルダ胞の置き場
       _OnChange :TDelegates;
       ///// A C C E S S O R
       function GetCells :TDelaCellSet3D;
       ///// M E T H O D
       function InitCell :Boolean;
       procedure InsertLoose;
       procedure InsertPoin( const Poin_:TDelaPoin3D; const Cell_:TDelaCell3D );
       function JumpPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
       function ScanSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;
       procedure CollectStar( const Poin_:TDelaPoin3D; var Cells_:TArray<TDelaCell3D> );
       function CellOK( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Boolean;
       function Hook( const Cell_:TDelaCell3D; const K_:Byte ) :TCellHook;
       procedure WeldCells( const C1_,C2_:TDelaCell3D );
       procedure EdgeLink( const Cell_:TDelaCell3D; const PA_,PB_:TDelaPoin3D; out F1_,F2_:TDelaPoin3D );
       function Flip23( const Cell_:TDelaCell3D; const K_:Byte ) :Boolean;
       function Flip32( const Cell_:TDelaCell3D; const PA_,PB_:TDelaPoin3D ) :Boolean;
       function Flip20( const Cell_:TDelaCell3D; const K_:Byte ) :Boolean;
     protected
       ///// M E T H O D
       function NewPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
       function NewCell( const Poin0_,Poin1_,Poin2_,Poin3_:TDelaPoin3D ) :TDelaCell3D;
     public
       constructor Create; overload; override;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property PoinInf  :TDelaPoin3D    read _PoinInf ;  // 唯一の無限遠頂点（点集合には属さない）
       property Cells    :TDelaCellSet3D read GetCells ;  // 胞の集合（＝自分自身）
       property OnChange :TDelegates     read _OnChange;  // 構造が変化したときに発火（Add / Del で多播購読）
       ///// M E T H O D
       function HitSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;  // Pos_ を空球に含む胞（ジャンプ＆ウォーク・期待 O(n^(1/4))）
       function FindPoin( const Pos_:TSingle3D; const Radius_:Single ) :TDelaPoin3D;  // Pos_ の最近傍点（Radius_ 内に無ければ nil）
       function AddPoin( const Pos_:TSingle3D ) :TDelaPoin3D; overload;
       function AddPoin( const Pos_:TSingle3D; const Cell_:TDelaCell3D ) :TDelaPoin3D; overload;
       function DeletePoin( const Poin_:TDelaPoin3D ) :Boolean;
       procedure Clear; reintroduce;  // 点と胞を全消去する（PoinInf は残る）
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

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

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellJoint

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellHook

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

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

function TDelaunay3D.InitCell :Boolean;
var
   N, I :Integer;
   P0, P1, P2 :TDelaPoin3D;
   C0, C1 :TDelaCell3D;
begin
     Result := False;

     N := Poins.ChildrsN;

     if N < 3 then Exit;

     P0 := Poins[ 0 ];

     P1 := nil;  // 一致しない2点目と、一直線に乗らない3点目を探して種にする（退化した先頭には頼らない）
     for I := 1 to N-1 do
     begin
          if Distance2( P0.Pos, Poins[ I ].Pos ) > 0 then begin  P1 := Poins[ I ];  Break;  end;
     end;

     if P1 = nil then Exit;

     P2 := nil;
     for I := 1 to N-1 do
     begin
          if CrossProduct( Poins[ I ].Pos - P0.Pos, P1.Pos - P0.Pos ).Size2 > 0 then begin  P2 := Poins[ I ];  Break;  end;
     end;

     if P2 = nil then Exit;  // 全点が一直線上（胞は張れない）

     C0 := NewCell( _PoinInf, P0, P1, P2 );  // 全空間を二重に覆う鏡像の無限遠胞
     C1 := NewCell( _PoinInf, P0, P2, P1 );

     C0.Weld( 0, C1, 0 );
     C0.Weld( 1, C1, 1 );
     C0.Weld( 2, C1, 3 );
     C0.Weld( 3, C1, 2 );

     Result := True;
end;

procedure TDelaunay3D.InsertLoose;
var
   I :Integer;
   P :TDelaPoin3D;
   C :TDelaCell3D;
begin
     for I := 0 to Poins.ChildrsN-1 do  // 胞に繋がっていない点を挿入し直す
     begin
          P := Poins[ I ];

          if Assigned( P.Cell ) then Continue;

          C := HitSphereCell( P.Pos );

          if Assigned( C ) then InsertPoin( P, C );  // 退化配置の点は繋がらないまま残る（追加時と同じ扱い）
     end;
end;

//------------------------------------------------------------------------------

procedure TDelaunay3D.InsertPoin( const Poin_:TDelaPoin3D; const Cell_:TDelaCell3D );
//･･･････････････････････････････････････････
     function CellTree( const Cell_:TDelaCell3D; const Corn_:Byte; const E1_,E2_,E3_:Byte ) :TCellJoint;
     //･････････････････････････････････
          procedure Connect( const J1_,J2_,J3_:TCellJoint );  // 入口の面の辺の周りで、新しい胞どうしを縫う
          begin
               with J1_ do
               begin
                    Cell2.Cell[ Corn2 ] := J2_.Cell3;
                    Cell2.Corn[ Corn2 ] := J2_.Corn3;
                    Cell2.Bond[ Corn2 ] := BondTable[ Edge2 ]._[ J2_.Edge3 ];

                    Cell3.Cell[ Corn3 ] := J3_.Cell2;
                    Cell3.Corn[ Corn3 ] := J3_.Corn2;
                    Cell3.Bond[ Corn3 ] := BondTable[ Edge3 ]._[ J3_.Edge2 ];
               end;
          end;
     //･････････････････････････････････
     var
        V1, V2, V3 :Byte;
        J1, J2, J3 :TCellJoint;
        C :TDelaCell3D;
     begin
          V1 := VertTable[ Corn_ ]._[ E1_ ];
          V2 := VertTable[ Corn_ ]._[ E2_ ];
          V3 := VertTable[ Corn_ ]._[ E3_ ];

          case Cell_.Flag of
            0: begin
                    if Cell_.IsHitSphere( Poin_.Pos ) then
                    begin
                         Cell_.Flag := 1;  // キャビティに取り込む

                         with BondTable[ Cell_.Bond[ V1 ] ] do J1 := CellTree( Cell_.Cell[ V1 ], Cell_.Corn[ V1 ], _[ E1_ ], _[ E3_ ], _[ E2_ ] );
                         with BondTable[ Cell_.Bond[ V2 ] ] do J2 := CellTree( Cell_.Cell[ V2 ], Cell_.Corn[ V2 ], _[ E2_ ], _[ E1_ ], _[ E3_ ] );
                         with BondTable[ Cell_.Bond[ V3 ] ] do J3 := CellTree( Cell_.Cell[ V3 ], Cell_.Corn[ V3 ], _[ E3_ ], _[ E2_ ], _[ E1_ ] );

                         Cell_.Free;

                         Connect( J1, J2, J3 );
                         Connect( J2, J3, J1 );
                         Connect( J3, J1, J2 );

                         with Result do
                         begin
                              Cell1 := J1.Cell1;  Corn1 := J1.Corn1;  Edge1 := J1.Edge1;
                              Cell2 := J2.Cell1;  Corn2 := J2.Corn1;  Edge2 := J2.Edge1;
                              Cell3 := J3.Cell1;  Corn3 := J3.Corn1;  Edge3 := J3.Edge1;
                         end;
                    end
                    else
                    begin
                         C := NewCell( Poin_, Cell_.Poin[ V1 ], Cell_.Poin[ V2 ], Cell_.Poin[ V3 ] );  // キャビティの境界面に新しい胞を張る

                         C.Cell[ 0 ] := Cell_;
                         C.Corn[ 0 ] := Corn_;
                         C.Bond[ 0 ] := BondTable[ 1 ]._[ E1_ ];

                         Cell_.Cell[ Corn_ ] := C;
                         Cell_.Corn[ Corn_ ] := 0;
                         Cell_.Bond[ Corn_ ] := BondTable[ E1_ ]._[ 1 ];

                         with Result do
                         begin
                              Cell1 := C;  Corn1 := 1;  Edge1 := 1;
                              Cell2 := C;  Corn2 := 2;  Edge2 := 2;
                              Cell3 := C;  Corn3 := 3;  Edge3 := 3;
                         end;
                    end;
               end;
            1: begin
                    C := TDelaCell3D.Create( _TempSet );  // 削除済みの胞に別の経路で再突入 → プレースホルダを縫合待ちの受け箱にする

                    C.Flag := 2;

                    C.Corn[ 1 ] := 0;
                    C.Corn[ 2 ] := 0;
                    C.Corn[ 3 ] := 0;

                    Cell_.Cell[ Corn_ ] := C;
                    Cell_.Corn[ Corn_ ] := 0;
                    Cell_.Bond[ Corn_ ] := BondTable[ E1_ ]._[ 1 ];

                    with Result do
                    begin
                         Cell1 := C;  Corn1 := 1;  Edge1 := 1;
                         Cell2 := C;  Corn2 := 2;  Edge2 := 2;
                         Cell3 := C;  Corn3 := 3;  Edge3 := 3;
                    end;
               end;
            2: begin
                    with Result do  // プレースホルダに残された縫合の相手をそのまま返す
                    begin
                         Cell1 := Cell_.Cell[ V1 ];  Corn1 := Cell_.Corn[ V1 ];  Edge1 := BondTable[ Cell_.Bond[ V1 ] ]._[ E1_ ];
                         Cell2 := Cell_.Cell[ V2 ];  Corn2 := Cell_.Corn[ V2 ];  Edge2 := BondTable[ Cell_.Bond[ V2 ] ]._[ E2_ ];
                         Cell3 := Cell_.Cell[ V3 ];  Corn3 := Cell_.Corn[ V3 ];  Edge3 := BondTable[ Cell_.Bond[ V3 ] ]._[ E3_ ];
                    end;
               end;
          end;
     end;
//･･･････････････････････････････････････････
     procedure Connect( const J0_,J1_,J2_,J3_:TCellJoint );  // 元の胞の4面から伸びた縫合面どうしを縫う
     begin
          with J0_ do
          begin
               Cell1.Cell[ Corn1 ] := J1_.Cell1;
               Cell1.Corn[ Corn1 ] := J1_.Corn1;
               Cell1.Bond[ Corn1 ] := BondTable[ Edge1 ]._[ J1_.Edge1 ];

               Cell2.Cell[ Corn2 ] := J2_.Cell2;
               Cell2.Corn[ Corn2 ] := J2_.Corn2;
               Cell2.Bond[ Corn2 ] := BondTable[ Edge2 ]._[ J2_.Edge2 ];

               Cell3.Cell[ Corn3 ] := J3_.Cell3;
               Cell3.Corn[ Corn3 ] := J3_.Corn3;
               Cell3.Bond[ Corn3 ] := BondTable[ Edge3 ]._[ J3_.Edge3 ];
          end;
     end;
//･･･････････････････････････････････････････
var
   J0, J1, J2, J3 :TCellJoint;
begin
     Cell_.Flag := 1;

     with BondTable[ Cell_.Bond[ 0 ] ] do J0 := CellTree( Cell_.Cell[ 0 ], Cell_.Corn[ 0 ], _[ 1 ], _[ 2 ], _[ 3 ] );
     with BondTable[ Cell_.Bond[ 1 ] ] do J1 := CellTree( Cell_.Cell[ 1 ], Cell_.Corn[ 1 ], _[ 1 ], _[ 2 ], _[ 3 ] );
     with BondTable[ Cell_.Bond[ 2 ] ] do J2 := CellTree( Cell_.Cell[ 2 ], Cell_.Corn[ 2 ], _[ 1 ], _[ 2 ], _[ 3 ] );
     with BondTable[ Cell_.Bond[ 3 ] ] do J3 := CellTree( Cell_.Cell[ 3 ], Cell_.Corn[ 3 ], _[ 1 ], _[ 2 ], _[ 3 ] );

     Cell_.Free;

     Connect( J0, J1, J2, J3 );
     Connect( J1, J0, J3, J2 );
     Connect( J2, J3, J0, J1 );
     Connect( J3, J2, J1, J0 );

     _TempSet.Clear;  // プレースホルダは役目を終えた
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

//------------------------------------------------------------------------------

function TDelaunay3D.CellOK( const P0_,P1_,P2_,P3_:TDelaPoin3D ) :Boolean;
begin
     Result := P0_.Inf or P1_.Inf or P2_.Inf or P3_.Inf            // 無限遠胞は幾何を持たないため無条件に良い
            or ( _PoinInf.InSphered( P0_, P1_, P2_, P3_ ) < 0 );   // 有限胞は正の向き（＝無限遠点が球の外）であること
end;

function TDelaunay3D.Hook( const Cell_:TDelaCell3D; const K_:Byte ) :TCellHook;
begin
     Result.Cell := Cell_.Cell[ K_ ];
     Result.Corn := Cell_.Corn[ K_ ];
end;

procedure TDelaunay3D.WeldCells( const C1_,C2_:TDelaCell3D );
var
   K1, K2 :Byte;
begin
     for K1 := 0 to 3 do if C2_.CornOf( C1_.Poin[ K1 ] ) < 0 then Break;  // 相手に無い頂点の対面が共有面
     for K2 := 0 to 3 do if C1_.CornOf( C2_.Poin[ K2 ] ) < 0 then Break;

     C1_.Weld( K1, C2_, K2 );
end;

procedure TDelaunay3D.EdgeLink( const Cell_:TDelaCell3D; const PA_,PB_:TDelaPoin3D; out F1_,F2_:TDelaPoin3D );
var
   B :Byte;
   W1, W2, W3 :TDelaPoin3D;
begin
     // 胞 Cell_ = +( PA, PB, F1, F2 ) となるリンク対 ( F1, F2 ) を取り出す。
     // PB の対面の正準順を PA から巡回させて ( PA, X, Y ) としたとき、( F1, F2 ) = ( Y, X )
     B := Cell_.CornOf( PB_ );

     W1 := Cell_.Poin[ VertTable[ B ]._[ 1 ] ];
     W2 := Cell_.Poin[ VertTable[ B ]._[ 2 ] ];
     W3 := Cell_.Poin[ VertTable[ B ]._[ 3 ] ];

     if W1 = PA_ then begin  F1_ := W3;  F2_ := W2;  end
                 else
     if W2 = PA_ then begin  F1_ := W1;  F2_ := W3;  end
                 else begin  F1_ := W2;  F2_ := W1;  end;
end;

//------------------------------------------------------------------------------

function TDelaunay3D.Flip23( const Cell_:TDelaCell3D; const K_:Byte ) :Boolean;
var
   N, E1, E2, E3 :TDelaCell3D;
   A, B, F1, F2, F3 :TDelaPoin3D;
   HC1, HC2, HC3, HN1, HN2, HN3 :TCellHook;
begin
     Result := False;

     N := Cell_.Cell[ K_ ];

     A := Cell_.Poin[ K_ ];             // 共有面の両側の対頂点
     B := N.Poin[ Cell_.Corn[ K_ ] ];

     F1 := Cell_.Poin[ VertTable[ K_ ]._[ 1 ] ];  // 共有面（Cell_ の正準順）
     F2 := Cell_.Poin[ VertTable[ K_ ]._[ 2 ] ];
     F3 := Cell_.Poin[ VertTable[ K_ ]._[ 3 ] ];

     HC1 := Hook( Cell_, Cell_.CornOf( F1 ) );  HN1 := Hook( N, N.CornOf( F1 ) );  // 消える2胞の外側リンクを控える
     HC2 := Hook( Cell_, Cell_.CornOf( F2 ) );  HN2 := Hook( N, N.CornOf( F2 ) );
     HC3 := Hook( Cell_, Cell_.CornOf( F3 ) );  HN3 := Hook( N, N.CornOf( F3 ) );

     if ( HC1.Cell = N ) or ( HC2.Cell = N ) or ( HC3.Cell = N )            // 外側リンクが消える胞を指す（捻れた隣接）
     or ( HN1.Cell = Cell_ ) or ( HN2.Cell = Cell_ ) or ( HN3.Cell = Cell_ ) then Exit;

     E1 := NewCell( A, B, F1, F2 );  // 新しい辺 ( A, B ) の周りの3胞（向きは共有面の巡回順から従う）
     E2 := NewCell( A, B, F2, F3 );
     E3 := NewCell( A, B, F3, F1 );

     if not ( E1.CanWeld( 1, HC3.Cell, HC3.Corn ) and E1.CanWeld( 0, HN3.Cell, HN3.Corn )    // 全ての貼り合わせが可能な
          and E2.CanWeld( 1, HC1.Cell, HC1.Corn ) and E2.CanWeld( 0, HN1.Cell, HN1.Corn )    // ことを確かめてから壊す。
          and E3.CanWeld( 1, HC2.Cell, HC2.Corn ) and E3.CanWeld( 0, HN2.Cell, HN2.Corn ) ) then  // 捻れた隣接は見送る
     begin
          E1.Free;  E2.Free;  E3.Free;

          Cell_.BindPoins;  N.BindPoins;  // アンカーを元に戻す

          Exit;
     end;

     WeldCells( E1, E2 );
     WeldCells( E2, E3 );
     WeldCells( E3, E1 );

     E1.Weld( 1, HC3.Cell, HC3.Corn );  E1.Weld( 0, HN3.Cell, HN3.Corn );  // 面 ( A, F1, F2 ) は Cell_ の F3 対面だった
     E2.Weld( 1, HC1.Cell, HC1.Corn );  E2.Weld( 0, HN1.Cell, HN1.Corn );
     E3.Weld( 1, HC2.Cell, HC2.Corn );  E3.Weld( 0, HN2.Cell, HN2.Corn );

     Cell_.Free;
     N.Free;

     Result := True;
end;

function TDelaunay3D.Flip32( const Cell_:TDelaCell3D; const PA_,PB_:TDelaPoin3D ) :Boolean;
var
   C1, C2, C3, CA, CB :TDelaCell3D;
   F1, F2, F3 :TDelaPoin3D;
   HA1, HA2, HA3, HB1, HB2, HB3 :TCellHook;
   I :Byte;
begin
     Result := False;

     C1 := Cell_;

     EdgeLink( C1, PA_, PB_, F1, F2 );  // C1 = { PA, PB, F1, F2 }

     C2 := C1.Cell[ C1.CornOf( F1 ) ];  // C2 = { PA, PB, F2, F3 }
     C3 := C1.Cell[ C1.CornOf( F2 ) ];  // C3 = { PA, PB, F3, F1 }

     F3 := nil;
     for I := 0 to 3 do
     begin
          if ( C2.Poin[ I ] <> PA_ ) and ( C2.Poin[ I ] <> PB_ ) and ( C2.Poin[ I ] <> F2 ) then F3 := C2.Poin[ I ];
     end;

     HB1 := Hook( C1, C1.CornOf( PB_ ) );  HA1 := Hook( C1, C1.CornOf( PA_ ) );  // 消える3胞の外側リンクを控える
     HB2 := Hook( C2, C2.CornOf( PB_ ) );  HA2 := Hook( C2, C2.CornOf( PA_ ) );
     HB3 := Hook( C3, C3.CornOf( PB_ ) );  HA3 := Hook( C3, C3.CornOf( PA_ ) );

     if ( HB1.Cell = C1 ) or ( HB1.Cell = C2 ) or ( HB1.Cell = C3 )    // 外側リンクが消える胞を指す（捻れた隣接）
     or ( HB2.Cell = C1 ) or ( HB2.Cell = C2 ) or ( HB2.Cell = C3 )
     or ( HB3.Cell = C1 ) or ( HB3.Cell = C2 ) or ( HB3.Cell = C3 )
     or ( HA1.Cell = C1 ) or ( HA1.Cell = C2 ) or ( HA1.Cell = C3 )
     or ( HA2.Cell = C1 ) or ( HA2.Cell = C2 ) or ( HA2.Cell = C3 )
     or ( HA3.Cell = C1 ) or ( HA3.Cell = C2 ) or ( HA3.Cell = C3 ) then Exit;

     CA := NewCell( PA_, F1, F2, F3 );  // 辺 ( PA, PB ) が消え、リンク三角形 ( F1, F2, F3 ) の両側の2胞になる
     CB := NewCell( PB_, F1, F3, F2 );

     if not ( CA.CanWeld( Byte( CA.CornOf( F3 ) ), HB1.Cell, HB1.Corn ) and CB.CanWeld( Byte( CB.CornOf( F3 ) ), HA1.Cell, HA1.Corn )    // 全ての貼り合わせが
          and CA.CanWeld( Byte( CA.CornOf( F1 ) ), HB2.Cell, HB2.Corn ) and CB.CanWeld( Byte( CB.CornOf( F1 ) ), HA2.Cell, HA2.Corn )    // 可能なことを確かめて
          and CA.CanWeld( Byte( CA.CornOf( F2 ) ), HB3.Cell, HB3.Corn ) and CB.CanWeld( Byte( CB.CornOf( F2 ) ), HA3.Cell, HA3.Corn ) ) then  // から壊す
     begin
          CA.Free;  CB.Free;

          C1.BindPoins;  C2.BindPoins;  C3.BindPoins;  // アンカーを元に戻す

          Exit;
     end;

     WeldCells( CA, CB );

     CA.Weld( CA.CornOf( F3 ), HB1.Cell, HB1.Corn );  CB.Weld( CB.CornOf( F3 ), HA1.Cell, HA1.Corn );  // 面 ( PA, F1, F2 ) は C1 の PB 対面だった
     CA.Weld( CA.CornOf( F1 ), HB2.Cell, HB2.Corn );  CB.Weld( CB.CornOf( F1 ), HA2.Cell, HA2.Corn );
     CA.Weld( CA.CornOf( F2 ), HB3.Cell, HB3.Corn );  CB.Weld( CB.CornOf( F2 ), HA3.Cell, HA3.Corn );

     C1.Free;
     C2.Free;
     C3.Free;

     Result := True;
end;

function TDelaunay3D.Flip20( const Cell_:TDelaCell3D; const K_:Byte ) :Boolean;
var
   N :TDelaCell3D;
   Ps :array [ 0..3 ] of TDelaPoin3D;
   HC, HN :array [ 0..3 ] of TCellHook;
   I, J :Byte;
begin
     // 同一頂点集合の鏡像対（体積ゼロのポケット）を取り除き、外側どうしを貼り合わせる。
     // 凸包頂点の削除では、フリップの副産物としてこの退化対が自然に現れる
     Result := False;

     N := Cell_.Cell[ K_ ];

     for I := 0 to 3 do
     begin
          Ps[ I ] := Cell_.Poin[ I ];

          HC[ I ] := Hook( Cell_, I );
          HN[ I ] := Hook( N, Byte( N.CornOf( Ps[ I ] ) ) );
     end;

     for I := 0 to 3 do  // 壊す前に、全ての貼り合わせが可能なことを確かめる（捻れた対は除去できない）
     begin
          if HC[ I ].Cell = N then
          begin
               if HN[ I ].Cell <> Cell_ then Exit;  // 貼り合わせが対称でない
          end
          else
          begin
               if ( HC[ I ].Cell = Cell_ ) or ( HN[ I ].Cell = Cell_ ) or ( HN[ I ].Cell = N ) then Exit;  // 自己貼り合わせ

               if not HC[ I ].Cell.CanWeld( HC[ I ].Corn, HN[ I ].Cell, HN[ I ].Corn ) then Exit;  // 同じ向きの面
          end;
     end;

     for I := 0 to 3 do
     begin
          if HC[ I ].Cell = N then Continue;  // 対の内側で貼り合っている面はそのまま消える

          HC[ I ].Cell.Weld( HC[ I ].Corn, HN[ I ].Cell, HN[ I ].Corn );
     end;

     for I := 0 to 3 do  // アンカーを生き残る胞へ張り替える
     begin
          for J := 0 to 3 do
          begin
               if ( J <> I ) and ( HC[ J ].Cell <> N ) then
               begin
                    Ps[ I ].Cell := HC[ J ].Cell;
                    Ps[ I ].Corn := Byte( HC[ J ].Cell.CornOf( Ps[ I ] ) );

                    Break;
               end;
          end;
     end;

     Cell_.Free;
     N.Free;

     Result := True;
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

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunay3D.Create;
begin
     inherited;

     _PoinInf := TDelaPoin3DInf.Create( TSingle3D.Create( 0, 0, 0 ) );

     _TempSet := TDelaCellSet3D.Create;
end;

destructor TDelaunay3D.Destroy;
begin
     inherited;        // 点と胞は集合ごと解放される

     _PoinInf.Free;

     _TempSet.Free;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay3D.HitSphereCell( const Pos_:TSingle3D ) :TDelaCell3D;
var
   C :TDelaCell3D;
   N, O, I :Integer;
   E :Byte;
   K :Shortint;
begin
     C := JumpPoin( Pos_ ).Cell;  // ジャンプ：無作為標本の最近点のアンカー胞から出発する

     if not Assigned( C ) then Exit( ScanSphereCell( Pos_ ) );

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

function TDelaunay3D.AddPoin( const Pos_:TSingle3D ) :TDelaPoin3D;
var
   C :TDelaCell3D;
begin
     case Poins.ChildrsN of
       0,
       1: begin
               Result := NewPoin( Pos_ );  _OnChange.Run( Self );
          end;
       2: begin
               Result := NewPoin( Pos_ );  InitCell;  _OnChange.Run( Self );
          end;
     else
          if ChildrsN = 0 then  // 胞がまだ無い（これまでの点が退化配置だった）→ 種を探し直して繋ぐ
          begin
               Result := NewPoin( Pos_ );

               if InitCell then InsertLoose;

               _OnChange.Run( Self );

               Exit;
          end;

          C := HitSphereCell( Pos_ );

          if Assigned( C ) then Result := AddPoin( Pos_, C )
                           else Result := nil;  // 退化配置（既存の面と同一平面上など）は無視する
     end;
end;

function TDelaunay3D.AddPoin( const Pos_:TSingle3D; const Cell_:TDelaCell3D ) :TDelaPoin3D;
begin
     Result := NewPoin( Pos_ );  InsertPoin( Result, Cell_ );  _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TDelaunay3D.FindPoin( const Pos_:TSingle3D; const Radius_:Single ) :TDelaPoin3D;
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

function TDelaunay3D.DeletePoin( const Poin_:TDelaPoin3D ) :Boolean;
var
   Star :TArray<TDelaCell3D>;  // Poin_ の星（Poin_ を含む胞の集合）
   Link :TArray<TDelaPoin3D>;  // リンク頂点（最初の星の頂点から Poin_ を除いたもの）
//･･･････････････････････････････････････････
     procedure ScanStar;  // 星の収集は全胞走査で行う（退化した中間状態では、星が面の接続で連結とは限らない）
     var
        C :TDelaCell3D;
     begin
          Star := [];

          for C in Cells do
          begin
               if C.CornOf( Poin_ ) >= 0 then Star := Star + [ C ];
          end;
     end;
//･･･････････････････････････････････････････
     procedure CollectLink;  // リンクは最初の星から一度だけ集めて凍結する。星が縮んでも元のリンク全体に
     var                     // 対して空球性を検定し続けることで、実体化される耳が常に最終形の胞になる
        C :TDelaCell3D;
        I :Byte;
        W, L :TDelaPoin3D;
        Found :Boolean;
     begin
          Link := [];

          for C in Star do
          begin
               for I := 0 to 3 do
               begin
                    W := C.Poin[ I ];

                    if W = Poin_ then Continue;

                    Found := False;

                    for L in Link do if L = W then begin  Found := True;  Break;  end;

                    if not Found then Link := Link + [ W ];
               end;
          end;
     end;
//･･･････････････････････････････････････････
     function EarTry( const C_:TDelaCell3D; const K_:Byte ) :Boolean;  // 面 K_（Poin_ を含む）の耳を検査し、有効ならフリップする
     var
        N, C3, CS, CT :TDelaCell3D;
        A, B, S, T, W, F1, F2, F3 :TDelaPoin3D;
        FF :array [ 1..3 ] of TDelaPoin3D;
        P, I :Byte;
        DS, DT :Boolean;
     begin
          Result := False;

          N := C_.Cell[ K_ ];

          A := C_.Poin[ K_ ];             // 耳の両端（共有面の両側の対頂点）
          B := N.Poin[ C_.Corn[ K_ ] ];

          if A = B then Exit( Flip20( C_, K_ ) );  // 同一頂点集合の鏡像対（体積ゼロのポケット）→ 2-0 フリップで除去（捻れた対は除去できず、作り直しに任せる）

          FF[ 1 ] := C_.Poin[ VertTable[ K_ ]._[ 1 ] ];  // 共有面 = ( Poin_ とリンク辺 )
          FF[ 2 ] := C_.Poin[ VertTable[ K_ ]._[ 2 ] ];
          FF[ 3 ] := C_.Poin[ VertTable[ K_ ]._[ 3 ] ];

          if FF[ 1 ] = Poin_ then P := 1
                             else
          if FF[ 2 ] = Poin_ then P := 2
                             else P := 3;

          S := FF[ 1 + ( P     ) mod 3 ];  // 耳の四面体 ( A, B, S, T )（向きは共有面の巡回順から従う）
          T := FF[ 1 + ( P + 1 ) mod 3 ];

          // 自分が耳の球の内側にあり、耳が正の向きであること（裏向きの耳は符号が反転して自然に落ちる）
          if Poin_.InSphered( A, B, S, T ) <= 0 then Exit;

          if not CellOK( A, B, S, T ) then Exit;

          // 耳の球が他のリンク頂点を含まないこと（耳の頂点自身や無限遠点との判定は行列式が 0 以下となり、スキップは要らない）
          for W in Link do
          begin
               if W.InSphered( A, B, S, T ) > 0 then Exit;
          end;

          // フリップの選択。反射辺の周囲がちょうど3胞（環が閉じている）なら 3-2 で既存の胞を
          // 消費し、両方の環が開いているときだけ 2-3 で新しい辺を張る。この優先順位により、
          // 幾何検査が退化する無限遠胞の周りでも、既存の胞と同じ頂点集合の複製が生じない
          CS := C_.Cell[ C_.CornOf( T ) ];  // 辺 ( Poin_, S ) の周り = { C_, N, CS } ?
          CT := C_.Cell[ C_.CornOf( S ) ];  // 辺 ( Poin_, T ) の周り = { C_, N, CT } ?

          DS := ( CS = N.Cell[ N.CornOf( T ) ] ) and ( CS <> C_ ) and ( CS <> N );
          DT := ( CT = N.Cell[ N.CornOf( S ) ] ) and ( CT <> C_ ) and ( CT <> N );

          // 3-2 フリップ：辺 ( Poin_, S ) を消す（もう一方の環も閉じているときは複製が生じるので断念）
          if DS and not DT then
          begin
               EdgeLink( C_, Poin_, S, F1, F2 );

               F3 := nil;
               C3 := C_.Cell[ C_.CornOf( F1 ) ];
               for I := 0 to 3 do
               begin
                    if ( C3.Poin[ I ] <> Poin_ ) and ( C3.Poin[ I ] <> S ) and ( C3.Poin[ I ] <> F2 ) then F3 := C3.Poin[ I ];
               end;

               if CellOK( Poin_, F1, F2, F3 ) then  // 残る Poin_ 側の胞が有効であること（耳の側は検査済み）
               begin
                    Exit( Flip32( C_, Poin_, S ) );  // 捻れた隣接（退化）では見送られる
               end;
          end;

          // 3-2 フリップ：辺 ( Poin_, T ) を消す
          if DT and not DS then
          begin
               EdgeLink( C_, Poin_, T, F1, F2 );

               F3 := nil;
               C3 := C_.Cell[ C_.CornOf( F1 ) ];
               for I := 0 to 3 do
               begin
                    if ( C3.Poin[ I ] <> Poin_ ) and ( C3.Poin[ I ] <> T ) and ( C3.Poin[ I ] <> F2 ) then F3 := C3.Poin[ I ];
               end;

               if CellOK( Poin_, F1, F2, F3 ) then
               begin
                    Exit( Flip32( C_, Poin_, T ) );
               end;
          end;

          // 2-3 フリップ：線分 ( A, B ) が共有面を貫く（＝残る2胞が有効）なら、共有面を張り替えて耳を切り出す
          if not DS and not DT then
          begin
               if CellOK( A, B, Poin_, S ) and CellOK( A, B, T, Poin_ ) then
               begin
                    Exit( Flip23( C_, K_ ) );
               end;
          end;
     end;
//･･･････････････････････････････････････････
     function Unhook :Boolean;  // 次数4になった Poin_ を、4胞 → 1胞の畳み込みで取り除く
     var
        C, N :TDelaCell3D;
        A, I, K :Byte;
        Qs :array [ 0..3 ] of TDelaPoin3D;
        Ks :array [ 0..3 ] of Byte;
        W :TDelaPoin3D;
        Hs :array [ 0..3 ] of TCellHook;
        AbsentN :Integer;
     begin
          Result := False;

          C := Star[ 0 ];  A := C.CornOf( Poin_ );

          Qs[ 1 ] := C.Poin[ VertTable[ A ]._[ 1 ] ];  // リンク四面体 = ( Q0, Q1, Q2, Q3 )（向きはリンク面の正準順から従う）
          Qs[ 2 ] := C.Poin[ VertTable[ A ]._[ 2 ] ];
          Qs[ 3 ] := C.Poin[ VertTable[ A ]._[ 3 ] ];

          Qs[ 0 ] := nil;
          for I := 0 to 3 do
          begin
               W := Star[ 1 ].Poin[ I ];

               if ( W <> Poin_ ) and ( W <> Qs[ 1 ] ) and ( W <> Qs[ 2 ] ) and ( W <> Qs[ 3 ] ) then begin  Qs[ 0 ] := W;  Break;  end;
          end;

          if Qs[ 0 ] = nil then Exit;  // 退化した星（リンクが四面体の境界を成さない）→ 作り直しへ

          // 残る1胞が最終形（正の向きで、全ての点に対して空球）であることを確かめる。
          // 通らない残り方をした星（無限遠胞の退化）は作り直しへ回す
          if not CellOK( Qs[ 0 ], Qs[ 1 ], Qs[ 2 ], Qs[ 3 ] ) then Exit;

          for W in Poins do
          begin
               if W = Poin_ then Continue;

               if W.InSphered( Qs[ 0 ], Qs[ 1 ], Qs[ 2 ], Qs[ 3 ] ) > 0 then Exit;
          end;

          for I := 0 to 3 do
          begin
               Hs[ I ] := Hook( Star[ I ], Star[ I ].CornOf( Poin_ ) );  // 各胞のリンク面の外側を控える

               if Hs[ I ].Cell.CornOf( Poin_ ) >= 0 then Exit;  // リンク面が星の中で貼り合っている（退化）→ 作り直しへ

               AbsentN := 0;  // 星の胞はリンク四面体の頂点のうちちょうど3つ＋ Poin_ から成ること（退化した星は作り直しへ）

               for K := 0 to 3 do
               begin
                    if Star[ I ].CornOf( Qs[ K ] ) < 0 then begin  Inc( AbsentN );  Ks[ I ] := K;  end;
               end;

               if AbsentN <> 1 then Exit;
          end;

          N := NewCell( Qs[ 0 ], Qs[ 1 ], Qs[ 2 ], Qs[ 3 ] );

          for I := 0 to 3 do
          begin
               if not N.CanWeld( Ks[ I ], Hs[ I ].Cell, Hs[ I ].Corn ) then  // 捻れた隣接（退化）→ 作り直しへ
               begin
                    N.Free;

                    for K := 0 to 3 do Star[ K ].BindPoins;  // アンカーを元に戻す

                    Exit;
               end;
          end;

          for I := 0 to 3 do N.Weld( Ks[ I ], Hs[ I ].Cell, Hs[ I ].Corn );  // 星の胞に無い頂点の対面が、その胞のリンク面

          for I := 0 to 3 do Star[ I ].Free;

          Result := True;
     end;
//･･･････････････････････････････････････････
     procedure Rebuild;  // フリップで畳み切れない退化配置（凸包上の複雑な星）は、点を除いて胞を作り直す（最後の保険）
     begin
          inherited Clear;  // 胞を全解放する（点のインスタンスはそのまま残る）

          Poin_.Free;

          _PoinInf.Cell := nil;

          if InitCell then InsertLoose;  // 共線でない種を探して張り直す（見つからなければ胞は張れない）
     end;
//･･･････････････････････････････････････････
var
   D, N :Integer;
   C :TDelaCell3D;
   K :Byte;
   Flipped :Boolean;
begin
     Result := False;

     if ( Poin_ = nil ) or Poin_.Inf or ( Poin_.Parent <> PoinSet ) then Exit;

     case Poins.ChildrsN of
       1: begin
               Poin_.Free;
          end;
       2,
       3: begin
               inherited Clear;  // 胞を全解放する（残り2点以下では胞は張れない）

               Poin_.Free;
          end;
     else
          ScanStar;

          if Length( Star ) = 0 then  // どの胞にも属さない点（退化配置で繋がらなかった点）はそのまま外せる
          begin
               Poin_.Free;

               _OnChange.Run( Self );

               Exit( True );
          end;

          CollectLink;

          // 有効な耳をフリップで確定していき、星を4胞まで縮める
          D := Length( Star );

          for N := 1 to 2 * D * D + 8 do
          begin
               if Length( Star ) = 4 then Break;

               Flipped := False;

               for C in Star do
               begin
                    for K := 0 to 3 do
                    begin
                         if C.Poin[ K ] = Poin_ then Continue;  // Poin_ を含む3面が耳の候補

                         if EarTry( C, K ) then begin  Flipped := True;  Break;  end;
                    end;

                    if Flipped then Break;
               end;

               if not Flipped then Break;  // フリップできる有効な耳が無い（凹の反射辺の周囲が4胞以上など）→ 作り直しへ

               ScanStar;  // フリップで星が変わった
          end;

          // 星が4胞なら 4→1 の畳み込みで取り除く。畳めない残り方（退化）は作り直しで確実に取り除く
          if ( Length( Star ) <> 4 ) or not Unhook then Rebuild
                                                   else Poin_.Free;
     end;

     _OnChange.Run( Self );

     Result := True;
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
