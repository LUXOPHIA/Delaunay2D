﻿unit LUX;

interface //#################################################################### ■

uses System.Types, System.SysUtils, System.Classes, System.Math.Vectors, System.Generics.Collections, System.Threading;

type //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 T Y P E 】

     Int08u = Byte    ;  Int8u = Int08u;
     Int08s = Shortint;  Int8s = Int08s;
     Int16u = Word    ;
     Int16s = Smallint;
     Int32u = Cardinal;
     Int32s = Integer ;
     Int64u = UInt64  ;
     Int64s = Int64   ;

     Flo32s = Single  ;
     Flo64s = Double  ;

     //-------------------------------------------------------------------------

     PPByte    = ^PByte;
     PPLongint = ^PLongint;

     //-------------------------------------------------------------------------

     PUInt8   = ^UInt8  ;  PInt8   = ^Int8  ;
     PUInt16  = ^UInt16 ;  PInt16  = ^Int16 ;
     PUInt32  = ^UInt32 ;  PInt32  = ^Int32 ;
     PUIntPtr = ^UIntPtr;  PIntPtr = ^IntPtr;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TArray2/3<>

     TArray2<T> = array of TArray <T>;
     TArray3<T> = array of TArray2<T>;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TConstProc/Func<>

     TConstProc<TA         > = reference to procedure( const A:TA                                     );
     TConstProc<TA,TB      > = reference to procedure( const A:TA; const B:TB                         );
     TConstProc<TA,TB,TC   > = reference to procedure( const A:TA; const B:TB; const C:TC             );
     TConstProc<TA,TB,TC,TD> = reference to procedure( const A:TA; const B:TB; const C:TC; const D:TD );

     TConstFunc<TA,         TResult> = reference to function( const A:TA                                     ) :TResult;
     TConstFunc<TA,TB,      TResult> = reference to function( const A:TA; const B:TB                         ) :TResult;
     TConstFunc<TA,TB,TC,   TResult> = reference to function( const A:TA; const B:TB; const C:TC             ) :TResult;
     TConstFunc<TA,TB,TC,TD,TResult> = reference to function( const A:TA; const B:TB; const C:TC; const D:TD ) :TResult;

     TConstProc1<T> = reference to procedure( const A:T       );
     TConstProc2<T> = reference to procedure( const A,B:T     );
     TConstProc3<T> = reference to procedure( const A,B,C:T   );
     TConstProc4<T> = reference to procedure( const A,B,C,D:T );

     TConstFunc1<T,TResult> = reference to function( const A:T       ) :TResult;
     TConstFunc2<T,TResult> = reference to function( const A,B:T     ) :TResult;
     TConstFunc3<T,TResult> = reference to function( const A,B,C:T   ) :TResult;
     TConstFunc4<T,TResult> = reference to function( const A,B,C,D:T ) :TResult;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelegates

     TDelegates = record
     private
       _Events :TArray<TNotifyEvent>;
     public
       ///// M E T H O D
       procedure Add( E_:TNotifyEvent );
       procedure Del( const E_:TNotifyEvent );
       procedure Run( const Sender_:TObject );
       procedure Free;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% THex4

     THex4 = type Word;

     HHex4 = record helper for THex4
     private
     public
       ///// M E T H O D
       function ToString :String;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRay3D

     TRay3D = record
     private
     public
       Pos :TVector3D;
       Vec :TVector3D;
       /////
       constructor Create( const Pos_,Vec_:TVector3D );
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRangeArray<_TValue_>

     TRangeArray<_TValue_> = record
     private
       _Values :TArray<_TValue_>;
       _MinI   :Integer;
       _MaxI   :Integer;
       ///// A C C E S S O R
       function GetValues( I_:Integer ) :_TValue_;
       procedure SetValues( I_:Integer; const Value_:_TValue_ );
       procedure SetMinI( const MinI_:Integer );
       procedure SetMaxI( const MaxI_:Integer );
       function GetCount :Integer;
       ///// M E T H O D
       procedure InitArray;
     public
       constructor Create( const MinI_,MaxI_:Integer );
       ///// P R O P E R T Y
       property Values[ I_:Integer ] :_TValue_ read GetValues write SetValues; default;
       property MinI                 :Integer  read   _MinI   write SetMinI  ;
       property MaxI                 :Integer  read   _MaxI   write SetMaxI  ;
       property Count                :Integer  read GetCount                 ;
       ///// M E T H O D
       procedure SetRange( const I_:Integer ); overload;
       procedure SetRange( const MinI_,MaxI_:Integer ); overload;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TMarginArray<_TValue_>

     TMarginArray<_TValue_> = record
     private
       _Values :TArray<_TValue_>;
       _LowerN :Integer;
       _Count  :Integer;
       _UpperN :Integer;
       ///// A C C E S S O R
       function GetValues( I_:Integer ) :_TValue_;
       procedure SetValues( I_:Integer; const Value_:_TValue_ );
       procedure SetLowerN( const LowerN_:Integer );
       procedure SetCount( const Count_:Integer );
       procedure SetUpperN( const UpperN_:Integer );
       ///// M E T H O D
       procedure InitArray;
     public
       constructor Create( const LowerN_,Count_,UpperN_:Integer );
       ///// P R O P E R T Y
       property Values[ I_:Integer ] :_TValue_ read GetValues write SetValues; default;
       property LowerN               :Integer  read   _LowerN write SetLowerN;
       property Count                :Integer  read   _Count  write SetCount ;
       property UpperN               :Integer  read   _UpperN write SetUpperN;
     end;

     //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TInterfacedBase

     TInterfacedBase = class( TObject, IInterface )
     private
     protected
       function QueryInterface( const IID_:TGUID; out Obj_ ) :HResult; stdcall;
       function _AddRef :Integer; stdcall;
       function _Release :Integer; stdcall;
     public
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TIdleTask

     TIdleTask = class
     private
     protected class var
       _Task :ITask;
     public
       ///// M E T H O D
       class procedure Run( const Proc_:TThreadProcedure; const Delay_:Integer = 500 );
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TIter< TValue_ >

     TIter< TValue_ > = class
     private
     protected
       ///// A C C E S S O R
       function GetValue :TValue_; virtual; abstract;
       procedure SetValue( const Value_:TValue_ ); virtual; abstract;
     public
       ///// P R O P E R T Y
       property Value :TValue_ read GetValue write SetValue;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFileReader

     TFileReader = class( TBinaryReader )
     private
     protected
       _Encoding  :TEncoding;
       _OffsetBOM :Integer;
     public
       constructor Create( Stream_:TStream; Encoding_:TEncoding = nil; OwnsStream_:Boolean = False ); overload;
       constructor Create( const Filename_:String; Encoding_:TEncoding = nil ); overload;
       ///// P R O P E R T Y
       property OffsetBOM :Integer read _OffsetBOM;
       ///// M E T H O D
       function EndOfStream :Boolean;
       function ReadLine :String;
       function Read( var Buffer_; Count_:Longint ) :Longint;
     end;

     //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSearchBM<_TYPE_>

     TSearchBM<_TYPE_> = class
     private
       __TableBC :TDictionary<_TYPE_,Integer>;
       _PN0      :Integer;
       _PN1      :Integer;
       _PN2      :Integer;
       ///// A C C E S S O R
       function Get_TableBC( const Key_:_TYPE_ ) :Integer;
       procedure Set_TableBC( const Key_:_TYPE_; const Val_:Integer );
       ///// M E T H O D
       function Equal( const A_,B_:_TYPE_ ) :Boolean;
     protected
       _Pattern  :TArray<_TYPE_>;
       _TableSF  :TArray<Integer>;
       _TableGS  :TArray<Integer>;
       ///// P R O P E R T Y
       property _TableBC[ const Key_:_TYPE_ ] :Integer read Get_TableBC write Set_TableBC;
       ///// A C C E S S O R
       function GetPattern :TArray<_TYPE_>;
       procedure SetPattern( const Pattern_:TArray<_TYPE_> );
       ///// M E T H O D
       procedure MakeTableBC;
       procedure MakeTableSF;
       procedure MakeTableGS;
     public
       type TOnRead      = reference to function( const I_:Integer ) :_TYPE_;
       type TOnReadBlock = reference to procedure( const HeadI_:Integer; const Buffer_:TArray<_TYPE_> );
     public
       constructor Create; overload;
       constructor Create( const Pattern_:TArray<_TYPE_> ); overload;
       destructor Destroy; override;
       ///// P R O P E R T Y
       property Pattern :TArray<_TYPE_> read GetPattern write SetPattern;
       ///// M E T H O D
       function Match( const Source_:TArray<_TYPE_>; const StartI_,StopI_:Integer ) :Integer; overload;
       function Matches( const Source_:TArray<_TYPE_>; const StartI_,StopI_:Integer ) :TArray<Integer>; overload;
       function Match( const Source_:TArray<_TYPE_>; const StartI_:Integer = 0 ) :Integer; overload;
       function Matches( const Source_:TArray<_TYPE_>; const StartI_:Integer = 0 ) :TArray<Integer>; overload;
       function Match( const StartI_,StopI_:Integer; const OnRead_:TOnRead ) :Integer; overload;
       function Matches( const StartI_,StopI_:Integer; const OnRead_:TOnRead ) :TArray<Integer>; overload;
       function Match( const StartI_,StopI_:Integer; const OnReadBlock_:TOnReadBlock ) :Integer; overload;
       function Matches( const StartI_,StopI_:Integer; const OnReadBlock_:TOnReadBlock ) :TArray<Integer>; overload;
     end;

