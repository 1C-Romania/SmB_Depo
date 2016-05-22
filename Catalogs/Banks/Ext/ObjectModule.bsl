#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler "OnCopy".
//
Procedure OnCopy(CopiedObject)
	
	Code = "";
	
EndProcedure // OnCopy()

// Procedure - "FillCheckProcessing" event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
			
	If Not IsFolder Then
	
		If ValueIsFilled(CorrAccount) AND StrLen(TrimAll(CorrAccount)) <> 20 Then
			MessageText = NStr("en = 'Corr.bank account must consist of 20 characters.'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"CorrAccount",
				Cancel
			);			
		EndIf;
		
		If ValueIsFilled(CorrAccount) AND Not StringFunctionsClientServer.OnlyNumbersInString(TrimAll(CorrAccount)) Then
			MessageText = NStr("en = 'The Corr.account must consist of digits only.'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"CorrAccount",
				Cancel
			);
		EndIf;
		
		If StrLen(TrimAll(Code)) <> 9 Then
			MessageText = NStr("en = 'Bank BIN must have 9 symbols.'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Code",
				Cancel
			);
		EndIf;

		If Not StringFunctionsClientServer.OnlyNumbersInString(TrimAll(Code)) Then
			MessageText = NStr("en = 'BIN must contain only digits.'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"Code",
				Cancel
			);
		EndIf;
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Code");
		
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndIf