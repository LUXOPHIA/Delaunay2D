unit LUX.Delaunay.D2.Periodic;

// 周期境界２Ｄドロネー図（逐次添加法・最小表現・被覆空間なし）
//
//【モデル】
// ・平坦トーラス T = [0,L)² 上のドロネー三角形分割。ゴースト点の複製も被覆空間も
//   使わず、常に最小表現（頂点 n 個・面 2n 枚）を保つ。n = 1 でも「1頂点・2面」の
//   Δ複体（同じ頂点の実体を、異なる格子オフセットで面が3回参照する）として成立する。
//   これは 2009 年の VoronoiTools2P（Jump / Shift を持ち回る周期 Bowyer-Watson）の
//   方式を洗練し直したものである。
// ・LUX.Data.Model.TriFlip の接続構造（Poin / Face / Corn）は頂点の同一性ではなく
//   角番号の組合せで巡回するため、Δ複体をそのまま載せられる。TriFlip 本体は無変更で、
//   周期固有の情報（格子オフセットと幾何）だけを派生クラスが加える。
//     TPeriPoin2D    … TTriPoin2D<TPeriFace2D>                 ＋ サイト番号（Site）
//     TPeriPoinSet2D … TTriPoinSet2D<TPeriPoin2D>
//     TPeriFace2D    … TTriFace2D<TPeriPoin2D,TPeriFace2D>     ＋ 角ごとの格子オフセット・幾何
//     TPeriFaceSet2D … TTriFaceSet2D<TPeriFace2D,TPeriPoinSet2D>
//     TPeriDelaunay2D … TPeriFaceSet2D ＋ サイトの追加・削除
//
//【格子オフセットと正準化】
// ・頂点の座標は常に正準（∈ [0,L)²）。面は角ごとに格子オフセット o ∈ {0..3}²
//   （Off[K]・軸ごと2ビット）を持ち、角の幾何座標は Poin[K].Pos + Off[K]·L。
//   面ごとに普遍被覆 R² への独自のリフトを持ち、隣接面のリフトとは格子ベクトルだけ
//   ずれ得る（NeigShift）。オフセットは面の生成時に必ず正規化する（軸ごとの最小 = 0）
//   ので、追加・削除を繰り返しても点や面の実体が基本領域から乖離していくことはなく、
//   「散らばった実体を後から巻き戻す」処理は原理的に不要である。
// ・任意の空円の直径は「1サイトの格子コピーを避ける円」で抑えられ、高々 √2·L。
//   ゆえに面の軸方向の張り出しは 2L 未満で、正規化後のオフセットは {0,1,2} に収まる
//   （格納は2ビット = 0..3）。
//
//【座標の量子化と厳密述語】
// ・L を 2 の冪グリッド q = 2^(E-17)（L/q = K ∈ [2^16, 2^17]）へスナップし、
//   サイト座標も q の整数倍へスナップする。量子化誤差は L·2⁻¹⁶ 程度で実用上見えない。
// ・これにより全ての幾何は整数格子上にあり、向き判定（Orient）は 64 ビット整数で、
//   空円判定（InCircle）は 128 ビット整数の累算で「厳密に」評価できる。浮動小数の
//   丸めによる述語の誤判定 ―― 退化配置での構造破壊の源 ―― が原理的に存在しない。
//
//【点の追加（普遍被覆上の Bowyer-Watson）】
// ・追加点 p のリフト p̂ をひとつ固定し、キャビティ（p̂ を外接円に含む面のリフト）を
//   普遍被覆の中で幅優先に集める。要素は（面の実体 × 格子平行移動）の対であり、
//   疎な配置では同じ面の実体が異なる平行移動で2回入り得る（外接円が p の複数の
//   周期像を含む場合）。訪問済み判定は (面, 平行移動) の辞書で行う。
// ・通常の場合（p が自分の周期像とドロネー隣接にならない場合）は、境界辺ごとに
//   錐の面 ( A, p, B ) を張る普通の Bowyer-Watson で正しい。錐の妥当性は
//   「どの錐面の外接円も p の周期像を含まない」ことを厳密述語で確かめる。
// ・疎な配置では p が自分の周期像と隣接し、p を2つの角に持つ面（自己辺 p–p）が
//   必要になる。このとき錐は正しくないので、p̂ のスター（扇）を候補点集合
//   （穴の境界頂点とその平行移動像 ＋ p の格子像）からギフトラッピングで直接
//   構築する。扇の面をトーラスへ射影すると同じ面が2回現れ得るので、回転・平行移動
//   正規化キーで同一視し、縫合の相手は幾何計算（辺の反対側の第3頂点）で一意に
//   解決する。共円の退化（タイ）を検出した場合は何も壊さずに失敗を返す
//   （AddPoin は nil を返す。平面版と同じ「退化は拒否し、分割は常に正しい」流儀）。
// ・位置検索はジャンプ＆ウォーク（累積平行移動つき・厳密述語）。退化時は全面走査。
//
//【点の削除（局所・星の除去と耳刈り埋め戻し）】
// ・頂点のひとつのリフト v̂ の周りの星を角の巡回で集め、穴の境界多角形をリフト
//   座標で取り出し、ドロネー耳 ―― 他のリンク頂点とその平行移動像を外接円に含まない
//   耳 ―― で埋める。縫合は「厳密座標の一致 → 外側も消える辺は隣の穴の平行移動 μ を
//   幾何的に特定して埋め草どうしを縫う」の二段方式。埋め草の計画と検証が完成して
//   から初めてメッシュに触れる（途中失敗は無傷で False）。失敗時と極小サイト数
//   （≤ 3）はサイト列からの再構築へ退避する。
//
// ・TriFlip のファイル入出力はオフセットを保存できないため封じてある（例外を投げる）。

interface //#################################################################### ■

uses System.Types,
     LUX,
     LUX.D2,
     LUX.D3,
     LUX.Data.Model.TriFlip.core,
     LUX.Data.Model.TriFlip.D2;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     TPeriPoin2D     = class;
     TPeriPoinSet2D  = class;
     TPeriFace2D     = class;
     TPeriFaceSet2D  = class;
     TPeriDelaunay2D = class;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriPoin2D

     // 頂点。サイトと1対1（コピーは存在しない）。
     TPeriPoin2D = class( TTriPoin2D<TPeriFace2D> )
     private
       _Site :Integer;
     protected
     public
       ///// P R O P E R T Y
       property Site :Integer read _Site;  // サイト番号（TPeriDelaunay2D.Site[] の添字）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriPoinSet2D

     // 点集合。
     TPeriPoinSet2D = class( TTriPoinSet2D<TPeriPoin2D> )
     private
     protected
       ///// M E T H O D
       function LoadPoin( const Pos_:TSingle2D ) :TTriPoin<TSingle2D>; override;  // 読み込む点を TPeriPoin2D として生成する
     public
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriFace2D

     // 三角形。角ごとの格子オフセット（0..3・軸ごと2ビット）と、リフト座標での幾何を持つ。
     TPeriFace2D = class( TTriFace2D<TPeriPoin2D,TPeriFace2D> )
     private
       _Offs :Word;  // 格子オフセット（角Kの X = bit 4K-4..4K-3, Y = bit 4K-2..4K-1）
       ///// A C C E S S O R
       function GetModel :TPeriDelaunay2D;
       function GetOff( const I_:Byte ) :TPoint;
       procedure SetOff( const I_:Byte; const Off_:TPoint );
     protected
     public
       ///// P R O P E R T Y
       property Model :TPeriDelaunay2D read GetModel;  // 属すモデル（= Parent）
       property Off[ const I_:Byte ] :TPoint read GetOff write SetOff;  // 角の格子オフセット（0..3）
       ///// M E T H O D
       function CornGrid( const I_:Byte ) :TPoint;     // 角の格子座標（自面のリフト・q 単位・厳密）
       function CornPos( const I_:Byte ) :TSingle2D;   // 角の幾何座標（自面のリフト。格子上なので厳密）
       procedure CircumD( out Center_:TDouble2D; out Radius2_:Double );  // 外心（自面のリフト）と半径の平方
       function CircumPos :TSingle2D;
       function CircumRadius :Single;
       function NeigShift( const I_:Byte ) :TSingle2D;  // 隣接面 Face[I] のリフト座標を自面のリフトへ移す平行移動量
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriFaceSet2D

     // 面集合。
     TPeriFaceSet2D = class( TTriFaceSet2D<TPeriFace2D,TPeriPoinSet2D> )
     private
     protected
       ///// A C C E S S O R
       function GetPoins :TPeriPoinSet2D;
     public
       ///// P R O P E R T Y
       property Poins :TPeriPoinSet2D read GetPoins;  // 頂点の集合（サイトと1対1）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunay2D

     TPeriDelaunay2D = class( TPeriFaceSet2D )
     private
       type
           TLift = record            // 面のリフト（T は L 単位の格子平行移動）
             F :TPeriFace2D;
             T :TPoint;
           end;
           TBond = record            // キャビティ・穴の境界辺（GA → GB・内側は左）と両側の面のリフト
             GA, GB :TPoint;         // 両端の格子座標（q 単位・リフト内）
             PA, PB :TPeriPoin2D;    // 両端の頂点の実体
             FIn :TPeriFace2D;       // 内側（消える側）の面のリフト
             TIn :TPoint;
             OF_ :TPeriFace2D;       // 外側の面のリフト
             OC  :Byte;
             OT  :TPoint;
           end;
           TCand = record            // スター構築の候補点（実体と被覆格子座標）
             P :TPeriPoin2D;
             G :TPoint;
           end;
     private
       _Size  :Single;               // 基本領域の一辺 L（グリッドへスナップ済み）
       _GridQ :Single;               // 座標グリッドの量子 q（2の冪）
       _GridK :Integer;              // L / q（2^16 ≤ K ≤ 2^17）
       _SiteQ :TArray<TSingle2D>;    // サイトの正準座標（∈ [0,L)²・グリッド上）
       _CentQ :TArray<TPeriPoin2D>;  // サイトの頂点（1対1）
       _LocalDelN   :Integer;        // 統計：局所削除の回数
       _RebuildDelN :Integer;        // 統計：再構築に退避した削除の回数
       _StarInsN    :Integer;        // 統計：スター構築（自己隣接の疎な配置）で追加した回数
       _OnChange :TDelegates;
       ///// A C C E S S O R
       function GetFaces :TPeriFaceSet2D;
       function GetSitesN :Integer;
       function GetSite( const I_:Integer ) :TSingle2D;
       function GetSitePoin( const I_:Integer ) :TPeriPoin2D;
       procedure SetSize( const Size_:Single );
       ///// M E T H O D
       procedure SetSizeCore( const Size_:Single );  // L をグリッドへスナップして確定する
       function WrapSnap1( const X_:Single ) :Single;
       function GridOf( const Pos_:TSingle2D ) :TPoint;
       function NewPoin( const Pos_:TSingle2D; const Site_:Integer ) :TPeriPoin2D;
       function NewFaceG( const P1_:TPeriPoin2D; const G1_:TPoint;
                          const P2_:TPeriPoin2D; const G2_:TPoint;
                          const P3_:TPeriPoin2D; const G3_:TPoint ) :TPeriFace2D;
       procedure SeedTwo( const Poin_:TPeriPoin2D );
       function JumpPoin( const Pos_:TSingle2D ) :TPeriPoin2D;
       function IsHitLift( const Face_:TPeriFace2D; const T_:TPoint; const MP_:TPoint; const QRank_:Integer ) :Boolean;
       function FindHitLift( const Pos_:TSingle2D; const QRank_:Integer; out Face_:TPeriFace2D; out T_:TPoint ) :Boolean;
       function InsertPoin( const Poin_:TPeriPoin2D; const Face_:TPeriFace2D; const T0_:TPoint ) :Boolean;
       function TryLocalDelete( const Poin_:TPeriPoin2D ) :Boolean;
       procedure RemoveSiteAt( const Site_:Integer );
       procedure BuildAll;
     protected
     public
       constructor Create; overload; override;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property Faces    :TPeriFaceSet2D read GetFaces  ;  // 面の集合（＝自分自身。トーラスの面そのもの）
       property Size     :Single         read   _Size    write SetSize;  // 基本領域の一辺 L（設定はグリッドへスナップし、サイトを巻き直して再構築する）
       property SitesN   :Integer        read GetSitesN ;  // サイトの数
       property Site    [ const I_:Integer ] :TSingle2D   read GetSite    ;  // サイトの正準座標（∈ [0,L)²）
       property SitePoin[ const I_:Integer ] :TPeriPoin2D read GetSitePoin;  // サイトの頂点
       property OnChange :TDelegates     read   _OnChange;  // 構造が変化したときに発火（Add / Del で多播購読）
       property LocalDelN   :Integer read _LocalDelN  ;  // 統計：局所削除の回数
       property RebuildDelN :Integer read _RebuildDelN;  // 統計：再構築に退避した削除の回数
       property StarInsN    :Integer read _StarInsN   ;  // 統計：スター構築で追加した回数
       ///// M E T H O D
       function WrapPos( const Pos_:TSingle2D ) :TSingle2D;  // 任意の座標を正準座標（∈ [0,L)²・グリッド上）へ写す
       function TorusDist2( const A_,B_:TSingle2D ) :Single;  // トーラス距離の平方（引数は正準座標）
       function HitCircleFace( const Pos_:TSingle2D ) :TPeriFace2D;  // Pos_ を空円に含む面（ジャンプ＆ウォーク）
       function FindMaxCircle :TPeriFace2D;  // 最大半径の空円を持つ面（面が無ければ nil。トーラス上に無限半径の面は無いので全面が対象）
       function FindNearPoin( const Pos_:TSingle2D; out Poin_:TPeriPoin2D ) :Single;  // 最近傍サイトの頂点と、そのトーラス距離
       function AddPoin( const Pos_:TSingle2D ) :TPeriPoin2D;  // サイトの追加（重複・共円の退化は nil）
       function DeletePoin( const Poin_:TPeriPoin2D ) :Boolean;  // サイトの削除（局所処理。退化時のみ再構築）
       function TorusFaces :TArray<TPeriFace2D>;  // トーラスの全ての面（＝ Faces の配列。ビューア用）
       procedure Clear; reintroduce;  // サイトと面を全消去する
       procedure SaveToFile( const FileName_:String ); override;    // 非対応（オフセットを保存できないため封じる）
       procedure LoadFromFile( const FileName_:String ); override;  // 非対応
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