const //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C O N S T A N T 】

      SINGLE_EPS = 1.1920928955078125E-7;
      DOUBLE_EPS = 2.220446049250313080847263336181640625E-16;

      SINGLE_EPS1 = SINGLE_EPS * 1E1;
      DOUBLE_EPS1 = DOUBLE_EPS * 1E1;

      SINGLE_EPS2 = SINGLE_EPS * 1E2;
      DOUBLE_EPS2 = DOUBLE_EPS * 1E2;

      SINGLE_EPS3 = SINGLE_EPS * 1E3;
      DOUBLE_EPS3 = DOUBLE_EPS * 1E3;

      SINGLE_EPS4 = SINGLE_EPS * 1E4;
      DOUBLE_EPS4 = DOUBLE_EPS * 1E4;

      //------------------------------------------------------------------------

      Pi2 = 2 * Pi;
      Pi3 = 3 * Pi;
      Pi4 = 4 * Pi;

      P2i = Pi / 2;
      P3i = Pi / 3;
      P4i = Pi / 4;

      P3i2 = Pi2 / 3;

      //------------------------------------------------------------------------

      CRLF = #13#10;

//var //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 V A R I A B L E 】

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

{$IF SizeOf( Extended ) = 10 }
  function Int( const X_:Extended ) :Extended; inline; overload;
  function Frac( const X_:Extended ) :Extended; inline; overload;
  function Exp( const X_:Extended ) :Extended; inline; overload;
  function Cos( const X_:Extended ) :Extended; inline; overload;
  function Sin( const X_:Extended ) :Extended; inline; overload;
  function Ln( const X_:Extended ) :Extended; inline; overload;
  function ArcTan( const X_:Extended ) :Extended; inline; overload;
  function Sqrt( const X_:Extended ) :Extended; inline; overload;
  function Tangent( const X_:Extended ) :Extended; inline; overload;
  procedure SineCosine( const X_:Extended; var Sin_,Cos_:Extended ); inline; overload;
  function ExpMinus1( const X_:Extended) :Extended; inline; overload;
  function LnXPlus1( const X_:Extended) :Extended; inline; overload;
{$ENDIF}

function Binomial( N_,K_:Integer ) :Integer;  // 0 <= N <= 33, 0 <= K <= N

function Pow2( const X_:Int32u ) :Int32u; inline; overload;
function Pow2( const X_:Int32s ) :Int32s; inline; overload;
function Pow2( const X_:Int64u ) :Int64u; inline; overload;
function Pow2( const X_:Int64s ) :Int64s; inline; overload;
function Pow2( const X_:Single ) :Single; inline; overload;
function Pow2( const X_:Double ) :Double; inline; overload;

function Pow3( const X_:Int32u ) :Int32u; inline; overload;
function Pow3( const X_:Int32s ) :Int32s; inline; overload;
function Pow3( const X_:Int64u ) :Int64u; inline; overload;
function Pow3( const X_:Int64s ) :Int64s; inline; overload;
function Pow3( const X_:Single ) :Single; inline; overload;
function Pow3( const X_:Double ) :Double; inline; overload;

function Pow4( const X_:Int32u ) :Int32u; inline; overload;
function Pow4( const X_:Int32s ) :Int32s; inline; overload;
function Pow4( const X_:Int64u ) :Int64u; inline; overload;
function Pow4( const X_:Int64s ) :Int64s; inline; overload;
function Pow4( const X_:Single ) :Single; inline; overload;
function Pow4( const X_:Double ) :Double; inline; overload;

function Pow5( const X_:Int32u ) :Int32u; inline; overload;
function Pow5( const X_:Int32s ) :Int32s; inline; overload;
function Pow5( const X_:Int64u ) :Int64u; inline; overload;
function Pow5( const X_:Int64s ) :Int64s; inline; overload;
function Pow5( const X_:Single ) :Single; inline; overload;
function Pow5( const X_:Double ) :Double; inline; overload;

function Roo2( const X_:Single ) :Single; inline; overload;
function Roo2( const X_:Double ) :Double; inline; overload;

function Roo3( const X_:Single ) :Single; inline; overload;
function Roo3( const X_:Double ) :Double; inline; overload;

function Clamp( const X_,Min_,Max_:Integer ) :Integer; inline; overload;
function Clamp( const X_,Min_,Max_:Single ) :Single; inline; overload;
function Clamp( const X_,Min_,Max_:Double ) :Double; inline; overload;

function ClampMin( const X_,Min_:Integer ) :Integer; inline; overload;
function ClampMin( const X_,Min_:Single ) :Single; inline; overload;
function ClampMin( const X_,Min_:Double ) :Double; inline; overload;

function ClampMax( const X_,Max_:Integer ) :Integer; inline; overload;
function ClampMax( const X_,Max_:Single ) :Single; inline; overload;
function ClampMax( const X_,Max_:Double ) :Double; inline; overload;

function Min( const A_,B_,C_:Integer ) :Integer; overload;
function Min( const A_,B_,C_:Single ) :Single; overload;
function Min( const A_,B_,C_:Double ) :Double; overload;

function Max( const A_,B_,C_:Integer ) :Integer; overload;
function Max( const A_,B_,C_:Single ) :Single; overload;
function Max( const A_,B_,C_:Double ) :Double; overload;

function MinI( const V1_,V2_:Integer ) :Byte; inline; overload;
function MinI( const V1_,V2_:Single ) :Byte; inline; overload;
function MinI( const V1_,V2_:Double ) :Byte; inline; overload;

function MaxI( const V1_,V2_:Integer ) :Byte; inline; overload;
function MaxI( const V1_,V2_:Single ) :Byte; inline; overload;
function MaxI( const V1_,V2_:Double ) :Byte; inline; overload;

