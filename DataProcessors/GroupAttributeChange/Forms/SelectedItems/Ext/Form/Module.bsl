
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ChangingObjectKind = Parameters.ChangingObjectKind;
	ObjectDataProcessor = FormAttributeToValue("Object");
	MetadataObject = Metadata.FindByFullName(ChangingObjectKind);
	QueryText = ObjectDataProcessor.QueryText(MetadataObject);
	
	InitializeSettingsComposer();
	SettingsComposer.LoadSettings(Parameters.Settings);
	
	List.QueryText = QueryText;
	List.MainTable = ChangingObjectKind;
	UpdateSelectedListAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersComposerSettingsFilterSettings

&AtClient
Procedure SettingsComposerSettingsFilterOnEditEnd(Item, NewRow, CancelEdit)
	InitializeSelectedListUpdate();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterAfterDeleting(Item)
	InitializeSelectedListUpdate();
EndProcedure

&AtClient
Procedure SettingsComposerSettingsFilterBeforeAddingStart(Item, Cancel, Copy, Parent, Group)
	DetachIdleHandler("UpdateSelectedList");
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	Result = SettingsComposer.Settings;
	Close(Result);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure InitializeSettingsComposer()
	If Not IsBlankString(ChangingObjectKind) Then
		DataCompositionSchema = DataCompositionSchema(QueryText);
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	EndIf;
EndProcedure

&AtServer
Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

&AtServer
Procedure UpdateSelectedListAtServer()
	
	List.SettingsComposer.LoadSettings(SettingsComposer.Settings);
	
	Structure = List.SettingsComposer.Settings.Structure;
	Structure.Clear();
	DataCompositionGroup = Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	Choice = List.SettingsComposer.Settings.Selection;
	ComboBox = Choice.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
EndProcedure

&AtClient
Procedure InitializeSelectedListUpdate()
	DetachIdleHandler("UpdateSelectedList");
	If Items.GroupSelectedObjects.Visible Then
		AttachIdleHandler("UpdateSelectedList", 1, True);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateSelectedList()
	UpdateSelectedListAtServer();
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
