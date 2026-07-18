unit LUX.CG2D;

// Skia ベースの２Ｄシーングラフ（コア）
//
//【構造】
// ・LUX.Data.Tree のノードでシーンを木構造に繋ぐ。
//     TCGLayers > TCGLayer > TCGShaper > …
//   生成・移籍・部分木ごとの解放・循環の禁止・子型の検査は Tree 層が担う。
// ・TCGObject は親も子も自型の節（TTreeKnot<TCGObject,TCGObject>）であり、互いに
//   自由にジョイントできる。TCGLayer は TCGObject の派生。ルートの TCGLayers は
//   TTreeRoot<TCGLayer> であり、TCGObject ではない（スタイルも行列も持たない）。
// ・TCGCamera は視野の広さ（SizeX / SizeY）を持つ視点ノード。通常のノードと同じく
//   シーンの任意の場所に置け、ビューアはこのカメラ越しにシーンを描く。
// ・子型の検査（ETreeError）: TCGLayers はレイヤだけを受け入れる。TCGObject は
//   レイヤを受け入れない（レイヤは TCGLayers 直下専用）。TCGLayers はどのノード
//   の子にもなれない。
//
//【座標系】
// ・LocalPose は局所行列（親ノード座標系 ← 自ノード座標系）、GlobalPose は大域
//   行列（先祖の LocalPose の積）。レイヤがシーンの最上位の座標系となる。
// ・Draw は「行列適用 → 自分の描画（DrawMain）→ 子の描画」を再帰する。行列は
//   Canvas の Save / Concat / Restore（Skia の行列スタック）に積むため、描画時に
//   GlobalPose の計算は不要。恒等行列や FMX の TMatrix との変換は TSingleM3 の
//   型変換演算子で書く（_LocalPose := 1 など）。
//
//【スタイル】
// ・TCGStyle は塗り色・線色・線幅・線端を持ち、PaintFill / PaintLine の ISkPaint
//   を内部に生成・保持する（属性が変わったときだけ作り直す）。塗りと線で色が
//   異なる図形は Skia の仕様上ひとつのペイントで描けないため、図形は2回描く。
// ・ノードの Style は親を遡って解決される（自分が nil なら親の Style）。レイヤは
//   既定のスタイルを強制生成するため、シーンに属すノードの Style は nil にならない。
// ・代入されたスタイルはノードの所有物であり、ノードの破棄時に解放される。
//   ひとつのスタイルを複数ノードに代入しないこと（共有は親に代入して継承させる）。
// ・スタイルの属性変更は OnChange（TDelegates）で所有ノードへ伝わり、Changed と
//   してシーンに通知される（購読は SetStyle が管理する）。
//
//【通知】
// ・ノードの挿抜・スタイルの変更・属性の変更は Changed としてルートの TCGLayers
//   へ集まり、OnChange（TDelegates による多播）で外へ出る。破棄中の親からは
//   通知されない。ハンドラ内でシーンを操作しないこと。
// ・大量の変更は BeginUpdate / EndUpdate（Tree 層の一括更新）で束ねる。任意の
//   ノードで使え、その部分木の発火を止めて最後に1回だけ発火する。入れ子にできる。
// ・破棄中のノードは Updating 扱いのため通知は発火しない。部分木を破棄したとき、
//   生きている親には取り外しの Changed が1回だけ届く。
//
// ・図形プリミティブは LUX.CG2D.Shapers ユニットで定義する。

interface //#################################################################### ■

