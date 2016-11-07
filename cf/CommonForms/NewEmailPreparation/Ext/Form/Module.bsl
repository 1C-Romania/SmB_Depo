
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	For Each SavingFormat IN PrintManagement.SpreadsheetDocumentSavingFormatsSettings() Do
		SelectedSavingFormats.Add(SavingFormat.SpreadsheetDocumentFileType, String(SavingFormat.Ref), False, SavingFormat.Picture);
	EndDo;
	
	RecipientsList = Parameters.Recipients;
	If TypeOf(RecipientsList) = Type("String") Then
		FillRecipientsTableFromRow(RecipientsList);
	ElsIf TypeOf(RecipientsList) = Type("ValueList") Then
		FillRecipientsTableFromValuesList(RecipientsList);
	ElsIf TypeOf(RecipientsList) = Type("Array") Then
		FillRecipientsTableFromStructuresArray(RecipientsList);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	SavingFromSettingsFormats = Settings["SelectedSavingFormats"];
	If SavingFromSettingsFormats <> Undefined Then
		For Each SelectedFormat IN SelectedSavingFormats Do 
			FormatFromSettings = SavingFromSettingsFormats.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SelectedSavingFormats");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetFormatChoice();
	GenerateSelectedFormatsPresentation();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.AttachmentFormatSelection") Then
		
		If ValueSelected <> DialogReturnCode.Cancel AND ValueSelected <> Undefined Then
			SetFormatChoice(ValueSelected.SavingFormats);
			PackIntoArchive = ValueSelected.PackIntoArchive;
			GenerateSelectedFormatsPresentation();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Select(Command)
	ChoiceResult = SelectedFormatSettings();
	NotifyChoice(ChoiceResult);
EndProcedure

&AtClient
Procedure SelectAllReceivers(Command)
	SetChoiceForAllRecipients(True);
EndProcedure

&AtClient
Procedure CancelSelectionForAll(Command)
	SetChoiceForAllRecipients(False);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AttachmentsFormatClick(Item, StandardProcessing)
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("FormatSettings", SelectedFormatSettings());
	OpenForm("CommonForm.AttachmentFormatSelection", OpenParameters, ThisObject);
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersRecipients

&AtClient
Procedure RecipientsBeforeRowChange(Item, Cancel)
	Cancel = True;
	Selected = Not Items.Recipients.CurrentData.Selected;
	For Each SelectedRow IN Items.Recipients.SelectedRows Do
		Recipient = Recipients.FindByID(SelectedRow);
		Recipient.Selected = Selected;
	EndDo;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillRecipientsTableFromRow(Val RecipientsList)
	
	RecipientsList = CommonUseClientServer.EmailsFromString(RecipientsList);
	
	For Each Recipient IN RecipientsList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Address;
		NewRecipient.Presentation = Recipient.Alias;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientsTableFromValuesList(RecipientsList)
	
	For Each Recipient IN RecipientsList Do
		NewRecipient = Recipients.Add();
		NewRecipient.Address = Recipient.Value;
		NewRecipient.Presentation = Recipient.Presentation;
		NewRecipient.AddressPresentation = NewRecipient.Address;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientsTableFromStructuresArray(RecipientsList)
	
	For Each Recipient IN RecipientsList Do
		NewRecipient = Recipients.Add();
		FillPropertyValues(NewRecipient, Recipient);
		NewRecipient.AddressPresentation = NewRecipient.Address;
		If Not IsBlankString(Recipient.PostalAddressKind) Then
			NewRecipient.AddressPresentation = NewRecipient.AddressPresentation + " (" + Recipient.PostalAddressKind + ")";
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetFormatChoice(Val SavingFormats = Undefined)
	
	IsSelectedFormat = False;
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SavingFormats <> Undefined Then
			SelectedFormat.Check = SavingFormats.Find(SelectedFormat.Value) <> Undefined;
		EndIf;
			
		If SelectedFormat.Check Then
			IsSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not IsSelectedFormat Then
		SelectedSavingFormats[0].Check = True; // Selection by default - first in list.
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateSelectedFormatsPresentation()
	
	AttachmentsFormat = "";
	QuantityOfFormats = 0;
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(AttachmentsFormat) Then
				AttachmentsFormat = AttachmentsFormat + ", ";
			EndIf;
			AttachmentsFormat = AttachmentsFormat + SelectedFormat.Presentation;
			QuantityOfFormats = QuantityOfFormats + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SavingFormats = New Array;
	
	For Each SelectedFormat IN SelectedSavingFormats Do
		If SelectedFormat.Check Then
			SavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;	
	
	Result = New Structure;
	Result.Insert("PackIntoArchive", PackIntoArchive);
	Result.Insert("SavingFormats", SavingFormats);
	Result.Insert("Recipients", SelectedRecipients());
	
	Return Result;
	
EndFunction

&AtClient
Function SelectedRecipients()
	Result = New Array;
	For Each SelectedRecipient IN Recipients Do
		If SelectedRecipient.Selected Then
			StructureRecipient = New Structure("Address,Presentation,ContactInformationSource,PostalAddressKind");
			FillPropertyValues(StructureRecipient, SelectedRecipient);
			Result.Add(StructureRecipient);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function SetChoiceForAllRecipients(Selection)
	For Each Recipient IN Recipients Do
		Recipient.Selected = Selection;
	EndDo;
EndFunction

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
