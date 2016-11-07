&AtServer
// Returns cash assets type
//
Function GetCashAssetsType(DocumentRef)
	
	Return DocumentRef.CashAssetsType;
	
EndFunction // GetCashAssetsType()

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure("BasisDocument", CommandParameter);
	CashAssetsType = GetCashAssetsType(CommandParameter);
	
	If Not ValueIsFilled(CashAssetsType) Then
		OpenForm("CommonForm.CashAssetsTypesForm",,,,,, New NotifyDescription("CommandDataProcessorEnd", ThisObject, New Structure("Parameters", Parameters)));
		Return;
	EndIf;
	
	CommandDataProcessorFragment(Parameters, CashAssetsType);
EndProcedure

&AtClient
Procedure CommandDataProcessorEnd(Result, AdditionalParameters) Export
	
	Parameters = AdditionalParameters.Parameters;
	
	
	CashAssetsType = Result;
	
	CommandDataProcessorFragment(Parameters, CashAssetsType);

EndProcedure

&AtClient
Procedure CommandDataProcessorFragment(Val Parameters, Val CashAssetsType)
	
	If CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashPayment.ObjectForm", Parameters);
	ElsIf CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		OpenForm("Document.PaymentExpense.ObjectForm", Parameters);
	EndIf;
	
EndProcedure
 // CommandProcessing()