uses System.UITypes, System.Math.Vectors, System.Skia,
     LUX,
     LUX.D3x3,
     LUX.Data.Tree;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     TCGStyle  = class;
     TCGObject = class;
     TCGLayer  = class;
     TCGLayers = class;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGStyle

     // 描画スタイル。ISkPaint を内部に生成・保持し、属性が変わったときだけ作り直す。
     TCGStyle = class
     private
       _FillColor :TAlphaColor;
       _LineColor :TAlphaColor;
       _LineThick :Single;
       _LineCap   :TSkStrokeCap;
       _PaintFill :ISkPaint;  // ペイントのキャッシュ（属性の変更で破棄される）
       _PaintLine :ISkPaint;
       ///// E V E N T
       _OnChange :TDelegates;
       ///// A C C E S S O R
       procedure SetFillColor( const FillColor_:TAlphaColor );
       procedure SetLineColor( const LineColor_:TAlphaColor );
       procedure SetLineThick( const LineThick_:Single );
       procedure SetLineCap( const LineCap_:TSkStrokeCap );
       function GetPaintFill :ISkPaint;
       function GetPaintLine :ISkPaint;
     public
       constructor Create;
       ///// P R O P E R T Y
       property FillColor :TAlphaColor  read _FillColor   write SetFillColor;  // 塗り色
       property LineColor :TAlphaColor  read _LineColor   write SetLineColor;  // 線色
       property LineThick :Single       read _LineThick   write SetLineThick;  // 線幅
       property LineCap   :TSkStrokeCap read _LineCap     write SetLineCap  ;  // 線端（点群は Round ＋ LineThick で描く）
       property PaintFill :ISkPaint     read GetPaintFill                   ;  // 塗りのペイント（透明なら nil）
       property PaintLine :ISkPaint     read GetPaintLine                   ;  // 線のペイント　（透明なら nil）
       ///// E V E N T
       property OnChange :TDelegates read _OnChange;  // 属性の変更の通知（Add / Del で多播購読）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGObject

     TCGObject = class( TTreeKnot<TCGObject,TCGObject> )
     private
     protected
       _Style :TCGStyle;  // 代入されたスタイル（ノードの所有物。破棄時に解放される）
       ///// A C C E S S O R
       function GetLocalPose :TSingleM3; virtual;
       procedure SetLocalPose( const LocalPose_:TSingleM3 ); virtual;
       function GetGlobalPose :TSingleM3; virtual;
       procedure SetGlobalPose( const GlobalPose_:TSingleM3 ); virtual;
       function GetStyle :TCGStyle; virtual;
       procedure SetStyle( const Style_:TCGStyle ); virtual;
       ///// E V E N T
       function AcceptChildr( const Childr_:TTreeNode ) :Boolean; override;  // レイヤは受け入れない（レイヤは TCGLayers 直下専用）
       procedure OnInsertChildr( const Childr_:TTreeNode ); override;
       procedure OnRemoveChildr( const Childr_:TTreeNode ); override;
       procedure StyleChange( Sender_:TObject ); virtual;  // 所有スタイルの属性変更を受ける
       procedure Updated; override;  // 一括更新の終了を Changed として発火する
       ///// M E T H O D
       procedure Changed; virtual;  // 変更をルートへ伝える
       procedure DrawMain( const Canvas_:ISkCanvas ); virtual;
     public
       destructor Destroy; override;
       ///// P R O P E R T Y
       property LocalPose  :TSingleM3 read GetLocalPose  write SetLocalPose ;  // 局所行列（親ノード座標系 ← 自ノード座標系）
       property GlobalPose :TSingleM3 read GetGlobalPose write SetGlobalPose;  // 大域行列（＝ 先祖の局所行列の積）
       property Style      :TCGStyle  read GetStyle      write SetStyle     ;  // スタイル（nil なら親を遡って解決される）
       ///// M E T H O D
       procedure Draw( const Canvas_:ISkCanvas );
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGShaper

     TCGShaper = class( TCGObject )
     private
     protected
       _LocalPose :TSingleM3;
       ///// A C C E S S O R
       function GetLocalPose :TSingleM3; override;
       procedure SetLocalPose( const LocalPose_:TSingleM3 ); override;
     public
       constructor Create; overload; override;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGCamera

     // カメラ。シーンに置ける視点ノードであり、自分では何も描かない。
     // SizeX / SizeY は、カメラの絶対座標（GlobalPose の位置）を中心とする視野の
     // 広さ（ワールド単位）。姿勢は先祖の Pose の積（GlobalPose）で決まる。
     TCGCamera = class( TCGObject )
     private
     protected
       _SizeX :Single;
       _SizeY :Single;
       ///// A C C E S S O R
       procedure SetSizeX( const SizeX_:Single );
       procedure SetSizeY( const SizeY_:Single );
     public
       constructor Create; overload; override;
       ///// P R O P E R T Y
       property SizeX :Single read _SizeX write SetSizeX;  // 視野の幅
       property SizeY :Single read _SizeY write SetSizeY;  // 視野の高さ
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLayer

     // レイヤ。TCGLayers の直下に置く。シーンの最上位の座標系であり、
     // 既定のスタイルを強制生成して持つ（スタイルの親遡りはここで止まる）。
     TCGLayer = class( TCGObject )
     private
     protected
       ///// A C C E S S O R
       function GetParent :TCGLayers; reintroduce; virtual;
       procedure SetParent( const Layers_:TCGLayers ); reintroduce; virtual;
       function GetGlobalPose :TSingleM3; override;
       procedure SetGlobalPose( const GlobalPose_:TSingleM3 ); override;
       function GetStyle :TCGStyle; override;
       ///// M E T H O D
       procedure Changed; override;
     public
       constructor Create; overload; override;
       constructor Create( const Layers_:TCGLayers ); overload;
       ///// P R O P E R T Y
       property Parent :TCGLayers read GetParent write SetParent;  // 所属先（代入は自動移籍）
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLayers

     // ルート。レイヤを束ねる入れ物であり、TCGObject ではない。
     // シーンの変化を OnChange で外へ出す。
     TCGLayers = class( TTreeRoot<TCGLayer> )
     private
       _BackColor :TAlphaColorF;
       ///// E V E N T
       _OnChange :TDelegates;
       ///// A C C E S S O R
       procedure SetBackColor( const BackColor_:TAlphaColorF );
     protected
       ///// E V E N T
       procedure OnInsertChildr( const Childr_:TTreeNode ); override;
       procedure OnRemoveChildr( const Childr_:TTreeNode ); override;
       procedure Updated; override;  // 一括更新の終了を Changed として発火する
       ///// M E T H O D
       procedure Changed; virtual;
     public
       constructor Create; overload; override;
       ///// P R O P E R T Y
       property BackColor :TAlphaColorF read _BackColor write SetBackColor;  // 背景色
       ///// E V E N T
       property OnChange :TDelegates read _OnChange;  // シーンの変化の通知（Add / Del で多播購読）
       ///// M E T H O D
       procedure Render( const Canvas_:ISkCanvas );
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGStyle

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGStyle.SetFillColor( const FillColor_:TAlphaColor );
begin
     _FillColor := FillColor_;  _PaintFill := nil;

     _OnChange.Run( Self );