function MinI( const V1_,V2_,V3_:Integer ) :Integer; inline; overload;
function MinI( const V1_,V2_,V3_:Single ) :Integer; inline; overload;
function MinI( const V1_,V2_,V3_:Double ) :Integer; inline; overload;

function MinI( const V1_,V2_,V3_,V4_:Integer ) :Integer; inline; overload;
function MinI( const V1_,V2_,V3_,V4_:Single ) :Integer; inline; overload;
function MinI( const V1_,V2_,V3_,V4_:Double ) :Integer; inline; overload;

function MaxI( const V1_,V2_,V3_:Integer ) :Integer; inline; overload;
function MaxI( const V1_,V2_,V3_:Single ) :Integer; inline; overload;
function MaxI( const V1_,V2_,V3_:Double ) :Integer; inline; overload;

function MaxI( const V1_,V2_,V3_,V4_:Integer ) :Integer; inline; overload;
function MaxI( const V1_,V2_,V3_,V4_:Single ) :Integer; inline; overload;
function MaxI( const V1_,V2_,V3_,V4_:Double ) :Integer; inline; overload;

function MinI( const Vs_:array of Integer ) :Integer; overload;
function MinI( const Vs_:array of Single ) :Integer; overload;
function MinI( const Vs_:array of Double ) :Integer; overload;

function MaxI( const Vs_:array of Integer ) :Integer; overload;
function MaxI( const Vs_:array of Single ) :Integer; overload;
function MaxI( const Vs_:array of Double ) :Integer; overload;

function PoMod( const X_,Range_:Integer ) :Integer; overload;
function PoMod( const X_,Range_:Int64 ) :Int64; overload;

{$IF Defined( MACOS ) or Defined( MSWINDOWS ) }
function RevBytes( const Value_:Word ) :Word; overload;
function RevBytes( const Value_:Smallint ) :Smallint; overload;

function RevBytes( const Value_:Cardinal ) :Cardinal; overload;
function RevBytes( const Value_:Integer ) :Integer; overload;
function RevBytes( const Value_:Single ) :Single; overload;

function RevBytes( const Value_:UInt64 ) :UInt64; overload;
function RevBytes( const Value_:Int64 ) :Int64; overload;
function RevBytes( const Value_:Double ) :Double; overload;
{$ENDIF}

{$IF Defined( MACOS ) or Defined( MSWINDOWS ) }
function CharsToStr( const Cs_:TArray<AnsiChar> ) :AnsiString;
{$ENDIF}

function FileToBytes( const FileName_:string ) :TBytes;

function Comb( N_,K_:Cardinal ) :UInt64;

function BinPow( const N_:Integer ) :Integer; overload;
function BinPow( const N_:Cardinal ) :Cardinal; overload;
function BinPow( const N_:Int64 ) :Int64; overload;
function BinPow( const N_:UInt64 ) :UInt64; overload;

function UIntToStr( const Value_:Uint32; const N_:Integer; const C_:Char = '0' ) :String; overload;
function UIntToStr( const Value_:UInt64; const N_:Integer; const C_:Char = '0' ) :String; overload;

function IntToStr( const Value_:Integer; const N_:Integer; const C_:Char = '0' ) :String; overload;
function IntToStr( const Value_:Int64; const N_:Integer; const C_:Char = '0' ) :String; overload;
function IntToStrP( const Value_:Integer; const N_:Integer; const C_:Char = '0' ) :String; overload;
function IntToStrP( const Value_:Int64; const N_:Integer; const C_:Char = '0' ) :String; overload;

function FloatToStr( const Value_:Single; const N_:Integer; out Man_,Exp_:String ) :Boolean; overload;
function FloatToStr( const Value_:Double; const N_:Integer; out Man_,Exp_:String ) :Boolean; overload;

function _TestFloatToStr_Single( const Value_:String; const N_:Integer ) :String;
function _TestFloatToStr_Double( const Value_:String; const N_:Integer ) :String;

function FloatToStr( const Value_:Single; const N_:Integer; out Man_,Exp_:String; out DecN_:Integer ) :Boolean; overload;
function FloatToStr( const Value_:Double; const N_:Integer; out Man_,Exp_:String; out DecN_:Integer ) :Boolean; overload;

function FloatToStr( const Value_:Single; const N_:Integer ) :String; overload;
function FloatToStr( const Value_:Double; const N_:Integer ) :String; overload;
function FloatToStrP( const Value_:Single; const N_:Integer ) :String; overload;
function FloatToStrP( const Value_:Double; const N_:Integer ) :String; overload;

function Floor( const X_,D_:UInt32 ) :UInt32; overload;
function Floor( const X_,D_:UInt64 ) :UInt64; overload;

function Ceil( const X_,D_:UInt32 ) :UInt32; overload;
function Ceil( const X_,D_:UInt64 ) :UInt64; overload;

function Floor2N( const X_,D_:UInt32 ) :UInt32; overload;
function Floor2N( const X_,D_:UInt64 ) :UInt64; overload;

function Ceil2N( const X_,D_:UInt32 ) :UInt32; overload;
function Ceil2N( const X_,D_:UInt64 ) :UInt64; overload;

procedure GetMemAligned( out P_:Pointer; const Size_,Align2N_:UInt32 );
procedure FreeMemAligned( const P_:Pointer );

implementation //############################################################### ■

uses System.Math;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R E C O R D 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TDelegates

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TDelegates.Add( E_:TNotifyEvent );
begin
     if TArray.IndexOf<TNotifyEvent>( _Events, E_ ) < 0 then _Events := _Events + [ E_ ];
end;

procedure TDelegates.Del( const E_:TNotifyEvent );
var
   I :Integer;
begin
     I := TArray.IndexOf<TNotifyEvent>( _Events, E_ );  if I < 0 then Exit;

     Delete( _Events, I, 1 );
end;

procedure TDelegates.Run( const Sender_:TObject );
var
   E :TNotifyEvent;
begin
     for E in _Events do E( Sender_ );
end;

procedure TDelegates.Free;
var
   E :TNotifyEvent;
begin
     for E in Copy( _Events ) do TObject( TMethod( E ).Data ).Free;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% THex4

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

function HHex4.ToString :String;
begin
     Result := IntToHex( Self, 4 );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRay3D

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TRay3D.Create( const Pos_,Vec_:TVector3D );
begin
     Pos := Pos_;
     Vec := Vec_;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TRangeArray<_TValue_>

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TRangeArray<_TValue_>.GetValues( I_:Integer ) :_TValue_;
begin
     Dec( I_, _MinI );  Result := _Values[ I_ ];
end;

procedure TRangeArray<_TValue_>.SetValues( I_:Integer; const Value_:_TValue_ );
begin
     Dec( I_, _MinI );  _Values[ I_ ] := Value_;
end;

procedure TRangeArray<_TValue_>.SetMinI( const MinI_:Integer );
begin
     _MinI := MinI_;

     InitArray;
end;

procedure TRangeArray<_TValue_>.SetMaxI( const MaxI_:Integer );
begin
     _MaxI := MaxI_;

     InitArray;
end;

function TRangeArray<_TValue_>.GetCount :Integer;
begin
     Result := _MaxI - _MinI + 1;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TRangeArray<_TValue_>.InitArray;
begin
     SetLength( _Values, GetCount );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TRangeArray<_TValue_>.Create( const MinI_,MaxI_:Integer );
begin
     SetRange( MinI_, MaxI_ );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TRangeArray<_TValue_>.SetRange( const I_:Integer );
