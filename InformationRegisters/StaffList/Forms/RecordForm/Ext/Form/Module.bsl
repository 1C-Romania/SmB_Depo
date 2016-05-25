
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
