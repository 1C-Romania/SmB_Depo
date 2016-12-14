#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnCopy(CopiedObject)
	
	Code = "";
	
EndProcedure // OnCopy()

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
			
	If Not IsFolder Then
	
		If ValueIsFilled(CorrAccount) AND StrLen(TrimAll(CorrAccount)) <> 20 Then
			MessageText = NStr("en='Corr.bank account must consist of 20 characters.';ru='Корр.счета банка должен иметь 20 знаков.'");
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
			MessageText = NStr("en='The Corr.account must consist of digits only.';ru='В составе Корр.счета банка должны быть только цифры.'");
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				,
				,
				"CorrAccount",
				Cancel
			);
		EndIf;
		
		If StrLen(TrimAll(Code)) <> 8 AND StrLen(TrimAll(Code)) <> 11 Then
			MessageText = NStr("en='SWIFT must have 8 or 11 symbols.';ru='SWIFT банка должен иметь 8 или 11 знаков.'");
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

#EndRegion

#EndIf