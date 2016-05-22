
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillingValues = New Structure;
	FillingValues.Insert("OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.JobOrder"));
	OpenParameters = New Structure;
	OpenParameters.Insert("FillingValues", FillingValues);
	OpenForm("Document.CustomerOrder.ObjectForm", OpenParameters);
	
EndProcedure
