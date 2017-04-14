
&AtServer
Procedure GetFillParameters(FillStructure, CommandParameter)
	
	If CommandParameter.Participants.Count() > 0 AND TypeOf(CommandParameter.Participants[0].Contact) = Type("CatalogRef.Counterparties") Then
		FillStructure.Insert("Counterparty", CommandParameter.Participants[0].Contact);
		FillStructure.Insert("Contract", FillStructure.Counterparty.ContractByDefault);
	EndIf;
	FillStructure.Insert("OperationKind", Enums.OperationKindsCustomerOrder.JobOrder);
	
EndProcedure

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If Not ValueIsFilled(CommandParameter) Then
		Return;
	EndIf;
	
	FillStructure = New Structure();
	GetFillParameters(FillStructure, CommandParameter);
	
	OpenForm("Document.CustomerOrder.ObjectForm", New Structure("FillingValues", FillStructure));
	
EndProcedure
