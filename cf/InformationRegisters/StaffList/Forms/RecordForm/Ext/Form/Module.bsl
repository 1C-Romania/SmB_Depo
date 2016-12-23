
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		
		Items.Company.Visible = False;
		Record.Company = Constants.SubsidiaryCompany.Get();
		
	EndIf;
	
EndProcedure














