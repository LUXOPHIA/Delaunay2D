unit LUX.CG2D.Shapers;

// シーングラフの図形プリミティブ
//
// ・スタイル（塗り色・線色・線幅・線端）はノード自身ではなく TCGStyle が持つ。
//   図形は Style プロパティ（親を遡って解決される実効スタイル）のペイントを
//   そのまま使うため、描画のたびのペイント生成は起こらない。
// ・頂点は TCGCirc（半径を持つ円ノード）。位置は専用のフィールドではなく
//   局所行列の平行移動成分（AxisP）であり、Pos プロパティは GlobalPose.AxisP で
//   求まる。描画は行列適用後の原点に対して行う。
// ・三角形 TCGTria と線分 TCGLine は座標（TSingle2D）で形を定める。
// ・座標点列を Skia へ一括で渡す図形として TCGPlots（点群）を用意する。
//   点のサイズと丸さはスタイルの LineThick / LineCap で与える。
// ・座標の変更はすべてセッタを経て Changed としてシーンへ通知される。

interface //#################################################################### ■

uses System.Types, System.UITypes, System.Skia,
     LUX, LUX.D2, LUX.D3x3,
     LUX.CG2D;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGCirc

     TCGCirc = class( TCGShaper )
     private
     protected
       _Radius :Single;
       ///// A C C E S S O R
       function GetPos :TSingle2D;
       procedure SetPos( const Pos_:TSingle2D );
       procedure SetRadius( const Radius_:Single );
       ///// M E T H O D
       procedure DrawMain( const Canvas_:ISkCanvas ); override;
     public
       constructor Create; overload; override;
       ///// P R O P E R T Y
       property Pos    :TSingle2D read GetPos  write SetPos   ;  // 位置（行列の平行移動成分）
       property Radius :Single    read _Radius write SetRadius;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGTria

     TCGTria = class( TCGShaper )
     private
     protected
       _Vert1 :TSingle2D;
       _Vert2 :TSingle2D;
       _Vert3 :TSingle2D;
       ///// A C C E S S O R
       procedure SetVert1( const Vert1_:TSingle2D );
       procedure SetVert2( const Vert2_:TSingle2D );
       procedure SetVert3( const Vert3_:TSingle2D );
       ///// M E T H O D
       procedure DrawMain( const Canvas_:ISkCanvas ); override;
     public
       ///// P R O P E R T Y
       property Vert1 :TSingle2D read _Vert1 write SetVert1;
       property Vert2 :TSingle2D read _Vert2 write SetVert2;
       property Vert3 :TSingle2D read _Vert3 write SetVert3;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLine

     TCGLine = class( TCGShaper )
     private
     protected
       _Pos1 :TSingle2D;
       _Pos2 :TSingle2D;
       ///// A C C E S S O R
       procedure SetPos1( const Pos1_:TSingle2D );
       procedure SetPos2( const Pos2_:TSingle2D );
       ///// M E T H O D
       procedure DrawMain( const Canvas_:ISkCanvas ); override;
     public
       ///// P R O P E R T Y
       property Pos1 :TSingle2D read _Pos1 write SetPos1;
       property Pos2 :TSingle2D read _Pos2 write SetPos2;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGPlots

     TCGPlots = class( TCGShaper )
     private
     protected
       _Poins :TArray<TPointF>;
       ///// A C C E S S O R
       procedure SetPoins( const Poins_:TArray<TPointF> );
       ///// M E T H O D
       procedure DrawMain( const Canvas_:ISkCanvas ); override;
     public
       ///// P R O P E R T Y
       property Poins :TArray<TPointF> read _Poins write SetPoins;  // 座標点列（Skia へそのまま渡る）
     end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

implementation //############################################################### ■

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGCirc

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TCGCirc.GetPos :TSingle2D;
begin
     Result := GlobalPose.AxisP;
end;

procedure TCGCirc.SetPos( const Pos_:TSingle2D );
begin
     _LocalPose.AxisP := Pos_;

     Changed;
end;

//------------------------------------------------------------------------------

procedure TCGCirc.SetRadius( const Radius_:Single );
begin
     _Radius := Radius_;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGCirc.DrawMain( const Canvas_:ISkCanvas );
var
   S :TCGStyle;
   P :ISkPaint;
begin
     S := Style;  if not Assigned( S ) then Exit;

     P := S.PaintFill;  if Assigned( P ) then Canvas_.DrawCircle( TPointF.Zero, _Radius, P );
     P := S.PaintLine;  if Assigned( P ) then Canvas_.DrawCircle( TPointF.Zero, _Radius, P );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TCGCirc.Create;
begin
     inherited;

     _Radius := 1;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGTria

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGTria.SetVert1( const Vert1_:TSingle2D );
begin
     _Vert1 := Vert1_;

     Changed;
end;

procedure TCGTria.SetVert2( const Vert2_:TSingle2D );
begin
     _Vert2 := Vert2_;

     Changed;
end;

procedure TCGTria.SetVert3( const Vert3_:TSingle2D );
begin
     _Vert3 := Vert3_;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGTria.DrawMain( const Canvas_:ISkCanvas );
var
   S :TCGStyle;
   B :ISkPathBuilder;
   T :ISkPath;
   P :ISkPaint;
begin
     S := Style;  if not Assigned( S ) then Exit;

     B := TSkPathBuilder.Create;

     B.MoveTo( _Vert1 );
     B.LineTo( _Vert2 );
     B.LineTo( _Vert3 );
     B.Close;

     T := B.Detach;

     P := S.PaintFill;  if Assigned( P ) then Canvas_.DrawPath( T, P );
     P := S.PaintLine;  if Assigned( P ) then Canvas_.DrawPath( T, P );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGLine

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGLine.SetPos1( const Pos1_:TSingle2D );
begin
     _Pos1 := Pos1_;

     Changed;
end;

procedure TCGLine.SetPos2( const Pos2_:TSingle2D );
begin
     _Pos2 := Pos2_;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGLine.DrawMain( const Canvas_:ISkCanvas );
var
   S :TCGStyle;
   P :ISkPaint;
begin
     S := Style;  if not Assigned( S ) then Exit;

     P := S.PaintLine;  if Assigned( P ) then Canvas_.DrawLine( _Pos1, _Pos2, P );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCGPlots

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

procedure TCGPlots.SetPoins( const Poins_:TArray<TPointF> );
begin
     _Poins := Poins_;

     Changed;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TCGPlots.DrawMain( const Canvas_:ISkCanvas );
var
   S :TCGStyle;
   P :ISkPaint;
begin
     S := Style;  if not Assigned( S ) then Exit;

     if Length( _Poins ) = 0 then Exit;

     P := S.PaintLine;  if Assigned( P ) then Canvas_.DrawPoints( TSkDrawPointsMode.Points, _Poins, P );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

end. //######################################################################### ■
