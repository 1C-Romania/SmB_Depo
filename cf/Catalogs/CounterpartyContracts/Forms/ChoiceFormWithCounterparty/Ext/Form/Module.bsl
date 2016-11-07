
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not SmallBusinessreuse.CounterpartyContractsControlNeeded() Then
		
		Items.ListCompanies.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, ThisForm.CommandBar);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	Close(Value);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List.CurrentData);
EndProcedure
// End StandardSubsystems.Printing


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