uses System.SysUtils, System.Math, System.Generics.Collections;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】
// 厳密整数述語。座標は格子（q 単位）の整数で、|差| < 2^21 を前提とする。
// Orient は 64 ビットで、InCircle は 128 ビットの累算で、丸め誤差なしに評価できる。

type
    TInt128 = record
      Hi :Int64;
      Lo :UInt64;
    end;

{$IFOPT Q+}{$DEFINE _PERI_Q}{$Q-}{$ENDIF}  // 128ビット演算は意図的に桁あふれを使う

procedure Acc128( var A_:TInt128; const X_,Y_:Int64 );  // A += X·Y（|X|,|Y| < 2^63）
var
   Neg :Boolean;
   UX, UY, X0, X1, Y0, Y1, LL, M1, M2, LoP, T :UInt64;
   HiP :UInt64;
begin
     Neg := ( X_ < 0 ) xor ( Y_ < 0 );

     if X_ < 0 then UX := UInt64( -X_ ) else UX := UInt64( X_ );
     if Y_ < 0 then UY := UInt64( -Y_ ) else UY := UInt64( Y_ );

     X0 := UX and $FFFFFFFF;  X1 := UX shr 32;
     Y0 := UY and $FFFFFFFF;  Y1 := UY shr 32;

     LL  := X0 * Y0;
     M1  := X1 * Y0;
     M2  := X0 * Y1;
     HiP := X1 * Y1;

     LoP := LL + ( M1 shl 32 );  if LoP < LL then Inc( HiP );  HiP := HiP + ( M1 shr 32 );
     T   := LoP;
     LoP := LoP + ( M2 shl 32 );  if LoP < T then Inc( HiP );  HiP := HiP + ( M2 shr 32 );

     if Neg then
     begin
          if A_.Lo < LoP then A_.Hi := A_.Hi - Int64( HiP ) - 1
                         else A_.Hi := A_.Hi - Int64( HiP );

          A_.Lo := A_.Lo - LoP;
     end
     else
     begin
          T := A_.Lo + LoP;

          if T < A_.Lo then Inc( A_.Hi );

          A_.Lo := T;
          A_.Hi := A_.Hi + Int64( HiP );
     end;
end;

function Sign128( const A_:TInt128 ) :Integer;
begin
     if A_.Hi < 0 then Result := -1
     else
     if ( A_.Hi > 0 ) or ( A_.Lo > 0 ) then Result := +1
                                       else Result :=  0;
end;

{$IFDEF _PERI_Q}{$Q+}{$UNDEF _PERI_Q}{$ENDIF}

//------------------------------------------------------------------------------

function OrientG( const Q_,L_,R_:TPoint ) :Int64;
begin
     // 有向線分 L → R に対する… (L-Q)×(R-Q)。厳密。
     // OrientG( U, V, C ) > 0 ⇔ C は有向辺 U → V の左側
     Result := Int64( L_.X - Q_.X ) * ( R_.Y - Q_.Y ) - Int64( L_.Y - Q_.Y ) * ( R_.X - Q_.X );
end;

function InCircleSign( const A_,B_,C_,Q_:TPoint ) :Integer;
var
   X1, Y1, Z1, X2, Y2, Z2, X3, Y3, Z3 :Int64;
   Acc :TInt128;
begin
     // 判定点 Q を原点とするリフト行列式の符号（正 = 円の内側。( A, B, C ) は正の向き）。厳密
     X1 := A_.X - Q_.X;  Y1 := A_.Y - Q_.Y;  Z1 := X1 * X1 + Y1 * Y1;
     X2 := B_.X - Q_.X;  Y2 := B_.Y - Q_.Y;  Z2 := X2 * X2 + Y2 * Y2;
     X3 := C_.X - Q_.X;  Y3 := C_.Y - Q_.Y;  Z3 := X3 * X3 + Y3 * Y3;

     Acc.Hi := 0;
     Acc.Lo := 0;

     Acc128( Acc,  X1, Y2 * Z3 - Y3 * Z2 );
     Acc128( Acc, -Y1, X2 * Z3 - X3 * Z2 );
     Acc128( Acc,  Z1, X2 * Y3 - X3 * Y2 );

     Result := Sign128( Acc );
end;

function InCirclePert( const A_,B_,C_,Q_:TPoint; const RA_,RB_,RC_,RQ_:Integer ) :Integer;
// 記号摂動つき空円判定。共円（行列式 = 0）のとき、サイト順位 R の小さい点から順に
// リフトを δ^R だけ持ち上げたとみなして符号を決める（Simulation of Simplicity）。
// 摂動はサイト単位（同じサイトの全ての周期像に共通）なので格子同変であり、
// 「同一頂点の平行移動対による構造的な共円」も決定的に解消される。
// それでも決まらない超退化（4点が共線など）だけが 0 を返す
var
   R :array [ 0..3 ] of Integer;
   C4 :array [ 0..3 ] of Int64;
   O :array [ 0..3 ] of Integer;
   I, J, T :Integer;
   S :Int64;
begin
     Result := InCircleSign( A_, B_, C_, Q_ );

     if Result <> 0 then Exit;

     R[ 0 ] := RA_;  C4[ 0 ] :=  OrientG( Q_, B_, C_ );  // ∂det/∂z の余因子
     R[ 1 ] := RB_;  C4[ 1 ] := -OrientG( Q_, A_, C_ );
     R[ 2 ] := RC_;  C4[ 2 ] :=  OrientG( Q_, A_, B_ );
     R[ 3 ] := RQ_;  C4[ 3 ] := -OrientG( A_, B_, C_ );

     O[ 0 ] := 0;  O[ 1 ] := 1;  O[ 2 ] := 2;  O[ 3 ] := 3;

     for I := 0 to 2 do  // 順位の昇順に並べる
     for J := I + 1 to 3 do
     begin
          if R[ O[ J ] ] < R[ O[ I ] ] then begin  T := O[ I ];  O[ I ] := O[ J ];  O[ J ] := T;  end;
     end;

     I := 0;
     while I <= 3 do
     begin
          S := C4[ O[ I ] ];

          J := I + 1;
          while ( J <= 3 ) and ( R[ O[ J ] ] = R[ O[ I ] ] ) do  // 同じサイト（同順位）の周期像は余因子を束ねる
          begin
               S := S + C4[ O[ J ] ];  Inc( J );
          end;

          if S > 0 then Exit( +1 );
          if S < 0 then Exit( -1 );

          I := J;
     end;

     Result := 0;
