unit LUX.Delaunay.D2;

// 2D ドロネー図（逐次添加法・無限遠頂点方式）
//
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
// ・点の削除は耳切り法。頂点の周囲の面（星型領域）を隣接をたどって一周収集し、
//   まとめて削除して穴（リング）を作り、「外接円が他のリング頂点を含まない耳」
//   から埋め戻す（Devillers の削除法）。凸包上の頂点ではリングに無限遠頂点が
//   含まれるが、統一述語がそのまま扱うので場合分けは要らない。

interface //#################################################################### ■

uses System.Classes, System.Generics.Collections,
     LUX,
     LUX.D2;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     TDelaPoin2D = class;
     TDelaFace2D = class;
     TDelaunay2D = class;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TVertLR

     TVertLR = record
     private
     public
       L :Byte;
       R :Byte;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFaceJoint

     TFaceJoint = record
     private
     public
       FaceL :TDelaFace2D;
       FaceR :TDelaFace2D;
       VertL :Byte;
       VertR :Byte;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSingleCircl2

     TSingleCircl2 = record
     private
     public
       Center :TSingle2D;
       Radiu2 :Single;
       /////
       constructor Create( const P1_,P2_,P3_:TSingle2D ); overload;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSingleCircle

     TSingleCircle = record
     private
     public
       Center :TSingle2D;
       Radius :Single;
       /////
       constructor Create( const P1_,P2_,P3_:TSingle2D ); overload;
       ///// 型変換
       class operator Implicit( const Circl2_:TSingleCircl2 ) :TSingleCircle;
       class operator Implicit( const Circle_:TSingleCircle ) :TSingleCircl2;
     end;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2D

     TDelaPoin2D = class
     private
     protected
       _Pos :TSingle2D;
       _Inf :Boolean;
     public
       ///// P R O P E R T Y
       property Pos :TSingle2D read _Pos write _Pos;
       property Inf :Boolean   read _Inf            ;  // 無限遠頂点か
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFace2D

     TDelaFace2D = class
     private
     protected
       _Poin :array [ 1..3 ] of TDelaPoin2D;
       _Face :array [ 1..3 ] of TDelaFace2D;
       _Corn :array [ 1..3 ] of Byte;
       ///// A C C E S S O R
       function GetPoin( const I_:Byte ) :TDelaPoin2D;
       procedure SetPoin( const I_:Byte; const Poin_:TDelaPoin2D );
       function GetFace( const I_:Byte ) :TDelaFace2D;
       procedure SetFace( const I_:Byte; const Face_:TDelaFace2D );
       function GetCorn( const I_:Byte ) :Byte;
       procedure SetCorn( const I_,Corn_:Byte );
       function GetInfCorn :Byte;
       function GetCircle :TSingleCircle;
     public
       ///// P R O P E R T Y
       property Poin[ const I_:Byte ] :TDelaPoin2D   read GetPoin    write SetPoin;
       property Face[ const I_:Byte ] :TDelaFace2D   read GetFace    write SetFace;
       property Corn[ const I_:Byte ] :Byte          read GetCorn    write SetCorn;
       property InfCorn               :Byte          read GetInfCorn              ;  // 無限遠頂点の番号（0 = 有限面）
       property Circle                :TSingleCircle read GetCircle               ;  // 描画用（無限遠面では半平面表現）
       ///// M E T H O D
       class function InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Single;  // 統一リフト行列式（正 = 円の内側）
       function IsHitCircle( const Pos_:TSingle2D ) :Boolean;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay2D

     TDelaunay2D = class
       type TPoin_ = TDelaPoin2D;
       type TFace_ = TDelaFace2D;
     private
       _PoinInf  :TPoin_;
       _Poins    :TObjectList<TPoin_>;
       _Faces    :TObjectList<TFace_>;
       _OnChange :TNotifyEvent;
       ///// M E T H O D
       procedure Changed;
       function HasPoin( const Pos_:TSingle2D ) :Boolean;
       procedure InitFace;
       function FaceTree( const Poin_:TPoin_; const Face_:TFace_; const Vert_:Byte ) :TFaceJoint;
       procedure Connect( const J_,JL_,JR_:TFaceJoint );
       procedure InsertPoin( const Poin_:TPoin_; const Face_:TFace_ );
     protected
       ///// M E T H O D
       function NewPoin( const Pos_:TSingle2D ) :TPoin_;
       function NewFace( const Poin1_,Poin2_,Poin3_:TPoin_ ) :TFace_;
       procedure DeleteFace( const Face_:TFace_ );
     public
       constructor Create;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property PoinInf  :TPoin_              read _PoinInf                 ;  // 唯一の無限遠頂点
       property Poins    :TObjectList<TPoin_> read _Poins                   ;  // 有限頂点のみ
       property Faces    :TObjectList<TFace_> read _Faces                   ;
       property OnChange :TNotifyEvent        read _OnChange write _OnChange;  // 構造が変化したときに発火
       ///// M E T H O D
       function HitCircleFace( const Pos_:TSingle2D ) :TFace_;
       function FindPoin( const Pos_:TSingle2D; const Radius_:Single ) :TPoin_;
       function AddPoin( const Pos_:TSingle2D ) :TPoin_; overload;
       function AddPoin( const Pos_:TSingle2D; const Face_:TFace_ ) :TPoin_; overload;
       function DeletePoin( const Poin_:TPoin_ ) :Boolean;
       procedure Clear;
       function CheckEdges :Integer;
     end;

