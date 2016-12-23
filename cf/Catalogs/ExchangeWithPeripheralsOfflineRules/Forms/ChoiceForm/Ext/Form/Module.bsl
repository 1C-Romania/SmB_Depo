
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonUseClientServer.SetFilterItem(List.Filter, "PeripheralsType", Parameters.PeripheralsType, DataCompositionComparisonType.Equal,, ValueIsFilled(Parameters.PeripheralsType));
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.PrintCommandGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion













