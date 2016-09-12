
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ReadOnly = True;
	EndIf;
	
	CanUpdateClassifier =
		Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode()   // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.RFBankClassifier); // User with the required rights.

	Items.FormImportClassifier.Visible = CanUpdateClassifier;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportClassifier(Command)
	FormParameters = New Structure("OpenFromList");
	OpenForm("Catalog.RFBankClassifier.Form.ImportClassifier", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	CommonUseClientServer.MessageToUser(
		NStr("en='Interactive adding to the classifier is not supported."
"Use command ""Import classifier""';ru='Интерактивное добавление в классификатор не поддерживается."
"Воспользуйтесь командой ""Загрузить классификатор""'"));
	
EndProcedure

#EndRegion


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
