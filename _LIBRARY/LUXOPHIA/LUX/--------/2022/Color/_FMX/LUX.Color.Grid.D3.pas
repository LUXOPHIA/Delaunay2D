﻿unit LUX.Color.Grid.D3;

interface //#################################################################### ■

uses System.UITypes,
     FMX.Graphics,
     LUX,
     LUX.Data.Grid.T3,
     LUX.Color;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【型】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【レコード】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【クラス】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPoinColorGrid3D<_TItem_>

     TPoinColorGrid3D<_TItem_> = class( TPoinArray3D<_TItem_> )
     private
     protected
       ///// メソッド
       procedure DrawToXY( const BMP_:TBitmap; Z_:Integer; const Func_:TConstFunc<Integer,Integer,Integer,TAlphaColor> ); overload;
     public
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellColorGrid3D<_TItem_>

     TCellColorGrid3D<_TItem_> = class( TCellArray3D<_TItem_> )
     private
     protected
       ///// メソッド
       procedure DrawToXY( const BMP_:TBitmap; Z_:Integer; const Func_:TConstFunc<Integer,Integer,Integer,TAlphaColor> ); overload;
     public
     end;

//const //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【定数】

//var //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【変数】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【ルーチン】

implementation //############################################################### ■

uses System.Threading;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【レコード】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【クラス】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TPoinColorGrid3D<_TItem_>

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

/////////////////////////////////////////////////////////////////////// メソッド

procedure TPoinColorGrid3D<_TItem_>.DrawToXY( const BMP_:TBitmap; Z_:Integer; const Func_:TConstFunc<Integer,Integer,Integer,TAlphaColor> );
var
   B :TBitmapData;
begin
     BMP_.SetSize( PoinsX, PoinsY );

     BMP_.Map( TMapAccess.Write, B );

     TParallel.For( 0, PoinsY-1, procedure( Y:Integer )
     var
        P :PAlphaColor;
        X :Integer;
     begin
          P := B.GetScanline( Y );

          for X := 0 to PoinsX-1 do
          begin
               P^ := Func_( X, Y, Z_ );  Inc( P );
          end;
     end );

     BMP_.Unmap( B );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TCellColorGrid3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

/////////////////////////////////////////////////////////////////////// メソッド

procedure TCellColorGrid3D<_TItem_>.DrawToXY( const BMP_:TBitmap; Z_:Integer; const Func_:TConstFunc<Integer,Integer,Integer,TAlphaColor> );
var
   B :TBitmapData;
begin
     BMP_.SetSize( CellsX, CellsY );

     BMP_.Map( TMapAccess.Write, B );

     TParallel.For( 0, CellsY-1, procedure( Y:Integer )
     var
        P :PAlphaColor;
        X :Integer;
     begin
          P := B.GetScanline( Y );

          for X := 0 to CellsX-1 do
          begin
               P^ := Func_( X, Y, Z_ );  Inc( P );
          end;
     end );

     BMP_.Unmap( B );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【ルーチン】

//############################################################################## □

initialization //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ 初期化

finalization //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ 最終化

end. //######################################################################### ■