end;

//------------------------------------------------------------------------------

function PtAdd( const A_,B_:TPoint ) :TPoint;
begin
     Result.X := A_.X + B_.X;
     Result.Y := A_.Y + B_.Y;
end;

function PtSub( const A_,B_:TPoint ) :TPoint;
begin
     Result.X := A_.X - B_.X;
     Result.Y := A_.Y - B_.Y;
end;

function PtMulAdd( const A_:TPoint; const B_:TPoint; const K_:Integer ) :TPoint;  // A + B·K
begin
     Result.X := A_.X + B_.X * K_;
     Result.Y := A_.Y + B_.Y * K_;
end;

function PtEq( const A_,B_:TPoint ) :Boolean;
begin
     Result := ( A_.X = B_.X ) and ( A_.Y = B_.Y );
end;

function GridKey( const G_:TPoint ) :Int64;  // 格子座標の辞書キー（|成分| < 2^22）
begin
     Result := ( Int64( G_.X + $400000 ) shl 24 ) or Int64( G_.Y + $400000 );
end;

function LiftEdgeStr( const A_,B_:TPoint ) :String;  // リフト座標の厳密な有向辺キー
begin
     Result := IntToStr( A_.X ) + ',' + IntToStr( A_.Y ) + '>' + IntToStr( B_.X ) + ',' + IntToStr( B_.Y );
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriPoinSet2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TPeriPoinSet2D.LoadPoin( const Pos_:TSingle2D ) :TTriPoin<TSingle2D>;
begin
     Result := TPeriPoin2D.Create( Pos_, Self );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriFace2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TPeriFace2D.GetModel :TPeriDelaunay2D;
begin
     Result := TPeriDelaunay2D( TObject( Parent ) );
end;

function TPeriFace2D.GetOff( const I_:Byte ) :TPoint;
var
   S :Byte;
begin
     S := ( I_ - 1 ) shl 2;

     Result.X := ( _Offs shr   S       ) and 3;
     Result.Y := ( _Offs shr ( S + 2 ) ) and 3;
end;

procedure TPeriFace2D.SetOff( const I_:Byte; const Off_:TPoint );
var
   S :Byte;
begin
     S := ( I_ - 1 ) shl 2;

     _Offs := ( _Offs and not ( Word( 15 ) shl S ) )
           or ( Word( ( Off_.X and 3 ) or ( ( Off_.Y and 3 ) shl 2 ) ) shl S );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function TPeriFace2D.CornGrid( const I_:Byte ) :TPoint;
var
   M :TPeriDelaunay2D;
begin
     M := Model;

     Result := PtMulAdd( M.GridOf( Poin[ I_ ].Pos ), Off[ I_ ], M._GridK );
end;

function TPeriFace2D.CornPos( const I_:Byte ) :TSingle2D;
var
   L :Single;
   O :TPoint;
begin
     L := Model.Size;
     O := Off[ I_ ];

     with Poin[ I_ ].Pos do Result := TSingle2D.Create( X + O.X * L, Y + O.Y * L );  // 格子上なので厳密
end;

//------------------------------------------------------------------------------

procedure TPeriFace2D.CircumD( out Center_:TDouble2D; out Radius2_:Double );
var
   Q :Single;
   G1, G2, G3 :TPoint;
   X2, Y2, X3, Y3, N2, N3, D, CX, CY :Double;
begin
     // 角1を基準に平行移動して評価する。D = 4×面積 は正の向きで正
     Q := Model._GridQ;

     G1 := CornGrid( 1 );
     G2 := CornGrid( 2 );
     G3 := CornGrid( 3 );

     X2 := G2.X - G1.X;  Y2 := G2.Y - G1.Y;
     X3 := G3.X - G1.X;  Y3 := G3.Y - G1.Y;

     N2 := X2 * X2 + Y2 * Y2;
     N3 := X3 * X3 + Y3 * Y3;

     D := 2 * ( X2 * Y3 - Y2 * X3 );

     if D = 0 then  // 潰れた面（正しい分割では現れない）
     begin
          Center_.X := G1.X * Q;
          Center_.Y := G1.Y * Q;

          Radius2_ := Infinity;  Exit;
     end;

     CX := ( Y3 * N2 - Y2 * N3 ) / D;
     CY := ( X2 * N3 - X3 * N2 ) / D;

     Center_.X := ( G1.X + CX ) * Q;
     Center_.Y := ( G1.Y + CY ) * Q;

     Radius2_ := ( CX * CX + CY * CY ) * Q * Q;
end;

function TPeriFace2D.CircumPos :TSingle2D;
var
   C :TDouble2D;
   R2 :Double;
begin
     CircumD( C, R2 );

     Result := TSingle2D.Create( C.X, C.Y );
end;

function TPeriFace2D.CircumRadius :Single;
var
   C :TDouble2D;
   R2 :Double;
begin
     CircumD( C, R2 );

     Result := Sqrt( R2 );
end;

function TPeriFace2D.NeigShift( const I_:Byte ) :TSingle2D;
var
   G :TPeriFace2D;
   GK :Byte;
begin
     // 共有辺の対応は角番号で決まる（自分の R 角 = 隣の L 角）。Δ複体では頂点の
     // 同一性で探してはならない（同じ実体が複数の角に現れ得る）
     G  := Face[ I_ ];
     GK := Corn[ I_ ];

     Result := CornPos( VertTableInc[ I_ ].R ) - G.CornPos( VertTableInc[ GK ].L );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriFaceSet2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TPeriFaceSet2D.GetPoins :TPeriPoinSet2D;
begin
     Result := PoinSet;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPeriDelaunay2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TPeriDelaunay2D.GetFaces :TPeriFaceSet2D;
begin
     Result := Self;
end;

function TPeriDelaunay2D.GetSitesN :Integer;
begin
     Result := Length( _SiteQ );
end;

function TPeriDelaunay2D.GetSite( const I_:Integer ) :TSingle2D;
begin
     Result := _SiteQ[ I_ ];
end;

function TPeriDelaunay2D.GetSitePoin( const I_:Integer ) :TPeriPoin2D;
begin
     Result := _CentQ[ I_ ];
end;

procedure TPeriDelaunay2D.SetSize( const Size_:Single );
var
   I :Integer;
begin
     if not ( ( Size_ > 0 ) and ( Size_ < 1E18 ) ) then Exit;  // NaN・0・負・∞は無視する

     SetSizeCore( Size_ );

     for I := 0 to High( _SiteQ ) do _SiteQ[ I ] := WrapPos( _SiteQ[ I ] );  // 新しい領域へ巻き直す（重複はビルドで除かれる）

     BuildAll;

     _OnChange.Run( Self );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TPeriDelaunay2D.SetSizeCore( const Size_:Single );
var
   M :Single;
   E :Integer;
begin
     Frexp( Size_, M, E );  // Size_ = M·2^E（M ∈ [0.5,1)）

     _GridQ := Ldexp( 1, E - 17 );  // q = 2^(E-17) → L/q ∈ [2^16, 2^17]。格子座標が整数になり述語が厳密になる

     _GridK := Round( Size_ / _GridQ );

     _Size := _GridK * _GridQ;
end;

function TPeriDelaunay2D.WrapSnap1( const X_:Single ) :Single;
var
   M :Int64;
begin
     M := Round( X_ / _GridQ ) mod _GridK;  // 格子番号での剰余なので、巻き戻しに丸め誤差が無い

     if M < 0 then Inc( M, _GridK );

     Result := M * _GridQ;
end;

function TPeriDelaunay2D.GridOf( const Pos_:TSingle2D ) :TPoint;
begin
     Result.X := Round( Pos_.X / _GridQ );  // 座標は格子上にあるので厳密
     Result.Y := Round( Pos_.Y / _GridQ );
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.NewPoin( const Pos_:TSingle2D; const Site_:Integer ) :TPeriPoin2D;
begin
     Result := TPeriPoin2D.Create( Pos_, PoinSet );

     Result._Site := Site_;
end;

function TPeriDelaunay2D.NewFaceG( const P1_:TPeriPoin2D; const G1_:TPoint;
                                   const P2_:TPeriPoin2D; const G2_:TPoint;
                                   const P3_:TPeriPoin2D; const G3_:TPoint ) :TPeriFace2D;
var
   T1, T2, T3 :TPoint;
   MX, MY :Integer;
//･･･････････････････････････････････････････
     function OffOf( const P_:TPeriPoin2D; const G_:TPoint ) :TPoint;
     var
        M :TPoint;
     begin
          M := GridOf( P_.Pos );

          Result.X := ( G_.X - M.X ) div _GridK;  // 差は必ず K の倍数（格子座標は m + t·K）
          Result.Y := ( G_.Y - M.Y ) div _GridK;
     end;
//･･･････････････････････････････････････････
begin
     T1 := OffOf( P1_, G1_ );
     T2 := OffOf( P2_, G2_ );
     T3 := OffOf( P3_, G3_ );

     MX := Min( T1.X, Min( T2.X, T3.X ) );  // 面ごとのリフトを正規化する（軸ごとの最小オフセット = 0）。
     MY := Min( T1.Y, Min( T2.Y, T3.Y ) );  // 実体の乖離はここで常に断ち切られる

     T1.X := T1.X - MX;  T1.Y := T1.Y - MY;
     T2.X := T2.X - MX;  T2.Y := T2.Y - MY;
     T3.X := T3.X - MX;  T3.Y := T3.Y - MY;

     Assert( ( ( T1.X or T2.X or T3.X or T1.Y or T2.Y or T3.Y ) and not 3 ) = 0 );  // 空円直径 ≤ √2·L より 0..2 に収まる

     Result := TPeriFace2D.Create( Self );

     Result.Poin[ 1 ] := P1_;  Result.Off[ 1 ] := T1;
     Result.Poin[ 2 ] := P2_;  Result.Off[ 2 ] := T2;
     Result.Poin[ 3 ] := P3_;  Result.Off[ 3 ] := T3;

     Result.BindPoins;
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunay2D.SeedTwo( const Poin_:TPeriPoin2D );
// 1サイトのトーラス分割（1頂点・2面のΔ複体）。正方形を正の向きの2枚に割る
var
   M, M10, M11, M01 :TPoint;
   F1, F2 :TPeriFace2D;
