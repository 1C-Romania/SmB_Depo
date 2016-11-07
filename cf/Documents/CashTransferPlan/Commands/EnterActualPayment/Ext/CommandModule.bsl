
&AtServer
Function GetCashAssetsType(DocumentRef)
	
	Return DocumentRef.CashAssetsType;
	
EndFunction

&AtServer
Function GetCashAssetsTypePayee(DocumentRef)
	
	Return DocumentRef.CashAssetsTypePayee;
	
EndFunction

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Parameters = New Structure("BasisDocument", CommandParameter);
	
	CashAssetsType = GetCashAssetsType(CommandParameter);
	CashAssetsTypePayee = GetCashAssetsTypePayee(CommandParameter);
	
	If CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashPayment.ObjectForm", Parameters);
	Else
		OpenForm("Document.PaymentExpense.ObjectForm", Parameters);
	EndIf;
	
	If CashAssetsTypePayee = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		OpenForm("Document.CashReceipt.ObjectForm", Parameters);
	Else
		OpenForm("Document.PaymentReceipt.ObjectForm", Parameters);
	EndIf;
	
EndProcedure // CommandProcessing()
