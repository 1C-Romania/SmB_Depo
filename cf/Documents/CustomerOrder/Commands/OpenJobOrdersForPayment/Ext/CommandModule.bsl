
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("OperationKindJobOrder", True);
	OpenForm("Document.CustomerOrder.Form.PaymentDocumentsListForm", OpenParameters, , "JobOrderPaymentDocumentsListForm");
	
EndProcedure
