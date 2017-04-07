
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	List.Parameters.SetParameterValue("ThisNode", ExchangePlans.ExchangeSmallBusinessSite.ThisNode());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ExchangeWithSiteSessionFinished" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Copy Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("CallPlanOfExchange", True);
	
	OpenForm("DataProcessor.DataExchangeWithSiteCreationAssistant.Form.Form", FormParameters, ThisForm);
	
EndProcedure