const //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C O N S T A N T 】

      VertTable :array [ 1..3 ] of TVertLR
        = ( ( L:2; R:3 ), ( L:3; R:1 ), ( L:1; R:2 ) );

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

function CircumCenter( const P1_,P2_,P3_:TSingle2D ) :TSingle2D;

function LineNormal( const P0_,P1_:TSingle2D ) :TSingle2D;

implementation //############################################################### ■

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TVertLR

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFaceJoint

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSingleCircl2

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TSingleCircl2.Create( const P1_,P2_,P3_:TSingle2D );
begin
     Center := CircumCenter( P1_, P2_, P3_ );

     Radiu2 := ( Distance2( Center, P1_ )
               + Distance2( Center, P2_ )
               + Distance2( Center, P3_ ) ) / 3;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSingleCircle

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TSingleCircle.Create( const P1_,P2_,P3_:TSingle2D );
begin
     Self := TSingleCircl2.Create( P1_, P2_, P3_ );
end;

///////////////////////////////////////////////////////////////////////// 型変換

class operator TSingleCircle.Implicit( const Circl2_:TSingleCircl2 ) :TSingleCircle;
begin
     with Result do
     begin
          Center :=       Circl2_.Center  ;
          Radius := Roo2( Circl2_.Radiu2 );
     end;
end;

class operator TSingleCircle.Implicit( const Circle_:TSingleCircle ) :TSingleCircl2;
begin
     with Result do
     begin
          Center :=       Circle_.Center  ;
          Radiu2 := Pow2( Circle_.Radius );
     end;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaPoin2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaFace2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TDelaFace2D.GetPoin( const I_:Byte ) :TDelaPoin2D;
begin
     Result := _Poin[ I_ ];
end;

procedure TDelaFace2D.SetPoin( const I_:Byte; const Poin_:TDelaPoin2D );
begin
     _Poin[ I_ ] := Poin_;
end;

function TDelaFace2D.GetFace( const I_:Byte ) :TDelaFace2D;
begin
     Result := _Face[ I_ ];
end;

procedure TDelaFace2D.SetFace( const I_:Byte; const Face_:TDelaFace2D );
begin
     _Face[ I_ ] := Face_;
end;

function TDelaFace2D.GetCorn( const I_:Byte ) :Byte;
begin
     Result := _Corn[ I_ ];