begin
     M := GridOf( Poin_.Pos );

     M10 := PtAdd( M, TPoint.Create( _GridK, 0      ) );
     M11 := PtAdd( M, TPoint.Create( _GridK, _GridK ) );
     M01 := PtAdd( M, TPoint.Create( 0,      _GridK ) );

     F1 := NewFaceG( Poin_, M, Poin_, M10, Poin_, M11 );
     F2 := NewFaceG( Poin_, M, Poin_, M11, Poin_, M01 );

     // 辺の対応（平行移動不変な変位で決まる）:
     //   F1の辺1 (M10→M11, d=(0,+K)) ↔ F2の辺2 (M01→M,  d=(0,-K))
     //   F1の辺2 (M11→M,   d=(-,-) ) ↔ F2の辺3 (M →M11, d=(+,+))
     //   F1の辺3 (M →M10,  d=(+K,0)) ↔ F2の辺1 (M11→M01, d=(-K,0))
     F1.Face[ 1 ] := F2;  F1.Corn[ 1 ] := 2;   F2.Face[ 2 ] := F1;  F2.Corn[ 2 ] := 1;
     F1.Face[ 2 ] := F2;  F1.Corn[ 2 ] := 3;   F2.Face[ 3 ] := F1;  F2.Corn[ 3 ] := 2;
     F1.Face[ 3 ] := F2;  F1.Corn[ 3 ] := 1;   F2.Face[ 1 ] := F1;  F2.Corn[ 1 ] := 3;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.JumpPoin( const Pos_:TSingle2D ) :TPeriPoin2D;
var
   N, K, I :Integer;
   P :TPeriPoin2D;
   D, Dm :Single;
begin
     N := Poins.ChildrsN;

     Result := Poins[ Random( N ) ];  Dm := TorusDist2( Pos_, Result.Pos );

     K := 1;  while K * K * K < N do Inc( K );  // 標本数 = ⌈n^(1/3)⌉

     for I := 2 to K do
     begin
          P := Poins[ Random( N ) ];  D := TorusDist2( Pos_, P.Pos );

          if D < Dm then begin  Dm := D;  Result := P;  end;
     end;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.IsHitLift( const Face_:TPeriFace2D; const T_:TPoint; const MP_:TPoint; const QRank_:Integer ) :Boolean;
var
   G1, G2, G3 :TPoint;
begin
     G1 := PtMulAdd( Face_.CornGrid( 1 ), T_, _GridK );

     if ( Abs( G1.X - MP_.X ) > 8 * _GridK ) or ( Abs( G1.Y - MP_.Y ) > 8 * _GridK ) then Exit( False );  // 遠すぎる
                                                                                        // （空円直径 ≤ √2·L なので入り得ない。述語の桁も守る）
     G2 := PtMulAdd( Face_.CornGrid( 2 ), T_, _GridK );
     G3 := PtMulAdd( Face_.CornGrid( 3 ), T_, _GridK );

     Result := InCirclePert( G1, G2, G3, MP_,
                             Face_.Poin[ 1 ].Site, Face_.Poin[ 2 ].Site, Face_.Poin[ 3 ].Site, QRank_ ) > 0;
end;

function TPeriDelaunay2D.FindHitLift( const Pos_:TSingle2D; const QRank_:Integer; out Face_:TPeriFace2D; out T_:TPoint ) :Boolean;
var
   MP :TPoint;
   F, G :TPeriFace2D;
   T, T0 :TPoint;
   GQ :array [ 1..3 ] of TPoint;
   N, I, O, TX, TY :Integer;
   E, K, GK :Byte;
   C1 :TPoint;
begin
     Face_ := nil;

     if ChildrsN = 0 then Exit( False );

     MP := GridOf( Pos_ );

     F := JumpPoin( Pos_ ).Face;  // ジャンプ：無作為標本の最近点のアンカー面から出発する

     if F <> nil then
     begin
          C1 := F.CornGrid( 1 );  // 出発のリフト：面のアンカーを p̂ の近くへ寄せる

          T.X := Floor( ( MP.X - C1.X ) / _GridK + 0.5 );
          T.Y := Floor( ( MP.Y - C1.Y ) / _GridK + 0.5 );

          for N := 1 to 4 * ChildrsN + 8 do  // ウォーク：p̂ が外側にある辺を越えて隣へ渡り続ける（累積平行移動つき）
          begin
               for K := 1 to 3 do GQ[ K ] := PtMulAdd( F.CornGrid( K ), T, _GridK );

               K := 0;

               O := Random( 3 );  // 調べる辺の順を無作為化した確率的歩行

               for I := 0 to 2 do
               begin
                    E := 1 + ( O + I ) mod 3;

                    with VertTableInc[ E ] do
                    begin
                         if OrientG( MP, GQ[ L ], GQ[ R ] ) < 0 then K := E;
                    end;

                    if K > 0 then Break;
               end;

               if K > 0 then
               begin
                    G  := F.Face[ K ];
                    GK := F.Corn[ K ];

                    T := PtSub( PtAdd( T, F.Off[ VertTableInc[ K ].R ] ), G.Off[ VertTableInc[ GK ].L ] );  // 共有頂点のリフトを揃える

                    F := G;
               end
               else
               begin
                    if IsHitLift( F, T, MP, QRank_ ) then
                    begin
                         Face_ := F;  T_ := T;  Exit( True );  // 内包面に到達（三角形 ⊆ 外接円）
                    end;

                    Break;  // 共円・重複の退化 → 全面走査で確定する
               end;
          end;
     end;

     for F in Faces do  // 全面走査（歩行の保険。アンカー近傍のリフトを総当たり）
     begin
          C1 := F.CornGrid( 1 );

          T0.X := Floor( ( MP.X - C1.X ) / _GridK + 0.5 );
          T0.Y := Floor( ( MP.Y - C1.Y ) / _GridK + 0.5 );

          for TY := -2 to +2 do
          for TX := -2 to +2 do
          begin
               T := PtAdd( T0, TPoint.Create( TX, TY ) );

               if IsHitLift( F, T, MP, QRank_ ) then
               begin
                    Face_ := F;  T_ := T;  Exit( True );
               end;
          end;
     end;

     Result := False;  // どの面の空円にも真に入らない（＝既存頂点との重複）
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.InsertPoin( const Poin_:TPeriPoin2D; const Face_:TPeriFace2D; const T0_:TPoint ) :Boolean;
// 普遍被覆上の Bowyer-Watson。キャビティは（面の実体 × 格子平行移動）の対の集合。
// 通常（p が自分の周期像と隣接しない場合）は境界辺への錐張りで済ませ、疎な配置では
// p̂ のスターをギフトラッピングで直接構築する（ユニット先頭の解説を参照）
var
   MP :TPoint;
   Star :TArray<TLift>;
   Seen :TDictionary<Int64,Boolean>;
   Kill :TArray<TPeriFace2D>;
   Bonds :TArray<TBond>;
   BondDic :TDictionary<String,Integer>;
   I :Integer;
   K, GK, CL, CR :Byte;
   F, G :TPeriFace2D;
   T, TG :TPoint;
   B :TBond;
   LiftKey :Int64;
//･･･････････････････････････････････････････
     function KeyOf( const F_:TPeriFace2D; const T_:TPoint ) :Int64;
     begin
          Result := ( Int64( F_.Order ) shl 20 ) or ( Int64( T_.X + 512 ) shl 10 ) or Int64( T_.Y + 512 );
     end;
//･･･････････････････････････････････････････
     function ConeOK :Boolean;  // 錐張りが正しいか（p が自分の周期像と隣接しないか）を厳密に判定する
     var
        I, LX, LY :Integer;
        X2, Y2, X3, Y3, N2, N3, D, CX, CY, R2 :Double;
        PL :TPoint;
     begin
          Result := False;

          for I := 0 to High( Bonds ) do
          begin
               if Bonds[ I ].OF_.Flag then Exit;  // 外側も消える辺がある ＝ 穴が巻いている ＝ 自己隣接

               with Bonds[ I ] do  // 錐面 ( GB, p̂, GA ) の外接円
               begin
                    X2 := GA.X - GB.X;  Y2 := GA.Y - GB.Y;
                    X3 := MP.X - GB.X;  Y3 := MP.Y - GB.Y;
               end;

               N2 := X2 * X2 + Y2 * Y2;
               N3 := X3 * X3 + Y3 * Y3;

               D := 2 * ( X2 * Y3 - Y2 * X3 );

               if D = 0 then Exit;  // 潰れた錐面

               CX := ( Y3 * N2 - Y2 * N3 ) / D;  // 中心（GB 基準）
               CY := ( X2 * N3 - X3 * N2 ) / D;

               R2 := CX * CX + CY * CY;

               if 4 * R2 > 2.05 * Double( _GridK ) * _GridK then Exit;  // 直径が √2·L を超えかねない ＝ どこかの周期像を含む

               for LY := -1 to +1 do  // 直径 ≤ √2·L なら、含み得る周期像は隣接する8つに限る
               for LX := -1 to +1 do
               begin
                    if ( LX = 0 ) and ( LY = 0 ) then Continue;

                    PL := PtMulAdd( MP, TPoint.Create( LX, LY ), _GridK );

                    with Bonds[ I ] do
                    begin
                         if InCirclePert( GB, MP, GA, PL,
                                          PB.Site, Poin_.Site, PA.Site, Poin_.Site ) > 0 then Exit;  // 錐面の円が p の周期像を含む
                    end;
               end;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
     procedure BuildCone;  // 錐張り（通常の Bowyer-Watson。外側は全て生き残る）
     var
        I, J :Integer;
        C, D :TPeriFace2D;
        NewsF :TArray<TPeriFace2D>;
        FanDic :TDictionary<Int64,Integer>;
     begin
          NewsF := [];

          FanDic := TDictionary<Int64,Integer>.Create;
          try
             for I := 0 to High( Bonds ) do  // 境界辺ごとに新しい面 C = ( B端, p, A端 ) を張る
             begin                           // （C の辺 3→1 が境界辺 GA→GB と同じ向きで重なる）
                  with Bonds[ I ] do C := NewFaceG( PB, GB,  Poin_, MP,  PA, GA );

                  NewsF := NewsF + [ C ];

                  FanDic.Add( GridKey( Bonds[ I ].GB ), I );  // 角1（B端）の格子座標は扇の中で一意

                  with Bonds[ I ] do  // 外側と縫う
                  begin
                       C.Face[ 2 ]    := OF_;  C.Corn[ 2 ]    := OC;
                       OF_.Face[ OC ] := C;    OF_.Corn[ OC ] := 2;
                  end;
             end;

             for I := 0 to High( NewsF ) do  // 追加点の周りの縫合：C の辺 (p → A端) の相手は、A端から始まる面 D
             begin
                  C := NewsF[ I ];

                  J := FanDic[ GridKey( Bonds[ I ].GA ) ];  // D の角1の格子座標 = C の A端

                  D := NewsF[ J ];

                  C.Face[ 1 ] := D;  C.Corn[ 1 ] := 3;
                  D.Face[ 3 ] := C;  D.Corn[ 3 ] := 1;
             end;
          finally
             FanDic.Free;
          end;
     end;
