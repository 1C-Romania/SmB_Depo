
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

&AtClient
// Procedure - command handler CreateNumberOfCCD
//
Procedure CreateNumberOfCCD(Command)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogNumberCCDOpen");
	// End StandardSubsystems.PerformanceEstimation
	
	OpenForm("Catalog.CCDNumbers.Form.ItemForm");
	
EndProcedure // CreateNumberOfCCD()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM ITEM HANDLERS

// Procedure - event handler Form list choice
//
&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogNumberCCDOpen");
	// End StandardSubsystems.PerformanceEstimation
	
EndProcedure // ListSelection()