end;

procedure TDelaFace2D.SetCorn( const I_,Corn_:Byte );
begin
     _Corn[ I_ ] := Corn_;
end;

//------------------------------------------------------------------------------

function TDelaFace2D.GetInfCorn :Byte;
begin
     if _Poin[ 1 ].Inf then Result := 1
                       else
     if _Poin[ 2 ].Inf then Result := 2
                       else
     if _Poin[ 3 ].Inf then Result := 3
                       else Result := 0;
end;

function TDelaFace2D.GetCircle :TSingleCircle;
//･･･････････････････････････････････････････
     function EdgeCircle( const P1_,P2_:TDelaPoin2D ) :TSingleCircle;
     begin
          with Result do
          begin
               Center := LineNormal( P1_.Pos, P2_.Pos ).Unitor;
               Radius := ( DotProduct( Center, P1_.Pos ) + DotProduct( Center, P2_.Pos ) ) / 2;
          end;
     end;
//･･･････････････････････････････････････････
begin
     case InfCorn of
       0: Result := TSingleCircle.Create( Poin[1].Pos, Poin[2].Pos, Poin[3].Pos );
       1: Result := EdgeCircle( Poin[2], Poin[3] );
       2: Result := EdgeCircle( Poin[3], Poin[1] );
       3: Result := EdgeCircle( Poin[1], Poin[2] );
     end;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

class function TDelaFace2D.InCircle( const P1_,P2_,P3_:TDelaPoin2D; const Pos_:TSingle2D ) :Single;
//･･･････････････････････････････････････････
     procedure Lift( const P_:TDelaPoin2D; out X_,Y_,Z_:Single );
     begin
          if P_.Inf then
          begin
               X_ := 0;
               Y_ := 0;
               Z_ := 1;
          end
          else
          begin
               X_ := P_.Pos.X - Pos_.X;
               Y_ := P_.Pos.Y - Pos_.Y;
               Z_ := X_ * X_ + Y_ * Y_;
          end;
     end;
//･･･････････････････････････････････････････
var
   X1, Y1, Z1,
   X2, Y2, Z2,
   X3, Y3, Z3 :Single;
begin
     Lift( P1_, X1, Y1, Z1 );
     Lift( P2_, X2, Y2, Z2 );
     Lift( P3_, X3, Y3, Z3 );

     Result := X1 * ( Y2 * Z3 - Z2 * Y3 )
             - Y1 * ( X2 * Z3 - Z2 * X3 )
             + Z1 * ( X2 * Y3 - Y2 * X3 );
end;

function TDelaFace2D.IsHitCircle( const Pos_:TSingle2D ) :Boolean;
begin
     Result := InCircle( _Poin[ 1 ], _Poin[ 2 ], _Poin[ 3 ], Pos_ ) > 0;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelaunay2D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelaunay2D.Changed;
begin
     if Assigned( _OnChange ) then _OnChange( Self );
end;

//------------------------------------------------------------------------------

function TDelaunay2D.HasPoin( const Pos_:TSingle2D ) :Boolean;
var
   I :Integer;
begin
     Result := True;

     for I := 0 to _Poins.Count-1 do
     begin
          with _Poins[ I ].Pos do if ( X = Pos_.X ) and ( Y = Pos_.Y ) then Exit;
     end;

     Result := False;
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.InitFace;
var
   P1, P2 :TPoin_;
   C1, C2 :TFace_;
begin
     P1 := _Poins[ 0 ];
     P2 := _Poins[ 1 ];

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

function TDelaunay2D.FaceTree( const Poin_:TPoin_; const Face_:TFace_; const Vert_:Byte ) :TFaceJoint;
var
   JL, JR :TFaceJoint;
   C :TFace_;
