////////////////////////////////////////////////////////////////////////////////
// Determine if there are rights to work with the counterparties checking mechanism
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

Function HasRightOnSettingsEditing() Export
	
	Return Users.RolesAvailable("SystemAdministrator");
	
EndFunction

Function HasRightOnCheckingUsage() Export
	
	Return Users.RolesAvailable("SBBasicRights");
	
EndFunction

Procedure GetDataForCheckingCounterpartiesInTabularSectionRow(Form, TabularSectionName, RowSource, RowReceiver) Export
	
	
	
EndProcedure

Procedure InitializeCheckedCounterpartiesData(Form, CounterpartiesData) Export
	
	
	
EndProcedure

Procedure DefineAtLeastOneCounterpartyInCustomerInvoiceNotePresence(InvoiceObject, CounterpartyFilled) Export
	
	
	
EndProcedure

Procedure DrawCounterpartyInDocumentStates(Form, CheckingState, Item = Undefined) Export
	
	
	
EndProcedure

Procedure CheckChangeCounterpartiesInCustomerInvoiceNote(NewCustomerInvoiceNote, PreviousCustomerInvoiceNote, CounterpartiesChanged) Export
	
	
	
EndProcedure

Procedure RememberCounterpartiesCheckResult(Form, CounterpartiesData) Export
	
	
	
EndProcedure

Procedure DefinePreviousErrorValues(Form) Export
	
	
	
EndProcedure

Procedure DefineCurrentErrorValues(Form) Export
	
	
	
EndProcedure

#EndRegion