begin
     SetRange( I_, I_ );
end;

procedure TRangeArray<_TValue_>.SetRange( const MinI_,MaxI_:Integer );
begin
     _MinI := MinI_;
     _MaxI := MaxI_;

     InitArray;
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TMarginArray<_TValue_>

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TMarginArray<_TValue_>.GetValues( I_:Integer ) :_TValue_;
begin
     Inc( I_, _LowerN );  Result := _Values[ I_ ];
end;

procedure TMarginArray<_TValue_>.SetValues( I_:Integer; const Value_:_TValue_ );
begin
     Inc( I_, _LowerN );  _Values[ I_ ] := Value_;
end;

procedure TMarginArray<_TValue_>.SetLowerN( const LowerN_:Integer );
begin
     _LowerN := LowerN_;

     InitArray;
end;

procedure TMarginArray<_TValue_>.SetCount( const Count_:Integer );
begin
     _Count := Count_;

     InitArray;
end;

procedure TMarginArray<_TValue_>.SetUpperN( const UpperN_:Integer );
begin
     _UpperN := UpperN_;

     InitArray;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TMarginArray<_TValue_>.InitArray;
begin
     SetLength( _Values, _LowerN + _Count + _UpperN );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TMarginArray<_TValue_>.Create( const LowerN_,Count_,UpperN_:Integer );
begin
     _LowerN := LowerN_;
     _Count  := Count_ ;
     _UpperN := UpperN_;

     InitArray;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 C L A S S 】

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TInterfacedBase

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////////// M E T H O D

function TInterfacedBase.QueryInterface( const IID_:TGUID; out Obj_ ) :HResult;
begin
     if GetInterface( IID_, Obj_ ) then Result := 0
                                   else Result := E_NOINTERFACE;
end;

function TInterfacedBase._AddRef :Integer;
begin
     Result := 0;
end;

function TInterfacedBase._Release :Integer;
begin
     Result := 0;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TIdleTask

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//////////////////////////////////////////////////////////////////// M E T H O D

class procedure TIdleTask.Run( const Proc_:TThreadProcedure; const Delay_:Integer = 500 );
begin
     if Assigned( _Task ) then _Task.Cancel;

     _Task := TTask.Run( procedure
     begin
          Sleep( Delay_ );

          if TTask.CurrentTask.Status = TTaskStatus.Running then TThread.Queue( nil, Proc_ );
     end );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TIter< TValue_ >

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TFileReader

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TFileReader.Create( Stream_:TStream; Encoding_:TEncoding = nil; OwnsStream_:Boolean = False );
begin
     inherited Create( Stream_, TEncoding.ANSI, OwnsStream_ );

     _OffsetBOM := TEncoding.GetBufferEncoding( ReadBytes( 8 ), _Encoding, Encoding_ );

     BaseStream.Position := _OffsetBOM;
end;

constructor TFileReader.Create( const Filename_:String; Encoding_:TEncoding = nil );
begin
     Create( TFileStream.Create( Filename_, fmOpenRead or fmShareDenyWrite ), Encoding_, True );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TFileReader.EndOfStream :Boolean;
begin
     Result := ( PeekChar = -1 );
end;

function TFileReader.ReadLine :String;
var
   Bs :TBytes;
   B :Byte;
begin
     Bs := [];

     while not EndOfStream do
     begin
          B := ReadByte;

          case B of
           10: Break;
           13: begin
                    if PeekChar = 10 then ReadByte;

                    Break;
               end;
          else Bs := Bs + [ B ];
          end;
     end;

     Result := _Encoding.GetString( Bs );
end;

function TFileReader.Read( var Buffer_; Count_:Longint ) :Longint;
begin
     Result := BaseStream.Read( Buffer_, Count_ );
end;

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TSearchBM<_TYPE_>

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& private

//////////////////////////////////////////////////////////////// A C C E S S O R

function TSearchBM<_TYPE_>.Get_TableBC( const Key_:_TYPE_ ) :Integer;
begin
     if __TableBC.ContainsKey( Key_ ) then Result := __TableBC[ Key_ ]
                                      else Result := _PN0;

end;

procedure TSearchBM<_TYPE_>.Set_TableBC( const Key_:_TYPE_; const Val_:Integer );
begin
     __TableBC.AddOrSetValue( Key_, Val_ );
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TSearchBM<_TYPE_>.Equal( const A_,B_:_TYPE_ ) :Boolean;
begin
     Result := CompareMem( @A_, @B_, SizeOf( _TYPE_ ) );
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& protected

//////////////////////////////////////////////////////////////// A C C E S S O R

function TSearchBM<_TYPE_>.GetPattern :TArray<_TYPE_>;
begin
     Result := _Pattern;
end;

procedure TSearchBM<_TYPE_>.SetPattern( const Pattern_:TArray<_TYPE_> );
begin
     _Pattern := Pattern_;

     _PN0 := Length( _Pattern );
     _PN1 := _PN0 - 1;
     _PN2 := _PN1 - 1;

     MakeTableBC;
     MakeTableSF;
     MakeTableGS;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

procedure TSearchBM<_TYPE_>.MakeTableBC;
var
   I :Integer;
begin
     with __TableBC do
     begin
          Clear;

          for I := 0 to _PN2 do AddOrSetValue( _Pattern[ I ], _PN1 - I );
     end;
end;

procedure TSearchBM<_TYPE_>.MakeTableSF;
var
   I, G, F :Integer;
begin
     SetLength( _TableSF, _PN0 );

     _TableSF[ _PN1 ] := _PN0;

     F := _PN1;
     G := _PN1;
     for I := _PN2 downto 0 do
     begin
          if ( I > G ) and ( _TableSF[ I + _PN1 - F ] < I - G ) then
          begin
               _TableSF[ I ] := _TableSF[ I + _PN1 - F ];
          end
          else
          begin
               if I < G then G := I;

               F := I;

               while ( G >= 0 ) and Equal( _Pattern[ G ], _Pattern[ G + _PN1 - F ] ) do Dec( G );

               _TableSF[ I ] := F - G;
          end;
     end;
end;
{
procedure TSearchBM<_TYPE_>.MakeTableGS;
var
   S, I, J :Integer;
begin
     SetLength( _TableGS, _PN0 );

     for I := 0 to _PN1 do _TableGS[ I ] := _PN0;

     I := 0;
     S := 0;
     for J := _PN1 downto 0 do
     begin
          if _TableSF[ J ] = J + 1 then
          begin
               while I < S do
               begin
                    _TableGS[ I ] := S;

                    Inc( I );
               end;
          end;

          Inc( S );
     end;

     for I := 0 to _PN2 do _TableGS[ _PN1 - _TableSF[ I ] ] := _PN1 - I;
end;
}
procedure TSearchBM<_TYPE_>.MakeTableGS;
var
   S, I, J :Integer;
begin
     SetLength( _TableGS, _PN0 );

     S := _PN0;

     _TableGS[ _PN1 ] := S;

     J := 0;
     for I := _PN2 downto 0 do
     begin
          if _TableSF[ J ] = J + 1 then S := I + 1;

          _TableGS[ I ] := S;

          Inc( J );
     end;

     for I := 0 to _PN2 do _TableGS[ _PN1 - _TableSF[ I ] ] := _PN1 - I;
end;

//&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& public

constructor TSearchBM<_TYPE_>.Create;
begin
     inherited;

     __TableBC := TDictionary<_TYPE_,Integer>.Create;
end;

constructor TSearchBM<_TYPE_>.Create( const Pattern_:TArray<_TYPE_> );
begin
     Create;

     SetPattern( Pattern_ );