begin
     if Face_.IsHitCircle( Poin_.Pos ) then
     begin
          with VertTable[ Vert_ ] do
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

          DeleteFace( Face_ );

          with Result do
          begin
               FaceL := JL.FaceL;  VertL := JL.VertL;
               FaceR := JR.FaceR;  VertR := JR.VertR;
          end;
     end
     else
     begin
          with VertTable[ Vert_ ] do C := NewFace( Face_.Poin[ L ], Poin_, Face_.Poin[ R ] );

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

procedure TDelaunay2D.InsertPoin( const Poin_:TPoin_; const Face_:TFace_ );
var
   J1, J2, J3 :TFaceJoint;
begin
     J1 := FaceTree( Poin_, Face_.Face[ 1 ], Face_.Corn[ 1 ] );
     J2 := FaceTree( Poin_, Face_.Face[ 2 ], Face_.Corn[ 2 ] );
     J3 := FaceTree( Poin_, Face_.Face[ 3 ], Face_.Corn[ 3 ] );

     DeleteFace( Face_ );

     Connect( J1, J2, J3 );
     Connect( J2, J3, J1 );
     Connect( J3, J1, J2 );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay2D.NewPoin( const Pos_:TSingle2D ) :TPoin_;
begin
     Result := TPoin_.Create;

     Result.Pos := Pos_;

     _Poins.Add( Result );
end;

function TDelaunay2D.NewFace( const Poin1_,Poin2_,Poin3_:TPoin_ ) :TFace_;
begin
     Result := TFace_.Create;

     Result.Poin[1] := Poin1_;
     Result.Poin[2] := Poin2_;
     Result.Poin[3] := Poin3_;

     _Faces.Add( Result );
end;

procedure TDelaunay2D.DeleteFace( const Face_:TFace_ );
begin
     _Faces.Remove( Face_ );  // OwnsObjects = True なので同時に解放される
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TDelaunay2D.Create;
begin
     inherited;

     _PoinInf := TPoin_.Create;
     _PoinInf._Inf := True;

     _Poins := TObjectList<TPoin_>.Create;
     _Faces := TObjectList<TFace_>.Create;
end;

destructor TDelaunay2D.Destroy;
begin
     _Faces.Free;
     _Poins.Free;

     _PoinInf.Free;

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TDelaunay2D.HitCircleFace( const Pos_:TSingle2D ) :TFace_;
var
   I :Integer;
begin
     for I := 0 to _Faces.Count-1 do
     begin
          Result := _Faces[ I ];

          if Result.IsHitCircle( Pos_ ) then Exit;
     end;

     Result := nil;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.AddPoin( const Pos_:TSingle2D ) :TPoin_;
var
   F :TFace_;
begin
     if HasPoin( Pos_ ) then Exit( nil );  // 重複点は無視する

     case _Poins.Count of
       0: begin
               Result := NewPoin( Pos_ );  Changed;
          end;
       1: begin
               Result := NewPoin( Pos_ );  InitFace;  Changed;
          end;
     else
          F := HitCircleFace( Pos_ );

          if Assigned( F ) then Result := AddPoin( Pos_, F )
                           else Result := nil;  // 退化配置（既存の辺と一直線上）は無視する
     end;
end;

function TDelaunay2D.AddPoin( const Pos_:TSingle2D; const Face_:TFace_ ) :TPoin_;
begin
     Result := NewPoin( Pos_ );  InsertPoin( Result, Face_ );  Changed;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.FindPoin( const Pos_:TSingle2D; const Radius_:Single ) :TPoin_;
var
   I :Integer;
   D, Dm :Single;
begin
     Result := nil;

     Dm := Pow2( Radius_ );

     for I := 0 to _Poins.Count-1 do
     begin
          D := Distance2( Pos_, _Poins[ I ].Pos );

          if D < Dm then
          begin
               Dm := D;  Result := _Poins[ I ];
          end;
     end;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.DeletePoin( const Poin_:TPoin_ ) :Boolean;
type
    TLink = record
      Face :TFace_;
      Corn :Byte;
    end;
