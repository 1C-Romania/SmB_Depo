
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("SaveUserData", Metadata);
	
	StructureOfCIAttributesAndKinds = New Structure;
	
	AddContactInformationAttributes();
	LoadSettings();
	
EndProcedure

// Procedure - event  handler BeforeClose.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Modified Then
		
		QuestionText = NStr("en='Contact information content was modified."
"Save changes?';ru='Состав контактной информации был изменен."
"Сохранить изменения?'");
		
		Notification = New NotifyDescription("BeforeCloseSaveOffered", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.Cancel, NStr("en='Edit content contact information';ru='Редактирование состава контактной информации'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - handler commands SaveAndClose.
//
&AtClient
Procedure SaveAndClose(Command)
	
	If Modified Then
		SaveSettings();
	EndIf;
	
	Close(PrintContentChanged);
	
EndProcedure

// Procedure - Cancel command handler.
//
&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	Close(PrintContentChanged);
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - events handler OnChange CounterpartyTIN attribute.
//
&AtClient
Procedure CounterpartyTINOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange MainContactPerson attribute.
//
&AtClient
Procedure MainContactPersonOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange OtherContactPersons attribute.
//
&AtClient
Procedure OtherContactPersonsOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange ResponsibleManager attribute.
//
&AtClient
Procedure ResponsibleManagerOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - assigned OnChange events handler of added attributes of contact information kinds.
//
&AtClient
Procedure Attachable_AddedCIKind_OnChange(Item)
	
	If Item.Parent = Items.ContactInformationContactPersons Then
		If ThisForm[Item.Name] = True AND MainContactPerson = False AND OtherContactPersons = False Then
			MainContactPerson = True;
		EndIf;
	ElsIf Item.Parent = Items.ContactInformationResponsibleManager Then
		If ThisForm[Item.Name] = True AND ResponsibleManager = False Then
			ResponsibleManager = True;
		EndIf;
	EndIf;
	
	SetModifiedFlag();

EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtServer
Procedure SaveSettings()
	
	UsedCIKinds = New Map;
	
	For Each KeyAndValue IN StructureOfCIAttributesAndKinds Do

		UsedCIKinds.Insert(KeyAndValue.Value, ThisForm[KeyAndValue.Key]);
			
	EndDo;
	
	CommonUse.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"UsedCIKinds", UsedCIKinds);
	CommonUse.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"CounterpartyTIN", CounterpartyTIN);
	CommonUse.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"MainContactPerson", MainContactPerson);
	CommonUse.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"OtherContactPersons", OtherContactPersons);
	CommonUse.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"ResponsibleManager", ResponsibleManager);
		
	Modified = False;
	PrintContentChanged = True;
		
EndProcedure

&AtServer
Procedure LoadSettings()
	
	UsedCIKinds = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"UsedCIKinds", New Map);
		
	CounterpartyTIN = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"CounterpartyTIN", True);
		
	MainContactPerson = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"MainContactPerson", True);
		
	OtherContactPersons = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"OtherContactPersons", True);
		
	ResponsibleManager = CommonUse.CommonSettingsStorageImport("ManagementStructureTheContactInformationOfTheCounterparty",
		"ResponsibleManager", True);
		
		
	For Each KeyAndValue IN StructureOfCIAttributesAndKinds Do
			
		UseKEY = UsedCIKinds.Get(KeyAndValue.Value);

		// If there is no available kind of contact information in saved user settings, then we set usage by default
		If UseKEY = Undefined Then
			ThisForm[KeyAndValue.Key] = SmallBusinessServer.SetPrintDefaultCIKind(KeyAndValue.Value);
		Else
			ThisForm[KeyAndValue.Key] = UseKEY;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure BeforeCloseSaveOffered(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		SaveSettings();
		Close(PrintContentChanged);
	ElsIf QuestionResult = DialogReturnCode.No Then
		Modified = False;
		Close(PrintContentChanged);
	EndIf;
	
EndProcedure

&AtServer
Procedure AddContactInformationAttributes()
	
	TypeDescriptionBoolean = New TypeDescription("Boolean");
	AttributesToAdd = New Array;
	
	Selection = SmallBusinessServer.GetAvailableForPrintingCIKinds().Select();
	
	RecNo = 0;
	While Selection.Next() Do
		
		RecNo = RecNo + 1;
		
		AttributeName = "AddedCIKind_" + RecNo;
		AttributesToAdd.Add(New FormAttribute(AttributeName, TypeDescriptionBoolean, , Selection.Description));
		StructureOfCIAttributesAndKinds.Insert(AttributeName, Selection.CIKind);
		
	EndDo;
	
	ChangeAttributes(AttributesToAdd);
	
	RecNo = 0;
	Selection.Reset();
	
	While Selection.Next() Do
		
		RecNo = RecNo + 1;
		
		If Selection.CIOwnerIndex = 1 Then
			
			GroupNumber = ?(RecNo % 3 = 0, 3, RecNo % 3);
			Parent = Items["ContactInformationCounterparty" + GroupNumber];
			
		ElsIf Selection.CIOwnerIndex = 2 Then
			
			Parent = Items.ContactInformationContactPersons;

		ElsIf Selection.CIOwnerIndex = 3 Then
			
			Parent = Items.ContactInformationResponsibleManager;
			
		EndIf;
		
		ItemName = "AddedCIKind_" + RecNo;
		AddItemFormsCheckBoxControl(ItemName, Parent);
		
	EndDo;
	
EndProcedure

&AtServer
Function AddItemFormsCheckBoxControl(ItemName, Parent = Undefined, DataPath = "")
	
	If IsBlankString(DataPath) Then 
		DataPath = ItemName;
	EndIf;
	
	FormItem = Items.Add(ItemName, Type("FormField"), Parent);
	FormItem.DataPath = DataPath;
	FormItem.Type = FormFieldType.CheckBoxField;
	FormItem.TitleLocation = FormItemTitleLocation.Right;
	FormItem.SetAction("OnChange", "Attachable_AddedCIKind_OnChange");
	
	Return FormItem;
	
EndFunction

&AtClient
Procedure SetModifiedFlag()
	
	Modified = True;
	
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