end;

destructor TSearchBM<_TYPE_>.Destroy;
begin
     __TableBC.Free;

     inherited;
end;

//////////////////////////////////////////////////////////////////// M E T H O D

function TSearchBM<_TYPE_>.Match( const Source_:TArray<_TYPE_>; const StartI_,StopI_:Integer ) :Integer;
var
   J, I :Integer;
   A :_TYPE_;
label
     NOTMATCH;
begin
     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          for I := _PN1 downto 0 do
          begin
               A := Source_[ J + I ];

               if not Equal( _Pattern[ I ], A ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ A ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := J;

          Exit;

          NOTMATCH:
     end;

     Result := -1;
end;

function TSearchBM<_TYPE_>.Matches( const Source_:TArray<_TYPE_>; const StartI_,StopI_:Integer ) :TArray<Integer>;
var
   J, I :Integer;
   A :_TYPE_;
label
     NOTMATCH;
begin
     Result := [];

     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          for I := _PN1 downto 0 do
          begin
               A := Source_[ J + I ];

               if not Equal( _Pattern[ I ], A ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ A ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := Result + [ J ];

          Inc( J, _TableGS[ 0 ] );

          NOTMATCH:
     end;
end;

//------------------------------------------------------------------------------

function TSearchBM<_TYPE_>.Match( const Source_:TArray<_TYPE_>; const StartI_:Integer = 0 ) :Integer;
begin
     Result := Match( Source_, StartI_, Length( Source_ ) );
end;

function TSearchBM<_TYPE_>.Matches( const Source_:TArray<_TYPE_>; const StartI_:Integer = 0 ) :TArray<Integer>;
begin
     Result := Matches( Source_, StartI_, Length( Source_ ) );
end;

//------------------------------------------------------------------------------

function TSearchBM<_TYPE_>.Match( const StartI_,StopI_:Integer; const OnRead_:TOnRead ) :Integer;
var
   J, I :Integer;
   A :_TYPE_;
label
     NOTMATCH;
begin
     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          for I := _PN1 downto 0 do
          begin
               A := OnRead_( J + I );

               if not Equal( _Pattern[ I ], A ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ A ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := J;

          Exit;

          NOTMATCH:
     end;

     Result := -1;
end;

function TSearchBM<_TYPE_>.Matches( const StartI_,StopI_:Integer; const OnRead_:TOnRead ) :TArray<Integer>;
var
   J, I :Integer;
   A :_TYPE_;
label
     NOTMATCH;
begin
     Result := [];

     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          for I := _PN1 downto 0 do
          begin
               A := OnRead_( J + I );

               if not Equal( _Pattern[ I ], A ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ A ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := Result + [ J ];

          Inc( J, _TableGS[ 0 ] );

          NOTMATCH:
     end;
end;

//------------------------------------------------------------------------------

function TSearchBM<_TYPE_>.Match( const StartI_,StopI_:Integer; const OnReadBlock_:TOnReadBlock ) :Integer;
var
   B :TArray<_TYPE_>;
   J, I :Integer;
label
     NOTMATCH;
begin
     SetLength( B, _PN0 );

     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          OnReadBlock_( J, B );

          for I := _PN1 downto 0 do
          begin
               if not Equal( _Pattern[ I ], B[ I ] ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ B[ I ] ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := J;

          Exit;

          NOTMATCH:
     end;

     Result := -1;
end;

function TSearchBM<_TYPE_>.Matches( const StartI_,StopI_:Integer; const OnReadBlock_:TOnReadBlock ) :TArray<Integer>;
var
   B :TArray<_TYPE_>;
   J, I :Integer;
label
     NOTMATCH;
begin
     Result := [];

     SetLength( B, _PN0 );

     J := StartI_;

     while J <= StopI_ - _PN0 do
     begin
          OnReadBlock_( J, B );

          for I := _PN1 downto 0 do
          begin
               if not Equal( _Pattern[ I ], B[ I ] ) then
               begin
                    Inc( J, Max( _TableGS[ I ], _TableBC[ B[ I ] ] - _PN1 + I ) );

                    goto NOTMATCH;
               end;
          end;

          Result := Result + [ J ];

          Inc( J, _TableGS[ 0 ] );

          NOTMATCH:
     end;
end;

//$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$【 R O U T I N E 】

{$IF SizeOf( Extended ) = 10 }

function Int( const X_:Extended ) :Extended;
begin
     Result := System.Int( X_ );
end;

function Frac( const X_:Extended ) :Extended;
begin
     Result := System.Frac( X_ );
end;

function Exp( const X_:Extended ) :Extended;
begin
     Result := System.Exp( X_ );
end;

function Cos( const X_:Extended ) :Extended;
begin
     Result := System.Cos( X_ );
end;

function Sin( const X_:Extended ) :Extended;
begin
     Result := System.Sin( X_ );
end;

function Ln( const X_:Extended ) :Extended;
begin
     Result := System.Ln( X_ );
end;

function ArcTan( const X_:Extended ) :Extended;
begin
     Result := System.ArcTan( X_ );
end;

function Sqrt( const X_:Extended ) :Extended;
begin
     Result := System.Sqrt( X_ );
end;

function Tangent( const X_:Extended ) :Extended;
begin
     Result := System.Tangent( X_ );
end;

procedure SineCosine( const X_:Extended; var Sin_,Cos_:Extended );
begin
     System.SineCosine( X_, Sin_, Cos_ );
end;

function ExpMinus1( const X_:Extended) :Extended;
begin
     Result := System.ExpMinus1( X_ );
end;

function LnXPlus1( const X_:Extended) :Extended;
begin
     Result := System.LnXPlus1( X_ );
end;

{$ENDIF}

//------------------------------------------------------------------------------

function Binomial( N_,K_:Integer ) :Integer;  // 0 <= N <= 33, 0 <= K <= N
var
   I :Integer;
begin
     if K_ > N_ - K_ then K_ := N_ - K_;

     Result := 1;
     for I := 1 to K_ do Result := Result * ( N_ - K_ + I ) div I;
end;

//------------------------------------------------------------------------------

function Pow2( const X_:Int32u ) :Int32u;
begin
     Result := Sqr( X_ );
end;

function Pow2( const X_:Int32s ) :Int32s;
begin
     Result := Sqr( X_ );
end;

function Pow2( const X_:Int64u ) :Int64u;
begin
     Result := Sqr( X_ );
end;

function Pow2( const X_:Int64s ) :Int64s;
begin
     Result := Sqr( X_ );
end;

function Pow2( const X_:Single ) :Single;
begin
     Result := Sqr( X_ );
end;

function Pow2( const X_:Double ) :Double;
begin
     Result := Sqr( X_ );
end;

//------------------------------------------------------------------------------

function Pow3( const X_:Int32u ) :Int32u;
begin
     Result := X_ * Pow2( X_ );
end;

function Pow3( const X_:Int32s ) :Int32s;
begin
     Result := X_ * Pow2( X_ );
end;

function Pow3( const X_:Int64u ) :Int64u;
begin
     Result := X_ * Pow2( X_ );
end;

function Pow3( const X_:Int64s ) :Int64s;
begin
     Result := X_ * Pow2( X_ );
end;

function Pow3( const X_:Single ) :Single;
begin
     Result := X_ * Pow2( X_ );
end;

function Pow3( const X_:Double ) :Double;
begin
     Result := X_ * Pow2( X_ );
end;

//------------------------------------------------------------------------------

function Pow4( const X_:Int32u ) :Int32u;
begin
     Result := Pow2( Pow2( X_ ) );
end;

function Pow4( const X_:Int32s ) :Int32s;
begin
     Result := Pow2( Pow2( X_ ) );
end;

function Pow4( const X_:Int64u ) :Int64u;
begin
     Result := Pow2( Pow2( X_ ) );
end;

function Pow4( const X_:Int64s ) :Int64s;
begin
     Result := Pow2( Pow2( X_ ) );
end;

function Pow4( const X_:Single ) :Single;
begin
     Result := Pow2( Pow2( X_ ) );
end;

function Pow4( const X_:Double ) :Double;
begin
     Result := Pow2( Pow2( X_ ) );
end;

//------------------------------------------------------------------------------

function Pow5( const X_:Int32u ) :Int32u;
begin
     Result := Pow4( X_ ) * X_;
end;

function Pow5( const X_:Int32s ) :Int32s;
begin
     Result := Pow4( X_ ) * X_;
end;

function Pow5( const X_:Int64u ) :Int64u;
begin
     Result := Pow4( X_ ) * X_;
end;

function Pow5( const X_:Int64s ) :Int64s;
begin
     Result := Pow4( X_ ) * X_;
end;

function Pow5( const X_:Single ) :Single;
begin
     Result := Pow4( X_ ) * X_;
end;

function Pow5( const X_:Double ) :Double;
begin
     Result := Pow4( X_ ) * X_;
end;

//------------------------------------------------------------------------------

function Roo2( const X_:Single ) :Single;
begin
     Result := Sqrt( X_ );
end;

function Roo2( const X_:Double ) :Double;
begin
     Result := Sqrt( X_ );
end;

//------------------------------------------------------------------------------

function Roo3( const X_:Single ) :Single;
begin
     Result := Sign( X_ ) * Power( Abs( X_ ), 1/3 );
end;

function Roo3( const X_:Double ) :Double;
begin
     Result := Sign( X_ ) * Power( Abs( X_ ), 1/3 );
end;

//------------------------------------------------------------------------------

function Clamp( const X_,Min_,Max_:Integer ) :Integer;
begin
     if X_ < Min_ then Result := Min_
                  else
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

function Clamp( const X_,Min_,Max_:Single ) :Single;
begin
     if X_ < Min_ then Result := Min_
                  else
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

function Clamp( const X_,Min_,Max_:Double ) :Double;
begin
     if X_ < Min_ then Result := Min_
                  else
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

//------------------------------------------------------------------------------

function ClampMin( const X_,Min_:Integer ) :Integer;
begin
     if X_ < Min_ then Result := Min_
                  else Result := X_;
end;

function ClampMin( const X_,Min_:Single ) :Single;
begin
     if X_ < Min_ then Result := Min_
                  else Result := X_;
end;

function ClampMin( const X_,Min_:Double ) :Double;
begin
     if X_ < Min_ then Result := Min_
                  else Result := X_;
end;

//------------------------------------------------------------------------------

function ClampMax( const X_,Max_:Integer ) :Integer;
begin
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

function ClampMax( const X_,Max_:Single ) :Single;
begin
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

function ClampMax( const X_,Max_:Double ) :Double;
begin
     if Max_ < X_ then Result := Max_
                  else Result := X_;
end;

//------------------------------------------------------------------------------

function Min( const A_,B_,C_:Integer ) :Integer;
begin
     if A_ <= B_ then
     begin
          if A_ <= C_ then Result := A_ else Result := C_;
     end
     else
     begin
          if B_ <= C_ then Result := B_ else Result := C_;
     end;
end;

function Min( const A_,B_,C_:Single ) :Single;
begin
     if A_ <= B_ then
     begin
          if A_ <= C_ then Result := A_ else Result := C_;
     end
     else
     begin
          if B_ <= C_ then Result := B_ else Result := C_;
     end;
end;

function Min( const A_,B_,C_:Double ) :Double;
begin
     if A_ <= B_ then
     begin
          if A_ <= C_ then Result := A_ else Result := C_;
     end
     else
     begin
          if B_ <= C_ then Result := B_ else Result := C_;
     end;
end;

//------------------------------------------------------------------------------

function Max( const A_,B_,C_:Integer ) :Integer;
begin
     if A_ >= B_ then
     begin
          if A_ >= C_ then Result := A_ else Result := C_;
     end
     else
     begin

          if B_ >= C_ then Result := B_ else Result := C_;
     end;
end;

function Max( const A_,B_,C_:Single ) :Single;
begin
     if A_ >= B_ then
     begin
          if A_ >= C_ then Result := A_ else Result := C_;
     end
     else
     begin

          if B_ >= C_ then Result := B_ else Result := C_;
     end;
end;

function Max( const A_,B_,C_:Double ) :Double;
begin
     if A_ >= B_ then
     begin
          if A_ >= C_ then Result := A_ else Result := C_;
     end
     else
     begin
          if B_ >= C_ then Result := B_ else Result := C_;
     end;
end;

//------------------------------------------------------------------------------

function MinI( const V1_,V2_:Integer ) :Byte;
begin
     if V1_ <= V2_ then Result := 1 else Result := 2;
end;

function MinI( const V1_,V2_:Single ) :Byte;
begin
     if V1_ <= V2_ then Result := 1 else Result := 2;
end;

function MinI( const V1_,V2_:Double ) :Byte;
begin
     if V1_ <= V2_ then Result := 1 else Result := 2;
end;

//------------------------------------------------------------------------------

function MaxI( const V1_,V2_:Integer ) :Byte;
begin
     if V1_ <= V2_ then Result := 2 else Result := 1;
end;

function MaxI( const V1_,V2_:Single ) :Byte;
begin
     if V1_ <= V2_ then Result := 2 else Result := 1;
end;

function MaxI( const V1_,V2_:Double ) :Byte;
begin
     if V1_ <= V2_ then Result := 2 else Result := 1;
end;

//------------------------------------------------------------------------------

function MinI( const V1_,V2_,V3_:Integer ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ <= V3_ then Result := 2 else Result := 3;
     end;
end;

function MinI( const V1_,V2_,V3_:Single ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ <= V3_ then Result := 2 else Result := 3;
     end;
end;

function MinI( const V1_,V2_,V3_:Double ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ <= V3_ then Result := 2 else Result := 3;
     end;
end;

//------------------------------------------------------------------------------

function MinI( const V1_,V2_,V3_,V4_:Integer ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then
          begin
               if V1_ <= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ <= V3_ then
          begin
               if V2_ <= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

function MinI( const V1_,V2_,V3_,V4_:Single ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then
          begin
               if V1_ <= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ <= V3_ then
          begin
               if V2_ <= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

function MinI( const V1_,V2_,V3_,V4_:Double ) :Integer;
begin
     if V1_ <= V2_ then
     begin
          if V1_ <= V3_ then
          begin
               if V1_ <= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ <= V3_ then
          begin
               if V2_ <= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ <= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

//------------------------------------------------------------------------------

function MaxI( const V1_,V2_,V3_:Integer ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ >= V3_ then Result := 2 else Result := 3;
     end;
end;

function MaxI( const V1_,V2_,V3_:Single ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ >= V3_ then Result := 2 else Result := 3;
     end;
end;

function MaxI( const V1_,V2_,V3_:Double ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then Result := 1 else Result := 3;
     end
     else
     begin
          if V2_ >= V3_ then Result := 2 else Result := 3;
     end;
end;

//------------------------------------------------------------------------------

function MaxI( const V1_,V2_,V3_,V4_:Integer ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then
          begin
               if V1_ >= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ >= V3_ then
          begin
               if V2_ >= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

function MaxI( const V1_,V2_,V3_,V4_:Single ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then
          begin
               if V1_ >= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ >= V3_ then
          begin
               if V2_ >= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

function MaxI( const V1_,V2_,V3_,V4_:Double ) :Integer;
begin
     if V1_ >= V2_ then
     begin
          if V1_ >= V3_ then
          begin
               if V1_ >= V4_ then Result := 1 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end
     else
     begin
          if V2_ >= V3_ then
          begin
               if V2_ >= V4_ then Result := 2 else Result := 4;
          end
          else
          begin
               if V3_ >= V4_ then Result := 3 else Result := 4;
          end;
     end;
end;

//------------------------------------------------------------------------------

function MinI( const Vs_:array of Integer ) :Integer;
var
   I, V0, V1 :Integer;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 < V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

function MinI( const Vs_:array of Single ) :Integer;
var
   I :Integer;
   V0, V1 :Single;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 < V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

function MinI( const Vs_:array of Double ) :Integer;
var
   I :Integer;
   V0, V1 :Double;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 < V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

//------------------------------------------------------------------------------

function MaxI( const Vs_:array of Integer ) :Integer;
var
   I, V0, V1 :Integer;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 > V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

function MaxI( const Vs_:array of Single ) :Integer;
var
   I :Integer;
   V0, V1 :Single;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 > V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

function MaxI( const Vs_:array of Double ) :Integer;
var
   I :Integer;
   V0, V1 :Double;
begin
     Result := 0;  V0 := Vs_[ 0 ];

     for I := 1 to High( Vs_ ) do
     begin
          V1 := Vs_[ I ];

          if V1 > V0 then
          begin
               Result := I;  V0 := V1;
          end
     end
end;

//------------------------------------------------------------------------------

function PoMod( const X_,Range_:Integer ) :Integer;
begin
     Result := X_ - ( X_ div Range_ ) * Range_;

     if Result < 0 then Inc( Result, Range_ );
end;

function PoMod( const X_,Range_:Int64 ) :Int64;
begin
     Result := X_ - ( X_ div Range_ ) * Range_;

     if Result < 0 then Inc( Result, Range_ );
end;

//------------------------------------------------------------------------------

{$IF Defined( MACOS ) or Defined( MSWINDOWS ) }

function RevBytes( const Value_:Word ) :Word;
asm
{$IFDEF CPUX64 }
   mov rax, rcx
{$ENDIF}
   xchg al, ah
end;

function RevBytes( const Value_:Smallint ) :Smallint;
asm
{$IFDEF CPUX64 }
   mov rax, rcx
{$ENDIF}
   xchg al, ah
end;

//------------------------------------------------------------------------------

function RevBytes( const Value_:Cardinal ) :Cardinal;
asm
{$IFDEF CPUX64 }
   mov rax, rcx
{$ENDIF}
   bswap eax
end;

function RevBytes( const Value_:Integer ) :Integer;
asm
{$IFDEF CPUX64 }
   mov rax, rcx
{$ENDIF}
   bswap eax
end;

function RevBytes( const Value_:Single ) :Single;
var
   V :Cardinal;
begin
     V := RevBytes( PCardinal( @Value_ )^ );

     Result := PSingle( @V )^;
end;

//------------------------------------------------------------------------------

function RevBytes( const Value_:UInt64 ) :UInt64;
asm
{$IF Defined( CPUX86 ) }
   mov   edx, [ ebp + $08 ]
   mov   eax, [ ebp + $0c ]
   bswap edx
   bswap eax
{$ELSEIF Defined( CPUX64 ) }
   mov   rax, rcx
   bswap rax
{$ELSE}
   {$Message Fatal 'RevByte has not been implemented for this architecture.' }
{$ENDIF}
end;

function RevBytes( const Value_:Int64 ) :Int64;
asm
{$IF Defined( CPUX86 ) }
   mov   edx, [ ebp + $08 ]
   mov   eax, [ ebp + $0c ]
   bswap edx
   bswap eax
{$ELSEIF Defined( CPUX64 ) }
   mov   rax, rcx
   bswap rax
{$ELSE}
   {$Message Fatal 'RevByte has not been implemented for this architecture.' }
{$ENDIF}
end;

function RevBytes( const Value_:Double ) :Double;
var
   V :UInt64;
begin
     V := RevBytes( PUInt64( @Value_ )^ );

     Result := PDouble( @V )^;
end;

{$ENDIF}

//------------------------------------------------------------------------------

{$IF Defined( MACOS ) or Defined( MSWINDOWS ) }

function CharsToStr( const Cs_:TArray<AnsiChar> ) :AnsiString;
var
   I :Integer;
begin
     Result := '';

     for I := 0 to High( Cs_ ) do
     begin
          if Cs_[ I ] = Char(nil) then Result := Result + CRLF
                                  else Result := Result + Cs_[ I ];
     end;
end;

{$ENDIF}

//------------------------------------------------------------------------------

function FileToBytes( const FileName_:string ) :TBytes;
begin
     with TMemoryStream.Create do
     begin
          try
             LoadFromFile( FileName_ );

             SetLength( Result, Size );

             Read( Result, Size );

          finally
                 Free;
          end;
     end;
end;

//------------------------------------------------------------------------------

function Comb( N_,K_:Cardinal ) :UInt64;
var
   I :Cardinal;
begin
     if N_ < 2 * K_ then K_ := N_ - K_;

     Result := 1;

     for I := 1 to K_ do
     begin
          //Result := Result * ( N_ - K_ + I ) div I;

          Result := Result * N_ div I;  Dec( N_ );
     end;
end;

//------------------------------------------------------------------------------

function BinPow( const N_:Integer ) :Integer;
begin
     Result := 1 shl N_;
end;

function BinPow( const N_:Cardinal ) :Cardinal;
begin
     Result := 1 shl N_;
end;

function BinPow( const N_:Int64 ) :Int64;
begin
     Result := 1 shl N_;
end;

function BinPow( const N_:UInt64 ) :UInt64;
begin
     Result := 1 shl N_;
end;

//------------------------------------------------------------------------------

function UIntToStr( const Value_:Uint32; const N_:Integer; const C_:Char = '0' ) :String;
begin
     Result := UIntToStr( Value_ );

     Result := Result.Insert( 0, StringOfChar( C_, N_ - Length( Result ) ) );
end;

function UIntToStr( const Value_:UInt64; const N_:Integer; const C_:Char = '0' ) :String;
begin
     Result := UIntToStr( Value_ );

     Result := Result.Insert( 0, StringOfChar( C_, N_ - Length( Result ) ) );
end;

//------------------------------------------------------------------------------

function IntToStr( const Value_:Integer; const N_:Integer; const C_:Char = '0' ) :String;
var
   I :Integer;
begin
     Result := IntToStr( Value_ );

     if Value_ < 0 then I := 1
                   else I := 0;

     Result := Result.Insert( I, StringOfChar( C_, N_ + I - Length( Result ) ) );
end;

function IntToStr( const Value_:Int64; const N_:Integer; const C_:Char = '0' ) :String;
var
   I :Integer;
begin
     Result := IntToStr( Value_ );

     if Value_ < 0 then I := 1
                   else I := 0;

     Result := Result.Insert( I, StringOfChar( C_, N_ + I - Length( Result ) ) );
end;

function IntToStrP( const Value_:Integer; const N_:Integer; const C_:Char = '0' ) :String;
begin
     Result := IntToStr( Value_, N_, C_ );

     if Value_ > 0 then Result := '+' + Result;
end;

function IntToStrP( const Value_:Int64; const N_:Integer; const C_:Char = '0' ) :String;
begin
     Result := IntToStr( Value_, N_, C_ );

     if Value_ > 0 then Result := '+' + Result;
end;

//------------------------------------------------------------------------------

procedure _SplitME( const Value_:String; out Man_,Exp_:String );
var
   I :Integer;
begin
     I := Value_.IndexOf( 'E' );

     Man_ := Value_.Substring( 0, I ).TrimRight( [ '0' ] );
     Exp_ := Value_.Substring( I+1 );
end;

function FloatToStr( const Value_:Single; const N_:Integer; out Man_,Exp_:String ) :Boolean;
begin
     Result := not ( Value_.IsNan or Value_.IsInfinity );

     if Result then _SplitME( FloatToStrF( Value_, TFloatFormat.ffExponent, N_, 0 ), Man_,Exp_ );
end;

function FloatToStr( const Value_:Double; const N_:Integer; out Man_,Exp_:String ) :Boolean;
begin
     Result := not ( Value_.IsNan or Value_.IsInfinity );

     if Result then _SplitME( FloatToStrF( Value_, TFloatFormat.ffExponent, N_, 0 ), Man_,Exp_ );
end;

//------------------------------------------------------------------------------

function _DecN( const Man_,Exp_:String ) :Integer;
var
   M, E :Integer;
begin
     if Man_.Chars[ 0 ] = '-' then M := Man_.Length - 3
                              else M := Man_.Length - 2;

     E := Exp_.ToInteger;

     Result := M - E;

     if Result <= 0 then Result := -E-1;
end;

function FloatToStr( const Value_:Single; const N_:Integer; out Man_,Exp_:String; out DecN_:Integer ) :Boolean;
begin
     Result := FloatToStr( Value_, N_, Man_, Exp_ );

     if Result then DecN_ := _DecN( Man_, Exp_ );
end;

function FloatToStr( const Value_:Double; const N_:Integer; out Man_,Exp_:String; out DecN_:Integer ) :Boolean;
begin
     Result := FloatToStr( Value_, N_, Man_, Exp_ );

     if Result then DecN_ := _DecN( Man_, Exp_ );
end;

//------------------------------------------------------------------------------

function _TestFloatToStr_Single( const Value_:String; const N_:Integer ) :String;
var
   Zs, S0, S :String;
   I :Integer;
begin
     Zs := StringOfChar( '0', N_+1 );

     S0 := Zs + Value_ + Zs;

     for I := 1 to Length( S0 )-1 do
     begin
          S := S0;  S.Insert( I, '.' );

          Result := Result + S + '	' + FloatToStr( S.ToSingle, N_ ) + CRLF;
     end;
end;

function _TestFloatToStr_Double( const Value_:String; const N_:Integer ) :String;
var
   Zs, S0, S :String;
   I :Integer;
begin
     Zs := StringOfChar( '0', N_+1 );

     S0 := Zs + Value_ + Zs;

     for I := 1 to Length( S0 )-1 do
     begin
          S := S0;  S.Insert( I, '.' );

          Result := Result + S + '	' + FloatToStr( S.ToDouble, N_ ) + CRLF;
     end;
end;

//------------------------------------------------------------------------------

function FloatToStr( const Value_:Single; const N_:Integer ) :String;
var
   M, E :String;
   D :Integer;
begin
     if FloatToStr( Value_, N_, M, E, D ) then
     begin
          if Abs( D ) <= N_ then Result := FloatToStrF( Value_, TFloatFormat.ffFixed, N_, ClampMin( D, 0 ) )
                            else Result := M + 'e' + E;
     end
     else
     if Value_.IsNan              then Result :=  'NAN'
                                  else
     if Value_.IsNegativeInfinity then Result := '-INF'
                                  else
     if Value_.IsPositiveInfinity then Result := '+INF';
end;

function FloatToStr( const Value_:Double; const N_:Integer ) :String;
var
   M, E :String;
   D :Integer;
begin
     if FloatToStr( Value_, N_, M, E, D ) then
     begin
          if Abs( D ) <= N_ then Result := FloatToStrF( Value_, TFloatFormat.ffFixed, N_, ClampMin( D, 0 ) )
                            else Result := M + 'e' + E;
     end
     else
     if Value_.IsNan              then Result :=  'NAN'
                                  else
     if Value_.IsNegativeInfinity then Result := '-INF'
                                  else
     if Value_.IsPositiveInfinity then Result := '+INF';
end;

function FloatToStrP( const Value_:Single; const N_:Integer ) :String;
begin
     Result := FloatToStr( Value_, N_ );

     if Value_ > 0 then Result := '+' + Result;
end;

function FloatToStrP( const Value_:Double; const N_:Integer ) :String;
begin
     Result := FloatToStr( Value_, N_ );

     if Value_ > 0 then Result := '+' + Result;
end;

//------------------------------------------------------------------------------

function Floor( const X_,D_:UInt32 ) :UInt32;
begin
     Result := X_ div D_ * D_;
end;

function Floor( const X_,D_:UInt64 ) :UInt64;
begin
     Result := X_ div D_ * D_;
end;

//------------------------------------------------------------------------------

function Ceil( const X_,D_:UInt32 ) :UInt32;
begin
     Result := Floor( X_ + D_ - 1, D_ );
end;

function Ceil( const X_,D_:UInt64 ) :UInt64;
begin
     Result := Floor( X_ + D_ - 1, D_ );
end;

//------------------------------------------------------------------------------

function Floor2N( const X_,D_:UInt32 ) :UInt32;
begin
     Result := X_ and not ( D_ - 1 );
end;

function Floor2N( const X_,D_:UInt64 ) :UInt64;
begin
     Result := X_ and not ( D_ - 1 );
end;

//------------------------------------------------------------------------------

function Ceil2N( const X_,D_:UInt32 ) :UInt32;
begin
     Result := Floor( X_ + D_ - 1, D_ );
end;

function Ceil2N( const X_,D_:UInt64 ) :UInt64;
begin
     Result := Floor( X_ + D_ - 1, D_ );
end;

//------------------------------------------------------------------------------

procedure GetMemAligned( out P_:Pointer; const Size_,Align2N_:UInt32 );
const
     H :UInt32 = SizeOf( Pointer );
var
   P0 :Pointer;
   PP :PPointer;
   I0, I1 :NativeUInt;
begin
     //  ┠───Ａ───╂────────Ｓ────────┤
     //  ┃              ┃                                  │
     //  ┃  │I0        ┃              ┃              ┃  │      │  ┃
     //  ╂─├─┬─┬─┣━┯━┯━┯━╋━┯━┯━┯━╋━┥─┬─┤─╂
     //  ┃  │×│×│I0┃◯│◯│◯│◯┃◯│◯│◯│◯┃◯│×│×│  ┃
     //  ╂─├─┴─┴─┣━┷━┷━┷━╋━┷━┷━┷━╋━┥─┴─┤─╂
     //  ┃  │  │      ┃I1    │      ┃              ┃          │  ┃
     //      │  │              │                                  │
     //      ├Ｈ┼───Ａ───┼────────Ｓ────────┤

     GetMem( P0, H + Align2N_ + Size_ );

     I0 := NativeUInt( P0 );

     I1 := Ceil2N( H + I0, Align2N_ );

     P_ := Pointer( I1 );

     PP := P_;  Dec( PP );  PP^ := P0;
end;

procedure FreeMemAligned( const P_:Pointer );
var
   PP :PPointer;
begin
     PP := P_;  Dec( PP );  FreeMem( PP^ );
end;

initialization //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

     Randomize;

     SetCurrentDir( ExtractFilePath( ParamStr( 0 ) ) );

finalization //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

end. //######################################################################### ■
