#Region FormEventsHandlers
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess() Then
		ReadOnly = True;
	EndIf;
	
	CloseOnElementChoice = Parameters.CloseOnChoice; // SB
	
	CanUpdateClassifier =
		Not CommonUseReUse.DataSeparationEnabled() // Updated automatically in the service model.
		AND Not CommonUse.IsSubordinateDIBNode()   // Updated automatically in DIB node.
		AND AccessRight("Update", Metadata.Catalogs.RFBankClassifier); // User with the required rights.

	Items.FormImportClassifier.Visible = CanUpdateClassifier;
	
	SwitchVisibleInactiveBanks(False);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ImportClassifier(Command)
	OpenForm("Catalog.RFBankClassifier.Form.ImportClassifier", , ThisObject);
EndProcedure

&AtClient
Procedure ShowInactiveBanks(Command)
	SwitchVisibleInactiveBanks(NOT Items.FormShowInactiveBanks.Check);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SwitchVisibleInactiveBanks(Visible)
	
	Items.FormShowInactiveBanks.Check = Visible;
	
	CommonUseClientServer.SetFilterDynamicListItem(
			List, "ActivityDiscontinued", False, , , Not Visible);
			
EndProcedure

 ////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtServer
Procedure BankClassificatorSelection(Refs)
	
	WorkWithBanksOverridable.BankClassificatorSelection(Refs);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessSelection(SelectedRow, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	ProcessSelection(Value, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ProcessSelection(SelectedRows, StandardProcessing)
	
	If TypeOf(SelectedRows) <> Type("Array") Then
		Return;
	EndIf;
	
	StandardProcessing = CloseOnElementChoice; // SB
	
	Refs = New Array;
	For Each Ref IN SelectedRows Do
		If Items.List.RowData(Ref).IsFolder Then
			Continue;
		EndIf;
		
		Refs.Add(Ref);
	EndDo;
	
	If Refs.Count() > 0 Then
		BankClassificatorSelection(Refs);
		Notify("RefreshAfterAdd");
	EndIf;
	
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
