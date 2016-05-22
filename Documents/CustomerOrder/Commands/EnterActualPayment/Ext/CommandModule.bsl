
&AtServer
Function GetCashAssetsType(DocumentRef)
	
	Return DocumentRef.CashAssetsType;
	
EndFunction // GetCashAssetsType()

&AtClient
// Procedure of command data processor.
//
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CashAssetsType = GetCashAssetsType(CommandParameter);
	
	If CommandExecuteParameters.Source.Items.Find("PaymentCalendar") <> Undefined Then
		
		If CommandExecuteParameters.Source.Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.JobOrder") Then
			PaymentCalendarCurrentString = CommandExecuteParameters.Source.Items.ValPaymentCalendar.CurrentData;
		Else
			PaymentCalendarCurrentString = CommandExecuteParameters.Source.Items.PaymentCalendar.CurrentData;
		EndIf; 
		
		
		If PaymentCalendarCurrentString <> Undefined Then
			
			FillStructure = New Structure();
			FillStructure.Insert("Basis", CommandExecuteParameters.Source.Object.Ref);
			FillStructure.Insert("LineNumber", PaymentCalendarCurrentString.LineNumber);
			Parameters = New Structure("Basis", FillStructure);
			
		Else
			
			Parameters = New Structure("BasisDocument", CommandParameter);
			
		EndIf;
		
	Else
		
		Parameters = New Structure("BasisDocument", CommandParameter);
		
	EndIf;
	
	If CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		
		OpenForm("Document.CashReceipt.ObjectForm", Parameters);
		
	Else
		
		OpenForm("Document.PaymentReceipt.ObjectForm", Parameters);
		
	EndIf;
	
EndProcedure // CommandProcessing()
