////////////////////////////////////////////////////////////////////////////////
// Client events of the report form
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Decryption handler of the tabular document of the report form.
//
// Parameters:
//   ReportForm - ManagedForm - Report form.
//   Item     - FormField        - Tabular document.
//   Details          - Passed from the handler parameters "as is."
//   StandardProcessing - Passed from the handler parameters "as is."
//
// See also:
//   Extension of the form field for a field of tabular document.DecryptionProcessing in syntax helper.
//
Procedure DetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	
	SmallBusinessReportsClient.DetailProcessing(ReportForm, Item, Details, StandardProcessing);
	
EndProcedure

// Handler of the additional decryption (menu of the tabular document of report form).
//
// Parameters:
//   ReportForm - ManagedForm - Report form.
//   Item     - FormField        - Tabular document.
//   Details          - Passed from the handler parameters "as is."
//   StandardProcessing - Passed from the handler parameters "as is."
//
// See also:
//   Extension of the form field for a field of tabular document.AdditionalDecryptionProcessing in syntax helper.
//
Procedure AdditionalDetailProcessing(ReportForm, Item, Details, StandardProcessing) Export
	
EndProcedure

// Handler of the commands dynamically added and connected to the Attachable_Command handler.
//
// Parameters:
//   ReportForm - ManagedForm - Report form.
//   Command     - FormCommand     - Called command.
//   Result   - Boolean           - True if the command call was not processed.
//
// Auxiliary methods:
//   CommonForm.ReportForm.ExecuteContextServerCall() -> ReportsOverridable.ContextServerCall().
//
Procedure CommandHandler(ReportForm, Command, Result) Export
	
EndProcedure

// Result of the subordinate form selection handler.
//
// Parameters:
//   ReportForm       - ManagedForm - Report form.
//   ValueSelected - Random value - Selection result in the subordinate form.
//   ChoiceSource    - ManagedForm - Form in which the selection is run.
//   Result         - Boolean           - True if the selection result was processed.
//
// See also:
//   ManagedForm.SelectionProcessing in syntax helper.
//
Procedure ChoiceProcessing(ReportForm, ValueSelected, ChoiceSource, Result) Export
	
EndProcedure

// Broadcast alert of report form handler.
//
// Parameters:
//   ReportForm - ManagedForm - Report form.
//   EventName  - Passed from the handler parameters "as is."
//   Parameter    - Passed from the handler parameters "as is."
//   Source    - Passed from the handler parameters "as is."
//
// See also:
//   ManagedForm.NotificationProcessing in syntax helper.
//
Procedure NotificationProcessing(ReportForm, EventName, Parameter, Source, NotificationProcessed) Export
	
EndProcedure

#EndRegion
