
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each Record IN Parameters.Certificates Do
		NewPage = ListCertificates.Add();
		NewPage.Certificate = Record.Value;
		NewPage.ID = Record.Presentation;
	EndDo
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS <List of certificates>

&AtClient
Procedure ListCertificatesChoice(Item, SelectedRow, Field, StandardProcessing)
	
	Close(Items.ListCertificates.CurrentData.ID);
	
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