end;

procedure TCGStyle.SetLineColor( const LineColor_:TAlphaColor );
begin
     _LineColor := LineColor_;  _PaintLine := nil;

     _OnChange.Run( Self );
end;

procedure TCGStyle.SetLineThick( const LineThick_:Single );
begin
     _LineThick := LineThick_;  _PaintLine := nil;

     _OnChange.Run( Self );
end;

procedure TCGStyle.SetLineCap( const LineCap_:TSkStrokeCap );
begin
     _LineCap := LineCap_;  _PaintLine := nil;

     _OnChange.Run( Self );
end;

//------------------------------------------------------------------------------

function TCGStyle.GetPaintFill :ISkPaint;
begin
     if TAlphaColorRec( _FillColor ).A = 0 then Exit( nil );

     if not Assigned( _PaintFill ) then
     begin
          _PaintFill := TSkPaint.Create( TSkPaintStyle.Fill );
          _PaintFill.AntiAlias := True;
          _PaintFill.Color     := _FillColor;
     end;

     Result := _PaintFill;
end;

function TCGStyle.GetPaintLine :ISkPaint;
begin
     if TAlphaColorRec( _LineColor ).A = 0 then Exit( nil );

     if not Assigned( _PaintLine ) then
     begin
          _PaintLine := TSkPaint.Create( TSkPaintStyle.Stroke );
          _PaintLine.AntiAlias   := True;
          _PaintLine.Color       := _LineColor;
          _PaintLine.StrokeWidth := _LineThick;
          _PaintLine.StrokeCap   := _LineCap;
     end;

     Result := _PaintLine;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGStyle.Create;
begin
     inherited;

     _FillColor := TAlphaColors.Null;
     _LineColor := TAlphaColors.Null;
     _LineThick := 1;
     _LineCap   := TSkStrokeCap.Butt;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGObject

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TCGObject.GetLocalPose :TSingleM3;
begin
     Result := 1;  // 既定は恒等（行列の実体は TCGShaper が持つ）
end;

procedure TCGObject.SetLocalPose( const LocalPose_:TSingleM3 );
begin
     /////  // 行列を持たないノードへの代入は無視する
end;

//------------------------------------------------------------------------------

function TCGObject.GetGlobalPose :TSingleM3;
begin
     if Assigned( Parent ) then Result := Parent.GlobalPose * LocalPose
                           else Result := LocalPose;
end;

procedure TCGObject.SetGlobalPose( const GlobalPose_:TSingleM3 );
begin
     if Assigned( Parent ) then LocalPose := Parent.GlobalPose.Inverse * GlobalPose_
                           else LocalPose := GlobalPose_;
end;

//------------------------------------------------------------------------------

function TCGObject.GetStyle :TCGStyle;
begin
     if Assigned( _Style ) then Result := _Style       else
     if Assigned( Parent )    then Result := Parent.Style
                              else Result := nil;  // どこにも属していなければ無し
end;

procedure TCGObject.SetStyle( const Style_:TCGStyle );
begin
     if Style_ = _Style then Exit;

     if Assigned( _Style ) then _Style.OnChange.Del( StyleChange );

     _Style := Style_;

     if Assigned( _Style ) then _Style.OnChange.Add( StyleChange );

     Changed;
end;

////////////////////////////////////////////////////////////////////// E V E N T

function TCGObject.AcceptChildr( const Childr_:TTreeNode ) :Boolean;
begin
     Result := inherited AcceptChildr( Childr_ ) and not ( Childr_ is TCGLayer );  // レイヤは TCGLayers 直下専用
end;

procedure TCGObject.OnInsertChildr( const Childr_:TTreeNode );
begin
     inherited;

     Changed;
end;

