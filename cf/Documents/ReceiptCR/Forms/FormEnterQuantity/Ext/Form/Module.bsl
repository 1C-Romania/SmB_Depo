
#Region ProceduresFormEventsHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SymbolsCountAfterComma = 3;
	
	Quantity = Parameters.Quantity;
	Price = Parameters.Price;
	Amount = Parameters.Amount;
	DiscountMarkupPercent = Parameters.DiscountMarkupPercent;
	AutomaticDiscountsPercent = Parameters.AutomaticDiscountsPercent;
	ProductsAndServicesCharacteristicAndBatch = Parameters.ProductsAndServicesCharacteristicAndBatch;
	
	// Key combination setting
	For Ct = 0 To 9 Do
		Items["Button"+Ct].Shortcut = New Shortcut(Key["Num"+Ct]);
	EndDo;
	Items.DelimiterFractionalParts.Shortcut = New Shortcut(Key.NumDecimal);
	Items.Reset.Shortcut = New Shortcut(Key.BackSpace);
	
EndProcedure

#EndRegion

#Region ProceduresElementFormEventsHandlers

// Procedure - event handler OnChange item Quantity form.
//
&AtClient
Procedure QuantityOnChange(Item)
	
	AmountWithoutDiscount = Price * Quantity;
	
	// Discounts.
	If AmountWithoutDiscount <> 0 Then
		If DiscountMarkupPercent = 100 Then
			AmountAfterManualDiscountsMarkupsApplication = 0;
		ElsIf DiscountMarkupPercent <> 0 AND Quantity <> 0 Then
			AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount * (1 - (DiscountMarkupPercent) / 100);
		Else
			AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
		EndIf;
	Else
		AmountAfterManualDiscountsMarkupsApplication = AmountWithoutDiscount;
	EndIf;
	
	ManualDiscountAmount = AmountWithoutDiscount - AmountAfterManualDiscountsMarkupsApplication;
	
	If AutomaticDiscountsPercent <> 0 Then
		AutomaticDiscountAmount = AmountWithoutDiscount * AutomaticDiscountsPercent / 100;
	Else
		AutomaticDiscountAmount = 0;
	EndIf;
	DiscountAmount = AutomaticDiscountAmount + ManualDiscountAmount;
	
	Amount = AmountWithoutDiscount - ?(DiscountAmount > AmountWithoutDiscount, AmountWithoutDiscount, DiscountAmount);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure adds the digit right from the entered number. Fractional part divider existence is considered.
//
&AtClient
Procedure AddDigit(EnteredDigitByString)
	
	If FirstEntry Then
		EnteredNumber = "";
		FirstEntry = False;
	EndIf;
	
	Comma = Mid(EnteredNumber, StrLen(EnteredNumber) - SymbolsCountAfterComma, 1);
	
	If Not Comma = "," Then
		EnteredNumber = EnteredNumber + EnteredDigitByString;
	EndIf;
	
	Quantity = LeadStringToNumber(EnteredNumber, True);
	QuantityOnChange(Items.Quantity);
	
EndProcedure

//function executes string reduction
// to number Parameters:
//  NumberByString           - String - String provided
//  to number ReturnUndefined - Boolean - If True and string contains incorrect value that return Undefined
//
// Returns:
//  Number
//
&AtClient
Function LeadStringToNumber(NumberByString, ReturnUndefined = False)
	
	NumberTypeDescription = New TypeDescription("Number");
	NumberValue = NumberTypeDescription.AdjustValue(NumberByString);
	
	If ReturnUndefined AND (NumberValue = 0) Then
		
		Str = String(NumberByString);
		If Str = "" Then
			Return Undefined;
		EndIf;
		
		Str = StrReplace(TrimAll(Str), "0", "");
		If (Str <> "") AND (Str <> ".") AND (Str <> ",") Then
			Return Undefined;
		EndIf;
	EndIf;
	
	Return NumberValue;
	
EndFunction

#EndRegion

#Region FormCommandsHandlers

#Region Calculator

// Procedure - command handler FractionalPartDevider form.
//
&AtClient
Procedure CommandPoint(Command)
	
	If FirstEntry Then
		EnteredNumber = "";
		CurFirstEntry = False;
	EndIf;
	
	If EnteredNumber = "" Then
		EnteredNumber = "0";
	EndIf;
	
	OccurrenceCount = StrOccurrenceCount(EnteredNumber, ",");
	
	If Not OccurrenceCount > 0 Then
		EnteredNumber = EnteredNumber + ",";
	EndIf;
	
EndProcedure

// Procedure - command handler Reset forms.
//
&AtClient
Procedure CommandClear(Command)
	
	EnteredNumber = "";
	FirstEntry = False;
	Quantity = 0;
	QuantityOnChange(Items.Quantity);
	
EndProcedure

// Procedure - command handler Button1 form.
//
&AtClient
Procedure Button1(Command)
	
	AddDigit("1");
	
EndProcedure

// Procedure - command handler Button2 form.
//
&AtClient
Procedure Button2(Command)
	
	AddDigit("2");
	
EndProcedure

// Procedure - command handler Button3 form.
//
&AtClient
Procedure Button3(Command)
	
	AddDigit("3");
	
EndProcedure

// Procedure - command handler Button4 form.
//
&AtClient
Procedure Button4(Command)
	
	AddDigit("4");
	
EndProcedure

// Procedure - command handler Button5 form.
//
&AtClient
Procedure Button5(Command)
	
	AddDigit("5");
	
EndProcedure

// Procedure - command handler Button6 form.
//
&AtClient
Procedure Button6(Command)
	
	AddDigit("6");
	
EndProcedure

// Procedure - command handler Button7 form.
//
&AtClient
Procedure Button7(Command)
	
	AddDigit("7");
	
EndProcedure

// Procedure - command handler Button8 form.
//
&AtClient
Procedure Button8(Command)
	
	AddDigit("8");
	
EndProcedure

// Procedure - command handler Button9 form.
//
&AtClient
Procedure Button9(Command)
	
	AddDigit("9");
	
EndProcedure

// Procedure - command handler Button0 form.
//
&AtClient
Procedure Button0(Command)
	
	AddDigit("0");
	
EndProcedure

#EndRegion

// Procedure - command handler OK form.
//
&AtClient
Procedure OK(Command)
	
	CloseParameters = New Structure("Quantity", Quantity);
	Close(CloseParameters);
	
EndProcedure

#EndRegion