var
   Ring  :TArray<TPoin_>;
   Links :TArray<TLink>;
//･･･････････････････････････････････････････
     procedure Link( const F_:TFace_; const C_:Byte; const L_:TLink );
     begin
          F_.Face[ C_ ] := L_.Face;  F_.Corn[ C_ ] := L_.Corn;

          L_.Face.Face[ L_.Corn ] := F_;  L_.Face.Corn[ L_.Corn ] := C_;
     end;
//･･･････････････････････････････････････････
     function EarOK( const I_:Integer; const Strict_,GhostTip_:Boolean ) :Boolean;
     var
        K, J :Integer;
        A, B, C, Q :TPoin_;
        D :Single;
     begin
          Result := False;

          K := Length( Ring );

          A := Ring[ ( I_ + K-1 ) mod K ];
          B := Ring[         I_         ];
          C := Ring[ ( I_ +  1  ) mod K ];

          if B.Inf and not GhostTip_ then Exit;

          // 有限の耳は左折 (正の向き) であること
          if not ( A.Inf or B.Inf or C.Inf ) then
          begin
               if CrossProduct( B.Pos - A.Pos, C.Pos - A.Pos ) <= 0 then Exit;
          end;

          // 外接円が他のリング頂点を含まないこと
          for J := 0 to K-1 do
          begin
               Q := Ring[ J ];

               if ( Q = A ) or ( Q = B ) or ( Q = C ) or Q.Inf then Continue;

               D := TDelaFace2D.InCircle( A, B, C, Q.Pos );

               if Strict_ then begin if D >= 0 then Exit; end
                          else begin if D >  0 then Exit; end;
          end;

          Result := True;
     end;
//･･･････････････････････････････････････････
     procedure Clip( const I_:Integer );
     var
        K, J :Integer;
        F :TFace_;
     begin
          K := Length( Ring );

          F := NewFace( Ring[ ( I_ + K-1 ) mod K ],
                        Ring[         I_         ],
                        Ring[ ( I_ +  1  ) mod K ] );

          Link( F, 3, Links[ ( I_ + K-1 ) mod K ] );  // 辺 (A,B)
          Link( F, 1, Links[         I_         ] );  // 辺 (B,C)

          for J := I_ to K-2 do
          begin
               Ring [ J ] := Ring [ J+1 ];
               Links[ J ] := Links[ J+1 ];
          end;
          SetLength( Ring , K-1 );
          SetLength( Links, K-1 );

          if I_ = 0 then J := K-2
                    else J := I_-1;

          Links[ J ].Face := F;  // 新リング辺 (A,C) は corner 2 の向かい
          Links[ J ].Corn := 2;
     end;
//･･･････････････････････････････････････････
     procedure Fill;
     var
        Pass, I :Integer;
        Done :Boolean;
        F :TFace_;
     begin
          while Length( Ring ) > 3 do
          begin
               Done := False;

               for Pass := 1 to 3 do  // 1:厳密 → 2:非厳密(有限の耳先のみ) → 3:非厳密(∞の耳先も)
               begin
                    for I := 0 to Length( Ring )-1 do
                    begin
                         if EarOK( I, Pass = 1, Pass <> 2 ) then
                         begin
                              Clip( I );  Done := True;  Break;
                         end;
                    end;

                    if Done then Break;
               end;

               Assert( Done, 'DeletePoin: ear deadlock' );
               if not Done then Break;
          end;

          F := NewFace( Ring[ 0 ], Ring[ 1 ], Ring[ 2 ] );

          Link( F, 3, Links[ 0 ] );
          Link( F, 1, Links[ 1 ] );
          Link( F, 2, Links[ 2 ] );
     end;
//･･･････････････････････････････････････････
var
   I, K, J :Integer;
   C, C1, R :Byte;
   F0, F, F1 :TFace_;
   Star :TArray<TFace_>;
   Ws   :TArray<TPoin_>;
   Ls   :TArray<TLink>;
   L :TLink;
