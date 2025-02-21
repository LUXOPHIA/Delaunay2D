﻿unit LUX.D1.Gamma.C2;

interface //#################################################################### ■

uses LUX, LUX.Complex;

//type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

function Gamma( const X_:TSingleC ) :TSingleC; overload;
function Gamma( const X_:TDoubleC ) :TDoubleC; overload;

implementation //############################################################### ■

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

function Gamma( const X_:TSingleC ) :TSingleC;
var
   W, U, V, Y :TSingleC;
   T :Single;
begin
     if X_.R < 0 then W := 1 - X_
                 else W :=     X_;

     U :=       W + 6.00009857740312429   ;
     V := U * ( W + 4.99999857982434025  );
     Y := U * 13.2280130755055088 + V * 66.2756400966213521 + 0.293729529320536228;

     U := V * ( W + 4.00000003016801681  );
     V := U * ( W + 2.99999999944915534  );
     Y := Y + U * 91.1395751189899762 + V * 47.3821439163096063;

     U := V * ( W + 2.00000000000603851  );
     V := U * ( W + 0.999999999999975753 );
     Y := Y + U * 10.5400280458730808 + V;

     U := V * W;  T := U.Siz2;
     V := Y * U.Conj + T * 0.0327673720261526849;

     Y := W + 7.31790632447016203;
     U := Ln( Y ) - 1;

     Y := U * ( W - 0.5 );
     U := Exp( Y - 3.48064577727581257 ) / T;

     Y := U * V;

     if X_.R < 0 then
     begin
          W := X_ * Pi;  W.I := Exp( W.I );

          V.I := 1 / W.I;

          U.R := ( V.I + W.I ) * Sin( W.R );
          U.I := ( V.I - W.I ) * Cos( W.R );

          V := U * Y.Conj;

          Y := Pi2 / V.Siz2 * V;
     end;

     Result := Y;
end;

function Gamma( const X_:TDoubleC ) :TDoubleC;
var
   W, U, V, Y :TDoubleC;
   T :Double;
begin
     if X_.R < 0 then W := 1 - X_
                 else W :=     X_;

     U :=       W + 6.00009857740312429   ;
     V := U * ( W + 4.99999857982434025  );
     Y := U * 13.2280130755055088 + V * 66.2756400966213521 + 0.293729529320536228;

     U := V * ( W + 4.00000003016801681  );
     V := U * ( W + 2.99999999944915534  );
     Y := Y + U * 91.1395751189899762 + V * 47.3821439163096063;

     U := V * ( W + 2.00000000000603851  );
     V := U * ( W + 0.999999999999975753 );
     Y := Y + U * 10.5400280458730808 + V;

     U := V * W;  T := U.Siz2;
     V := Y * U.Conj + T * 0.0327673720261526849;

     Y := W + 7.31790632447016203;
     U := Ln( Y ) - 1;

     Y := U * ( W - 0.5 );
     U := Exp( Y - 3.48064577727581257 ) / T;

     Y := U * V;

     if X_.R < 0 then
     begin
          W := X_ * Pi;  W.I := Exp( W.I );

          V.I := 1 / W.I;

          U.R := ( V.I + W.I ) * Sin( W.R );
          U.I := ( V.I - W.I ) * Cos( W.R );

          V := U * Y.Conj;

          Y := Pi2 / V.Siz2 * V;
     end;

     Result := Y;
end;

end. //######################################################################### ■