//･･･････････････････････････････････････････
     function BuildStar :Boolean;  // スター構築（疎な配置。p が自分の周期像と隣接する）
     var
        Cands :TArray<TCand>;
        CandSet :TDictionary<Int64,Boolean>;
        Tie :Boolean;
        InstP :TArray<TArray<TPeriPoin2D>>;   // インスタンス（トーラスの新面）の角の実体
        InstG :TArray<TArray<TPoint>>;        // 角の格子座標（最初に現れたリフトの枠）
        InstDic :TDictionary<String,Integer>; // 正規化キー → インスタンス番号
        PlanK :TArray<TArray<Byte>>;          // 縫合計画（0 = 未, 1 = 新面どうし, 2 = 外側の面と）
        PlanV :TArray<TArray<Integer>>;       // 相手（新面: インスタンス×4+角, 外側: 境界辺番号）
        EntI, EntR :TArray<Integer>;          // 扇の要素 → インスタンス番号・回転
        EntA, EntB :TArray<TCand>;            // 扇の要素の（w_i, w_{i+1}）
        BondUsed :TArray<Boolean>;
        PlanOK :Boolean;
        FInst :TArray<TPeriFace2D>;
        I, J, N :Integer;
        K :Byte;
        W0, WC, WN, X :TCand;
        F :TPeriFace2D;
     //･･････････････････････
          procedure AddCand( const P_:TPeriPoin2D; const G_:TPoint );
          begin
               if CandSet.TryAdd( GridKey( G_ ), True ) then
               begin
                    SetLength( Cands, Length( Cands ) + 1 );

                    Cands[ High( Cands ) ].P := P_;
                    Cands[ High( Cands ) ].G := G_;
               end;
          end;
     //･･････････････････････
          function Third( const U_,V_:TPoint; const RU_,RV_:Integer; out X_:TCand ) :Boolean;  // 有向辺 U→V の左側のドロネー第3頂点
          var
             I :Integer;
             Have :Boolean;
          begin
               Have := False;

               for I := 0 to High( Cands ) do
               begin
                    with Cands[ I ] do
                    begin
                         if PtEq( G, U_ ) or PtEq( G, V_ ) then Continue;

                         if OrientG( U_, V_, G ) <= 0 then Continue;  // 左側だけ

                         if not Have then begin  X_ := Cands[ I ];  Have := True;  Continue;  end;

                         if InCirclePert( U_, V_, X_.G, G,  RU_, RV_, X_.P.Site, P.Site ) > 0 then X_ := Cands[ I ];  // 記号摂動で共円を裁く
                    end;
               end;

               if Have then  // 最終勝者と摂動でも引き分ける候補が残るときだけ本物のタイ
               begin         // （走査途中の敗者どうしの引き分けは無害）
                    for I := 0 to High( Cands ) do
                    begin
                         with Cands[ I ] do
                         begin
                              if PtEq( G, U_ ) or PtEq( G, V_ ) or PtEq( G, X_.G ) then Continue;

                              if OrientG( U_, V_, G ) <= 0 then Continue;

                              if InCirclePert( U_, V_, X_.G, G,  RU_, RV_, X_.P.Site, P.Site ) = 0 then begin  Tie := True;  Break;  end;
                         end;
                    end;
               end;

               Result := Have;
          end;
     //･･････････････････････
          function InstOf( const P1_:TPeriPoin2D; const G1_:TPoint;
                           const P2_:TPeriPoin2D; const G2_:TPoint;
                           const P3_:TPeriPoin2D; const G3_:TPoint; out Rot_:Integer; const AddNew_:Boolean ) :Integer;
          // トーラス正規化（平行移動 ＋ 回転）でインスタンスを同一視する。Rot_ は
          // 「この呼び出しの角 c が、インスタンスの角 ((c-1-Rot+3) mod 3)+1 に当たる」回転
          var
             PP :array [ 0..2 ] of TPeriPoin2D;
             GG :array [ 0..2 ] of TPoint;
             MX, MY, R, I, BR :Integer;
             S, BS :String;
          //･･････
               function RotStr( const R_:Integer ) :String;
               var
                  I, J :Integer;
               begin
                    Result := '';

                    for I := 0 to 2 do
                    begin
                         J := ( I + R_ ) mod 3;

                         Result := Result + IntToStr( PP[ J ].Order ) + ':' + IntToStr( GG[ J ].X - MX ) + ':' + IntToStr( GG[ J ].Y - MY ) + '|';
                    end;
               end;
          //･･････
          begin
               PP[ 0 ] := P1_;  GG[ 0 ] := G1_;
               PP[ 1 ] := P2_;  GG[ 1 ] := G2_;
               PP[ 2 ] := P3_;  GG[ 2 ] := G3_;

               MX := Min( G1_.X, Min( G2_.X, G3_.X ) );
               MY := Min( G1_.Y, Min( G2_.Y, G3_.Y ) );

               BR := 0;  BS := RotStr( 0 );

               for R := 1 to 2 do
               begin
                    S := RotStr( R );

                    if S < BS then begin  BS := S;  BR := R;  end;
               end;

               Rot_ := BR;

               if InstDic.TryGetValue( BS, Result ) then Exit;

               if not AddNew_ then Exit( -1 );

               Result := Length( InstP );

               InstDic.Add( BS, Result );

               SetLength( InstP, Result + 1 );  SetLength( InstP[ Result ], 4 );
               SetLength( InstG, Result + 1 );  SetLength( InstG[ Result ], 4 );

               for I := 1 to 3 do
               begin
                    J := ( I - 1 + BR ) mod 3;  // インスタンスの角 I = この呼び出しの角 J+1

                    InstP[ Result ][ I ] := PP[ J ];
                    InstG[ Result ][ I ] := GG[ J ];
               end;
          end;
     //･･････････････････････
          function MapCorn( const Rot_,Corn_:Integer ) :Byte;  // 呼び出しの角 → インスタンスの角
          begin
               Result := ( ( Corn_ - 1 - Rot_ + 3 ) mod 3 ) + 1;
          end;
     //･･････････････････････
          procedure PlanSet( const II_:Integer; const IC_:Byte; const Kind_:Byte; const Val_:Integer );
          begin
               if PlanK[ II_ ][ IC_ ] = 0 then
               begin
                    PlanK[ II_ ][ IC_ ] := Kind_;
                    PlanV[ II_ ][ IC_ ] := Val_;
               end
               else
               if ( PlanK[ II_ ][ IC_ ] <> Kind_ ) or ( PlanV[ II_ ][ IC_ ] <> Val_ ) then PlanOK := False;  // 矛盾
          end;
     //･･････････････････････
     var
        MUX, MUY, BI, II, JJ, RI, RJ :Integer;
        D2, BD :Int64;
        JC :Byte;
     begin
          Result := False;

          Tie := False;

          Cands := [];

          CandSet := TDictionary<Int64,Boolean>.Create;
          InstDic := TDictionary<String,Integer>.Create;
          try
             for I := 0 to High( Bonds ) do  // 候補点 = 穴の境界頂点とその平行移動像 ＋ p の格子像
             begin
                  for MUY := -3 to +3 do
                  for MUX := -3 to +3 do
                  begin
                       AddCand( Bonds[ I ].PA, PtMulAdd( Bonds[ I ].GA, TPoint.Create( MUX, MUY ), _GridK ) );
                  end;
             end;

             for MUY := -3 to +3 do
             for MUX := -3 to +3 do
             begin
                  AddCand( Poin_, PtMulAdd( MP, TPoint.Create( MUX, MUY ), _GridK ) );
             end;

             ///// 扇の構築（p̂ の最近傍候補から左回りにギフトラッピング）

             BD := -1;

             for I := 0 to High( Cands ) do
             begin
                  with Cands[ I ] do
                  begin
                       if PtEq( G, MP ) then Continue;

                       D2 := Int64( G.X - MP.X ) * ( G.X - MP.X ) + Int64( G.Y - MP.Y ) * ( G.Y - MP.Y );

                       if ( BD < 0 ) or ( D2 < BD ) then begin  BD := D2;  W0 := Cands[ I ];  end;
                  end;
             end;

             if BD < 0 then Exit;

             EntA := [];  EntB := [];

             WC := W0;

             for N := 0 to Length( Cands ) + 4 do
             begin
                  if not Third( MP, WC.G, Poin_.Site, WC.P.Site, WN ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: no third' ); {$ENDIF} Exit; end;

                  SetLength( EntA, Length( EntA ) + 1 );  EntA[ High( EntA ) ] := WC;
                  SetLength( EntB, Length( EntB ) + 1 );  EntB[ High( EntB ) ] := WN;

                  WC := WN;

                  if PtEq( WN.G, W0.G ) then Break;
             end;

             if not PtEq( WC.G, W0.G ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: fan not closed m=', Length( EntA ) ); {$ENDIF} Exit; end;

             if Tie then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: tie in fan' ); {$ENDIF} Exit; end;

             ///// インスタンス化（トーラスの新面として同一視）と縫合計画

             SetLength( EntI, Length( EntA ) );
             SetLength( EntR, Length( EntA ) );

             for I := 0 to High( EntA ) do
             begin
                  EntI[ I ] := InstOf( Poin_, MP,  EntA[ I ].P, EntA[ I ].G,  EntB[ I ].P, EntB[ I ].G,  EntR[ I ], True );
             end;

             if Length( InstP ) <> Length( Kill ) + 2 then
             begin
                  {$IFDEF PERI_DEBUG} WriteLn( 'STAR: inst=', Length( InstP ), ' kill=', Length( Kill ), ' fan=', Length( EntA ) ); {$ENDIF}
                  Exit;  // 面数（オイラーの式 F = 2n）が合わない
             end;

             SetLength( PlanK, Length( InstP ) );
             SetLength( PlanV, Length( InstP ) );

             for I := 0 to High( InstP ) do
             begin
                  SetLength( PlanK[ I ], 4 );
                  SetLength( PlanV[ I ], 4 );
             end;

             SetLength( BondUsed, Length( Bonds ) );

             PlanOK := True;

             for I := 0 to High( EntA ) do  // 扇の隣接（p̂ の周り）：要素 i の辺2 ↔ 要素 i+1 の辺3
             begin
                  J := ( I + 1 ) mod Length( EntA );

                  II := EntI[ I ];  RI := EntR[ I ];
                  JJ := EntI[ J ];  RJ := EntR[ J ];

                  PlanSet( II, MapCorn( RI, 2 ), 1, JJ * 4 + MapCorn( RJ, 3 ) );
                  PlanSet( JJ, MapCorn( RJ, 3 ), 1, II * 4 + MapCorn( RI, 2 ) );
             end;

             for I := 0 to High( EntA ) do  // 底辺（w_i → w_{i+1}）：境界辺か、反対側の新面か
             begin
                  II := EntI[ I ];  RI := EntR[ I ];

                  if BondDic.TryGetValue( LiftEdgeStr( EntA[ I ].G, EntB[ I ].G ), BI ) and not Bonds[ BI ].OF_.Flag then
                  begin
                       PlanSet( II, MapCorn( RI, 1 ), 2, BI );

                       BondUsed[ BI ] := True;
                  end
                  else
                  begin
                       if not Third( EntB[ I ].G, EntA[ I ].G, EntB[ I ].P.Site, EntA[ I ].P.Site, X ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: no across' ); {$ENDIF} Exit; end;

                       JJ := InstOf( EntB[ I ].P, EntB[ I ].G,  EntA[ I ].P, EntA[ I ].G,  X.P, X.G,  RJ, False );

                       if JJ < 0 then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: across inst missing ent=', I ); {$ENDIF} Exit; end;  // 反対側の面が扇に現れていない

                       PlanSet( II, MapCorn( RI, 1 ), 1, JJ * 4 + MapCorn( RJ, 3 ) );
                       PlanSet( JJ, MapCorn( RJ, 3 ), 1, II * 4 + MapCorn( RI, 1 ) );
                  end;
             end;

             for BI := 0 to High( Bonds ) do  // 生き残る外側の面は、必ずどれかの新面と接する
             begin
                  if Bonds[ BI ].OF_.Flag or BondUsed[ BI ] then Continue;

                  if not Third( Bonds[ BI ].GA, Bonds[ BI ].GB, Bonds[ BI ].PA.Site, Bonds[ BI ].PB.Site, X ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: no bond inner' ); {$ENDIF} Exit; end;

                  JJ := InstOf( Bonds[ BI ].PA, Bonds[ BI ].GA,  Bonds[ BI ].PB, Bonds[ BI ].GB,  X.P, X.G,  RJ, False );

                  if JJ < 0 then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: bond inner inst missing bi=', BI ); {$ENDIF} Exit; end;

                  PlanSet( JJ, MapCorn( RJ, 3 ), 2, BI );

                  BondUsed[ BI ] := True;
             end;

             if Tie or not PlanOK then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: tie=', Tie, ' planok=', PlanOK ); {$ENDIF} Exit; end;

             for I := 0 to High( Bonds ) do  // 生き残る外側は全て縫われたか
             begin
                  if not ( Bonds[ I ].OF_.Flag or BondUsed[ I ] ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: bond unsewn' ); {$ENDIF} Exit; end;
             end;

             for I := 0 to High( InstP ) do  // 全ての辺に計画があるか・新面どうしの相互参照が合うか
             begin
                  for K := 1 to 3 do
                  begin
                       if PlanK[ I ][ K ] = 0 then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: plan hole ', I, '/', K ); {$ENDIF} Exit; end;

                       if PlanK[ I ][ K ] = 1 then
                       begin
                            JJ := PlanV[ I ][ K ] shr 2;
                            JC := PlanV[ I ][ K ] and 3;

                            if ( PlanK[ JJ ][ JC ] <> 1 ) or ( PlanV[ JJ ][ JC ] <> I * 4 + K ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'STAR: plan mismatch ', I, '/', K ); {$ENDIF} Exit; end;
                       end;
                  end;
             end;

             ///// ここからは失敗しない ―― メッシュを張り替える

             SetLength( FInst, Length( InstP ) );

             for I := 0 to High( InstP ) do
             begin
                  FInst[ I ] := NewFaceG( InstP[ I ][ 1 ], InstG[ I ][ 1 ],
                                          InstP[ I ][ 2 ], InstG[ I ][ 2 ],
                                          InstP[ I ][ 3 ], InstG[ I ][ 3 ] );
             end;

             for I := 0 to High( InstP ) do
             begin
                  F := FInst[ I ];

                  for K := 1 to 3 do
                  begin
                       if PlanK[ I ][ K ] = 1 then
                       begin
                            F.Face[ K ] := FInst[ PlanV[ I ][ K ] shr 2 ];
                            F.Corn[ K ] := PlanV[ I ][ K ] and 3;
                       end
                       else
                       begin
                            with Bonds[ PlanV[ I ][ K ] ] do
                            begin
                                 F.Face[ K ]    := OF_;  F.Corn[ K ]    := OC;
                                 OF_.Face[ OC ] := F;    OF_.Corn[ OC ] := K;
                            end;
                       end;
                  end;
             end;

             Inc( _StarInsN );

             Result := True;
          finally
             CandSet.Free;
             InstDic.Free;
          end;
     end;
//･･･････････････････････････････････････････
begin
     MP := GridOf( Poin_.Pos );

     Seen := TDictionary<Int64,Boolean>.Create;
     BondDic := TDictionary<String,Integer>.Create;
     try
        Star := [];
        Kill := [];
        Bonds := [];

        Seen.Add( KeyOf( Face_, T0_ ), True );

        SetLength( Star, 1 );
        Star[ 0 ].F := Face_;
        Star[ 0 ].T := T0_;

        Face_.Flag := True;  Kill := [ Face_ ];

        I := 0;
        while I < Length( Star ) do  // ①マーク（普遍被覆内の幅優先。同じ面の実体が異なる移動で2回入り得る）
        begin
             F := Star[ I ].F;
             T := Star[ I ].T;

             Inc( I );

             for K := 1 to 3 do
             begin
                  G  := F.Face[ K ];
                  GK := F.Corn[ K ];

                  CL := VertTableInc[ K ].L;
                  CR := VertTableInc[ K ].R;

                  TG := PtSub( PtAdd( T, F.Off[ CR ] ), G.Off[ VertTableInc[ GK ].L ] );  // 共有頂点のリフトを揃える

                  LiftKey := KeyOf( G, TG );

                  if Seen.ContainsKey( LiftKey ) then Continue;  // 既にキャビティの一員

                  if IsHitLift( G, TG, MP, Poin_.Site ) then
                  begin
                       Seen.Add( LiftKey, True );

                       SetLength( Star, Length( Star ) + 1 );
                       Star[ High( Star ) ].F := G;
                       Star[ High( Star ) ].T := TG;

                       if not G.Flag then begin  G.Flag := True;  Kill := Kill + [ G ];  end;
                  end
                  else
                  begin
                       B.GA := PtMulAdd( F.CornGrid( CL ), T, _GridK );  // 境界辺（GA → GB・キャビティは左）
                       B.GB := PtMulAdd( F.CornGrid( CR ), T, _GridK );
                       B.PA := F.Poin[ CL ];
                       B.PB := F.Poin[ CR ];
                       B.FIn := F;   B.TIn := T;
                       B.OF_ := G;   B.OC  := GK;   B.OT := TG;

                       Bonds := Bonds + [ B ];

                       BondDic.Add( LiftEdgeStr( B.GA, B.GB ), High( Bonds ) + 0 );
                  end;
             end;
        end;

        if ConeOK then
        begin
             BuildCone;  // ②カーブ（通常の錐張り）

             Result := True;
        end
        else Result := BuildStar;  // 疎な配置：スターの直接構築（失敗は無傷で False）

        if Result then
        begin
             for I := 0 to High( Kill ) do Kill[ I ].Free;  // キャビティの面（実体）をまとめて解放する
        end
        else
        begin
             for I := 0 to High( Kill ) do Kill[ I ].Flag := False;  // 何も壊していない ―― 旗だけ戻す
        end;
     finally
        Seen.Free;
        BondDic.Free;
     end;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.TryLocalDelete( const Poin_:TPeriPoin2D ) :Boolean;
// 局所削除。頂点のひとつのリフト v̂ の周りの星を角の巡回で集め、穴の境界多角形を
// リフト座標で取り出し、ドロネー耳（他のリンク頂点とその平行移動像を外接円に含まない
// 耳）で埋める。埋め草の計画と縫合の検証が完成してから初めてメッシュに触れる
// （失敗は無傷で False。呼び出し側が再構築へ退避する）
type
    TFill = record
      P :array [ 1..3 ] of TPeriPoin2D;
      G :array [ 1..3 ] of TPoint;
    end;
var
   Bonds :TArray<TBond>;
   Kill :TArray<TPeriFace2D>;
   StarLifts :TArray<TLift>;
   StarSet :TDictionary<Int64,Boolean>;
   PolyP :TArray<TPeriPoin2D>;
   PolyG :TArray<TPoint>;
   Cands :TArray<TCand>;                 // 耳の判定の候補（リンク頂点とその平行移動像）
   CandSet :TDictionary<Int64,Boolean>;
   Fills :TArray<TFill>;
   FillF :TArray<TPeriFace2D>;
   EdgeDic :TDictionary<String,Int64>;   // 厳密座標の有向辺 → 埋め草番号×4＋角
   BondDic :TDictionary<String,Integer>; // 消える境界辺の厳密座標 → 境界辺番号
   WSewn :TArray<Boolean>;
   SewA, SewB :TArray<Int64>;            // 縫合の計画（埋め草番号×4＋角 の対）
   BondFill :TArray<Int64>;              // 境界辺 → 穴側の埋め草の辺
   F0, F, G :TPeriFace2D;
   C0, C, GK :Byte;
   T0, T, MU :TPoint;
   B :TBond;
   I, J, N, SI, MUX, MUY, Guard :Integer;
   K :Byte;
   FI :TFill;
   SS :String;
   V :Int64;
   Found :Boolean;
//･･･････････････････････････････････････････
     function KeyOf( const F_:TPeriFace2D; const T_:TPoint ) :Int64;
     begin
          Result := ( Int64( F_.Order ) shl 20 ) or ( Int64( T_.X + 512 ) shl 10 ) or Int64( T_.Y + 512 );
     end;
//･･･････････････････････････････････････････
     function CutEars :Boolean;  // 穴の多角形をドロネー耳で刈り取る（データだけを作る。メッシュには触れない）
     var
        WP :TArray<TPeriPoin2D>;
        WG :TArray<TPoint>;
        N, I, J, IP, IN_ :Integer;
        OK :Boolean;
     begin
          Result := False;

          WP := Copy( PolyP );
          WG := Copy( PolyG );

          Fills := [];

          while Length( WG ) > 3 do
          begin
               N := Length( WG );

               I := 0;
               while I < N do
               begin
                    IP  := ( I + N - 1 ) mod N;
                    IN_ := ( I + 1     ) mod N;

                    OK := OrientG( WG[ IP ], WG[ I ], WG[ IN_ ] ) > 0;  // 耳は正の向き（多角形は穴を左に見る = 正の向き）

                    if OK then
                    begin
                         for J := 0 to High( Cands ) do  // 候補（リンクの平行移動像を含む）が外接円・閉三角形に入らないこと
                         begin
                              with Cands[ J ] do
                              begin
                                   if PtEq( G, WG[ IP ] ) or PtEq( G, WG[ I ] ) or PtEq( G, WG[ IN_ ] ) then Continue;

                                   if InCirclePert( WG[ IP ], WG[ I ], WG[ IN_ ], G,
                                                    WP[ IP ].Site, WP[ I ].Site, WP[ IN_ ].Site, P.Site ) > 0 then begin  OK := False;  Break;  end;

                                   if ( OrientG( WG[ IP  ], WG[ I   ], G ) >= 0 ) and
                                      ( OrientG( WG[ I   ], WG[ IN_ ], G ) >= 0 ) and
                                      ( OrientG( WG[ IN_ ], WG[ IP  ], G ) >= 0 ) then begin  OK := False;  Break;  end;
                              end;
                         end;
                    end;

                    if OK then
                    begin
                         FI.P[ 1 ] := WP[ IP ];   FI.G[ 1 ] := WG[ IP ];
                         FI.P[ 2 ] := WP[ I  ];   FI.G[ 2 ] := WG[ I  ];
                         FI.P[ 3 ] := WP[ IN_ ];  FI.G[ 3 ] := WG[ IN_ ];

                         Fills := Fills + [ FI ];

                         Delete( WP, I, 1 );  // 耳を刈る
                         Delete( WG, I, 1 );

                         Break;
                    end;

                    Inc( I );
               end;

               if I >= N then Exit;  // 耳が見つからない退化 → 呼び出し側が再構築へ退避する
          end;

          if OrientG( WG[ 0 ], WG[ 1 ], WG[ 2 ] ) <= 0 then Exit;  // 最後の三角形が潰れている

          FI.P[ 1 ] := WP[ 0 ];  FI.G[ 1 ] := WG[ 0 ];
          FI.P[ 2 ] := WP[ 1 ];  FI.G[ 2 ] := WG[ 1 ];
          FI.P[ 3 ] := WP[ 2 ];  FI.G[ 3 ] := WG[ 2 ];

          Fills := Fills + [ FI ];

          Result := True;
     end;
//･･･････････････････････････････････････････
begin
     Result := False;

     F0 := Poin_.Face;
     C0 := Poin_.Corn;

     if F0 = nil then Exit;

     T0 := TPoint.Create( -F0.Off[ C0 ].X, -F0.Off[ C0 ].Y );  // v̂ = 正準座標（オフセット 0）のリフト

     Bonds := [];
     Kill  := [];
     StarLifts := [];

     StarSet := TDictionary<Int64,Boolean>.Create;
     CandSet := TDictionary<Int64,Boolean>.Create;
     EdgeDic := TDictionary<String,Int64>.Create;
     BondDic := TDictionary<String,Integer>.Create;
     try
        ///// 星の巡回（読むだけ）

        F := F0;  C := C0;  T := T0;

        Guard := 3 * ChildrsN + 8;

        repeat
              B.GA := PtMulAdd( F.CornGrid( VertTableInc[ C ].L ), T, _GridK );  // v の対辺（GA → GB・穴は左）
              B.GB := PtMulAdd( F.CornGrid( VertTableInc[ C ].R ), T, _GridK );
              B.PA := F.Poin[ VertTableInc[ C ].L ];
              B.PB := F.Poin[ VertTableInc[ C ].R ];
              B.FIn := F;
              B.TIn := T;
              B.OF_ := F.Face[ C ];
              B.OC  := F.Corn[ C ];
              B.OT  := PtSub( PtAdd( T, F.Off[ VertTableInc[ C ].L ] ),          // 共有頂点（v の対辺の始点）でリフトを揃える
                              B.OF_.Off[ VertTableInc[ B.OC ].R ] );

              Bonds := Bonds + [ B ];

              SetLength( StarLifts, Length( StarLifts ) + 1 );
              StarLifts[ High( StarLifts ) ].F := F;
              StarLifts[ High( StarLifts ) ].T := T;

              if not StarSet.TryAdd( KeyOf( F, T ), True ) then Exit;  // 同じリフトを2度巡った（壊れている）

              if not F.Flag then begin  F.Flag := True;  Kill := Kill + [ F ];  end;  // 同じ実体が2つの角で v を参照していれば2回巡る

              K := VertTableInc[ C ].R;  // 次の面へ（v を保ったまま辺を渡る）

              G  := F.Face[ K ];
              GK := F.Corn[ K ];

              T := PtSub( PtAdd( T, F.Off[ C ] ), G.Off[ VertTableInc[ GK ].R ] );  // v のリフトを揃える

              C := VertTableInc[ GK ].R;
              F := G;

              Dec( Guard );

              if Guard <= 0 then Exit;

        until ( F = F0 ) and ( C = C0 ) and ( T.X = T0.X ) and ( T.Y = T0.Y );

        ///// 穴の多角形（リンク）を組み立てる

        N := Length( Bonds );

        if N < 3 then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: ring < 3' ); {$ENDIF} Exit; end;

        Found := True;  // 巡回の整合（GB_i = GA_{i+1}）。巡回の向きが逆なら並びを反転して揃える

        for I := 0 to N-1 do
        begin
             if not PtEq( Bonds[ I ].GB, Bonds[ ( I + 1 ) mod N ].GA ) then begin  Found := False;  Break;  end;
        end;

        if not Found then
        begin
             for I := 0 to ( N div 2 ) - 1 do
             begin
                  B := Bonds[ I ];  Bonds[ I ] := Bonds[ N - 1 - I ];  Bonds[ N - 1 - I ] := B;
             end;

             for I := 0 to N-1 do
             begin
                  if not PtEq( Bonds[ I ].GB, Bonds[ ( I + 1 ) mod N ].GA ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: ring chain broken' ); {$ENDIF} Exit; end;
             end;
        end;

        SetLength( PolyP, N );
        SetLength( PolyG, N );

        for I := 0 to N-1 do
        begin
             PolyP[ I ] := Bonds[ I ].PA;
             PolyG[ I ] := Bonds[ I ].GA;
        end;

        Cands := [];

        for I := 0 to N-1 do  // 耳の判定の候補 = リンク頂点とその平行移動像
        begin
             for MUY := -3 to +3 do
             for MUX := -3 to +3 do
             begin
                  MU := PtMulAdd( PolyG[ I ], TPoint.Create( MUX, MUY ), _GridK );

                  if CandSet.TryAdd( GridKey( MU ), True ) then
                  begin
                       SetLength( Cands, Length( Cands ) + 1 );

                       Cands[ High( Cands ) ].P := PolyP[ I ];
                       Cands[ High( Cands ) ].G := MU;
                  end;
             end;
        end;

        ///// 耳刈りと縫合の計画（メッシュには触れない）

        if not CutEars then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: no ear' ); {$ENDIF} Exit; end;

        SewA := [];  SewB := [];

        for I := 0 to High( Fills ) do  // 埋め草どうしの内部の辺：リフト座標の厳密一致で対にする
        begin
             for K := 1 to 3 do
             begin
                  with VertTableInc[ K ] do SS := LiftEdgeStr( Fills[ I ].G[ R ], Fills[ I ].G[ L ] );  // 相手の向き

                  if EdgeDic.TryGetValue( SS, V ) then
                  begin
                       SewA := SewA + [ Int64( I ) * 4 + K ];
                       SewB := SewB + [ V ];

                       EdgeDic.Remove( SS );
                  end
                  else
                  begin
                       with VertTableInc[ K ] do SS := LiftEdgeStr( Fills[ I ].G[ L ], Fills[ I ].G[ R ] );

                       EdgeDic.Add( SS, Int64( I ) * 4 + K );
                  end;
             end;
        end;

        SetLength( BondFill, N );

        for I := 0 to N-1 do  // 境界辺は、穴側の埋め草の辺と厳密一致するはず
        begin
             SS := LiftEdgeStr( Bonds[ I ].GA, Bonds[ I ].GB );

             if not EdgeDic.TryGetValue( SS, V ) then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: bond-fill miss' ); {$ENDIF} Exit; end;  // 整合が崩れている

             BondFill[ I ] := V;

             EdgeDic.Remove( SS );
        end;

        if EdgeDic.Count <> 0 then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: edges left' ); {$ENDIF} Exit; end;  // 対にならない辺が残った

        SetLength( WSewn, N );

        for I := 0 to N-1 do
        begin
             if Bonds[ I ].OF_.Flag then BondDic.Add( LiftEdgeStr( Bonds[ I ].GA, Bonds[ I ].GB ), I )  // 消える辺は照合に備えて登録
                                    else WSewn[ I ] := True;  // 生き残る外側と縫う辺は後段で直接縫う
        end;

        for I := 0 to N-1 do  // 外側の面も星で消える境界辺（穴がトーラスを巻いて、隣のリフトの穴と接している）
        begin
             if WSewn[ I ] then Continue;

             // 隣の穴 v̂+μ を一意に特定する：外側のリフトが隣の星に属し（(OF, OT-μ) ∈ StarSet）、
             // かつ自分側のリフトは属さない（(FIn, TIn-μ) ∉ StarSet）。相手の埋め草は、
             // 境界辺を μ だけ戻した逆向きの境界辺の穴側にある
             Found := False;

             for SI := 0 to High( StarLifts ) do
             begin
                  if StarLifts[ SI ].F <> Bonds[ I ].OF_ then Continue;

                  MU := PtSub( Bonds[ I ].OT, StarLifts[ SI ].T );

                  if ( MU.X = 0 ) and ( MU.Y = 0 ) then Continue;

                  if StarSet.ContainsKey( KeyOf( Bonds[ I ].FIn, PtSub( Bonds[ I ].TIn, MU ) ) ) then Continue;

                  if not BondDic.TryGetValue( LiftEdgeStr( PtMulAdd( Bonds[ I ].GB, MU, -_GridK ),
                                                           PtMulAdd( Bonds[ I ].GA, MU, -_GridK ) ), J ) then Continue;

                  if WSewn[ J ] then Continue;

                  SewA := SewA + [ BondFill[ I ] ];
                  SewB := SewB + [ BondFill[ J ] ];

                  WSewn[ I ] := True;
                  WSewn[ J ] := True;

                  Found := True;  Break;
             end;

             if not Found then begin {$IFDEF PERI_DEBUG} WriteLn( 'DEL: wrap pair miss' ); {$ENDIF} Exit; end;  // 隣の穴が特定できない退化 → 再構築へ退避
        end;

        ///// ここからは失敗しない ―― メッシュを張り替える

        FillF := [];

        for I := 0 to High( Fills ) do
        begin
             with Fills[ I ] do FillF := FillF + [ NewFaceG( P[ 1 ], G[ 1 ], P[ 2 ], G[ 2 ], P[ 3 ], G[ 3 ] ) ];
        end;

        for I := 0 to High( SewA ) do  // 埋め草どうし（内部の辺と巻き付きの辺）
        begin
             F := FillF[ SewA[ I ] shr 2 ];  C  := SewA[ I ] and 3;
             G := FillF[ SewB[ I ] shr 2 ];  GK := SewB[ I ] and 3;

             F.Face[ C  ] := G;  F.Corn[ C  ] := GK;
             G.Face[ GK ] := F;  G.Corn[ GK ] := C;
        end;

        for I := 0 to N-1 do  // 生き残る外側の面と縫う
        begin
             with Bonds[ I ] do
             begin
                  if OF_.Flag then Continue;

                  F := FillF[ BondFill[ I ] shr 2 ];  C := BondFill[ I ] and 3;

                  F.Face[ C ]    := OF_;  F.Corn[ C ]    := OC;
                  OF_.Face[ OC ] := F;    OF_.Corn[ OC ] := C;
             end;
        end;

        for I := 0 to High( Kill ) do Kill[ I ].Free;  // 星を取り除き、

        for I := 0 to High( FillF ) do FillF[ I ].BindPoins;  // リンク頂点のアンカーを張り直す

        Result := True;
     finally
        StarSet.Free;
        CandSet.Free;
        EdgeDic.Free;
        BondDic.Free;

        if not Result then
        begin
             for I := 0 to High( Kill ) do Kill[ I ].Flag := False;  // 何も壊していない ―― 旗だけ戻す
        end;
     end;
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunay2D.RemoveSiteAt( const Site_:Integer );
var
   I :Integer;
begin
     for I := Site_ to High( _SiteQ ) - 1 do _SiteQ[ I ] := _SiteQ[ I + 1 ];

     SetLength( _SiteQ, Length( _SiteQ ) - 1 );
end;

procedure TPeriDelaunay2D.BuildAll;
// サイト列からの全再構築（Size 変更と、退化した削除の退避にだけ使う）
var
   K :Integer;
   V :TPeriPoin2D;
   F :TPeriFace2D;
   T :TPoint;
begin
     inherited Clear;  // 面 → 点の順で全て消す（面の破棄は頂点のアンカーに触れる）

     Poins.Clear;

     SetLength( _CentQ, Length( _SiteQ ) );

     if Length( _SiteQ ) = 0 then Exit;

     V := NewPoin( _SiteQ[ 0 ], 0 );

     _CentQ[ 0 ] := V;

     SeedTwo( V );

     K := 1;
     while K <= High( _SiteQ ) do
     begin
          if FindHitLift( _SiteQ[ K ], K, F, T ) then
          begin
               V := NewPoin( _SiteQ[ K ], K );

               if InsertPoin( V, F, T ) then
               begin
                    _CentQ[ K ] := V;

                    Inc( K );
               end
               else
               begin
                    V.Free;

                    RemoveSiteAt( K );  // 共円の退化で挿入できない点は取り除く
               end;
          end
          else RemoveSiteAt( K );  // 重複（スナップの一致）は取り除く
     end;

     SetLength( _CentQ, Length( _SiteQ ) );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TPeriDelaunay2D.Create;
begin
     inherited;

     SetSizeCore( 100 );
end;

destructor TPeriDelaunay2D.Destroy;
begin
     inherited;  // 点と面は集合ごと解放される
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TPeriDelaunay2D.WrapPos( const Pos_:TSingle2D ) :TSingle2D;
begin
     Result := TSingle2D.Create( WrapSnap1( Pos_.X ), WrapSnap1( Pos_.Y ) );
end;

function TPeriDelaunay2D.TorusDist2( const A_,B_:TSingle2D ) :Single;
var
   dX, dY :Single;
begin
     dX := Abs( A_.X - B_.X );  if dX > _Size - dX then dX := _Size - dX;
     dY := Abs( A_.Y - B_.Y );  if dY > _Size - dY then dY := _Size - dY;

     Result := dX * dX + dY * dY;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.HitCircleFace( const Pos_:TSingle2D ) :TPeriFace2D;
var
   T :TPoint;
begin
     if not FindHitLift( WrapPos( Pos_ ), MaxInt, Result, T ) then Result := nil;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.FindMaxCircle :TPeriFace2D;
var
   F :TPeriFace2D;
   C :TDouble2D;
   R2, Rm :Double;
begin
     Result := nil;  Rm := -1;

     for F in Faces do  // トーラス上の面は全て有限（無限半径の面は無い）。外接円半径の平方で比べる
     begin
          F.CircumD( C, R2 );

          if R2 > Rm then begin  Rm := R2;  Result := F;  end;
     end;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.FindNearPoin( const Pos_:TSingle2D; out Poin_:TPeriPoin2D ) :Single;
var
   P :TSingle2D;
   I, Im :Integer;
   D, Dm :Single;
begin
     Poin_ := nil;  Result := Infinity;

     if Length( _SiteQ ) = 0 then Exit;

     P := WrapPos( Pos_ );

     Im := 0;  Dm := TorusDist2( P, _SiteQ[ 0 ] );

     for I := 1 to High( _SiteQ ) do
     begin
          D := TorusDist2( P, _SiteQ[ I ] );

          if D < Dm then begin  Dm := D;  Im := I;  end;
     end;

     Poin_ := _CentQ[ Im ];  Result := Sqrt( Dm );
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.AddPoin( const Pos_:TSingle2D ) :TPeriPoin2D;
var
   P :TSingle2D;
   I :Integer;
   F :TPeriFace2D;
   T :TPoint;
   V :TPeriPoin2D;
begin
     Result := nil;

     if not ( ( Abs( Pos_.X ) < 1E18 ) and ( Abs( Pos_.Y ) < 1E18 ) ) then Exit;  // 座標が数でない（NaN・∞）か大きすぎる

     P := WrapPos( Pos_ );

     for I := 0 to High( _SiteQ ) do  // 重複（グリッド上の厳密比較）
     begin
          if ( P.X = _SiteQ[ I ].X ) and ( P.Y = _SiteQ[ I ].Y ) then Exit;
     end;

     if Length( _SiteQ ) = 0 then
     begin
          V := NewPoin( P, 0 );

          _SiteQ := [ P ];
          _CentQ := [ V ];

          SeedTwo( V );

          Result := V;
     end
     else
     begin
          if not FindHitLift( P, Length( _SiteQ ), F, T ) then Exit;  // 起こらないはずの保険（重複は上で弾いている）

          V := NewPoin( P, Length( _SiteQ ) );

          if InsertPoin( V, F, T ) then
          begin
               _SiteQ := _SiteQ + [ P ];
               _CentQ := _CentQ + [ V ];

               Result := V;
          end
          else
          begin
               V.Free;  // 共円の退化 → 何も変えずに拒否する

               Exit;
          end;
     end;

     _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.DeletePoin( const Poin_:TPeriPoin2D ) :Boolean;
var
   S, I :Integer;
begin
     Result := False;

     if ( Poin_ = nil ) or ( Poin_.Parent <> PoinSet ) then Exit;

     S := Poin_.Site;

     if ( S < 0 ) or ( S > High( _SiteQ ) ) then Exit;

     if Length( _SiteQ ) <= 3 then
     begin
          Inc( _RebuildDelN );

          RemoveSiteAt( S );  // 極小サイト数はサイト列から作り直す（平面版の少数点の特別扱いに相当。O(1)）

          BuildAll;
     end
     else
     begin
          if not TryLocalDelete( Poin_ ) then Exit;  // 退化配置で埋め戻せなければ、何も変えずに False（平面版と同じ）

          Inc( _LocalDelN );

          Poin_.Free;  // 星と埋め草の張り替えは済んでいる

          RemoveSiteAt( S );

          for I := 0 to Poins.ChildrsN-1 do  // サイト番号を詰める
          begin
               if Poins[ I ]._Site > S then Dec( Poins[ I ]._Site );
          end;

          for I := S to High( _SiteQ ) do _CentQ[ I ] := _CentQ[ I + 1 ];

          SetLength( _CentQ, Length( _SiteQ ) );
     end;

     _OnChange.Run( Self );

     Result := True;
end;

//------------------------------------------------------------------------------

function TPeriDelaunay2D.TorusFaces :TArray<TPeriFace2D>;
var
   F :TPeriFace2D;
   I :Integer;
begin
     SetLength( Result, ChildrsN );

     I := 0;

     for F in Faces do
     begin
          Result[ I ] := F;  Inc( I );
     end;
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunay2D.Clear;
begin
     _SiteQ := nil;

     BuildAll;

     _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

procedure TPeriDelaunay2D.SaveToFile( const FileName_:String );
begin
     raise ENotSupportedException.Create( 'TPeriDelaunay2D.SaveToFile: TriFlip 形式は格子オフセットを保存できない' );
end;

procedure TPeriDelaunay2D.LoadFromFile( const FileName_:String );
begin
     raise ENotSupportedException.Create( 'TPeriDelaunay2D.LoadFromFile: TriFlip 形式は格子オフセットを保存できない' );
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

end. //######################################################################### ■
