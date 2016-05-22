////////////////////////////////////////////////////////////////////////////////
// Reports options subsystem (server)
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Returns a formatted row of the 00,00 format. Fractional part is drawn using a smaller font.
//
// Amount - Number. Number, which is converted in the row
//
// Returns a formatted row.
//
Function AmountFormattedString(Amount) Export
	
	Amount = Format(Amount, "ND=15; NFD=2; NZ=0,00");
	
	SeparatorPosition = Find(Amount, ",");
	
	AmountIntegralPart = Left(Amount, SeparatorPosition);
	FractionalPart	= StrReplace(Amount, AmountIntegralPart, "");
	
	Font14 = New Font(,14);
	Font10 = New Font(,10);
	
	LabelIntegralPart = New FormattedString(AmountIntegralPart, Font14);
	LabelFractionalPart = New FormattedString(FractionalPart, Font10);
	
	A = New Array();
	A.Add(LabelIntegralPart);
	A.Add(LabelFractionalPart);
	
	Return New FormattedString(A); 
	
EndFunction // AmountFormattedString()
