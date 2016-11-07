
&AtServer
Procedure GetFillParameters(FillStructure)
	
	FillStructure.Insert("Contract", FillStructure.Counterparty.ContractByDefault);
	FillStructure.Insert("OperationKind", Enums.OperationKindsCustomerOrder.JobOrder);
	FillStructure.Insert("IsFolder", FillStructure.Counterparty.IsFolder);
	
EndProcedure

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)

	If Not ValueIsFilled(CommandParameter) Then
		Return;
	EndIf;
	
	FillStructure = New Structure();
	FillStructure.Insert("Counterparty", CommandParameter);
	GetFillParameters(FillStructure);
	
	If FillStructure.IsFolder Then
		Raise NStr("en='Unable to select counterparty group.';ru='Нельзя выбирать группу контрагентов.'");
	EndIf;
	
	OpenForm("Document.CustomerOrder.ObjectForm", New Structure("FillingValues", FillStructure));
	
EndProcedure