begin
     Result := False;

     if ( Poin_ = nil ) or Poin_.Inf or ( _Poins.IndexOf( Poin_ ) < 0 ) then Exit;

     case _Poins.Count of
       1: begin
               _Poins.Remove( Poin_ );
          end;
       2: begin
               _Faces.Clear;  _Poins.Remove( Poin_ );
          end;
     else
          // 頂点を含む面を1つ探す
          F0 := nil;  C := 0;
          for I := 0 to _Faces.Count-1 do
          begin
               F := _Faces[ I ];
               for C1 := 1 to 3 do
               begin
                    if F.Poin[ C1 ] = Poin_ then begin F0 := F;  C := C1;  Break; end;
               end;
               if Assigned( F0 ) then Break;
          end;
          if F0 = nil then Exit;

          // 星型領域を回転収集（境界辺の外側リンクも記録）
          Star := nil;  Ws := nil;  Ls := nil;
          F := F0;
          repeat
                R := VertTable[ C ].R;

                Star := Star + [ F ];
                Ws   := Ws   + [ F.Poin[ R ] ];

                L.Face := F.Face[ C ];
                L.Corn := F.Corn[ C ];
                Ls := Ls + [ L ];

                C1 := F.Corn[ R ];
                F  := F.Face[ R ];
                C  := VertTable[ C1 ].R;
          until F = F0;

          for F1 in Star do DeleteFace( F1 );

          // 収集順は時計回りなので反転して正の向きのリングにする
          K := Length( Ws );
          SetLength( Ring , K );
          SetLength( Links, K );
          for J := 0 to K-1 do
          begin
               Ring [ J ] := Ws[ K-1-J ];
               Links[ J ] := Ls[ ( K-2-J + K ) mod K ];
          end;

          Fill;

          _Poins.Remove( Poin_ );
     end;

     Changed;

     Result := True;
end;

//------------------------------------------------------------------------------

procedure TDelaunay2D.Clear;
begin
     _Faces.Clear;
     _Poins.Clear;

     Changed;
end;

//------------------------------------------------------------------------------

function TDelaunay2D.CheckEdges :Integer;
var
   I :Integer;
   C0, C1 :Byte;
   F0, F1 :TFace_;
begin
     Result := 0;

     for I := 0 to _Faces.Count-1 do
     begin
          F0 := _Faces[ I ];

          for C0 := 1 to 3 do
          begin
               F1 := F0.Face[ C0 ];
               C1 := F0.Corn[ C0 ];

               if ( F1 = nil ) or ( F1.Face[ C1 ] <> F0 )
                              or ( F1.Corn[ C1 ] <> C0 ) then Inc( Result );
          end;
     end;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

function CircumCenter( const P1_,P2_,P3_:TSingle2D ) :TSingle2D;
var
   L1, L2, L3, W :Single;
   E1, E2, E3 :TSingle2D;
begin
     L1 := P1_.Size2;  E1 := P3_ - P2_;
     L2 := P2_.Size2;  E2 := P1_ - P3_;
     L3 := P3_.Size2;  E3 := P2_ - P1_;

     W := 2 * ( P2_.X * P1_.Y - P1_.X * P2_.Y
              + P3_.X * P2_.Y - P2_.X * P3_.Y
              + P1_.X * P3_.Y - P3_.X * P1_.Y );

     with Result do
     begin
          X := ( L1 * E1.Y + L2 * E2.Y + L3 * E3.Y ) / +W;
          Y := ( L1 * E1.X + L2 * E2.X + L3 * E3.X ) / -W;
     end;
end;

function LineNormal( const P0_,P1_:TSingle2D ) :TSingle2D;
begin
     with P0_.VectorTo( P1_ ) do
     begin
          Result.X := +Y;
          Result.Y := -X;
     end;
end;

end. //######################################################################### ■
