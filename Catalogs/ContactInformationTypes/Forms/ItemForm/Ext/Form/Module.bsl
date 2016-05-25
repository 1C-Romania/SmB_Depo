
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.DisableEditByUser Then
		ReadOnly = True;
	EndIf;
	
	If Object.Predefined Then
		Items.Description.ReadOnly = True;
		Items.Parent.ReadOnly      = True;
		Items.Type.ReadOnly        = True;
		Items.ToolTip.ReadOnly     = True;
	Else
		// Subsystem handler of the objects attributes editing prohibition.
		If CommonUse.SubsystemExists("StandardSubsystems.ObjectsAttributesEditProhibition") Then
			ModuleObjectAttributeEditProhibition = CommonUse.CommonModule("ObjectsAttributesEditProhibition");
			ModuleObjectAttributeEditProhibition.LockAttributes(ThisObject,, NStr("en = 'Allow editing of type and groups'"));
			
		Else
			Items.Parent.ReadOnly = True;
			Items.Type.ReadOnly = True;
			
		EndIf;
	EndIf;
	
	ParentRef = Object.Parent;
	CurrentLevel = ?(ParentRef.IsEmpty(), 0, ParentRef.Level() );
	
	Items.AllowInputOfMultipleValues.Enabled = ?(CurrentLevel = 1, False, True);
	
	If Not Object.EditMethodEditable Then
		Items.EditInDialogOnly.Enabled       = False;
		Items.AllowInputOfMultipleValues.Enabled    = False;
		Items.DescriptionOfFolderSettingsByStyle.Enabled = False;
	EndIf;
	
	CheckByClassifier = ?(Object.CheckByFIAS, 0, 1);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChangeOfRepresentationOnChangeType();
	DisplayEnabledOptionsCheckByClassifier();
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Not CurrentObject.Predefined Then
		// Subsystem handler of the objects attributes editing prohibition.
		If CommonUse.SubsystemExists("StandardSubsystems.ObjectsAttributesEditProhibition") Then
			ModuleObjectAttributeEditProhibition = CommonUse.CommonModule("ObjectsAttributesEditProhibition");
			ModuleObjectAttributeEditProhibition.LockAttributes(ThisObject);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	CheckedAttributes.Clear();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure TypeOnChange(Item)
	
	ChangeAttributesOnChangeType();
	ChangeOfRepresentationOnChangeType();
	
EndProcedure

&AtClient
Procedure TypeClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure AddressRussianOnlyOnChange(Item)
	
	ChangeAttributesOnChangeOnlyRussia();
	ChangeRepresentationOnChangeOnlyRussia();
	
EndProcedure

&AtClient
Procedure ProhibitEntryOfIncorrectOnChange(Item)
	DisplayEnabledOptionsCheckByClassifier();
EndProcedure

&AtClient
Procedure CheckCorrectnessOnChange(Item)
	
	ChangeAttributesOnChangeCheckCorrectness();
	
EndProcedure

&AtClient
Procedure CheckByClassifierOnChange(Item)
	If CheckByClassifier = 0 Then
		Object.CheckByFIAS = True;
		Object.CheckCorrectness = True;
	Else
		Object.CheckByFIAS = False;
		Object.CheckCorrectness = True;
	EndIf;
EndProcedure


#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Attachable_AuthorizeObjectDetailsEditing(Command)
	
	If Not Object.Predefined Then
		If CommonUseClient.SubsystemExists("StandardSubsystems.ObjectsAttributesEditProhibition") Then
			ModuleObjectAttributeEditProhibitionClient = CommonUseClient.CommonModule("ObjectsAttributesEditProhibitionClient");
			ModuleObjectAttributeEditProhibitionClient.AuthorizeObjectDetailsEditing(ThisObject);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ChangeOfRepresentationOnChangeType()
	
	If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Items.Checks.CurrentPage = Items.Checks.ChildItems.Address;
		Items.EditInDialogOnly.Enabled = Object.EditMethodEditable;
		
		ChangeRepresentationOnChangeOnlyRussia();
		
	ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Items.Checks.CurrentPage = Items.Checks.ChildItems.EmailAddress;
		Items.EditInDialogOnly.Enabled = False;
		
	ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or Object.Type = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		Items.Checks.CurrentPage = Items.Checks.ChildItems.Another;
		Items.EditInDialogOnly.Enabled = Object.EditMethodEditable;
		
	Else
		Items.Checks.CurrentPage = Items.Checks.ChildItems.Another;
		Items.EditInDialogOnly.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayEnabledOptionsCheckByClassifier()
	If Object.ProhibitEntryOfIncorrect Then
		Items.CheckByClassifier.Enabled = True;
	Else
		Items.CheckByClassifier.Enabled = False;
	EndIf;
EndProcedure

&AtClient
Procedure ChangeAttributesOnChangeType()
	If Object.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		ChangeAttributesOnChangeOnlyRussia();
		
	ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Object.EditInDialogOnly = False;
		ChangeAttributesOnChangeCheckCorrectness();
		
	ElsIf Object.Type = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or Object.Type = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		// No changes
		
	Else
		Object.EditInDialogOnly = False;

	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeRepresentationOnChangeOnlyRussia()
	
	Items.CheckByClassifier.Enabled   = Object.ProhibitEntryOfIncorrect;
	Items.ProhibitEntryOfIncorrect.Enabled   = Object.AddressRussianOnly;
	Items.HideObsoleteAddresses.Enabled  = Object.AddressRussianOnly;
	
EndProcedure

&AtClient
Procedure ChangeAttributesOnChangeOnlyRussia()
	
	If Not Object.AddressRussianOnly Then
		Object.CheckCorrectness      = False;
		Object.HideObsoleteAddresses = False;
	EndIf;
	
	ChangeAttributesOnChangeCheckCorrectness();
	
EndProcedure

&AtClient
Procedure ChangeAttributesOnChangeCheckCorrectness()
	
	Object.ProhibitEntryOfIncorrect = Object.CheckCorrectness;
	
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