procedure TCGObject.OnRemoveChildr( const Childr_:TTreeNode );
begin
     inherited;

     Changed;
end;

//------------------------------------------------------------------------------

procedure TCGObject.StyleChange( Sender_:TObject );
begin
     Changed;
end;

procedure TCGObject.Updated;
begin
     inherited;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGObject.Changed;
begin
     if Updating then Exit;  // 一括更新中は発火しない（最外殻の EndUpdate で Updated が発火する）

     if Assigned( Parent ) then Parent.Changed;  // ルート（TCGLayers）まで遡る
end;

//------------------------------------------------------------------------------

procedure TCGObject.DrawMain( const Canvas_:ISkCanvas );
begin
     /////  // 既定は何も描かない
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

destructor TCGObject.Destroy;
begin
     _Style.Free;  // 代入されたスタイルはノードの所有物（nil なら何もしない）

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGObject.Draw( const Canvas_:ISkCanvas );
var
   C :TCGObject;
begin
     Canvas_.Save;
     try
          Canvas_.Concat( TMatrix( LocalPose ) );

          DrawMain( Canvas_ );

          for C in Self do C.Draw( Canvas_ );  // 型付き for-in（TTreeEnumer<TCGObject>）

     finally
          Canvas_.Restore;
     end;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGShaper

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TCGShaper.GetLocalPose :TSingleM3;
begin
     Result := _LocalPose;
end;

procedure TCGShaper.SetLocalPose( const LocalPose_:TSingleM3 );
begin
     _LocalPose := LocalPose_;

     Changed;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGShaper.Create;
begin
     inherited;

     _LocalPose := 1;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGCamera

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGCamera.SetSizeX( const SizeX_:Single );
begin
     _SizeX := SizeX_;

     Changed;
end;

procedure TCGCamera.SetSizeY( const SizeY_:Single );
begin
     _SizeY := SizeY_;

     Changed;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGCamera.Create;
begin
     inherited;

     _SizeX := 2;  // 視野 -1〜+1
     _SizeY := 2;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLayer

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TCGLayer.GetParent :TCGLayers;
begin
     Result := TCGLayers( TObject( inherited GetParent ) );  // レイヤの親は TCGLayers だけ（AcceptChildr が保証）
end;

procedure TCGLayer.SetParent( const Layers_:TCGLayers );
begin
     inherited SetParent( TCGObject( TObject( Layers_ ) ) );  // Tree 層の検査は TObject 経由なので型は素通しできる
end;

//------------------------------------------------------------------------------

function TCGLayer.GetGlobalPose :TSingleM3;
begin
     Result := LocalPose;  // レイヤが最上位の座標系（TCGLayers は行列を持たない）
end;

procedure TCGLayer.SetGlobalPose( const GlobalPose_:TSingleM3 );
begin
     LocalPose := GlobalPose_;
end;

//------------------------------------------------------------------------------

function TCGLayer.GetStyle :TCGStyle;
begin
     Result := _Style;  // レイヤは必ず自前のスタイルを持つ（親へは遡らない）
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGLayer.Changed;
begin
     if Updating then Exit;  // 一括更新中は発火しない（最外殻の EndUpdate で Updated が発火する）

     if Assigned( Parent ) then Parent.Changed;  // TCGLayers へ直接伝える
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGLayer.Create;
begin
     inherited;

     Style := TCGStyle.Create;  // 既定のスタイルを強制生成（購読と解放は TCGObject が行う）
end;

constructor TCGLayer.Create( const Layers_:TCGLayers );
begin
     inherited Create( TCGObject( TObject( Layers_ ) ) );  // Tree 層の検査は TObject 経由なので型は素通しできる
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLayers

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGLayers.SetBackColor( const BackColor_:TAlphaColorF );
begin
     _BackColor := BackColor_;

     Changed;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

////////////////////////////////////////////////////////////////////// E V E N T

procedure TCGLayers.OnInsertChildr( const Childr_:TTreeNode );
begin
     inherited;

     Changed;
end;

procedure TCGLayers.OnRemoveChildr( const Childr_:TTreeNode );
begin
     inherited;

     Changed;
end;

//------------------------------------------------------------------------------

procedure TCGLayers.Updated;
begin
     inherited;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGLayers.Changed;
begin
     if Updating then Exit;  // 一括更新中は発火しない（最外殻の EndUpdate で Updated が発火する）

     _OnChange.Run( Self );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGLayers.Create;
begin
     inherited;

     _BackColor := TAlphaColorF.Create( 1, 1, 1, 1 );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGLayers.Render( const Canvas_:ISkCanvas );
var
   L :TCGLayer;
begin
     Canvas_.Clear( _BackColor.ToAlphaColor );

     for L in Self do L.Draw( Canvas_ );  // 型付き for-in（TTreeEnumer<TCGLayer>）
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

end. //######################################################################### ■
